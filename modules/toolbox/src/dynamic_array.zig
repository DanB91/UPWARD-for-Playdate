const toolbox = @import("toolbox.zig");
pub fn DynamicArray(T: type) type {
    return struct {
        store: []T = @ptrCast([*]T, undefined)[0..0],
        _len: usize = 0,

        const Self = @This();

        pub fn init() Self {
            return Self{};
        }

        pub fn append(self: *Self, value: T, arena: *toolbox.Arena) void {
            if (self._len >= self.store.len) {
                self.ensure_capacity(self.store.len * 2, arena);
            }
            self.store[self._len] = value;
            self._len += 1;
        }

        pub fn len(self: *const Self) usize {
            return self._len;
        }

        pub fn clear(self: *Self) void {
            self.* = .{};
        }

        fn ensure_capacity(self: *Self, capacity: usize, arena: *toolbox.Arena) void {
            if (capacity <= self.store.len) {
                return;
            }
            const src = self.store;
            const dest = arena.push_slice([]T, capacity);
            for (dest) |*d, i| d.* = src[i];
        }
    };
}
