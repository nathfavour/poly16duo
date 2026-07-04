const std = @import("std");

pub fn SplicerEngine(comptime N: usize, comptime T: type) type {
    return struct {
        pub inline fn biasVector(vec: @Vector(8, T), comptime bound: T) @Vector(8, u32) {
            const bias: @Vector(8, T) = @splat(bound);
            const added = vec +% bias;
            if (T == i16) {
                const unsigned_16 = @as(@Vector(8, u16), @bitCast(added));
                return @as(@Vector(8, u32), @intCast(unsigned_16));
            } else {
                return @as(@Vector(8, u32), @bitCast(added));
            }
        }

        pub inline fn unbiasVector(vec: @Vector(8, u32), comptime bound: T) @Vector(8, T) {
            if (T == i16) {
                const val_16 = @as(@Vector(8, i16), @bitCast(@as(@Vector(8, u16), @intCast(vec))));
                const bias: @Vector(8, i16) = @splat(bound);
                return val_16 -% bias;
            } else {
                const val_32 = @as(@Vector(8, i32), @bitCast(vec));
                const bias: @Vector(8, i32) = @splat(bound);
                return val_32 -% bias;
            }
        }

        pub fn pack12(coefficients: []const T, output: []u8, comptime bias_val: T) void {
            const lanes = 8;
            const vector_count = N / lanes;
            var out_idx: usize = 0;

            var i: usize = 0;
            while (i < vector_count) : (i += 1) {
                const raw_vec: @Vector(lanes, T) = coefficients[i * lanes ..][0..lanes].*;
                const unsigned_vec = if (bias_val != 0)
                    biasVector(raw_vec, bias_val)
                else if (T == i16)
                    @as(@Vector(lanes, u32), @intCast(@as(@Vector(lanes, u16), @bitCast(raw_vec))))
                else
                    @as(@Vector(lanes, u32), @bitCast(raw_vec));

                const mask = @as(@Vector(lanes, u32), @splat(@as(u32, 0x0FFF)));
                const v = unsigned_vec & mask;

                const x_vec = @shuffle(u32, v, undefined, [4]i32{0, 2, 4, 6});
                const y_vec = @shuffle(u32, v, undefined, [4]i32{1, 3, 5, 7});

                const b0 = @as(@Vector(4, u8), @truncate(x_vec));
                const b1 = @as(@Vector(4, u8), @truncate((x_vec >> @as(@Vector(4, u5), @splat(8))) | (y_vec << @as(@Vector(4, u5), @splat(4)))));
                const b2 = @as(@Vector(4, u8), @truncate(y_vec >> @as(@Vector(4, u5), @splat(4))));

                const b01 = @shuffle(u8, b0, b1, [8]i32{0, 1, 2, 3, 4, 5, 6, 7});
                const dynamic_reg = @shuffle(u8, b01, b2, [12]i32{0, 4, 8, 1, 5, 9, 2, 6, 10, 3, 7, 11});

                output[out_idx..][0..12].* = dynamic_reg;
                out_idx += 12;
            }
        }

        pub fn unpack12(input: []const u8, coefficients: []T, comptime bias_val: T) void {
            const lanes = 8;
            const vector_count = N / lanes;
            var in_idx: usize = 0;

            var i: usize = 0;
            while (i < vector_count) : (i += 1) {
                const raw_bytes: @Vector(12, u8) = input[in_idx..][0..12].*;
                in_idx += 12;

                const b0 = @shuffle(u8, raw_bytes, undefined, [4]i32{0, 3, 6, 9});
                const b1 = @shuffle(u8, raw_bytes, undefined, [4]i32{1, 4, 7, 10});
                const b2 = @shuffle(u8, raw_bytes, undefined, [4]i32{2, 5, 8, 11});

                const b1_mask = b1 & @as(@Vector(4, u8), @splat(0x0F));
                const x_vec = @as(@Vector(4, u32), b0) | (@as(@Vector(4, u32), b1_mask) << @as(@Vector(4, u5), @splat(8)));
                const y_vec = (@as(@Vector(4, u32), b1 >> @as(@Vector(4, u5), @splat(4))) & @as(@Vector(4, u32), @splat(0x0F))) | (@as(@Vector(4, u32), b2) << @as(@Vector(4, u5), @splat(4)));

                const unsigned_vec = @shuffle(u32, x_vec, y_vec, [8]i32{0, 4, 1, 5, 2, 6, 3, 7});
                const raw_vec = if (bias_val != 0)
                    unbiasVector(unsigned_vec, bias_val)
                else if (T == i16)
                    @as(@Vector(8, i16), @bitCast(@as(@Vector(8, u16), @intCast(unsigned_vec))))
                else
                    @as(@Vector(8, T), @bitCast(unsigned_vec));

                coefficients[i * lanes ..][0..lanes].* = raw_vec;
            }
        }

        pub fn pack10(coefficients: []const T, output: []u8, comptime bias_val: T) void {
            const lanes = 8;
            const vector_count = N / lanes;
            var out_idx: usize = 0;

            var i: usize = 0;
            while (i < vector_count) : (i += 1) {
                const raw_vec: @Vector(lanes, T) = coefficients[i * lanes ..][0..lanes].*;
                const unsigned_vec = if (bias_val != 0)
                    biasVector(raw_vec, bias_val)
                else if (T == i16)
                    @as(@Vector(lanes, u32), @intCast(@as(@Vector(lanes, u16), @bitCast(raw_vec))))
                else
                    @as(@Vector(lanes, u32), @bitCast(raw_vec));

                const mask = @as(@Vector(lanes, u32), @splat(@as(u32, 0x03FF)));
                const v = unsigned_vec & mask;

                const v_16 = @shuffle(u32, v, @as(@Vector(8, u32), @splat(0)), [16]i32{0, 1, 2, 3, 4, 5, 6, 7, -1, -1, -1, -1, -1, -1, -1, -1});
                const comp1 = @shuffle(u32, v_16, undefined, [16]i32{0, 0, 1, 2, 3, 4, 4, 5, 6, 7, -1, -1, -1, -1, -1, -1});
                const comp2 = @shuffle(u32, v_16, @as(@Vector(16, u32), @splat(0)), [16]i32{-1, 1, 2, 3, -1, -1, 5, 6, 7, -1, -1, -1, -1, -1, -1, -1});

                const shift_r = @as(@Vector(16, u5), [16]u5{0, 8, 6, 4, 2, 0, 8, 6, 4, 2, 0, 0, 0, 0, 0, 0});
                const shift_l = @as(@Vector(16, u5), [16]u5{0, 2, 4, 6, 0, 0, 2, 4, 6, 0, 0, 0, 0, 0, 0, 0});

                const res = @as(@Vector(16, u8), @truncate((comp1 >> shift_r) | (comp2 << shift_l)));
                output[out_idx..][0..10].* = @shuffle(u8, res, undefined, [10]i32{0, 1, 2, 3, 4, 5, 6, 7, 8, 9});
                out_idx += 10;
            }
        }

        pub fn unpack10(input: []const u8, coefficients: []T, comptime bias_val: T) void {
            const lanes = 8;
            const vector_count = N / lanes;
            var in_idx: usize = 0;

            var i: usize = 0;
            while (i < vector_count) : (i += 1) {
                const bytes: @Vector(10, u8) = input[in_idx..][0..10].*;
                in_idx += 10;

                const b16 = @shuffle(u8, bytes, @as(@Vector(10, u8), @splat(0)), [16]i32{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, -1, -1, -1, -1, -1, -1});
                const b_low = @shuffle(u8, b16, undefined, [8]i32{0, 1, 2, 3, 5, 6, 7, 8});
                const b_high = @shuffle(u8, b16, undefined, [8]i32{1, 2, 3, 4, 6, 7, 8, 9});

                const low_part = @as(@Vector(8, u32), b_low) >> @as(@Vector(8, u5), [8]u5{0, 2, 4, 6, 0, 2, 4, 6});
                const high_mask = @as(@Vector(8, u32), [8]u32{0x03, 0x0F, 0x3F, 0xFF, 0x03, 0x0F, 0x3F, 0xFF});
                const high_part = (@as(@Vector(8, u32), b_high) & high_mask) << @as(@Vector(8, u5), [8]u5{8, 6, 4, 2, 8, 6, 4, 2});

                const unsigned_vec = low_part | high_part;
                const raw_vec = if (bias_val != 0)
                    unbiasVector(unsigned_vec, bias_val)
                else if (T == i16)
                    @as(@Vector(8, i16), @bitCast(@as(@Vector(8, u16), @intCast(unsigned_vec))))
                else
                    @as(@Vector(8, T), @bitCast(unsigned_vec));

                coefficients[i * lanes ..][0..lanes].* = raw_vec;
            }
        }

        pub fn pack14(coefficients: []const T, output: []u8, comptime bias_val: T) void {
            const lanes = 8;
            const vector_count = N / lanes;
            var out_idx: usize = 0;

            var i: usize = 0;
            while (i < vector_count) : (i += 1) {
                const raw_vec: @Vector(lanes, T) = coefficients[i * lanes ..][0..lanes].*;
                const unsigned_vec = if (bias_val != 0)
                    biasVector(raw_vec, bias_val)
                else if (T == i16)
                    @as(@Vector(lanes, u32), @intCast(@as(@Vector(lanes, u16), @bitCast(raw_vec))))
                else
                    @as(@Vector(lanes, u32), @bitCast(raw_vec));

                const mask = @as(@Vector(lanes, u32), @splat(@as(u32, 0x3FFF)));
                const v = unsigned_vec & mask;

                const v_16 = @shuffle(u32, v, @as(@Vector(8, u32), @splat(0)), [16]i32{0, 1, 2, 3, 4, 5, 6, 7, -1, -1, -1, -1, -1, -1, -1, -1});
                const comp1 = @shuffle(u32, v_16, undefined, [16]i32{0, 0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6, 7, -1, -1});
                const comp2 = @shuffle(u32, v_16, @as(@Vector(16, u32), @splat(0)), [16]i32{-1, 1, -1, 2, -1, 3, -1, -1, 5, -1, 6, -1, 7, -1, -1, -1});

                const shift_r = @as(@Vector(16, u5), [16]u5{0, 8, 2, 10, 4, 12, 6, 0, 8, 2, 10, 4, 12, 6, 0, 0});
                const shift_l = @as(@Vector(16, u5), [16]u5{0, 6, 0, 4, 0, 2, 0, 0, 6, 0, 4, 0, 2, 0, 0, 0});

                const res = @as(@Vector(16, u8), @truncate((comp1 >> shift_r) | (comp2 << shift_l)));
                output[out_idx..][0..14].* = @shuffle(u8, res, undefined, [14]i32{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13});
                out_idx += 14;
            }
        }

        pub fn unpack14(input: []const u8, coefficients: []T, comptime bias_val: T) void {
            const lanes = 8;
            const vector_count = N / lanes;
            var in_idx: usize = 0;

            var i: usize = 0;
            while (i < vector_count) : (i += 1) {
                const bytes: @Vector(14, u8) = input[in_idx..][0..14].*;
                in_idx += 14;

                const b16 = @shuffle(u8, bytes, @as(@Vector(14, u8), @splat(0)), [16]i32{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, -1, -1});

                const b_part0 = @shuffle(u8, b16, undefined, [8]i32{0, 1, 3, 5, 7, 8, 10, 12});
                const b_part1 = @shuffle(u8, b16, @as(@Vector(16, u8), @splat(0)), [8]i32{-1, 2, 4, 6, -1, 9, 11, 13});
                const b_part2 = @shuffle(u8, b16, @as(@Vector(16, u8), @splat(0)), [8]i32{1, 3, 5, -1, 8, 10, 12, -1});

                const part0_val = @as(@Vector(8, u32), b_part0) >> @as(@Vector(8, u5), [8]u5{0, 6, 4, 2, 0, 6, 4, 2});
                const part1_val = @as(@Vector(8, u32), b_part1) << @as(@Vector(8, u5), [8]u5{0, 2, 4, 6, 0, 2, 4, 6});
                
                const part2_mask = @as(@Vector(8, u32), [8]u32{0x3F, 0x0F, 0x03, 0, 0x3F, 0x0F, 0x03, 0});
                const part2_val = (@as(@Vector(8, u32), b_part2) & part2_mask) << @as(@Vector(8, u5), [8]u5{8, 10, 12, 0, 8, 10, 12, 0});

                const unsigned_vec = part0_val | part1_val | part2_val;
                const raw_vec = if (bias_val != 0)
                    unbiasVector(unsigned_vec, bias_val)
                else if (T == i16)
                    @as(@Vector(8, i16), @bitCast(@as(@Vector(8, u16), @intCast(unsigned_vec))))
                else
                    @as(@Vector(8, T), @bitCast(unsigned_vec));

                coefficients[i * lanes ..][0..lanes].* = raw_vec;
            }
        }
    };
}
