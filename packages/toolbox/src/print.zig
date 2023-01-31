const std = @import("std");
const toolbox = @import("toolbox.zig");

pub fn println_string(string: toolbox.String8) void {
    platform_print_to_console("{s}", .{string.bytes}, false);
}
pub fn println(comptime fmt: []const u8, args: anytype) void {
    platform_print_to_console(fmt, args, false);
}
pub fn printerr(comptime fmt: []const u8, args: anytype) void {
    platform_print_to_console(fmt, args, true);
}

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    var buffer = [_]u8{0} ** 2048;
    const to_print = std.fmt.bufPrint(&buffer, "PANIC: " ++ fmt ++ "\n", args) catch "Unknown error!";
    @panic(to_print);
}

fn platform_print_to_console(comptime fmt: []const u8, args: anytype, comptime is_err: bool) void {
    switch (comptime toolbox.THIS_PLATFORM) {
        .MacOS => {
            var buffer = [_]u8{0} ** 2048;
            //TODO dynamically allocate buffer for printing.  use std.fmt.count to count the size

            const to_print = if (is_err)
                std.fmt.bufPrint(&buffer, "ERROR: " ++ fmt ++ "\n", args) catch return
            else
                std.fmt.bufPrint(&buffer, fmt ++ "\n", args) catch return;

            _ = std.os.write(if (is_err) 2 else 1, to_print) catch {};
        },
        .Playdate => {
            var buffer = [_]u8{0} ** 128;
            const to_print = if (is_err)
                std.fmt.bufPrintZ(&buffer, "ERROR: " ++ fmt, args) catch {
                    toolbox.playdate_log_to_console("String too long to print");
                    return;
                }
            else
                std.fmt.bufPrintZ(&buffer, fmt, args) catch {
                    toolbox.playdate_log_to_console("String too long to print");
                    return;
                };
            toolbox.playdate_log_to_console("%s", to_print.ptr);
        },
        else => @compileError("Unsupported platform"),
    }
    //TODO support BoksOS
    //TODO think about stderr
    //TODO won't work on windows
}
