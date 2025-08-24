//! HTTP cookie jar that provides modification tracking.

const std = @import("std");

const Cookie = @import("Cookie.zig");

const Jar = @This();

/// Original cookies accessed by name.
originals: DeltaCookieMap = .empty,
/// Cookie modifications accessed by name.
deltas: DeltaCookieMap = .{},
/// Internal allocator.
allocator: std.mem.Allocator,

const DeltaCookieMap = std.StringHashMapUnmanaged(DeltaCookie);

/// Cookie that knows if it should be removed on client-side when sent to client.
pub const DeltaCookie = struct {
    is_removal: bool = false,
    cookie: Cookie,
};

/// Initialize cookie jar.
pub fn init(allocator: std.mem.Allocator) Jar {
    return .{ .allocator = allocator };
}

/// Deinitialize cookie jar.
pub fn deinit(self: *Jar) void {
    self.originals.deinit(self.allocator);
    self.deltas.deinit(self.allocator);
    self.* = undefined;
}

/// Retrieve cookie by name.
pub fn get(self: Jar, name: []const u8) ?Cookie {
    const delta = self.deltas.get(name) orelse self.originals.get(name) orelse return null;
    return if (delta.is_removal) null else delta.cookie;
}

/// Add cookie to jar.
pub fn addOriginal(self: *Jar, cookie: Cookie) std.mem.Allocator.Error!void {
    try self.originals.put(self.allocator, cookie.name, .{ .cookie = cookie });
}

/// Add cookie to cookie modifications storage.
pub fn add(self: *Jar, cookie: Cookie) std.mem.Allocator.Error!void {
    try self.deltas.put(self.allocator, cookie.name, .{ .cookie = cookie });
}

/// Remove cookie from cookie modifications storage.
pub fn remove(self: *Jar, cookie: Cookie) std.mem.Allocator.Error!void {
    var removed = cookie;
    if (self.originals.contains(removed.name)) {
        removed.makeRemoval();
        try self.deltas.put(self.allocator, removed.name, .{ .is_removal = true, .cookie = removed });
    } else {
        _ = self.deltas.remove(removed.name);
    }
}

/// Remove cookie from jar and cookie modifications storage.
pub fn removeAll(self: *Jar, name: []const u8) void {
    _ = self.originals.remove(name);
    _ = self.deltas.remove(name);
}

/// Clear all cookie modifications.
pub fn clearDelta(self: *Jar) void {
    self.deltas.clearRetainingCapacity();
}

/// Create jar iterator.
pub fn iterator(self: *Jar) Iterator {
    return .{
        .original_iter = self.originals.iterator(),
        .delta_iter = self.deltas.iterator(),
        .deltas = self.deltas,
    };
}

/// Cookie jar iterator.
pub const Iterator = struct {
    original_iter: DeltaCookieMap.Iterator,
    delta_iter: DeltaCookieMap.Iterator,
    deltas: DeltaCookieMap,
    count: usize = 0,

    /// Retrieve next cookie present in jar.
    pub fn next(self: *Iterator) ?Cookie {
        while (self.delta_iter.next()) |delta| {
            if (!delta.value_ptr.is_removal) {
                self.count += 1;
                return delta.value_ptr.cookie;
            }
        }
        while (self.original_iter.next()) |original| {
            if (!self.deltas.contains(original.key_ptr.*) and !original.value_ptr.is_removal) {
                self.count += 1;
                return original.value_ptr.cookie;
            }
        }
        return null;
    }
};

test Jar {
    var jar: Jar = .init(std.testing.allocator);
    defer jar.deinit();

    try jar.addOriginal(.{ .name = "original", .value = "original" });
    try jar.addOriginal(.{ .name = "original2", .value = "original2" });
    try std.testing.expectEqualStrings(jar.get("original2").?.value, "original2");

    try jar.add(.{ .name = "test", .value = "test" });
    try jar.add(.{ .name = "test2", .value = "test2" });
    try jar.add(.{ .name = "test3", .value = "test3" });
    try jar.add(.{ .name = "test4", .value = "test4" });
    try std.testing.expectEqualStrings(jar.get("test2").?.value, "test2");

    try jar.remove(.{ .name = "test" });
    try jar.remove(.{ .name = "original" });
    try std.testing.expectEqual(jar.get("test"), null);
    try std.testing.expectEqual(jar.get("original"), null);

    var jar_iter = jar.iterator();
    while (jar_iter.next()) |_| {}
    try std.testing.expectEqual(jar_iter.count, 4);
}
