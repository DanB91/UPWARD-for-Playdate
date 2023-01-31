const toolbox = @import("toolbox.zig");

pub const Milliseconds = switch (toolbox.THIS_PLATFORM) {
    .Playdate => i32,
    else => i64,
};
pub const Microseconds = Milliseconds;
pub const Seconds = switch (toolbox.THIS_PLATFORM) {
    .Playdate => f32,
    else => f64,
};
pub fn microseconds() Microseconds {
    switch (toolbox.THIS_PLATFORM) {
        .MacOS => {
            const ctime = @cImport(@cInclude("time.h"));
            const nanos = ctime.clock_gettime_nsec_np(ctime.CLOCK_MONOTONIC);
            toolbox.assert(nanos != 0, "nanotime call failed!", .{});
            return @intCast(Microseconds, nanos / 1000);
        },
        .Playdate => {
            const sec = seconds();
            return @floatToInt(Microseconds, sec * 1_000_000);
        },
        else => @compileError("Microsecond clock not supported on " ++ @tagName(toolbox.THIS_PLATFORM)),
    }
}
pub fn milliseconds() Milliseconds {
    switch (toolbox.THIS_PLATFORM) {
        .MacOS => return @divTrunc(microseconds(), 1000),
        .BoksOS => {
            const amd64 = @import("../ring0/amd64.zig");
            return amd64.milliseconds();
        },
        .Playdate => {
            const ms = toolbox.playdate_get_milliseconds();
            return @intCast(Milliseconds, ms);
        },
    }
}

pub fn seconds() Seconds {
    switch (toolbox.THIS_PLATFORM) {
        .MacOS => {
            const ctime = @cImport(@cInclude("time.h"));
            const nanos = ctime.clock_gettime_nsec_np(ctime.CLOCK_MONOTONIC);
            toolbox.assert(nanos != 0, "nanotime call failed!", .{});
            return @intToFloat(Seconds, nanos / 1_000_000_000);
        },
        .Playdate => {
            return toolbox.playdate_get_seconds();
        },
        else => @compileError("Microsecond clock not supported on " ++ @tagName(toolbox.THIS_PLATFORM)),
    }
}
