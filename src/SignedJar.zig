//! HTTP cookie jar that provides authentication.

const std = @import("std");
const Jar = @import("Jar.zig");
const Key = @import("Key.zig");
const Cookie = @import("Cookie.zig");

const SignedJar = @This();

/// Original cookie values accessed by signed values.
original_values: OriginalValueMap = .empty,
/// Signing key bytes.
key_bytes: [Key.SIGNING_KEY_SIZE]u8,
/// Basic cookie jar.
jar: Jar,

const BASE64_DIGEST_SIZE = 44;

const HmacSha256 = std.crypto.auth.hmac.sha2.HmacSha256;
const OriginalValueMap = std.StringHashMapUnmanaged([]const u8);

/// Initialize signed cookie jar.
pub fn init(allocator: std.mem.Allocator, key: Key) SignedJar {
    return .{ .key_bytes = key.signing_bytes, .jar = .init(allocator) };
}

/// Deinitialize signed cookie jar.
pub fn deinit(self: *SignedJar) void {
    var signed_value_iter = self.original_values.keyIterator();
    while (signed_value_iter.next()) |signed_value| {
        self.jar.allocator.free(signed_value.*);
    }
    self.original_values.deinit(self.jar.allocator);
    self.jar.deinit();
    self.* = undefined;
}

/// Sign cookie for authentication.
fn sign(self: *SignedJar, cookie: *Cookie) std.mem.Allocator.Error!void {
    var digest: [HmacSha256.mac_length]u8 = undefined;
    HmacSha256.create(&digest, cookie.value, &self.key_bytes);
    var signature: [BASE64_DIGEST_SIZE]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&signature, &digest);
    const signed_value = try std.mem.concat(self.jar.allocator, u8, &.{ &signature, cookie.value });
    const res = try self.original_values.getOrPut(self.jar.allocator, signed_value);
    if (res.found_existing) {
        self.jar.allocator.free(signed_value);
        res.value_ptr.* = cookie.value;
        cookie.value = res.key_ptr.*;
    } else {
        try self.original_values.put(self.jar.allocator, signed_value, cookie.value);
        cookie.value = signed_value;
    }
}

/// Verify cookie for authentication.
fn verify(self: SignedJar, cookie: Cookie) bool {
    if (cookie.value.len < BASE64_DIGEST_SIZE) {
        return false;
    }
    var actual_digest: [HmacSha256.mac_length]u8 = undefined;
    std.base64.standard.Decoder.decode(&actual_digest, cookie.value[0..BASE64_DIGEST_SIZE]) catch return false;
    var expected_digest: [HmacSha256.mac_length]u8 = undefined;
    HmacSha256.create(&expected_digest, cookie.value[BASE64_DIGEST_SIZE..], &self.key_bytes);
    return std.mem.eql(u8, &actual_digest, &expected_digest);
}

/// Retrieve and verify cookie by name.
pub fn get(self: SignedJar, name: []const u8) ?Cookie {
    var cookie = self.jar.get(name) orelse return null;
    if (self.verify(cookie)) {
        cookie.value = self.original_values.get(cookie.value).?;
        return cookie;
    } else {
        return null;
    }
}

/// Add cookie to signed jar.
pub fn add(self: *SignedJar, cookie: Cookie) std.mem.Allocator.Error!void {
    var new_cookie = cookie;
    try self.sign(&new_cookie);
    try self.jar.add(new_cookie);
}

/// Add cookie to signed cookie modifications storage.
pub fn addOriginal(self: *SignedJar, cookie: Cookie) std.mem.Allocator.Error!void {
    var new_cookie = cookie;
    try self.sign(&new_cookie);
    try self.jar.addOriginal(new_cookie);
}

/// Remove cookie from signed cookie modifications storage.
pub fn remove(self: *SignedJar, cookie: Cookie) std.mem.Allocator.Error!void {
    try self.jar.remove(cookie);
}

test SignedJar {
    const key: Key = .initFrom(&.{ 89, 202, 200, 125, 230, 90, 197, 245, 166, 249, 34, 169, 135, 31, 20, 197, 94, 154, 254, 79, 60, 26, 8, 143, 254, 24, 116, 138, 92, 225, 159, 60, 157, 41, 135, 129, 31, 226, 196, 16, 198, 168, 134, 4, 42, 1, 196, 24, 57, 103, 241, 147, 201, 185, 233, 10, 180, 170, 187, 89, 252, 137, 110, 107 });
    var signed: SignedJar = .init(std.testing.allocator, key);
    defer signed.deinit();

    try signed.add(.{ .name = "signed_with_ring014", .value = "Tamper-proof" });
    try signed.add(.{ .name = "signed_with_ring016", .value = "Tamper-proof" });

    try std.testing.expectEqualStrings(signed.get("signed_with_ring014").?.value, "Tamper-proof");
    try std.testing.expectEqualStrings(signed.get("signed_with_ring016").?.value, "Tamper-proof");
}

test "simple" {
    var signed: SignedJar = .init(std.testing.allocator, Key.initRandom());
    defer signed.deinit();

    var jar_iter = signed.jar.iterator();
    while (jar_iter.next()) |_| {}
    try std.testing.expectEqual(jar_iter.count, 0);

    try signed.add(.{ .name = "name", .value = "val" });

    jar_iter = signed.jar.iterator();
    while (jar_iter.next()) |_| {}
    try std.testing.expectEqual(jar_iter.count, 1);

    try std.testing.expectEqualStrings(signed.get("name").?.value, "val");

    try signed.add(.{ .name = "another", .value = "two" });

    jar_iter = signed.jar.iterator();
    while (jar_iter.next()) |_| {}
    try std.testing.expectEqual(jar_iter.count, 2);

    try signed.jar.remove(.{ .name = "another" });

    jar_iter = signed.jar.iterator();
    while (jar_iter.next()) |_| {}
    try std.testing.expectEqual(jar_iter.count, 1);

    try signed.remove(.{ .name = "name" });

    jar_iter = signed.jar.iterator();
    while (jar_iter.next()) |_| {}
    try std.testing.expectEqual(jar_iter.count, 0);
}

test "secure" {
    var signed: SignedJar = .init(std.testing.allocator, Key.initRandom());
    defer signed.deinit();

    try signed.add(.{ .name = "secure", .value = "secure" });
    try std.testing.expectEqualStrings(signed.get("secure").?.value, "secure");

    var cookie = signed.jar.get("secure").?;
    cookie.value = "vulnerable";
    try signed.jar.add(cookie);
    try std.testing.expectEqual(signed.get("secure"), null);

    cookie = signed.jar.get("secure").?;
    cookie.value = "foobar";
    try signed.jar.add(cookie);
    try std.testing.expectEqual(signed.get("secure"), null);
}
