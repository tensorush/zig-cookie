//! HTTP cookie jar that provides modification tracking.

const std = @import("std");
pub const Cookie = @import("Cookie.zig");

const Jar = @This();
const DeltaCookieSet = std.StringHashMapUnmanaged(DeltaCookie);

/// Cookie that knows if it should be removed on client-side when sent to client.
pub const DeltaCookie = struct {
    is_removal: bool = false,
    cookie: Cookie,
};

/// Original cookies.
originals: DeltaCookieSet = DeltaCookieSet{},
/// Cookie modifications.
deltas: DeltaCookieSet = DeltaCookieSet{},
allocator: std.mem.Allocator,

/// Initialize cookie jar.
pub fn init(allocator: std.mem.Allocator) Jar {
    return .{ .allocator = allocator };
}

/// Deinitialize cookie jar.
pub fn deinit(self: *Jar) void {
    self.originals.deinit(self.allocator);
    self.deltas.deinit(self.allocator);
}

/// Retrieve cookie pointer by name.
pub fn getPtr(self: Jar, name: []const u8) ?*Cookie {
    const delta = self.deltas.getPtr(name) orelse self.originals.getPtr(name) orelse return null;
    return if (delta.is_removal) null else &delta.cookie;
}

/// Add cookie to jar.
pub fn addOriginal(self: *Jar, cookie: Cookie) !void {
    try self.originals.put(self.allocator, cookie.name, .{ .cookie = cookie });
}

/// Add cookie to delta storage.
pub fn add(self: *Jar, cookie: Cookie) !void {
    try self.deltas.put(self.allocator, cookie.name, .{ .cookie = cookie });
}

/// Remove cookie with delta storage.
pub fn remove(self: *Jar, cookie: Cookie) !void {
    var removed = cookie;
    if (self.originals.contains(removed.name)) {
        removed.makeRemoval();
        try self.deltas.put(self.allocator, removed.name, .{ .is_removal = true, .cookie = removed });
    } else {
        _ = self.deltas.remove(removed.name);
    }
}

/// Remove cookie from jar and delta storage.
pub fn removeAll(self: *Jar, name: []const u8) void {
    _ = self.originals.remove(name);
    _ = self.deltas.remove(name);
}

/// Clear all delta cookies.
pub fn clearDelta(self: *Jar) void {
    self.deltas.clearRetainingCapacity();
}

test Jar {
    var jar = Jar.init(std.testing.allocator);
    defer jar.deinit();

    try jar.addOriginal(.{ .name = "original", .value = "original" });
    try jar.addOriginal(.{ .name = "original2", .value = "original2" });
    try std.testing.expectEqualStrings(jar.getPtr("original2").?.value, "original2");

    try jar.add(.{ .name = "test", .value = "test" });
    try jar.add(.{ .name = "test2", .value = "test2" });
    try jar.add(.{ .name = "test3", .value = "test3" });
    try jar.add(.{ .name = "test4", .value = "test4" });
    try std.testing.expectEqualStrings(jar.getPtr("test2").?.value, "test2");

    try jar.remove(.{ .name = "test" });
    try jar.remove(.{ .name = "original" });
    try std.testing.expectEqual(jar.getPtr("test"), null);
    try std.testing.expectEqual(jar.getPtr("original"), null);
}

test {
    std.testing.refAllDecls(@This());
}
