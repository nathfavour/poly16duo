const std = @import("std");

pub fn RingEngine(comptime N: usize, comptime T: type) type {
    return struct {
        const Self = @This();
        pub const VectorType = @Vector(8, T);

        fn genShuffleMask(comptime stride: usize) [8]i32 {
            var mask: [8]i32 = undefined;
            for (0..8) |i| {
                mask[i] = @as(i32, @intCast(i ^ stride));
            }
            return mask;
        }

        fn genTwiddleMask(comptime stride: usize) [8]i16 {
            var mask: [8]i16 = undefined;
            for (0..8) |i| {
                mask[i] = if ((i & stride) != 0) @as(i16, 1) else @as(i16, 0);
            }
            return mask;
        }

        pub fn montgomeryReduce(a: i32) i16 {
            const m = @as(i16, @intCast(@as(i32, @truncate(a)) *% 3327));
            const t = @as(i32, m) * 3329;
            const r = @as(i16, @intCast((a -% t) >> 16));
            return r;
        }

        pub fn montgomeryReduceVector(a: @Vector(8, i32)) @Vector(8, i16) {
            const q_inv: @Vector(8, i32) = @splat(3327);
            const q: @Vector(8, i32) = @splat(3329);
            const m = @as(@Vector(8, i16), @truncate(a *% q_inv));
            const m_32: @Vector(8, i32) = @intCast(m);
            const t = m_32 *% q;
            const res = @as(@Vector(8, i16), @truncate((a -% t) >> @as(@Vector(8, u5), @splat(16))));
            return res;
        }

        pub fn partialNttHybrid(coefficients: *[N]i16, twiddle_factors: []const i16) void {
            if (T != i16) @compileError("Modular NTT requires 16-bit coefficient domains.");

            // Global Inter-Lane Stages (Stages 0 to 3): Strides > 8 elements
            comptime var global_stage: usize = 0;
            inline while (global_stage < 4) : (global_stage += 1) {
                const stride = @as(usize, 1) << (7 - global_stage);
                var i: usize = 0;
                var twiddle_idx: usize = 0;
                while (i < N) : (i += 2 * stride) {
                    const twiddle = twiddle_factors[twiddle_idx];
                    twiddle_idx += 1;
                    for (0..stride) |j| {
                        const idx1 = i + j;
                        const idx2 = idx1 + stride;
                        
                        const t = montgomeryReduce(@as(i32, coefficients[idx2]) *% @as(i32, twiddle));
                        coefficients[idx2] = coefficients[idx1] -% t;
                        coefficients[idx1] = coefficients[idx1] +% t;
                    }
                }
            }

            // Local Intra-Lane Stages (Stages 4 to 6): In-Register Butterflies
            var block_idx: usize = 0;
            while (block_idx < N / 8) : (block_idx += 1) {
                const offset = block_idx * 8;
                var vec: @Vector(8, i16) = coefficients[offset..][0..8].*;

                comptime var local_stage: usize = 4;
                inline while (local_stage < 7) : (local_stage += 1) {
                    const stride = @as(usize, 1) << (6 - local_stage);
                    const mask = comptime genShuffleMask(stride);
                    const twiddle_select = comptime genTwiddleMask(stride);
                    
                    const twiddle = twiddle_factors[local_stage * (N / 8) + block_idx];
                    
                    // Construct valid mathematical twiddle vector: 1 for left-hand, omega for right-hand
                    const twiddle_vec: @Vector(8, i16) = @select(i16, twiddle_select == 1, @as(@Vector(8, i16), @splat(twiddle)), @as(@Vector(8, i16), @splat(@as(i16, 1))));
                    
                    // Execute Gentleman-Sande butterfly topology natively in register
                    const shuffled = @shuffle(i16, vec, undefined, mask);
                    const prod = @as(@Vector(8, i32), @intCast(shuffled)) *% @as(@Vector(8, i32), @intCast(twiddle_vec));
                    const t = montgomeryReduceVector(prod);
                    
                    const selection_mask = comptime @as(@Vector(8, i16), [8]i16{
                        if ((0 & stride) == 0) 1 else -1, if ((1 & stride) == 0) 1 else -1,
                        if ((2 & stride) == 0) 1 else -1, if ((3 & stride) == 0) 1 else -1,
                        if ((4 & stride) == 0) 1 else -1, if ((5 & stride) == 0) 1 else -1,
                        if ((6 & stride) == 0) 1 else -1, if ((7 & stride) == 0) 1 else -1,
                    });
                    
                    vec = vec +% (t *% selection_mask);
                }
                coefficients[offset..][0..8].* = vec;
            }
        }

        pub fn integerExactMultiply(a: []const i32, b: []const i32, out: []i32) void {
            if (T != i32) @compileError("Modulus-free integer multiplication requires 32-bit math boundaries.");
            
            // 64-bit intermediate accumulators eradicate integer overflow vulnerabilities during Hawk-512 convolution
            var i: usize = 0;
            while (i < N) : (i += 1) {
                var acc: i64 = 0;
                var j: usize = 0;
                while (j <= i) : (j += 1) {
                    acc += @as(i64, a[j]) * @as(i64, b[i - j]);
                }
                // Enforce strict bounding checks before casting down from the 64-bit mathematical domain
                out[i] = @as(i32, @intCast(acc));
            }
        }
    };
}
