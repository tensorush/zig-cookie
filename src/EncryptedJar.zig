//! HTTP cookie jar that provides authenticated encryption.

const std = @import("std");

const Jar = @import("Jar.zig");
const Key = @import("Key.zig");
const Cookie = @import("Cookie.zig");

const EncryptedJar = @This();

/// Original cookie values accessed by encrypted values.
original_values: OriginalValueMap = .empty,
/// Encryption key bytes.
key_bytes: [Key.ENCRYPTION_KEY_SIZE]u8,
/// Basic cookie jar.
jar: Jar,

const Aes256Gcm = std.crypto.aead.aes_gcm.Aes256Gcm;
const OriginalValueMap = std.StringHashMapUnmanaged([]const u8);

/// Initialize encrypted cookie jar.
pub fn init(allocator: std.mem.Allocator, key: Key) EncryptedJar {
    return .{ .key_bytes = key.encryption_bytes, .jar = .init(allocator) };
}

/// Deinitialize encrypted cookie jar.
pub fn deinit(self: *EncryptedJar) void {
    var encrypted_value_iter = self.original_values.keyIterator();
    while (encrypted_value_iter.next()) |encrypted_value| {
        self.jar.allocator.free(encrypted_value.*);
    }
    self.original_values.deinit(self.jar.allocator);
    self.jar.deinit();
    self.* = undefined;
}

/// Encrypt cookie for authenticated encryption.
fn encrypt(self: *EncryptedJar, cookie: *Cookie) std.mem.Allocator.Error!void {
    var value = try self.jar.allocator.alloc(u8, Aes256Gcm.nonce_length + cookie.value.len + Aes256Gcm.tag_length);
    defer self.jar.allocator.free(value);

    const c = value[Aes256Gcm.nonce_length .. Aes256Gcm.nonce_length + cookie.value.len];
    const nonce = value[0..Aes256Gcm.nonce_length];
    var tag: [Aes256Gcm.tag_length]u8 = undefined;
    std.crypto.random.bytes(nonce);
    Aes256Gcm.encrypt(c, &tag, cookie.value, cookie.name, nonce.*, self.key_bytes);

    @memcpy(value[Aes256Gcm.nonce_length + cookie.value.len ..], &tag);
    const encrypted_value = try self.jar.allocator.alloc(u8, std.base64.standard.Encoder.calcSize(value.len));
    _ = std.base64.standard.Encoder.encode(encrypted_value, value);

    const res = try self.original_values.getOrPut(self.jar.allocator, encrypted_value);
    if (res.found_existing) {
        self.jar.allocator.free(encrypted_value);
        res.value_ptr.* = cookie.value;
        cookie.value = res.key_ptr.*;
    } else {
        try self.original_values.put(self.jar.allocator, encrypted_value, cookie.value);
        cookie.value = encrypted_value;
    }
}

/// Decrypt cookie for authenticated decryption.
fn decrypt(self: EncryptedJar, cookie: Cookie) bool {
    const value_size = std.base64.standard.Decoder.calcSizeForSlice(cookie.value) catch return false;
    var value = self.jar.allocator.alloc(u8, value_size) catch return false;
    defer self.jar.allocator.free(value);

    std.base64.standard.Decoder.decode(value, cookie.value) catch return false;

    const c = value[Aes256Gcm.nonce_length .. value.len - Aes256Gcm.tag_length];
    const m = self.jar.allocator.alloc(u8, c.len) catch return false;
    defer self.jar.allocator.free(m);

    const nonce = value[0..Aes256Gcm.nonce_length];
    var tag: [Aes256Gcm.tag_length]u8 = undefined;
    @memcpy(&tag, value[value.len - Aes256Gcm.tag_length ..]);
    Aes256Gcm.decrypt(m, c, tag, cookie.name, nonce.*, self.key_bytes) catch return false;
    return true;
}

/// Retrieve and decrypt cookie by name.
pub fn get(self: EncryptedJar, name: []const u8) ?Cookie {
    var cookie = self.jar.get(name) orelse return null;
    if (self.decrypt(cookie)) {
        cookie.value = self.original_values.get(cookie.value).?;
        return cookie;
    } else {
        return null;
    }
}

/// Add cookie to encrypted jar.
pub fn addOriginal(self: *EncryptedJar, cookie: Cookie) std.mem.Allocator.Error!void {
    var new_cookie = cookie;
    try self.encrypt(&new_cookie);
    try self.jar.addOriginal(new_cookie);
}

/// Add cookie to encrypted cookie modifications storage.
pub fn add(self: *EncryptedJar, cookie: Cookie) std.mem.Allocator.Error!void {
    var new_cookie = cookie;
    try self.encrypt(&new_cookie);
    try self.jar.add(new_cookie);
}

/// Remove cookie from encrypted cookie modifications storage.
pub fn remove(self: *EncryptedJar, cookie: Cookie) std.mem.Allocator.Error!void {
    try self.jar.remove(cookie);
}

test EncryptedJar {
    const key: Key = .initFrom(&.{ 89, 202, 200, 125, 230, 90, 197, 245, 166, 249, 34, 169, 135, 31, 20, 197, 94, 154, 254, 79, 60, 26, 8, 143, 254, 24, 116, 138, 92, 225, 159, 60, 157, 41, 135, 129, 31, 226, 196, 16, 198, 168, 134, 4, 42, 1, 196, 24, 57, 103, 241, 147, 201, 185, 233, 10, 180, 170, 187, 89, 252, 137, 110, 107 });
    var encrypted: EncryptedJar = .init(std.testing.allocator, key);
    defer encrypted.deinit();

    try encrypted.add(.{ .name = "encrypted_with_ring014", .value = "Tamper-proof" });
    try encrypted.add(.{ .name = "encrypted_with_ring016", .value = "Tamper-proof" });

    try std.testing.expectEqualStrings(encrypted.get("encrypted_with_ring014").?.value, "Tamper-proof");
    try std.testing.expectEqualStrings(encrypted.get("encrypted_with_ring016").?.value, "Tamper-proof");
}

test "simple" {
    var signed: EncryptedJar = .init(std.testing.allocator, Key.initRandom());
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
    var signed: EncryptedJar = .init(std.testing.allocator, Key.initRandom());
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
