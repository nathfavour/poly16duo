const std = @import("std");
pub const ring = @import("ring.zig");
pub const splicer = @import("splicer.zig");
pub const kem = @import("kem.zig");
pub const hawk = @import("hawk.zig");

pub export fn verify_hawk_stateless(
    public_key_ptr: [*]const u8,
    signature_ptr: [*]const u8,
    msg_ptr: [*]const u8,
    msg_len: usize,
    scratchpad_ptr: [*]u8
) bool {
    const pk: *const [896]u8 = @ptrCast(public_key_ptr);
    const sig: *const [640]u8 = @ptrCast(signature_ptr);
    const msg = msg_ptr[0..msg_len];
    const scratchpad = scratchpad_ptr[0..16384];
    
    return hawk.Hawk.verify(pk, sig, msg, scratchpad);
}

test "splicer pack12/unpack12" {
    const N = 256;
    const Splicer = splicer.SplicerEngine(N, i16);
    
    var original: [N]i16 = undefined;
    for (0..N) |i| {
        original[i] = @as(i16, @intCast(i % 4096)); // 12-bit range
    }
    
    var packed_buf: [384]u8 = undefined;
    Splicer.pack12(&original, &packed_buf, 0);
    
    var unpacked: [N]i16 = undefined;
    Splicer.unpack12(&packed_buf, &unpacked, 0);
    
    try std.testing.expectEqualSlices(i16, &original, &unpacked);
}

test "splicer pack10/unpack10" {
    const N = 512;
    const Splicer = splicer.SplicerEngine(N, i32);
    
    var original: [N]i32 = undefined;
    for (0..N) |i| {
        original[i] = @as(i32, @intCast(i % 1024)) - 512; // 10-bit biased range
    }
    
    var packed_buf: [640]u8 = undefined;
    Splicer.pack10(&original, &packed_buf, 512);
    
    var unpacked: [N]i32 = undefined;
    Splicer.unpack10(&packed_buf, &unpacked, 512);
    
    try std.testing.expectEqualSlices(i32, &original, &unpacked);
}

test "splicer pack14/unpack14" {
    const N = 512;
    const Splicer = splicer.SplicerEngine(N, i32);
    
    var original: [N]i32 = undefined;
    for (0..N) |i| {
        original[i] = @as(i32, @intCast(i % 16384)) - 8192; // 14-bit biased range
    }
    
    var packed_buf: [896]u8 = undefined;
    Splicer.pack14(&original, &packed_buf, 8192);
    
    var unpacked: [N]i32 = undefined;
    Splicer.unpack14(&packed_buf, &unpacked, 8192);
    
    try std.testing.expectEqualSlices(i32, &original, &unpacked);
}

test "KEM operations" {
    var seed: [64]u8 = undefined;
    for (0..64) |i| {
        seed[i] = @as(u8, @intCast(i));
    }

    var pk: [384]u8 = undefined;
    var sk: [384]u8 = undefined;
    kem.KEM.generateKeypair(&seed, &pk, &sk);

    var ct: [384]u8 = undefined;
    var ss_enc: [32]u8 = undefined;
    kem.KEM.encapsulate(&seed, &pk, &ct, &ss_enc);

    var ss_dec: [32]u8 = undefined;
    kem.KEM.decapsulate(&sk, &ct, &ss_dec);

    try std.testing.expectEqualSlices(u8, &ss_enc, &ss_dec);
}

test "Hawk verification stateless" {
    var pk: [896]u8 = undefined;
    @memset(&pk, 0x42);
    var sig: [640]u8 = undefined;
    @memset(&sig, 0x11);
    
    var scratchpad: [16384]u8 = undefined;
    const msg = "test message";
    
    const valid = verify_hawk_stateless(&pk, &sig, msg.ptr, msg.len, &scratchpad);
    try std.testing.expect(!valid);
}
