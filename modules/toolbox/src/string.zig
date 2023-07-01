const toolbox = @import("toolbox.zig");
const std = @import("std");
pub const Rune = u32;

pub fn string8_literal(comptime bytes: [:0]const u8) String8 {
    return string8_bytes(bytes);
}
pub fn string8_fmt(buffer: []u8, comptime fmt: []const u8, args: anytype) !String8 {
    const string_bytes = try std.fmt.bufPrint(buffer, fmt, args);
    return string8_bytes(string_bytes);
}
pub fn string8_bytes(bytes: []const u8) String8 {
    var it = utf8le_rune_iterator(bytes);
    var rune_length: usize = 0;
    while (it.next()) |ral| {
        if (ral.rune == 0) {
            break;
        }
        rune_length += 1;
    }
    return String8{
        .bytes = bytes,
        .rune_length = rune_length,
    };
}
//NOTE: only little endian supported for now
pub const String8 = struct {
    bytes: []const u8 = @as([*]const u8, undefined)[0..0],
    rune_length: usize = 0,

    pub fn substring(self: *const String8, rune_start: usize, rune_end_opt: ?usize) String8 {
        if (rune_start >= self.rune_length) {
            return .{
                .bytes = @as([*]const u8, undefined)[0..0],
                .rune_length = 0,
            };
        }
        var it = utf8le_rune_iterator(self.bytes);
        var i: usize = 0;
        var start_byte: usize = 0;

        if (rune_start != 0) {
            while (it.next()) |rune_and_len| {
                defer i += 1;
                if (i == rune_start - 1) {
                    start_byte += rune_and_len.len;
                    if (rune_end_opt == null) {
                        return .{
                            .bytes = self.bytes[start_byte..],
                            .rune_length = self.rune_length - rune_start,
                        };
                    } else {
                        break;
                    }
                }
            }
        }
        var end_byte: usize = start_byte;
        if (rune_end_opt) |rune_end| {
            while (it.next()) |rune_and_len| {
                if (i == rune_end) {
                    break;
                }
                i += 1;
                end_byte += rune_and_len.len;
            }
            return .{
                .bytes = self.bytes[start_byte..end_byte],
                .rune_length = rune_end - rune_start,
            };
        }
        toolbox.panic("Should not be here!", .{});
    }
    pub fn rune_at(self: *const String8, index: usize) RuneAndLength {
        var it = self.iterator();
        var i: usize = 0;
        while (it.next()) |rune_and_length| {
            if (i == index) {
                return rune_and_length;
            }
        }
        toolbox.panic("String index out of bounds: {}", .{index});
    }
    pub fn iterator(self: *const String8) RuneIterator {
        return .{ .bytes = self.bytes };
    }

    //for zig std.fmt
    pub fn format(value: *const String8, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.writeAll(value.bytes);
    }
};
const RuneIteratorChecked = struct {
    bytes: []const u8,
    cursor: usize = 0,
    pub fn next(self: *RuneIteratorChecked) !?RuneAndLength {
        if (self.cursor >= self.bytes.len) {
            return null;
        }
        const rune_and_len = try utf8le_rune_from_bytes_checked(self.bytes[self.cursor..]);
        self.cursor += rune_and_len.len;
        return rune_and_len;
    }
};
const RuneIterator = struct {
    bytes: []const u8,
    cursor: usize = 0,
    pub fn next(self: *RuneIterator) ?RuneAndLength {
        if (self.cursor >= self.bytes.len) {
            return null;
        }
        const rune_and_len = utf8le_rune_from_bytes(self.bytes[self.cursor..]);
        self.cursor += rune_and_len.len;
        return rune_and_len;
    }
};
pub fn utf8le_rune_iterator(bytes: []const u8) RuneIterator {
    return .{ .bytes = bytes };
}
pub fn string_equals(s1: anytype, s2: anytype) bool {
    const a = s1.bytes;
    const b = s2.bytes;
    if (a.len != b.len) return false;
    if (a.ptr == b.ptr) return true;
    for (a, 0..) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}

pub const RuneAndLength = struct {
    rune: Rune,
    len: usize,
};

pub fn utf8le_rune_from_bytes(bytes: []const u8) RuneAndLength {
    const length = [_]usize{
        1, 1, 1, 1, // 000xx
        1, 1, 1, 1,
        1, 1, 1, 1,
        1, 1, 1, 1,
        0, 0, 0, 0, // 100xx (invalid)
        0, 0, 0, 0,
        2, 2, 2, 2, // 110xx
        3, 3, // 1110x
        4, // 11110
        0, // 11111 (invalid)
    };
    const first_byte_mask = [_]u8{ 0, 0x7F, 0x1F, 0x0F, 0x07 };
    const final_shift = [_]u5{ 0, 18, 12, 6, 0 };

    var r: Rune = 0;
    var l: usize = 0;
    if (bytes.len > 0) {
        const byte = bytes[0];
        l = length[byte >> 3];
        if (l > 0 and l <= bytes.len) {
            r = @as(Rune, byte & first_byte_mask[l]) << 18;
            switch (l) {
                2...4 => {
                    if (l == 4) {
                        r |= @as(Rune, bytes[3] & 0x3F) << 0;
                    }
                    if (l >= 3) {
                        r |= @as(Rune, bytes[2] & 0x3F) << 6;
                    }
                    r |= @as(Rune, bytes[1] & 0x3F) << 12;
                },
                1 => {},
                else => return .{ .rune = '?', .len = 1 },
            }
            r >>= final_shift[l];
        } else {
            return .{ .rune = '?', .len = 1 };
        }
    }
    return .{ .rune = r, .len = l };
}

pub fn utf8le_rune_from_bytes_checked(bytes: []const u8) !RuneAndLength {
    const length = [_]usize{
        1, 1, 1, 1, // 000xx
        1, 1, 1, 1,
        1, 1, 1, 1,
        1, 1, 1, 1,
        0, 0, 0, 0, // 100xx (invalid)
        0, 0, 0, 0,
        2, 2, 2, 2, // 110xx
        3, 3, // 1110x
        4, // 11110
        0, // 11111 (invalid)
    };
    const first_byte_mask = [_]u8{ 0, 0x7F, 0x1F, 0x0F, 0x07 };
    const final_shift = [_]u5{ 0, 18, 12, 6, 0 };

    var r: Rune = 0;
    var l: usize = 0;
    if (bytes.len > 0) {
        const byte = bytes[0];
        l = length[byte >> 3];
        if (l > 0 and l <= bytes.len) {
            r = @as(Rune, byte & first_byte_mask[l]) << 18;
            switch (l) {
                2...4 => {
                    if (l == 4) {
                        r |= @as(Rune, bytes[3] & 0x3F) << 0;
                    }
                    if (l >= 3) {
                        r |= @as(Rune, bytes[2] & 0x3F) << 6;
                    }
                    r |= @as(Rune, bytes[1] & 0x3F) << 12;
                },
                1 => {},
                else => return error.InvalidUTF8Rune,
            }
            r >>= final_shift[l];
        } else {
            return error.InvalidUTF8Rune;
        }
    }
    return .{ .rune = r, .len = l };
}
