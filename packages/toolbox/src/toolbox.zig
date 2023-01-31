pub usingnamespace @import("print.zig");
pub usingnamespace @import("assert.zig");
pub usingnamespace @import("type_utils.zig");
pub usingnamespace @import("time.zig");
pub usingnamespace @import("memory.zig");
pub usingnamespace @import("byte_math.zig");
pub usingnamespace @import("linked_list.zig");
pub usingnamespace @import("hash_map.zig");
pub usingnamespace @import("string.zig");
pub usingnamespace @import("stack.zig");
pub usingnamespace @import("fixed_list.zig");
pub usingnamespace @import("ring_queue.zig");
pub usingnamespace @import("random.zig");

const builtin = @import("builtin");
const build_flags = @import("build_flags");
const root = @import("root");
const std = @import("std");

pub const panic_handler = if (THIS_PLATFORM != .Playdate)
    std.builtin.default_panic
else
    playdate_panic;
pub const Platform = enum {
    MacOS,
    //Linux, //TODO
    Playdate,
    BoksOS,
};
pub const THIS_PLATFORM = if (@hasDecl(root, "THIS_PLATFORM"))
    root.THIS_PLATFORM
else
    @compileError("Please define the THIS_PLATFORM constant in the root source file");
pub const IS_DEBUG = builtin.mode == .Debug;

////BoksOS runtime functions

////Playdate runtime functions
pub var playdate_realloc: *const fn (?*anyopaque, usize) callconv(.C) ?*anyopaque = undefined;
pub var playdate_log_to_console: *const fn ([*c]const u8, ...) callconv(.C) void = undefined;
pub var playdate_error: *const fn ([*c]const u8, ...) callconv(.C) void = undefined;
pub var playdate_get_seconds: *const fn () callconv(.C) f32 = undefined;
pub var playdate_get_milliseconds: *const fn () callconv(.C) u32 = undefined;

pub fn init_playdate_runtime(
    _playdate_realloc: *const fn (?*anyopaque, usize) callconv(.C) ?*anyopaque,
    _playdate_log_to_console: *const fn ([*c]const u8, ...) callconv(.C) void,
    _playdate_error: *const fn ([*c]const u8, ...) callconv(.C) void,
    _playdate_get_seconds: *const fn () callconv(.C) f32,
    _playdate_get_milliseconds: *const fn () callconv(.C) u32,
) void {
    if (comptime THIS_PLATFORM != .Playdate) {
        @compileError("Only call this for the Playdate!");
    }
    playdate_realloc = _playdate_realloc;
    playdate_log_to_console = _playdate_log_to_console;
    playdate_error = _playdate_error;
    playdate_get_seconds = _playdate_get_seconds;
    playdate_get_milliseconds = _playdate_get_milliseconds;
}
pub fn playdate_panic(
    msg: []const u8,
    error_return_trace: ?*std.builtin.StackTrace,
    return_address: ?usize,
) noreturn {
    _ = error_return_trace;
    _ = return_address;

    switch (comptime builtin.os.tag) {
        .freestanding => {
            //playdate hardware
            playdate_error("%s lr: %x", msg.ptr, asm volatile (""
                : [lr] "={lr}" (-> u32),
            ));
        },
        else => {
            //playdate simulator
            var stack_trace_buffer = [_]u8{0} ** 4096;
            var buffer = [_]u8{0} ** 4096;
            var stream = std.io.fixedBufferStream(&stack_trace_buffer);

            b: {
                if (builtin.strip_debug_info) {
                    const to_print = std.fmt.bufPrintZ(&buffer, "Unable to dump stack trace: debug info stripped\n", .{}) catch return;
                    playdate_error("%s", to_print.ptr);
                    break :b;
                }
                const debug_info = std.debug.getSelfDebugInfo() catch |err| {
                    const to_print = std.fmt.bufPrintZ(&buffer, "Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)}) catch break :b;
                    playdate_error("%s", to_print.ptr);
                    break :b;
                };
                std.debug.writeCurrentStackTrace(stream.writer(), debug_info, std.debug.detectTTYConfig(), null) catch {};
            }
            const to_print = std.fmt.bufPrintZ(&buffer, "{s} -- {s}", .{ msg, stack_trace_buffer[0..stream.pos] }) catch "Unknown error";
            playdate_error("%s", to_print.ptr);
        },
    }

    while (true) {}
}

//C bridge functions
export fn c_assert(cond: bool) void {
    if (!cond) {
        unreachable;
    }
}
