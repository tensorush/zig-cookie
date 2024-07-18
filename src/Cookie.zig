//! HTTP cookie printing and parsing.

const std = @import("std");
const Datetime = @import("Datetime.zig");

const Cookie = @This();

pub const Error = error{
    MissingPair,
    EmptyName,
    Utf8Error,
} || Datetime.Error;

pub const Expiration = union(enum) {
    datetime: Datetime,
    session: void,
};

pub const SameSite = enum {
    Strict,
    None,
    Lax,
};

expires: ?Expiration = null,
same_site: ?SameSite = null,
domain: ?[]const u8 = null,
max_age: ?u64 = null,
partitioned: ?bool = null,
http_only: ?bool = null,
path: ?[]const u8 = null,
secure: ?bool = null,
value: []const u8 = "",
name: []const u8,

/// Set expires field from HTTP datetime value.
pub fn setExpires(self: *Cookie, value: []const u8) Datetime.Error!void {
    self.expires = .{ .datetime = try Datetime.parse(value) };
}

/// Turn into permanent cookie.
pub fn makePermanent(self: *Cookie) void {
    self.max_age = 20 * 365 * std.time.s_per_day;
    self.expires = .{ .datetime = Datetime.fromTimestamp(std.time.timestamp() + self.max_age) };
}

/// Turn into removal cookie.
pub fn makeRemoval(self: *Cookie) void {
    self.value = "";
    self.max_age = 0;
    self.expires = .{ .datetime = Datetime.fromTimestamp(std.time.timestamp() + 365 * std.time.s_per_day) };
}

/// Parse cookie from string, specifying whether name and value need escaping.
pub fn parse(cookie_str: []const u8) Error!Cookie {
    var attr_iter = std.mem.tokenizeScalar(u8, cookie_str, ';');
    const name_value = attr_iter.next() orelse return error.MissingPair;
    const name_value_idx = std.mem.indexOfScalar(u8, name_value, '=') orelse return error.MissingPair;
    var name = std.mem.trim(u8, name_value[0..name_value_idx], std.ascii.whitespace[0..]);
    var value = std.mem.trim(u8, name_value[name_value_idx + 1 ..], std.ascii.whitespace[0..]);

    if (name.len == 0) {
        return error.EmptyName;
    }

    var cookie = Cookie{ .name = name, .value = value };

    outer: while (attr_iter.next()) |attr| {
        if (std.mem.indexOfScalar(u8, attr, '=')) |idx| {
            name = std.mem.trim(u8, attr[0..idx], std.ascii.whitespace[0..]);
            value = std.mem.trim(u8, attr[idx + 1 ..], std.ascii.whitespace[0..]);
        } else {
            name = std.mem.trim(u8, attr, std.ascii.whitespace[0..]);
            value = "";
        }

        if (std.ascii.eqlIgnoreCase(name, "secure")) {
            cookie.secure = true;
        } else if (std.ascii.eqlIgnoreCase(name, "httponly")) {
            cookie.http_only = true;
        } else if (std.ascii.eqlIgnoreCase(name, "max-age")) {
            if (value.len > 0 and value[0] == '-') {
                cookie.max_age = 0;
            } else {
                for (value) |char| {
                    if (std.ascii.isDigit(char) == false) {
                        continue :outer;
                    }
                }
                cookie.max_age = std.fmt.parseInt(u64, value, 10) catch std.math.maxInt(u64);
            }
        } else if (std.ascii.eqlIgnoreCase(name, "domain") and value.len > 0) {
            cookie.domain = value;
        } else if (std.ascii.eqlIgnoreCase(name, "path")) {
            cookie.path = value;
        } else if (std.ascii.eqlIgnoreCase(name, "samesite")) {
            if (std.ascii.eqlIgnoreCase(value, "strict")) {
                cookie.same_site = .Strict;
            } else if (std.ascii.eqlIgnoreCase(value, "lax")) {
                cookie.same_site = .Lax;
            } else if (std.ascii.eqlIgnoreCase(value, "none")) {
                cookie.same_site = .None;
            }
        } else if (std.ascii.eqlIgnoreCase(name, "partitioned")) {
            cookie.partitioned = true;
        } else if (std.ascii.eqlIgnoreCase(name, "expires")) {
            cookie.expires = .{ .datetime = try Datetime.parse(value) };
        }
    }

    return cookie;
}

/// Print cookie to writer.
pub fn format(self: Cookie, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    try writer.print("{s}={s}", .{ self.name, self.value });

    if (self.http_only) |_| {
        try writer.writeAll("; HttpOnly");
    }

    if (self.same_site) |same_site| {
        try writer.print("; SameSite={s}", .{@tagName(same_site)});
    }

    if (self.partitioned) |_| {
        try writer.writeAll("; Partitioned");
    }

    if (self.partitioned == true or
        self.secure != null and self.secure == true or
        self.secure == null and self.same_site == .None)
    {
        try writer.writeAll("; Secure");
    }

    if (self.path) |path| {
        try writer.print("; Path={s}", .{path});
    }

    if (self.domain) |domain| {
        try writer.print("; Domain={s}", .{domain});
    }

    if (self.max_age) |max_age| {
        try writer.print("; Max-Age={d}", .{max_age});
    }

    if (self.expires) |expires| {
        if (std.meta.activeTag(expires) == .datetime) {
            try writer.print("; Expires={s}", .{expires.datetime});
        }
    }
}

test format {
    try std.testing.expectFmt("foo=bar", "{}", .{Cookie{ .name = "foo", .value = "bar" }});
    try std.testing.expectFmt("foo=bar; HttpOnly", "{}", .{Cookie{ .name = "foo", .value = "bar", .http_only = true }});
    try std.testing.expectFmt("foo=bar; Max-Age=10", "{}", .{Cookie{ .name = "foo", .value = "bar", .max_age = 10 }});
    try std.testing.expectFmt("foo=bar; Secure", "{}", .{Cookie{ .name = "foo", .value = "bar", .secure = true }});
    try std.testing.expectFmt("foo=bar; Path=/", "{}", .{Cookie{ .name = "foo", .value = "bar", .path = "/" }});
    try std.testing.expectFmt("foo=bar; Domain=ziglang.org", "{}", .{Cookie{ .name = "foo", .value = "bar", .domain = "ziglang.org" }});
    try std.testing.expectFmt("foo=bar; SameSite=Strict", "{}", .{Cookie{ .name = "foo", .value = "bar", .same_site = .Strict }});
    try std.testing.expectFmt("foo=bar; SameSite=Lax", "{}", .{Cookie{ .name = "foo", .value = "bar", .same_site = .Lax }});

    var cookie = Cookie{ .name = "foo", .value = "bar", .same_site = .None };
    try std.testing.expectFmt("foo=bar; SameSite=None; Secure", "{}", .{cookie});

    cookie.partitioned = true;
    try std.testing.expectFmt("foo=bar; SameSite=None; Partitioned; Secure", "{}", .{cookie});

    cookie.same_site = null;
    try std.testing.expectFmt("foo=bar; Partitioned; Secure", "{}", .{cookie});

    cookie.secure = false;
    try std.testing.expectFmt("foo=bar; Partitioned; Secure", "{}", .{cookie});

    cookie.secure = null;
    try std.testing.expectFmt("foo=bar; Partitioned; Secure", "{}", .{cookie});

    cookie.partitioned = null;
    try std.testing.expectFmt("foo=bar", "{}", .{cookie});

    cookie = Cookie{ .name = "foo", .value = "bar", .same_site = .None, .secure = false };
    try std.testing.expectFmt("foo=bar; SameSite=None", "{}", .{cookie});

    cookie.secure = true;
    try std.testing.expectFmt("foo=bar; SameSite=None; Secure", "{}", .{cookie});

    cookie = Cookie{ .name = "foo", .value = "bar" };
    try cookie.setExpires("Mon, 08 Feb 2016 07:28:00 GMT");
    try std.testing.expectFmt("foo=bar; Expires=Mon, 08 Feb 2016 07:28:00 GMT", "{}", .{cookie});
}

test parse {
    var cookie = try parse("foo=bar");
    try std.testing.expectEqualStrings(cookie.name, "foo");
    try std.testing.expectEqualStrings(cookie.value, "bar");

    cookie = try parse("foo = bar");
    try std.testing.expectEqualStrings(cookie.name, "foo");
    try std.testing.expectEqualStrings(cookie.value, "bar");

    cookie = try parse(" foo=bar ;Domain= ");
    try std.testing.expectEqualStrings(cookie.name, "foo");
    try std.testing.expectEqualStrings(cookie.value, "bar");

    cookie = try parse("foo=bar; SameSite=Lax");
    try std.testing.expectEqualStrings(cookie.name, "foo");
    try std.testing.expectEqualStrings(cookie.value, "bar");
    try std.testing.expectEqual(cookie.same_site, SameSite.Lax);

    cookie = try parse("foo=bar; Expires=Mon, 08 Feb 2016 07:28:00 GMT");
    try std.testing.expectEqualStrings(cookie.name, "foo");
    try std.testing.expectEqualStrings(cookie.value, "bar");
    try std.testing.expectEqual(cookie.expires.?.datetime, try Datetime.parse("Mon, 08 Feb 2016 07:28:00 GMT"));

    try std.testing.expectError(error.MissingPair, parse("bar"));
    try std.testing.expectError(error.EmptyName, parse("=bar"));
    try std.testing.expectError(error.EmptyName, parse(" =bar"));

    cookie = try parse("foo=bar=baz");
    try std.testing.expectEqualStrings(cookie.name, "foo");
    try std.testing.expectEqualStrings(cookie.value, "bar=baz");

    cookie = try parse("foo=\"\"bar\"\"");
    try std.testing.expectEqualStrings(cookie.name, "foo");
    try std.testing.expectEqualStrings(cookie.value, "\"\"bar\"\"");

    cookie = try parse("foo=  \"bar");
    try std.testing.expectEqualStrings(cookie.value, "\"bar");
    cookie = try parse("foo=\"bar  ");
    try std.testing.expectEqualStrings(cookie.value, "\"bar");
    cookie = try parse("foo=\"\"bar\"");
    try std.testing.expectEqualStrings(cookie.value, "\"\"bar\"");
    cookie = try parse("foo=\"\"bar  \"");
    try std.testing.expectEqualStrings(cookie.value, "\"\"bar  \"");
    cookie = try parse("foo=\"\"bar  \"  ");
    try std.testing.expectEqualStrings(cookie.value, "\"\"bar  \"");

    cookie = try parse("foo=bar; Partitioned");
    try std.testing.expect(cookie.partitioned.?);

    cookie = try parse("foo=bar ;HttpOnly");
    try std.testing.expect(cookie.http_only.?);

    cookie = try parse("foo=bar; httponly");
    try std.testing.expect(cookie.http_only.?);

    cookie = try parse("foo=bar; HTTPONLY");
    try std.testing.expect(cookie.http_only.?);

    cookie = try parse("foo=bar;HTTPONLY=whatever");
    try std.testing.expect(cookie.http_only.?);

    cookie = try parse("foo=bar; HttpOnly; Secure");
    try std.testing.expect(cookie.http_only.?);
    try std.testing.expect(cookie.secure.?);

    cookie = try parse("foo=bar; HttpOnly; secure=aaaa");
    try std.testing.expect(cookie.http_only.?);
    try std.testing.expect(cookie.secure.?);

    cookie = try parse("foo=bar; HttpOnly; Secure; Max-Age=0");
    try std.testing.expectEqual(cookie.max_age.?, 0);
    try std.testing.expect(cookie.http_only.?);
    try std.testing.expect(cookie.secure.?);

    cookie = try parse("foo=bar; HttpOnly; Secure; Max-Age = 0");
    try std.testing.expectEqual(cookie.max_age.?, 0);
    try std.testing.expect(cookie.http_only.?);
    try std.testing.expect(cookie.secure.?);

    cookie = try parse("foo=bar; HttpOnly; Secure; Max-Age=-1337");
    try std.testing.expectEqual(cookie.max_age.?, 0);
    try std.testing.expect(cookie.http_only.?);
    try std.testing.expect(cookie.secure.?);

    cookie = try parse("foo=bar; HttpOnly; Secure; Max-Age = -1337");
    try std.testing.expectEqual(cookie.max_age.?, 0);
    try std.testing.expect(cookie.http_only.?);
    try std.testing.expect(cookie.secure.?);

    cookie = try parse("foo=bar; HttpOnly; Secure; Max-Age =   60");
    try std.testing.expectEqual(cookie.max_age.?, 60);
    try std.testing.expect(cookie.http_only.?);
    try std.testing.expect(cookie.secure.?);

    cookie = try parse("foo=bar; HttpOnly; Secure; Max-Age=4; pAth= /foo");
    try std.testing.expectEqualStrings(cookie.path.?, "/foo");
    try std.testing.expectEqual(cookie.max_age.?, 4);
    try std.testing.expect(cookie.http_only.?);
    try std.testing.expect(cookie.secure.?);

    cookie = try parse("foo=bar; HttpOnly; Secure; Max-Age=4; Path=/foo; Domain=www.zachtronics.com");
    try std.testing.expectEqualStrings(cookie.domain.?, "www.zachtronics.com");
    try std.testing.expectEqualStrings(cookie.path.?, "/foo");
    try std.testing.expectEqual(cookie.max_age.?, 4);
    try std.testing.expect(cookie.http_only.?);
    try std.testing.expect(cookie.secure.?);

    cookie = try parse("foo=bar; HttpOnly; Secure; Max-Age=4; Path=/foo; Domain=www.zachtronics.com; Expires=Mon, 08 Feb 2016 07:28:00 GMT");
    try std.testing.expectEqual(cookie.expires.?.datetime, try Datetime.parse("Mon, 08 Feb 2016 07:28:00 GMT"));
    try std.testing.expectEqualStrings(cookie.domain.?, "www.zachtronics.com");
    try std.testing.expectEqualStrings(cookie.path.?, "/foo");
    try std.testing.expectEqual(cookie.max_age.?, 4);
    try std.testing.expect(cookie.http_only.?);
    try std.testing.expect(cookie.secure.?);
}
