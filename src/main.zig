const std = @import("std");
pub const ring = @import("ring.zig");
pub const splicer = @import("splicer.zig");

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
