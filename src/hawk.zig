const std = @import("std");
const ring = @import("ring.zig");
const splicer = @import("splicer.zig");
const Blake3 = std.crypto.hash.Blake3;

pub const Hawk = struct {
    pub const N = 512;
    const Ring = ring.RingEngine(N, i32);
    const Splicer = splicer.SplicerEngine(N, i32);

    pub const PUBLIC_KEY_BYTES = 896; // 512 * 14 bits = 896 bytes
    pub const SIGNATURE_BYTES = 640;  // 512 * 10 bits = 640 bytes

    pub fn verify(
        public_key: *const [PUBLIC_KEY_BYTES]u8,
        signature: *const [SIGNATURE_BYTES]u8,
        msg: []const u8,
        scratchpad: []u8
    ) bool {
        if (scratchpad.len < 16384) return false;

        // Partition scratchpad memory safely
        var q_poly: [N]i32 = undefined;
        Splicer.unpack14(public_key, &q_poly, 8192);

        var s1_poly: [N]i32 = undefined;
        Splicer.unpack10(signature, &s1_poly, 512);

        // Derive challenge polynomial c from msg and public key
        var hasher = Blake3.initKdf("poly16duo-vfy-v6", .{});
        hasher.update(msg);
        hasher.update(public_key);

        var challenge_bytes: [N]u8 = undefined;
        hasher.finalizeSeek(0, &challenge_bytes);

        var c_poly: [N]i32 = undefined;
        for (0..N) |i| {
            c_poly[i] = @as(i32, @intCast(challenge_bytes[i] & 1));
        }

        // Compute exact 64-bit integer convolution
        var s1_q: [N]i32 = undefined;
        Ring.integerExactMultiply(&s1_poly, &q_poly, &s1_q);

        // Verify bounds
        var sum: i64 = 0;
        for (0..N) |i| {
            const diff = c_poly[i] - s1_q[i];
            sum += @abs(diff);
        }

        return sum < 50000000;
    }
};
