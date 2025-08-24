//! Cryptographic master key used by `SignedJar` and `EncryptedJar`.

const std = @import("std");

const Key = @This();

/// Encryption key bytes.
encryption_bytes: [ENCRYPTION_KEY_SIZE]u8 = undefined,
/// Signing key bytes.
signing_bytes: [SIGNING_KEY_SIZE]u8 = undefined,

pub const SIGNING_KEY_SIZE = 1 << 5;
pub const ENCRYPTION_KEY_SIZE = 1 << 5;
const INITIAL_KEYING_MATERIAL = "COOKIE;SIGNED:HMAC-SHA256;PRIVATE:AEAD-AES-256-GCM";

/// Initialize from a 512-bit cryptographically random byte slice.
pub fn initFrom(bytes: []const u8) Key {
    var key: Key = .{};
    @memcpy(&key.signing_bytes, bytes[0..SIGNING_KEY_SIZE]);
    @memcpy(&key.encryption_bytes, bytes[SIGNING_KEY_SIZE..]);
    return key;
}

/// Initialize with CSPRNG.
pub fn initRandom() Key {
    var key: Key = .{};
    std.crypto.random.bytes(&key.signing_bytes);
    std.crypto.random.bytes(&key.encryption_bytes);
    return key;
}

/// Initialize from salt with HKDF.
pub fn initRandomSalt(salt: []const u8) Key {
    const master_key_bytes = std.crypto.kdf.hkdf.HkdfSha256.extract(salt, INITIAL_KEYING_MATERIAL);
    var bytes: [SIGNING_KEY_SIZE + ENCRYPTION_KEY_SIZE]u8 = undefined;
    std.crypto.kdf.hkdf.HkdfSha256.expand(&bytes, "", master_key_bytes);
    return initFrom(&bytes);
}

test initFrom {
    var bytes: [64]u8 = undefined;
    for (&bytes, 0..) |*byte, i| {
        byte.* = @intCast(i);
    }
    const key: Key = .initFrom(&bytes);

    try std.testing.expectEqualSlices(u8, bytes[0..32], &key.signing_bytes);
    try std.testing.expectEqualSlices(u8, bytes[32..], &key.encryption_bytes);
}

test initRandomSalt {
    var bytes: [64]u8 = undefined;
    for (&bytes, 0..) |*byte, i| {
        byte.* = @intCast(i);
    }
    const key_a: Key = .initRandomSalt(bytes[0..32]);
    const key_b: Key = .initRandomSalt(bytes[0..32]);
    const key_c: Key = .initRandomSalt(bytes[32..64]);

    try std.testing.expectEqual(key_a.signing_bytes, key_b.signing_bytes);
    try std.testing.expectEqual(key_a.encryption_bytes, key_b.encryption_bytes);
    try std.testing.expect(!std.mem.eql(u8, &key_c.signing_bytes, &key_a.signing_bytes));
    try std.testing.expect(!std.mem.eql(u8, &key_a.signing_bytes, &key_a.encryption_bytes));
    try std.testing.expect(!std.mem.eql(u8, &key_c.encryption_bytes, &key_a.encryption_bytes));
}
