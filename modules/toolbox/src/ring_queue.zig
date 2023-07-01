const toolbox = @import("toolbox.zig");
pub fn RingQueue(comptime T: type) type {
    return struct {
        data: []T,
        rcursor: usize,
        wcursor: usize,

        const Self = @This();

        pub fn init(ring_len: usize, arena: *toolbox.Arena) Self {
            if (!toolbox.is_power_of_2(ring_len)) {
                toolbox.panic("RingQueue len must be a power of 2! Was: {}", .{ring_len});
            }
            return .{
                .data = arena.push_slice(T, ring_len),
                .rcursor = 0,
                .wcursor = 0,
            };
        }

        pub inline fn enqueue(self: *Self, value: T) void {
            // if (self.is_full()) {
            //     toolbox.panic("Trying to enqueue full queue!", .{});
            // }
            self.data[self.wcursor] = value;
            self.wcursor = next_ring_index(self.wcursor, self.data.len);
        }
        pub inline fn dequeue(self: *Self) T {
            if (self.is_empty()) {
                toolbox.panic("Trying to dequeue empty queue!", .{});
            }
            const ret = self.data[self.rcursor];
            self.rcursor = next_ring_index(self.rcursor, self.data.len);
            return ret;
        }
        pub inline fn is_empty(self: Self) bool {
            return self.rcursor == self.wcursor;
        }
        pub inline fn is_full(self: Self) bool {
            return next_ring_index(self.wcursor, self.data.len) == self.rcursor;
        }
    };
}

inline fn next_ring_index(i: usize, len: usize) usize {
    return (i + 1) & (len - 1);
}
