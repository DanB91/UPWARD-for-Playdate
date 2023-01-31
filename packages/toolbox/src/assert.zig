const toolbox = @import("toolbox.zig");

pub fn assert(cond: bool, comptime fmt: []const u8, args: anytype) void {
    if (comptime toolbox.IS_DEBUG) {
        if (!cond) {
            toolbox.panic("ASSERT FAILED: " ++ fmt, args);
        }
    }
}
pub fn static_assert(comptime cond: bool, comptime msg: []const u8) void {
    if (comptime !cond) {
        @compileError(msg);
    }
}
pub fn asserteq(expected: anytype, actual: anytype, comptime message: []const u8) void {
    assert(expected == actual, message ++ " -- Expected: {any}, Actual: {any}", .{ expected, actual });
}

pub fn expect(cond: bool, comptime fmt: []const u8, args: anytype) void {
    if (!cond) {
        toolbox.panic("UEXPECTED CONDITION: " ++ fmt, args);
    }
}
