const std = @import("std");
const pdapi = @import("playdate_api.zig");
const toolbox = @import("toolbox");
const game = @import("game.zig");
const level_data = @import("level_data.zig");
const profiler = @import("profiler.zig");

pub const THIS_PLATFORM = toolbox.Platform.Playdate;

pub export fn eventHandler(playdate: *pdapi.PlaydateAPI, event: pdapi.PDSystemEvent, arg: u32) c_int {
    _ = arg;
    const Static = struct {
        var game_state: *game.Game = undefined;
    };
    switch (event) {
        .EventInit => {
            pdapi.set_playdate_api(playdate);
            toolbox.init_playdate_runtime(
                playdate.system.realloc,
                playdate.system.logToConsole,
                playdate.system.@"error",
                playdate.system.getElapsedTime,
                playdate.system.getCurrentTimeMilliseconds,
            );
            pdapi.set_refresh_rate(30);

            profiler.init();
            const font = pdapi.load_font("PICO-8-2x");
            pdapi.set_font(font);

            const game_state = b: {
                const sprites = pdapi.load_bitmap_table("sprites");
                const sprites_bitmap = pdapi.load_bitmap("sprites");
                const debug_font = font;

                var sfx: [22]*pdapi.SamplePlayer = undefined;
                var buffer: [128]u8 = undefined;
                inline for (&sfx, 0..) |*s, i| {
                    const file_name = std.fmt.bufPrintZ(&buffer, "sfx_{}", .{i}) catch |e|
                        toolbox.panic("Failed to create sfx file name: {}", .{e});
                    s.* = pdapi.new_sample_player();
                    const sample = pdapi.load_sample(file_name) catch
                        toolbox.panic("Failed to open {s}", .{file_name});
                    pdapi.set_sample_for_sample_player(s.*, sample);
                }

                var music: [12]game.Music = undefined;
                inline for (&music, 0..) |*m, i| {
                    const file_name = std.fmt.bufPrintZ(&buffer, "music_{}", .{i}) catch |e|
                        toolbox.panic("Failed to create music file name: {}", .{e});
                    const sample = pdapi.load_sample(file_name) catch
                        toolbox.panic("Failed to open {s}", .{file_name});
                    const next_sample = switch (i) {
                        0, 11 => null,
                        6 => 5,
                        10 => 9,
                        else => i + 1,
                    };
                    m.* = .{ .sample = sample, .next = next_sample };
                }
                const music_player = pdapi.new_sample_player();

                var global_arena = toolbox.Arena.init(toolbox.mb(2));
                const level_arena = toolbox.Arena.init(toolbox.mb(1));
                const frame_arena = toolbox.Arena.init(toolbox.mb(1));

                const game_state = global_arena.push(game.Game);
                const map_sprites = global_arena.push_slice(game.Sprite, level_data.map_sprites.len);

                const initial_state = game.GameInitialState{
                    .sprites = sprites,
                    .sprites_bitmap = sprites_bitmap,
                    .debug_font = debug_font,
                    .music = music,
                    .music_player = music_player,
                    .sfx = sfx,
                    .global_arena = global_arena,
                    .level_arena = level_arena,
                    .frame_arena = frame_arena,
                    .game = game_state,
                    .map_sprites = map_sprites,
                };

                game.init(initial_state);
                break :b game_state;
            };

            Static.game_state = game_state;

            pdapi.set_update_callback(update_and_render, game_state);
        },
        .EventResume => {
            game.game_resumed(Static.game_state);
        },
        else => {},
    }
    return 0;
}
fn update_and_render(userdata: ?*anyopaque) callconv(.C) c_int {
    var game_state: *game.Game = @ptrCast(@alignCast(userdata.?));
    const now = toolbox.milliseconds();
    game_state.dt = now - game_state.last_frame_time;
    game_state.last_frame_time = now;

    profiler.start("Frame");
    defer {
        game_state.frame_arena.reset();
    }
    game.reset_clip_rect();
    pdapi.clear_screen(.ColorBlack);

    game.set_main_game_clip_rect();
    game.rectfill(0, 0, 127, 127, 7);
    game_state.update_and_render_fn(game_state);

    pdapi.clear_clip_rect();
    //pdapi.draw_fps(pdapi.LCD_COLUMNS - 30, pdapi.LCD_ROWS - 30);
    //draw_grid();
    profiler.end();

    if (comptime profiler.ENABLE_PROFILING) {
        if (game_state.should_display_profiler) {
            profiler.draw_stats(game_state.debug_font, &game_state.frame_arena);
        }
        if (pdapi.is_chord_pressed(pdapi.BUTTON_UP | pdapi.BUTTON_A | pdapi.BUTTON_B)) {
            game_state.should_display_profiler = !game_state.should_display_profiler;
            //TODO:
            //profiler.flush_spall_json(&game_state.frame_arena);
        }
    }
    //returning 1 signals to the OS to draw the frame.
    //we always want this frame drawn
    return 1;
}
var pattern = [_]u8{
    0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, // Bitmap, each byte is a row of pixel
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // Mask, here fully opaque
};
fn draw_grid() void {
    {
        var y: pdapi.Pixel = game.TILE_SIZE - 1;
        while (y < pdapi.LCD_ROWS) : (y += game.TILE_SIZE) {
            pdapi.draw_line(
                0,
                y,
                pdapi.LCD_COLUMNS,
                y,
                1,
                //pdapi.solid_color_to_color(.ColorBlack),
                pdapi.pattern_to_color(&pattern),
            );
        }
    }
    {
        var x: pdapi.Pixel = game.TILE_SIZE - 1;
        while (x < pdapi.LCD_COLUMNS) : (x += game.TILE_SIZE) {
            pdapi.draw_line(
                x,
                0,
                x,
                pdapi.LCD_ROWS,
                1,
                //       pdapi.solid_color_to_color(.ColorBlack),
                pdapi.pattern_to_color(&pattern),
            );
        }
    }
}
