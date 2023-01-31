const std = @import("std");
const toolbox = @import("toolbox");
const pddefs = @import("playdate_api_definitions.zig");

pub const Pixel = i32;
pub const LCDPatternSlice = []u8;

var pd: *pddefs.PlaydateAPI = undefined;
var current_font: *pddefs.LCDFont = undefined;

pub inline fn set_playdate_api(playdate: *pddefs.PlaydateAPI) void {
    pd = playdate;
}

pub inline fn is_button_pressed(button: pddefs.PDButtons) bool {
    var pressed: pddefs.PDButtons = 0;
    get_button_state(null, &pressed, null);

    return pressed & button != 0;
}

pub inline fn is_button_down(button: pddefs.PDButtons) bool {
    var down: pddefs.PDButtons = 0;
    get_button_state(&down, null, null);

    return down & button != 0;
}
pub inline fn is_chord_pressed(chord: pddefs.PDButtons) bool {
    var down: pddefs.PDButtons = 0;
    var pressed: pddefs.PDButtons = 0;
    get_button_state(&down, &pressed, null);

    if (chord & pressed == 0) {
        return false;
    }

    return ((down | pressed) & chord) == chord;
}

pub inline fn get_button_state(current: ?*pddefs.PDButtons, pushed: ?*pddefs.PDButtons, released: ?*pddefs.PDButtons) void {
    pd.system.getButtonState(current, pushed, released);
}

pub inline fn set_update_callback(callback: ?pddefs.PDCallbackFunction, userdata: ?*anyopaque) void {
    pd.system.setUpdateCallback(callback, userdata);
}

//Draw Color
pub inline fn solid_color_to_color(solid_color: pddefs.LCDSolidColor) pddefs.LCDColor {
    return @intCast(usize, @enumToInt(solid_color));
}
pub inline fn pattern_to_color(pattern: LCDPatternSlice) pddefs.LCDColor {
    return @intCast(usize, @ptrToInt(pattern.ptr));
}
pub inline fn set_draw_mode(mode: pddefs.LCDBitmapDrawMode) void {
    pd.graphics.setDrawMode(mode);
}
/////Draw context
pub inline fn push_drawing_context(target: ?*pddefs.LCDBitmap) void {
    pd.graphics.pushContext(target);
}
pub inline fn pop_drawing_context() void {
    pd.graphics.popContext();
}

////Draw clipping
pub inline fn set_clip_rect(x: Pixel, y: Pixel, width: Pixel, height: Pixel) void {
    pd.graphics.setClipRect(x, y, width, height);
}
pub inline fn clear_clip_rect() void {
    pd.graphics.clearClipRect();
}

////Screen
pub inline fn clear_screen(color: pddefs.LCDSolidColor) void {
    pd.graphics.clear(@intCast(pddefs.LCDColor, @enumToInt(color)));
}
pub inline fn set_screen_clip_rect(x: Pixel, y: Pixel, width: Pixel, height: Pixel) void {
    pd.graphics.setScreenClipRect(x, y, width, height);
}

pub inline fn set_refresh_rate(comptime refresh_rate: f32) void {
    pd.display.setRefreshRate(refresh_rate);
}

pub inline fn set_draw_offset(x: Pixel, y: Pixel) void {
    pd.graphics.setDrawOffset(x, y);
}

////Fonts and text
pub inline fn load_font(path: [*c]const u8) *pddefs.LCDFont {
    var err: [*c]const u8 = undefined;
    const font_opt = pd.graphics.loadFont(path, &err);
    if (font_opt) |font| {
        return font;
    }
    toolbox.panic("Error loading font: {s}", .{err});
}
pub inline fn free_font(font: *pddefs.LCDFont) void {
    _ = font;
    //TODO: there doesn't seem to be a free font function
    //pd.graphics.freeFont(font);
}
pub inline fn set_font(font: *pddefs.LCDFont) void {
    current_font = font;
    pd.graphics.setFont(font);
}
pub inline fn get_font() *pddefs.LCDFont {
    return current_font;
}

pub inline fn draw_text(text: []const u8, x: Pixel, y: Pixel) Pixel {
    return pd.graphics.drawText(text.ptr, text.len, .UTF8Encoding, x, y);
}
pub inline fn draw_fmt(comptime fmt: []const u8, args: anytype, x: Pixel, y: Pixel) Pixel {
    var buffer = [_]u8{0} ** 128;
    const to_print = std.fmt.bufPrintZ(&buffer, fmt, args) catch |e| toolbox.panic("draw_fmt failed:  {}", .{e});
    return draw_text(to_print, x, y);
}
pub inline fn get_text_width(text: []const u8) Pixel {
    return pd.graphics.getTextWidth(current_font, text.ptr, text.len, .UTF8Encoding, 0);
}
pub inline fn get_fmt_width(comptime fmt: []const u8, args: anytype) Pixel {
    var buffer = [_]u8{0} ** 128;
    const to_count = std.fmt.bufPrintZ(&buffer, fmt, args) catch |e| toolbox.panic("draw_fmt failed:  {}", .{e});
    return pd.graphics.getTextWidth(current_font, to_count.ptr, to_count.len, .UTF8Encoding, 0);
}
pub inline fn get_font_height() Pixel {
    return pd.graphics.getFontHeight(current_font);
}

pub inline fn draw_fps(x: Pixel, y: Pixel) void {
    pd.system.drawFPS(x, y);
}

////Bitmap
pub inline fn load_bitmap_table(path: [*c]const u8) *pddefs.LCDBitmapTable {
    var err: [*c]const u8 = undefined;
    const bitmap_table_opt = pd.graphics.loadBitmapTable(path, &err);
    if (bitmap_table_opt) |bitmap_table| {
        return bitmap_table;
    }
    toolbox.panic("Error loading bitmap table: {s}", .{err});
}
pub inline fn free_bitmap_table(bitmap_table: *pddefs.LCDBitmapTable) void {
    pd.graphics.freeBitmapTable(bitmap_table);
}

pub inline fn load_bitmap(path: [*c]const u8) *pddefs.LCDBitmap {
    var err: [*c]const u8 = undefined;
    const bitmap_opt = pd.graphics.loadBitmap(path, &err);
    if (bitmap_opt) |bitmap| {
        return bitmap;
    }
    toolbox.panic("Error loading bitmap: {s}", .{err});
}
pub inline fn free_bitmap(bitmap: *pddefs.LCDBitmap) void {
    pd.graphics.freeBitmap(bitmap);
}

//Shapes
pub inline fn draw_rect(x: Pixel, y: Pixel, width: Pixel, height: Pixel, color: pddefs.LCDColor) void {
    pd.graphics.drawRect(x, y, width, height, color);
}

pub inline fn fill_rect(x: Pixel, y: Pixel, width: Pixel, height: Pixel, color: pddefs.LCDColor) void {
    pd.graphics.fillRect(x, y, width, height, color);
}

pub inline fn draw_ellipse(x: Pixel, y: Pixel, width: Pixel, height: Pixel, lineWidth: Pixel, startAngle: f32, endAngle: f32, color: pddefs.LCDColor) void {
    pd.graphics.drawEllipse(x, y, width, height, lineWidth, startAngle, endAngle, color);
}
pub inline fn fill_ellipse(x: Pixel, y: Pixel, width: Pixel, height: Pixel, startAngle: f32, endAngle: f32, color: pddefs.LCDColor) void {
    pd.graphics.fillEllipse(x, y, width, height, startAngle, endAngle, color);
}

pub inline fn draw_line(x1: Pixel, y1: Pixel, x2: Pixel, y2: Pixel, width: Pixel, color: pddefs.LCDColor) void {
    pd.graphics.drawLine(x1, y1, x2, y2, width, color);
}

pub inline fn set_line_cap_style(cap_style: pddefs.LCDLineCapStyle) void {
    pd.graphics.setLineCapStyle(cap_style);
}

pub const BitmapData = struct {
    width: i32,
    height: i32,
    row_bytes: i32,
    mask: ?[]u8,
    data: []u8,
};

pub fn get_bitmap_data(bitmap: *pddefs.LCDBitmap) BitmapData {
    var width: i32 = 0;
    var height: i32 = 0;
    var row_bytes: i32 = 0;
    var mask_opt: [*c]u8 = null;
    var data_opt: [*c]u8 = null;

    pd.graphics.getBitmapData(bitmap, &width, &height, &row_bytes, &mask_opt, &data_opt);

    const data_size = @intCast(usize, row_bytes * height);
    return .{
        .width = width,
        .height = height,
        .row_bytes = row_bytes,
        .mask = if (mask_opt) |mask| mask[0..data_size] else null,
        .data = data_opt[0..data_size],
    };
}

pub inline fn get_table_bitmap(table: *pddefs.LCDBitmapTable, index: i32) ?*pddefs.LCDBitmap {
    const table_bitmap = pd.graphics.getTableBitmap(table, @intCast(c_int, index));
    return table_bitmap;
}
pub fn get_table_bitmap_size(table: *pddefs.LCDBitmapTable) i32 {
    var ret: i32 = 0;
    while (get_table_bitmap(table, ret)) |_| {
        ret += 1;
    }
    return ret;
}
pub inline fn tile_bitmap(bitmap: *pddefs.LCDBitmap, x: Pixel, y: Pixel, width: Pixel, height: Pixel, flip: pddefs.LCDBitmapFlip) void {
    pd.graphics.tileBitmap(bitmap, x, y, width, height, flip);
}
pub inline fn draw_bitmap(bitmap: *pddefs.LCDBitmap, x: Pixel, y: Pixel, flip: pddefs.LCDBitmapFlip) void {
    pd.graphics.drawBitmap(bitmap, x, y, flip);
}
pub inline fn draw_scaled_bitmap(bitmap: *pddefs.LCDBitmap, x: Pixel, y: Pixel, xscale: f32, yscale: f32) void {
    pd.graphics.drawScaledBitmap(bitmap, x, y, xscale, yscale);
}

//Crank
pub inline fn get_crank_change() f32 {
    return pd.system.getCrankChange();
}
pub inline fn get_crank_angle() f32 {
    return pd.system.getCrankAngle();
}
pub inline fn is_crank_docked() bool {
    return pd.system.isCrankDocked() != 0;
}
pub inline fn set_crank_sounds_disabled(flag: bool) bool {
    return pd.system.setCrankSoundsDisabled(if (flag) 1 else 0) != 0; // returns previous setting
}

//Menu items
pub inline fn add_menu_item(
    title: [:0]const u8,
    callback: ?pddefs.PDMenuItemCallbackFunction,
    userdata: ?*anyopaque,
) *pddefs.PDMenuItem {
    return pd.system.addMenuItem(title.ptr, callback, userdata).?;
}
pub inline fn add_options_menu_item(
    title: [:0]const u8,
    callback: ?pddefs.PDMenuItemCallbackFunction,
    option_titles: [][*c]const u8,
    userdata: ?*anyopaque,
) *pddefs.PDMenuItem {
    return pd.system.addOptionsMenuItem(
        title.ptr,
        option_titles.ptr,
        @intCast(c_int, option_titles.len),
        callback,
        userdata,
    ).?;
}
pub inline fn add_checkmark_menu_item(
    title: [:0]const u8,
    value: bool,
    callback: ?pddefs.PDMenuItemCallbackFunction,
    userdata: ?*anyopaque,
) *pddefs.PDMenuItem {
    return pd.system.addCheckmarkMenuItem(
        title.ptr,
        if (value) 1 else 0,
        callback,
        userdata,
    ).?;
}
pub inline fn get_menu_item_value(menu_item: *pddefs.PDMenuItem) i32 {
    return @intCast(i32, pd.system.getMenuItemValue(menu_item));
}
pub inline fn get_menu_item_value_bool(menu_item: *pddefs.PDMenuItem) bool {
    return get_menu_item_value(menu_item) != 0;
}
pub inline fn set_menu_item_value(menu_item: *pddefs.PDMenuItem, value: i32) void {
    pd.system.setMenuItemValue(menu_item, @intCast(c_int, value));
}
pub inline fn set_menu_item_value_bool(menu_item: *pddefs.PDMenuItem, value: bool) void {
    get_menu_item_value(menu_item, if (value) 1 else 0);
}
pub inline fn remove_menu_item(menu_item: *pddefs.PDMenuItem) void {
    pd.system.removeMenuItem(menu_item);
}
pub inline fn remove_all_menu_items() void {
    pd.system.removeAllMenuItems();
}

//File API
pub fn FileResult(comptime Value: type) type {
    return union(enum) {
        Ok: Value,
        Error: []const u8,
    };
}
pub inline fn open_file(path: [:0]const u8, mode: pddefs.FileOptions) FileResult(*pddefs.SDFile) {
    if (pd.file.open(path.ptr, mode)) |file| {
        return .{ .Ok = file };
    } else {
        return .{ .Error = std.mem.span(pd.file.geterr()) };
    }
}
pub inline fn close_file(file: *pddefs.SDFile) void {
    _ = pd.file.close(file);
}
pub inline fn flush_file(file: *pddefs.SDFile) void {
    _ = pd.file.flush(file);
}
pub fn read_file(file: *pddefs.SDFile, buffer: []u8) FileResult([]const u8) {
    const bytes_read = pd.file.read(file, buffer.ptr, @intCast(c_uint, buffer.len));
    if (bytes_read >= 0) {
        if (bytes_read <= buffer.len) {
            return .{ .Ok = buffer[0..@intCast(usize, bytes_read)] };
        } else {
            return .{ .Error = "Read unexpected number of bytes" };
        }
    } else {
        return .{ .Error = std.mem.span(pd.file.geterr()) };
    }
}
pub fn write_file(file: *pddefs.SDFile, buffer: []const u8) FileResult(void) {
    var bytes_written: usize = 0;
    while (bytes_written < buffer.len) {
        const result = pd.file.write(file, buffer.ptr, @intCast(c_uint, buffer.len));
        if (result >= 0) {
            bytes_written += @intCast(usize, result);
        } else {
            return .{ .Error = std.mem.span(pd.file.geterr()) };
        }
    }
    return .Ok;
}
pub inline fn mkdir(path: [:0]const u8) void {
    _ = pd.file.mkdir(path.ptr);
}
pub inline fn rename_file(from: [:0]const u8, to: [:0]const u8) bool {
    return pd.file.rename(from.ptr, to.ptr) == 0;
}

const ListFilesContext = struct {
    paths_buffer: [][]const u8,
    arena: *toolbox.Arena,
    number_of_paths: usize,
};
pub fn list_files(path: [:0]const u8, arena: *toolbox.Arena) [][]const u8 {
    const MAX_FILES = 256;
    var context = ListFilesContext{
        .paths_buffer = arena.push_slice([]const u8, MAX_FILES),
        .number_of_paths = 0,
        .arena = arena,
    };
    const result = pd.file.listfiles(path.ptr, list_files_callback, &context, 1);
    if (result != 0) {
        toolbox.panic("List files failed: {s}", .{pd.file.geterr()});
    }
    return context.paths_buffer[0..context.number_of_paths];
}
fn list_files_callback(path: [*c]const u8, userdata: ?*anyopaque) callconv(.C) void {
    const context = @ptrCast(*ListFilesContext, @alignCast(@alignOf(ListFilesContext), userdata));
    const path_slice = std.mem.span(path);

    const result_path = context.arena.push_slice(u8, path_slice.len);
    for (result_path) |*c, i| c.* = path[i];

    context.paths_buffer[context.number_of_paths] = result_path;
    context.number_of_paths += 1;
}

//Time API
pub const Seconds = f32;
pub inline fn now_in_seconds() Seconds {
    return pd.system.getElapsedTime();
}
pub inline fn reset_system_clock() void {
    pd.system.resetElapsedTime();
}

//Sound API
pub inline fn get_default_sound_channel() *pddefs.SoundChannel {
    return pd.sound.getDefaultChannel().?;
}
pub inline fn add_sound_source(
    channel: *pddefs.SoundChannel,
    sound_source: *pddefs.SoundSource,
) !void {
    if (pd.sound.channel.addSource(channel, sound_source) == 0) {
        return error.CouldNotAddSoundSource;
    }
}
pub inline fn new_sound_file_player() *pddefs.FilePlayer {
    return pd.sound.fileplayer.newPlayer().?;
}
pub inline fn free_sound_file_player(player: *pddefs.FilePlayer) void {
    pd.sound.fileplayer.freePlayer(player);
}
pub inline fn load_into_sound_file_player(player: *pddefs.FilePlayer, path: [:0]const u8) !void {
    if (pd.sound.fileplayer.loadIntoPlayer(player, path.ptr) == 0) {
        return error.SoundFileNotFound;
    }
}
//repeat: >0: number of times to loop, 0: loop forever
pub inline fn play_sound_file_player(player: *pddefs.FilePlayer, repeat: i32) void {
    const play_result = pd.sound.fileplayer.play(player, @intCast(c_int, repeat));
    toolbox.assert(play_result != 0, "Failed to play file player", .{});
}
pub inline fn stop_sound_file_player(player: *pddefs.FilePlayer) void {
    pd.sound.fileplayer.stop(player);
}

pub inline fn load_sample(path: [:0]const u8) !*pddefs.AudioSample {
    if (pd.sound.sample.load(path.ptr)) |sample| {
        return sample;
    }
    return error.SoundSampleFileNotFound;
}
pub inline fn new_sample_player() *pddefs.SamplePlayer {
    return pd.sound.sampleplayer.newPlayer().?;
}
pub inline fn play_sample_player(player: *pddefs.SamplePlayer, repeat: i32, rate: f32) void {
    _ = pd.sound.sampleplayer.play(player, repeat, rate);
}
pub inline fn stop_sample_player(player: *pddefs.SamplePlayer) void {
    pd.sound.sampleplayer.stop(player);
}
pub inline fn set_sample_for_sample_player(
    player: *pddefs.SamplePlayer,
    sample: *pddefs.AudioSample,
) void {
    pd.sound.sampleplayer.setSample(player, sample);
}
pub fn set_sample_player_loop_callback(
    player: *pddefs.SamplePlayer,
    callback: ?*const fn (player: *pddefs.SamplePlayer, userdata: ?*anyopaque) void,
    userdata: ?*anyopaque,
) void {
    if (callback) |c| {
        sample_player_loop_callback_state = .{
            .callback = c,
            .userdata = userdata,
        };
    }
    pd.sound.sampleplayer.setLoopCallback(player, sample_player_loop_callback);
}
var sample_player_loop_callback_state: struct {
    callback: *const fn (player: *pddefs.SamplePlayer, userdata: ?*anyopaque) void,
    userdata: ?*anyopaque,
} = undefined;
fn sample_player_loop_callback(c: ?*pddefs.SoundSource) callconv(.C) void {
    sample_player_loop_callback_state.callback(
        @ptrCast(*pddefs.SamplePlayer, c),
        sample_player_loop_callback_state.userdata,
    );
}

pub inline fn new_synth() *pddefs.PDSynth {
    return pd.sound.synth.newSynth().?;
}
pub inline fn free_synth(synth: *pddefs.PDSynth) void {
    pd.sound.synth.freeSynth(synth);
}
pub inline fn play_synth_note(
    synth: *pddefs.PDSynth,
    freq: f32,
    vel: f32,
    len: f32,
    when: u32,
) void {
    pd.sound.synth.playNote(synth, freq, vel, len, when);
}
pub inline fn play_synth_midi_note(
    synth: *pddefs.PDSynth,
    note: pddefs.MIDINote,
    vel: f32,
    len: f32,
    when: u32,
) void {
    pd.sound.synth.playMIDINote(synth, note, vel, len, when);
}
pub inline fn set_synth_waveform(synth: *pddefs.PDSynth, wave: pddefs.SoundWaveform) void {
    pd.sound.synth.setWaveform(synth, wave);
}
