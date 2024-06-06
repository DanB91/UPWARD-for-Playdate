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
            //Playdate hardware

            //TODO: The Zig std library does not yet support stacktraces on Playdate hardware.
            //We will need to do this manually. Some notes on trying to get it working:
            //Frame pointer is R7
            //Next Frame pointer is *R7
            //Return address is *(R7+4)
            //To print out the trace corrently,
            //We need to know the load address and it doesn't seem to be exactly
            //0x6000_0000 as originally thought

            playdate_error("PANIC: %s", msg.ptr);
        },
        else => {
            //playdate simulator
            var stack_trace_buffer = [_]u8{0} ** 4096;
            var buffer = [_]u8{0} ** 4096;
            var stream = std.io.fixedBufferStream(&stack_trace_buffer);

            const stack_trace_string = b: {
                if (builtin.strip_debug_info) {
                    break :b "Unable to dump stack trace: Debug info stripped";
                }
                const debug_info = std.debug.getSelfDebugInfo() catch |err| {
                    const to_print = std.fmt.bufPrintZ(
                        &buffer,
                        "Unable to dump stack trace: Unable to open debug info: {s}\n",
                        .{@errorName(err)},
                    ) catch break :b "Unable to dump stack trace: Unable to open debug info due unknown error";
                    break :b to_print;
                };
                std.debug.writeCurrentStackTrace(
                    stream.writer(),
                    debug_info,
                    .no_color,
                    null,
                ) catch break :b "Unable to dump stack trace: Unknown error writng stack trace";

                //NOTE: playdate.system.error (and all Playdate APIs that deal with strings) require a null termination
                const null_char_index = @min(stream.pos, stack_trace_buffer.len - 1);
                stack_trace_buffer[null_char_index] = 0;

                break :b &stack_trace_buffer;
            };
            playdate_error(
                "PANIC: %s\n\n%s",
                msg.ptr,
                stack_trace_string.ptr,
            );
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
