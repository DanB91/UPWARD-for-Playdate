const toolbox = @import("toolbox.zig");

pub fn LinkedListDeque(comptime T: type) type {
    return struct {
        head: ?*Node = null,
        tail: ?*Node = null,
        len: usize = 0,
        free_list: ?*Node = null,

        pub const Iterator = struct {
            cursor: ?*Node,
            i: usize,
            len: usize,
            pub fn next(self: *Iterator) ?*T {
                if (self.cursor) |cursor| {
                    const ret = &cursor.value;
                    self.cursor = cursor.next;
                    if (toolbox.IS_DEBUG) {
                        self.i += 1;
                    }
                    return ret;
                } else {
                    toolbox.assert(self.i == self.len, "Linked List length is wrong!", .{});
                    return null;
                }
            }
        };

        const Self = @This();
        const Node = struct {
            next: ?*Node,
            value: T,
        };

        pub fn init() Self {
            return Self{};
        }

        pub fn push_queue(self: *Self, value: T, arena: *toolbox.Arena) *T {
            var to_add = self.alloc_node(arena);
            to_add.* = .{
                .value = value,
                .next = null,
            };
            if (self.tail) |t| {
                t.next = to_add;
            } else {
                self.head = to_add;
            }
            self.tail = to_add;

            self.len += 1;
            return &to_add.value;
        }

        pub fn push_stack(self: *Self, value: T, arena: *toolbox.Arena) *T {
            var to_add = self.alloc_node(arena);
            to_add.* = .{
                .value = value,
                .next = self.head,
            };
            if (self.head == null) {
                self.tail = to_add;
            }
            self.head = to_add;

            self.len += 1;
            return &to_add.value;
        }

        pub fn peek(self: *Self) ?T {
            if (self.head) |head| {
                return head.value;
            }
            return null;
        }

        pub fn pop(self: *Self) T {
            if (self.head) |head| {
                const ret = head.value;
                self.len -= 1;
                self.head = head.next;
                if (self.head == null) {
                    self.tail = null;
                }
                self.free_node(head);
                return ret;
            }
            toolbox.panic("Should not pop from an empty deque!", .{});
        }
        pub fn clear(self: *Self) void {
            if (self.head) |head| {
                var tmp: ?*Node = head;
                while (tmp) |node| {
                    tmp = node.next;
                    self.free_node(node);
                }
            }
            self.head = null;
            self.tail = null;
            self.len = 0;
        }

        pub fn iterator(self: *Self) Iterator {
            return .{
                .cursor = self.head,
                .i = 0,
                .len = self.len,
            };
        }
        fn alloc_node(self: *Self, arena: *toolbox.Arena) *Node {
            if (self.free_list) |node| {
                self.free_list = node.next;
                return node;
            }
            return arena.push(Node);
        }
        fn free_node(self: *Self, node: *Node) void {
            node.next = self.free_list;
            self.free_list = node;
        }
    };
}

pub fn RandomRemovalLinkedList(comptime T: type) type {
    return struct {
        head: ?*Node = null,
        tail: ?*Node = null,
        len: usize = 0,
        free_list: ?*Node = null,

        const Self = @This();
        pub const Node = struct {
            next: ?*Node,
            prev: ?*Node,
            value: T,
        };
        pub const Iterator = struct {
            cursor: ?*Node,
            i: usize,
            list: *const Self,
            pub fn next(self: *Iterator) ?*T {
                if (self.cursor) |cursor| {
                    const ret = &cursor.value;
                    self.cursor = cursor.next;
                    if (toolbox.IS_DEBUG) {
                        self.i += 1;
                    }
                    return ret;
                } else {
                    //NOTE: this assert is wrong if we remove nodes during iteration
                    // toolbox.assert(
                    //     self.i == self.list.len,
                    //     "Linked List length is wrong! Was {} but should be {}",
                    //     .{ self.list.len, self.i },
                    // );
                    return null;
                }
            }
        };

        pub fn init() Self {
            return Self{};
        }
        pub fn append(self: *Self, value: T, arena: *toolbox.Arena) *T {
            var to_add = self.alloc_node(arena);
            to_add.* = .{
                .value = value,
                .next = null,
                .prev = self.tail,
            };
            if (self.tail) |t| {
                t.next = to_add;
            } else {
                self.head = to_add;
            }
            self.tail = to_add;

            self.len += 1;
            return &to_add.value;
        }
        pub fn prepend(self: *Self, value: T, arena: *toolbox.Arena) *T {
            var to_add = self.alloc_node(arena);
            to_add.* = .{ .value = value, .next = self.head, .prev = null };
            if (self.head == null) {
                self.tail = to_add;
            }
            self.head = to_add;

            self.len += 1;
            return &to_add.value;
        }

        pub fn remove(self: *Self, to_remove: *T) void {
            const node: *Node = @alignCast(@fieldParentPtr("value", to_remove));
            defer {
                self.len -= 1;
                self.free_node(node);
            }
            if (node == self.head) {
                self.head = node.next;
                if (self.head) |head| {
                    head.prev = null;
                }
                if (node == self.tail) {
                    toolbox.assert(self.len == 1, "If head and tail are same, then len should be 1", .{});
                    self.tail = node.prev;
                    if (self.tail) |tail| {
                        tail.next = null;
                    }
                }
                return;
            }
            if (node == self.tail) {
                self.tail = node.prev;
                if (self.tail) |tail| {
                    tail.next = null;
                }
                return;
            }
            var next = node.next.?;
            var prev = node.prev.?;
            prev.next = next;
            next.prev = prev;
        }
        pub fn clear(self: *Self) void {
            self.* = .{};
        }
        pub fn clear_and_free(self: *Self) void {
            if (self.head) |head| {
                var tmp: ?*Node = head;
                while (tmp) |node| {
                    tmp = node.next;
                    self.free_node(node);
                }
            }
            self.head = null;
            self.tail = null;
            self.len = 0;
        }
        pub fn iterator(self: *Self) Iterator {
            return .{
                .cursor = self.head,
                .i = 0,
                .list = self,
            };
        }

        fn alloc_node(self: *Self, arena: *toolbox.Arena) *Node {
            if (self.free_list) |node| {
                self.free_list = node.next;
                return node;
            }
            return arena.push(Node);
        }
        fn free_node(self: *Self, node: *Node) void {
            node.next = self.free_list;
            self.free_list = node;
        }
    };
}
