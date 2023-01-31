const toolbox = @import("toolbox.zig");
pub fn Stack(comptime T: type) type {
    return struct {
        data: []T,
        back: usize,

        const Self = @This();

        pub fn init(arena: *toolbox.Arena, max_items: usize) Self {
            return .{
                .data = arena.push_slice(T, max_items),
                .back = 0,
            };
        }
        pub inline fn push(self: *Self, value: T) void {
            self.data[self.back] = value;
            self.back += 1;
        }
        pub inline fn pop(self: *Self) T {
            self.back -= 1;
            return self.data[self.back];
        }
        pub inline fn peek(self: *const Self) ?T {
            if (self.back >= 1) {
                return self.data[self.back - 1];
            }
            return null;
        }
        pub inline fn clear(self: *Self) void {
            self.back = 0;
        }
    };
}
