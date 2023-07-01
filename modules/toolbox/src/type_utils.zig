pub fn is_iterable(x: anytype) bool {
    comptime {
        const T = if (@TypeOf(x) == type) x else @TypeOf(x);
        const ti = @typeInfo(T);
        const ret = switch (ti) {
            .Pointer => |ptr_info| switch (ptr_info.size) {
                .Slice, .Many, .C => true,
                .One => !is_single_pointer(ptr_info.child) and is_iterable(ptr_info.child),
            },
            .Array => true,
            else => false,
        };
        if (@TypeOf(T) != type and ret) {
            //compile time assertion that the type is iterable
            for (x) |_| {}
        }
        return ret;
    }
}
pub fn is_single_pointer(x: anytype) bool {
    comptime {
        const T = if (@TypeOf(x) == type) x else @TypeOf(x);
        const ti = @typeInfo(T);
        switch (ti) {
            .Pointer => |ptr_info| return ptr_info.size == .One,
            else => return false,
        }
    }
}

pub fn child_type(comptime Type: type) type {
    comptime {
        const ti = @typeInfo(Type);
        switch (ti) {
            .Pointer => |info| {
                return info.child;
            },
            else => {
                @compileError("Must be a pointer type!");
            },
        }
    }
}

pub fn enum_size(comptime T: type) usize {
    comptime {
        return @typeInfo(T).Enum.fields.len;
    }
}
