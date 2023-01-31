const toolbox = @import("toolbox");
const pdapi = @import("playdate_api.zig");
const game = @import("game.zig");
const std = @import("std");
const GlobalState = @import("root").GlobalState;

pub const ENABLE_PROFILING = false; // !toolbox.IS_DEBUG;
const MAX_SECTIONS = 64;
var section_map: toolbox.HashMap([]const u8, Section) = undefined;

var section_stack: [MAX_SECTIONS][]const u8 = undefined;
var stack_index: usize = 0;
var profiler_arena: toolbox.Arena = undefined;

var g_spall_events: toolbox.RingQueue(SpallEvent) = undefined;
const SpallEvent = struct {
    name: []const u8,
    start: toolbox.Milliseconds,
    end: toolbox.Milliseconds,
};

const Section = struct {
    start: toolbox.Milliseconds = 0,
    last_time: toolbox.Milliseconds = 0,
    total_time: toolbox.Milliseconds = 0,
    max_time: toolbox.Milliseconds = 0,
    count: usize = 0,
};
pub fn clear() void {
    if (comptime !ENABLE_PROFILING) {
        return;
    }
    if (stack_index != 0) {
        @panic("section stack should be empty");
    }
    section_map.clear();
}
pub fn init() void {
    if (comptime !ENABLE_PROFILING) {
        return;
    }
    profiler_arena = toolbox.Arena.init(toolbox.mb(2));
    section_map = toolbox.HashMap([]const u8, Section).init(MAX_SECTIONS, &profiler_arena);
    g_spall_events = toolbox.RingQueue(SpallEvent).init(1 << 16, &profiler_arena);
}
pub fn start(comptime section_name: []const u8) void {
    if (comptime !ENABLE_PROFILING) {
        return;
    }
    section_stack[stack_index] = section_name;
    stack_index += 1;
    var section = section_map.get_or_put_ptr(section_name, .{}, &profiler_arena);
    section.start = toolbox.milliseconds();
}
pub fn end() void {
    if (comptime !ENABLE_PROFILING) {
        return;
    }
    const end_time = toolbox.milliseconds();

    stack_index -= 1;
    const section_name = section_stack[stack_index];
    var section = section_map.get_ptr(section_name).?;
    const time_taken = end_time - section.start;
    section.last_time = time_taken;
    section.max_time = @max(time_taken, section.max_time);
    const new_total = section.total_time +% time_taken;
    if (new_total >= 0) {
        section.total_time = new_total;
        section.count += 1;
    } else {
        section.total_time = 0;
        section.count = 0;
    }
    g_spall_events.enqueue(.{
        .name = section_name,
        .start = section.start,
        .end = end_time,
    });
}

pub fn flush_spall_json(scratch_arena: *toolbox.Arena) void {
    const save_point = scratch_arena.create_save_point();
    defer scratch_arena.restore_save_point(save_point);

    var file_name_buffer = scratch_arena.push_slice(u8, 256);
    var file_name = std.fmt.bufPrintZ(
        file_name_buffer,
        "spall_{}.json",
        .{toolbox.milliseconds()},
    ) catch |e| toolbox.panic("Error constructing spall file name: {}", .{e});
    var spall_json_file = switch (pdapi.open_file(file_name, pdapi.FILE_WRITE)) {
        .Ok => |file| file,
        .Error => |err| toolbox.panic(
            "Error opening spall.json: {s}",
            .{err},
        ),
    };
    _ = pdapi.write_file(spall_json_file, "[");
    while (!g_spall_events.is_empty()) {
        const tmp_save_point = scratch_arena.create_save_point();
        defer scratch_arena.restore_save_point(tmp_save_point);
        var bytes_consumed: usize = 0;
        var buffer = scratch_arena.push_slice(u8, toolbox.kb(64));

        while (!g_spall_events.is_empty() and bytes_consumed + 128 < buffer.len) {
            const event = g_spall_events.dequeue();
            var begin_line_buffer = buffer[bytes_consumed..];
            const begin_json = std.fmt.bufPrintZ(
                begin_line_buffer,
                "{{\"cat\":\"function\",\"name\":\"{s}\",\"ph\":\"B\",\"pid\":0,\"tid\":0,\"ts\":{}}},\n",
                .{
                    event.name,
                    event.start,
                },
            ) catch |e| toolbox.panic("Error constructing spall JSON: {}", .{e});
            bytes_consumed += begin_json.len;
            var end_line_buffer = buffer[bytes_consumed..];
            const end_json = std.fmt.bufPrintZ(
                end_line_buffer,
                "{{\"ph\":\"E\",\"pid\":0,\"tid\":0,\"ts\":{}}},\n",
                .{event.end},
            ) catch |e| toolbox.panic("Error constructing spall JSON: {}", .{e});
            bytes_consumed += end_json.len;
        }
        _ = pdapi.write_file(spall_json_file, buffer[0..bytes_consumed]);
    }
    _ = pdapi.write_file(spall_json_file, "]");
    pdapi.close_file(spall_json_file);

    toolbox.println("Profiler file {s} written!", .{file_name});
}

pub fn draw_stats(font: *pdapi.LCDFont, scratch_arena: *toolbox.Arena) void {
    if (comptime !ENABLE_PROFILING) {
        return;
    }
    const save_point = scratch_arena.create_save_point();
    defer {
        scratch_arena.restore_save_point(save_point);
    }

    var width: pdapi.Pixel = 0;
    const LineEntry = struct {
        line: []const u8,
        sort_key: f32,
    };

    var sorted_lines = scratch_arena.push_slice([]const u8, section_map.len());
    //sort sections
    {
        const sort_scratch = scratch_arena.push_slice(?LineEntry, section_map.len());
        for (sort_scratch) |*entry| entry.* = null;

        var it = section_map.iterator();
        while (it.next()) |kv| {
            const average = if (kv.v.count != 0) @intToFloat(f32, kv.v.total_time) / @intToFloat(f32, kv.v.count) else 0;
            const len = std.fmt.count("{s}: Last: {d:.2}ms, Avg: {d:.2}ms, Max: {d:.2}ms", .{ kv.k, kv.v.last_time, average, kv.v.max_time }) + 1;
            const line_buffer = scratch_arena.push_slice(u8, @intCast(usize, len));
            const line = std.fmt.bufPrintZ(line_buffer, "{s}: Last: {d:.2}ms, Avg: {d:.2}ms, Max: {d:.2}ms", .{ kv.k, kv.v.last_time, average, kv.v.max_time }) catch "Unknown error!";

            {
                var i: usize = 0;
                const sort_key = average;
                insert_loop: while (i < sort_scratch.len) : (i += 1) {
                    const entry_opt = &sort_scratch[i];
                    if (entry_opt.*) |entry| {
                        //sort with largest towards the begining
                        if (sort_key > entry.sort_key) {
                            //should be inserted in this spot if entry
                            //shift everything over to the right
                            var j: usize = sort_scratch.len - 1;
                            while (j > i) : (j -= 1) {
                                sort_scratch[j] = sort_scratch[j - 1];
                            }
                            entry_opt.* = .{
                                .line = line,
                                .sort_key = sort_key,
                            };
                            break :insert_loop;
                        }
                    } else {
                        entry_opt.* = .{
                            .line = line,
                            .sort_key = sort_key,
                        };
                        break :insert_loop;
                    }
                }
            }
        }
        for (sort_scratch) |entry, i| sorted_lines[i] = entry.?.line;
    }

    pdapi.push_drawing_context(null);
    defer pdapi.pop_drawing_context();

    const font_to_restore = pdapi.get_font();
    pdapi.set_font(font);
    defer {
        pdapi.set_font(font_to_restore);
        game.set_main_game_clip_rect();
    }

    {
        for (sorted_lines) |line| {
            width = @max(width, pdapi.get_text_width(line));
        }
    }

    const line_height = pdapi.get_font_height() + 4;
    pdapi.set_draw_offset(0, 0);
    pdapi.set_screen_clip_rect(0, 0, width, (@intCast(i32, sorted_lines.len) + 1) * line_height);
    pdapi.clear_screen(.ColorWhite);
    {
        var i: pdapi.Pixel = 0;
        // var it = lines.iterator();
        // while (it.next()) |line| {
        for (sorted_lines) |line| {
            _ = pdapi.draw_text(line, 0, i * line_height);
            i += 1;
        }
    }

    toolbox.asserteq(stack_index, 0, "section stack should be empty");
}
