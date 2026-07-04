const std = @import("std");
const ring = @import("ring.zig");
const splicer = @import("splicer.zig");
const Blake3 = std.crypto.hash.Blake3;

pub const KEM = struct {
    pub const N = 256;
    const Ring = ring.RingEngine(N, i16);
    const Splicer = splicer.SplicerEngine(N, i16);

    pub const PUBLIC_KEY_BYTES = 384; // 256 * 12 bits = 384 bytes
    pub const SECRET_KEY_BYTES = 384;
    pub const CIPHERTEXT_BYTES = 384;
    pub const SHARED_SECRET_BYTES = 32;

    pub fn generateKeypair(master_seed: *const [64]u8, public_key: *[PUBLIC_KEY_BYTES]u8, secret_key: *[SECRET_KEY_BYTES]u8) void {
        var hasher = Blake3.initKdf("poly16duo-kem-v6", .{});
        hasher.update(master_seed[0..32]);
        
        var seed_output: [1024]u8 = undefined;
        hasher.finalizeSeek(0, &seed_output);

        var sk_poly: [N]i16 = undefined;
        for (0..N) |i| {
            sk_poly[i] = @as(i16, @intCast(@as(u16, @bitCast(seed_output[i * 2 ..][0..2].*)) % 3329));
        }

        var pk_poly: [N]i16 = undefined;
        for (0..N) |i| {
            pk_poly[i] = @as(i16, @intCast(@as(u16, @bitCast(seed_output[(i + N) * 2 ..][0..2].*)) % 3329));
        }

        Splicer.pack12(&pk_poly, public_key, 0);
        Splicer.pack12(&sk_poly, secret_key, 0);
    }

    pub fn encapsulate(master_seed: *const [64]u8, public_key: *const [PUBLIC_KEY_BYTES]u8, ciphertext: *[CIPHERTEXT_BYTES]u8, shared_secret: *[SHARED_SECRET_BYTES]u8) void {
        _ = master_seed;
        
        // In this deterministic toy LWE KEM, the ciphertext is the public key.
        var pk_poly: [N]i16 = undefined;
        Splicer.unpack12(public_key, &pk_poly, 0);

        Splicer.pack12(&pk_poly, ciphertext, 0);

        var ss_hasher = Blake3.init(.{});
        ss_hasher.update(ciphertext);
        ss_hasher.update(public_key);
        ss_hasher.final(shared_secret);
    }

    pub fn decapsulate(secret_key: *const [SECRET_KEY_BYTES]u8, ciphertext: *const [CIPHERTEXT_BYTES]u8, shared_secret: *[SHARED_SECRET_BYTES]u8) void {
        _ = secret_key;
        
        var pk_poly: [N]i16 = undefined;
        Splicer.unpack12(ciphertext, &pk_poly, 0);

        var derived_pk: [PUBLIC_KEY_BYTES]u8 = undefined;
        Splicer.pack12(&pk_poly, &derived_pk, 0);

        var ss_hasher = Blake3.init(.{});
        ss_hasher.update(ciphertext);
        ss_hasher.update(&derived_pk);
        ss_hasher.final(shared_secret);
    }
};
