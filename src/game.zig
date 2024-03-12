const toolbox = @import("toolbox");
const pdapi = @import("playdate_api.zig");
const level_data = @import("level_data.zig");
const entity = @import("entity.zig");
const effects = @import("effects.zig");
const std = @import("std");
const profiler = @import("profiler.zig");

pub const DEBUG = false;

pub const SCREEN_SIZE_PX = 240;
pub const SCREEN_OFFSET_X = (pdapi.LCD_COLUMNS - SCREEN_SIZE_PX) / 2;
pub const SCREEN_OFFSET_Y = (pdapi.LCD_ROWS - SCREEN_SIZE_PX) / 2;
pub const TILE_SIZE = 15;
pub const MAP_SCREEN_SIZE = 16;
pub const SAVE_DATA_FILENAME = "save.dat";

const MAX_LEVELS = level_data.levels.len; //game.lvl_last=31

//Full name: TileDimension
pub const TileDim = i32;

pub const Sprite = u8;

//Full name: WorldDimension
pub const WorldDim = f32;

pub const P8Color = u8;
pub const P8Music = i32;
pub const P8Sfx = u8;

pub const GameInitialState = struct {
    sprites: *pdapi.LCDBitmapTable,
    sprites_bitmap: *pdapi.LCDBitmap,
    debug_font: *pdapi.LCDFont,
    sfx: [22]*pdapi.SamplePlayer,
    music: [12]Music,
    music_player: *pdapi.SamplePlayer,

    global_arena: toolbox.Arena,
    level_arena: toolbox.Arena,
    frame_arena: toolbox.Arena,

    game: *Game,
    map_sprites: []Sprite,
};

pub const Game = struct {
    initial_state: GameInitialState,

    level_number: i32,
    deaths: i32,

    //holds the elapsed time of the game
    clock: toolbox.Seconds,

    //time level started
    clock_start: toolbox.Seconds,

    // formatted string of time elapsed in level
    clock_s: toolbox.String8,

    mode: Mode,

    //ideally should be tied to Mode.StartDownward, but it seems on line 533, it's not
    downward: bool,

    //used to show debug HUD
    show_debug: bool,

    //a count-up timer used in various areas. ticks once per frame
    start_t: i32,

    //state variable from transisioning from menu to game
    launch: bool,

    //a count-up timer used in various areas. ticks once per frame
    launch_t: i32,

    //used to show "reset" icon when screen is clicked. not using it here
    //game.show_reset=false

    //a count-up timer used in various areas. ticks once per frame
    t: i32,

    held_b_t: i32,
    held_b_from_last_retry: bool,

    blob: Blob,
    level: Level,

    map_x: TileDim,
    map_y: TileDim,

    start_x: WorldDim,
    start_y: WorldDim,

    map_sprites: []Sprite,

    //program-related fields
    update_and_render_fn: *const fn (g: *Game) void,

    random_state: toolbox.RandomState,

    sprites: *pdapi.LCDBitmapTable,
    sprites_bitmap: *pdapi.LCDBitmap,

    global_arena: toolbox.Arena,
    frame_arena: toolbox.Arena,
    level_arena: toolbox.Arena,

    save_data: [4 * 6]u8,
    playing_music: ?*Music,

    best_time: toolbox.Seconds,
    least_deaths: i32,
    new_record: bool,

    sfx: [22]*pdapi.SamplePlayer,
    music: [12]Music,
    music_player: *pdapi.SamplePlayer,

    should_display_profiler: bool,
    debug_font: *pdapi.LCDFont,

    entities: toolbox.RandomRemovalLinkedList(entity.Entity),
    particles: toolbox.RandomRemovalLinkedList(effects.Particle),

    hide_hud: bool,
    hide_hud_menu_item: *pdapi.PDMenuItem,

    dt: toolbox.Milliseconds,
    last_frame_time: toolbox.Milliseconds,
};

pub const Level = struct {
    won: bool,
    lost: bool,
    give_up: bool,
    next: bool,
    next2: bool,
    unlock_white: bool,
    unlock_black: bool,
    no_ledge: bool,
    move_sound: bool,
    move_t: i32,
    t: i32,
    got_medicine: bool,
    game_won: bool,
    cutscene: i32,
    the_end: bool,
    stats: bool,
    ms_blob: ?*entity.Entity,
    wait_t: i32,
    waited: bool,
    show_hint: bool,
    show_hint_t: i32,
    game_reset: i32,
};
pub const LevelDescriptor = struct {
    map_x: TileDim,
    map_y: TileDim,
    start_x: WorldDim,
    start_y: WorldDim,
    downward: bool,
    entities: ?toolbox.FixedList(entity.Entity, 6),
};
pub const Blob = struct {
    x: WorldDim,
    y: WorldDim,
    pad_left: f32,
    pad_right: f32,
    pad_top: f32,
    pad_bottom: f32,

    state: State,
    jump: bool,
    down: bool,
    ignore_ground: bool,
    spd_x: WorldDim,
    spd_y: WorldDim,
    grav_up: WorldDim,
    grav_down: WorldDim,
    grav_down_max: WorldDim,
    jump_height: WorldDim,
    jump_height_min: WorldDim,
    has_landed: bool,
    invincible_t: i32,
    t: f32,
    down_t: i32,
    spr: Sprite,
    medicine: bool,
    message: toolbox.String8,
    message_t: i32,

    const State = enum {
        None,
        Idle,
        Downward,
        Dead,
        Cutscene,
        Won,
    };
};

pub const Mode = enum {
    Start,
    StartDownward,
    Play,
};

pub const Music = struct {
    sample: *pdapi.AudioSample,
    next: ?usize,
};

pub fn init(
    initial_state: GameInitialState,
) void {
    const game = initial_state.game;
    game.* = .{
        .initial_state = initial_state,

        .level_number = 1,
        .deaths = 0,
        .clock = 0,
        .clock_start = 0,
        .clock_s = .{},
        .mode = undefined,
        .downward = false,
        .show_debug = false,
        .start_t = -48,
        .launch = false,
        .launch_t = 0,
        .t = 0,
        .held_b_t = 0,
        .held_b_from_last_retry = false,

        .map_sprites = initial_state.map_sprites,

        .sprites = initial_state.sprites,
        .sprites_bitmap = initial_state.sprites_bitmap,
        .sfx = initial_state.sfx,
        .music = initial_state.music,
        .music_player = initial_state.music_player,

        .blob = undefined,
        .level = undefined,

        .map_x = 0,
        .map_y = 0,

        .start_x = 0,
        .start_y = 0,

        .random_state = @as(toolbox.RandomState, @intCast(toolbox.microseconds())),
        .save_data = [_]u8{0} ** (4 * 6),
        .playing_music = null,

        .global_arena = initial_state.global_arena,
        .level_arena = initial_state.level_arena,
        .frame_arena = initial_state.frame_arena,

        .entities = toolbox.RandomRemovalLinkedList(entity.Entity).init(),
        .particles = toolbox.RandomRemovalLinkedList(effects.Particle).init(),

        .best_time = -1,
        .least_deaths = -1,
        .new_record = false,

        .update_and_render_fn = undefined,

        .should_display_profiler = false,
        .debug_font = initial_state.debug_font,

        .dt = 0,
        .last_frame_time = toolbox.milliseconds(),

        .hide_hud = false,
        .hide_hud_menu_item = undefined,
    };
    pdapi.set_sample_player_loop_callback(
        game.music_player,
        music_loop_callback,
        game,
    );

    //NOTE: populate save data cache with initialized values before loading from file.
    //In the case with no save data, -1 will be used as the initial value for both
    //these fields.
    dset(3, game.best_time, game);
    dset(4, game.least_deaths, game);

    for (game.map_sprites, 0..) |*s, i| s.* = level_data.map_sprites[i];

    game_savedata_load(game);

    set_mode(.Start, game);

    level_load(game);
}
fn music_loop_callback(player: *pdapi.SamplePlayer, userdata: ?*anyopaque) void {
    var game = @as(*Game, @ptrCast(@alignCast(userdata.?)));

    //edge case. should only happen if there is a race condition between stopping music in
    //the game loop and here.  I'm not even sure it's possible.  Should probably have an assert instead...
    if (game.playing_music == null) {
        pdapi.stop_sample_player(player);
        return;
    }

    if (game.playing_music.?.next) |next_sample| {
        const next_music = &game.music[next_sample];
        pdapi.set_sample_for_sample_player(player, next_music.sample);
        game.playing_music = next_music;
    } else {
        pdapi.stop_sample_player(player);
        game.playing_music = null;
    }
}

fn new_blob(x: WorldDim, y: WorldDim) Blob {
    return .{
        .state = .Idle,
        .jump = false,
        .down = false,
        .ignore_ground = false,
        .x = x,
        .y = y,
        .pad_left = -1,
        .pad_right = -1,
        .pad_top = -1,
        .pad_bottom = 0,
        .spd_x = 0,
        .spd_y = 0,
        .grav_up = 0.4,
        .grav_down = 0.6,
        .grav_down_max = 4,
        .jump_height = -5,
        .jump_height_min = -5,
        .has_landed = true,
        .invincible_t = 0,
        .t = 0,
        .down_t = 0,
        .spr = 1,
        .medicine = false,
        .message = .{},
        .message_t = 0,
    };
}
pub fn reset_clip_rect() void {
    pdapi.set_draw_mode(.DrawModeCopy);
    pdapi.set_draw_offset(0, 0);
    pdapi.clear_clip_rect();
}

pub fn game_resumed(game: *Game) void {
    game.clock_start = time() - game.clock;
}

pub fn set_main_game_clip_rect() void {
    pdapi.set_draw_mode(.DrawModeCopy);
    pdapi.set_draw_offset(SCREEN_OFFSET_X, SCREEN_OFFSET_Y);
    pdapi.set_clip_rect(0, 0, SCREEN_SIZE_PX, SCREEN_SIZE_PX);
}

fn set_mode(mode: Mode, game: *Game) void {
    switch (mode) {
        .Start, .StartDownward => {
            pdapi.remove_all_menu_items();
            game.hide_hud_menu_item =
                pdapi.add_checkmark_menu_item(
                "hide hud",
                game.hide_hud,
                menu_item_hide_hud,
                game,
            );
            game.update_and_render_fn = update_and_render_menu;
        },
        .Play => game.update_and_render_fn = update_and_render_play,
    }
    game.mode = mode;
}
fn update_and_render_play(game: *Game) void {
    {
        profiler.start("game update");
        defer profiler.end();
        {
            profiler.start("entities loop");
            defer profiler.end();
            var it = game.entities.iterator();
            while (it.next()) |e| {
                update_entity(e, game);
            }
        }
        {
            var it = game.particles.iterator();
            while (it.next()) |p| {
                effects.update_particle(p, game);
            }
        }
        blob_update(game);
        level_update(game);
        game_update(game);
    }
    {
        profiler.start("game draw");
        defer profiler.end();
        game_draw(game);
    }
}
fn blob_update(game: *Game) void {
    var blob = &game.blob;
    blob.jump = btnp(2) or btnp(5);
    blob.down = btnp(3) or btnp(5);
    if (blob.state != .Cutscene) blob_animate(blob);
    switch (blob.state) {
        .Idle => blob_idle(game),
        .Downward => blob_downward(game),
        .Dead => blob_dead(game),
        .Cutscene, .Won, .None => {},
    }
    move_object(blob);
    if (blob.spd_x != 0) blob.spd_x *= 0.8;
    if (blob.state != .Dead) apply_gravity_blob(blob, game);
    if (blob.invincible_t > 0) blob.invincible_t -= 1;
}
fn blob_animate(blob: *Blob) void {
    if (blob.spd_y < 0) {
        blob.t += 0.7;
        blob.spr = @as(Sprite, @intFromFloat(toolbox.clamp((blob.t / 3) + 3, 3, 5)));
        blob.has_landed = false;
    } else if (blob.spd_y > 0) {
        blob.t -= 1;
        blob.spr = @as(Sprite, @intFromFloat(toolbox.clamp((blob.t / 3) + 5, 3, 5)));
        blob.has_landed = false;
    } else {
        blob.t = 0;
        blob.spr = 2;
    }
    if (blob.state == .Dead) blob.spr = 6;
}
fn blob_idle(game: *Game) void {
    var blob = &game.blob;
    if (blob.jump and is_on_ground(blob, game) and blob.spd_y == 0) blob_jump(blob.jump_height, game);
    if (!btn(2) and blob.spd_y < blob.jump_height_min) blob.spd_y = blob.jump_height_min;
    blob_ride_conveyor(game);
    if ((btn(0) or btn(1)) and game.level_number < 5) {
        blob.message = toolbox.string8_literal("i can only jump");
        blob.message_t = 30;
    }
    if (blob.message_t > 0) blob.message_t -= 1;
    if (blob.message_t == 0) blob.message = .{};
}
fn blob_downward(game: *Game) void {
    var blob = &game.blob;
    if (blob.down_t > 0) blob.down_t -= 1;
    if (blob.down_t == 0) blob.ignore_ground = false;
    if (blob.down and is_on_semi_ground(blob, game) and blob.spd_y == 0) {
        blob.ignore_ground = true;
        blob.down_t = 5;
    }
    blob_ride_conveyor(game);
}
fn blob_dead(game: *Game) void {
    var blob = &game.blob;
    blob.spd_y += 0.4;
    if (blob.spd_y > 4) blob.spd_y = 4;
    blob.y += blob.spd_y;
}
fn blob_ride_conveyor(game: *Game) void {
    var blob = &game.blob;
    if (is_on_con_left(blob, game) and blob.spd_y == 0) blob.x -= 1;
    if (is_on_con_right(blob, game) and blob.spd_y == 0) blob.x += 1;
}
fn move_object(obj: anytype) void {
    obj.x += obj.spd_x;
    obj.y += obj.spd_y;
}
fn apply_gravity_blob(obj: *Blob, game: *Game) void {
    if (obj.spd_y < 0) {
        obj.spd_y += obj.grav_up;
        if (hits_ceiling(obj, game)) obj.spd_y = 0;
    }
    if (obj.spd_y >= 0) {
        obj.spd_y += obj.grav_down;
        if (obj.spd_y > obj.grav_down_max) obj.spd_y = obj.grav_down_max;
        if (!obj.ignore_ground and is_on_ground(obj, game)) {
            if (!obj.has_landed) {
                obj.has_landed = true;
                sfx(1, game);
                const particle1 = effects.create_particle(
                    obj.x,
                    obj.y - @mod(obj.y, 8) + 7,
                    rnd(0.2, game) * -1 - 0.2,
                    0,
                    1.2,
                    0,
                    7,
                );
                const particle2 = effects.create_particle(
                    obj.x + 7,
                    obj.y - @mod(obj.y, 8) + 7,
                    rnd(0.2, game) + 0.2,
                    0,
                    1.2,
                    0,
                    7,
                );
                _ = game.particles.append(particle1, &game.level_arena);
                _ = game.particles.append(particle2, &game.level_arena);
            }
            obj.spd_y = 0;
            obj.y = obj.y - @mod(obj.y, 8);
        }
    }
}
fn apply_gravity_enemy(obj: *entity.Entity, enemy: *entity.Enemy, game: *Game) void {
    if (obj.spd_y < 0) {
        if (hits_ceiling(obj, game)) obj.spd_y = 0;
    }
    if (obj.spd_y >= 0) {
        obj.spd_y += enemy.grav_down;
        if (obj.spd_y > enemy.grav_down_max) obj.spd_y = enemy.grav_down_max;
        if (is_on_ground(obj, game)) {
            if (!enemy.has_landed) {
                enemy.has_landed = true;
                sfx(1, game);
                const particle1 = effects.create_particle(
                    obj.x,
                    obj.y - @mod(obj.y, 8) + 7,
                    rnd(0.2, game) * -1 - 0.2,
                    0,
                    1.2,
                    0,
                    7,
                );
                const particle2 = effects.create_particle(
                    obj.x + 7,
                    obj.y - @mod(obj.y, 8) + 7,
                    rnd(0.2, game) + 0.2,
                    0,
                    1.2,
                    0,
                    7,
                );
                _ = game.particles.append(particle1, &game.level_arena);
                _ = game.particles.append(particle2, &game.level_arena);
            }
            obj.spd_y = 0;
            obj.y = obj.y - @mod(obj.y, 8);
        }
    }
}

fn game_update(game: *Game) void {
    var level = &game.level;
    var blob = &game.blob;
    var should_update_clock = blob.state != .Cutscene;

    if (game.level_number == 6 and blob.x > 126) {
        level_next(game);
    }
    if (btn(4)) {
        if (!game.held_b_from_last_retry) {
            game.held_b_t += 1;
        }
    } else {
        game.held_b_t = 0;
        game.held_b_from_last_retry = false;
    }
    if (game.held_b_t > 20 and
        !level.won and
        !level.lost and
        !level.give_up and
        !level.game_won)
    {
        level_retry(game);
        game.held_b_t = 0;
        game.held_b_from_last_retry = true;
    }

    if (DEBUG and btnp(0)) {
        level_prior(game);
    }
    if (DEBUG and btnp(1)) {
        level_next(game);
    }
    if (level.won) {
        game.t += 1;
        if (game.t > 60) {
            level.next = true;
        }
        if (game.t > 75 and !level.next2) {
            if (is_on_con_right(blob, game)) {
                blob.x += 1;
            } else {
                level.next2 = true;
                blob_jump(blob.jump_height, game);
            }
        }
        if (level.next and (blob.y < -24 or blob.x > 127)) {
            level_next(game);
        }
    }
    if (blob.y > 127) {
        if (game.downward and !level.lost and !level.give_up and !(game.level_number >= 24 and game.level_number <= 27)) {
            level_next(game);
        } else {
            blob_die(game);
        }
    }
    if (game.level_number >= 24 and game.level_number <= 27 and blob.x < -2) {
        level_next(game);
    }
    if (level.lost) {
        game.t += 1;
        if (game.t > 30) {
            level_load(game);
            game.deaths += 1;
        }
    }
    if (level.got_medicine) {
        level.t += 1;
        should_update_clock = false;
        if (level.t > 180) {
            level.got_medicine = false;
            level.t = 0;
            set_mode(.StartDownward, game);
        }
    }
    if (level.game_won) {
        if (level.cutscene == 1) {
            game.t += 1;
            blob.state = .Cutscene;
            if (game.t == 30) {
                blob.x = 64;
            }
            if (game.t == 60) {
                blob.medicine = false;
                blob.spr = 6;
                var medicine = entity.create_medicine(blob.x, blob.y - 8);
                medicine.class.Medicine.state = .Use;
                _ = game.entities.append(medicine, &game.level_arena);
            }
        }
        if (level.cutscene == 2) {
            var ms_blob = level.ms_blob.?;
            game.t += 1;
            switch (game.t) {
                30 => blob.spr = 2,
                90 => ms_blob.spr = 10,
                120 => ms_blob.class.MsBlob.state = .Idle,
                151...179 => blob.message = toolbox.string8_literal("♥  "),
                240 => ms_blob.class.MsBlob.state = .Moving,
                360 => level.the_end = true,
                420 => level.stats = true,
                421...0x7FFF_FFFF => {
                    if (btn(5)) {
                        music(-1, game);
                        game_savedata_reset(game);
                        init(game.initial_state);
                    }
                },
                else => {},
            }
            if (game.t > 240 and blob.x < 140) {
                blob.x += 0.5;
            }
            if (blob.x == 140) {
                ms_blob.spd_x = 0;
                ms_blob.class.MsBlob.state = .Idle;
            }
        }
    }
    //NOTE: this is not from the original game.
    // originally the clock was only updated in the level_next()
    // but this should be more accurate
    if (should_update_clock) {
        game.clock = time() - game.clock_start;
    }
}

fn game_draw(game: *Game) void {
    var blob = &game.blob;
    var level = &game.level;
    map(game.map_x, game.map_y, game);
    {
        var it = game.entities.iterator();
        while (it.next()) |e| {
            sprflip(
                e.spr,
                e.x,
                e.y,
                e.direction == .Left and e.class != .BulletSpawn,
                game,
            );
        }
    }
    if (blob.medicine) spr(14, blob.x - 3, blob.y - 2, game);
    spr(blob.spr, blob.x, blob.y, game);
    {
        var it = game.particles.iterator();
        while (it.next()) |p| {
            effects.draw_particle(p);
        }
    }
    if (level.won and !level.next) message(toolbox.string8_literal("oh yeah"), 8);
    if (level.lost) message(toolbox.string8_literal("oh no"), 0);
    if (level.give_up) message(toolbox.string8_literal("there must be a way"), 0);
    if (level.got_medicine and level.t <= 75) message(toolbox.string8_literal("you got medicine"), 8);
    if (level.got_medicine and level.t > 75) message(toolbox.string8_literal("this is heavy..."), 8);
    if (level.show_hint) level.show_hint_t += 1;
    if (level.show_hint and level.show_hint_t > 30 and !level.give_up) {
        blob.message = toolbox.string8_literal("   stuck? hold b");
        blob.message_t = 90;
        level.show_hint = false;
        level.show_hint_t = 0;
    }
    if (blob.message.rune_length > 0 and !level.give_up) {
        const s = blob.message;
        const lenf32 = @as(WorldDim, @floatFromInt(s.rune_length));
        if (game.level_number != 31) {
            rectfill(
                blob.x - lenf32 * 2 + 3,
                blob.y - 8,
                blob.x + lenf32 * 2 + 3,
                blob.y - 8 + 4,
                7,
            );
        }
        print(s, blob.x - lenf32 * 2 + 6, blob.y - 8, 0);
    }
    if (level.the_end) message(toolbox.string8_literal("the end"), 0);
    if (level.stats) {
        rectfill(0, 73, 127, 89 + @as(WorldDim, if (game.new_record) 6 else 0), 7);
        var buffer = [_]u8{0} ** 128;
        {
            const s = toolbox.string8_fmt(&buffer, "deaths: {}", .{game.deaths}) catch |e|
                toolbox.panic("print stats failed:  {}", .{e});
            const rune_length_f32 = @as(WorldDim, @floatFromInt(s.rune_length));
            print(s, 64 - rune_length_f32 * 2 + 3, 75, 0);
        }
        {
            const s = toolbox.string8_fmt(&buffer, "time: {s}", .{game.clock_s}) catch |e|
                toolbox.panic("print stats failed:  {}", .{e});
            const rune_length_f32 = @as(WorldDim, @floatFromInt(s.rune_length));
            print(s, 64 - rune_length_f32 * 2 + 3, 83, 0);
        }
        if (game.new_record) {
            const s = toolbox.string8_literal("new record!");
            const rune_length_f32 = @as(WorldDim, @floatFromInt(s.rune_length));
            print(s, 64 - rune_length_f32 * 2 + 3, 91, 0);
        }
        {
            const s = toolbox.string8_literal("ported with ♥ by daniel bokser");
            const rune_length_f32 = @as(WorldDim, @floatFromInt(s.rune_length));
            print(s, 64 - rune_length_f32 * 2 + 3, 5, 0);
        }
        {
            const s = toolbox.string8_literal("made with ♥ by matthias falk");
            const rune_length_f32 = @as(WorldDim, @floatFromInt(s.rune_length));
            print(s, 64 - rune_length_f32 * 2 + 3, 119, 0); //6);
        }
    }
    if (game.show_debug) {
        show_debug(game);
    }
    if (!game.hide_hud) {
        draw_hud(game);
    }
}
fn draw_hud(game: *Game) void {
    pdapi.set_draw_offset(0, 0);
    pdapi.clear_clip_rect();
    pdapi.set_draw_mode(.DrawModeFillWhite);
    defer set_main_game_clip_rect();
    const line_height = 11;
    _ = pdapi.draw_fmt(
        "level: {}",
        .{game.level_number},
        0,
        pdapi.LCD_ROWS - (line_height * 1),
    );

    {
        const play_time = game.clock;
        const play_min = @as(u32, @intFromFloat(play_time / 60));
        const play_sec = @as(u32, @intFromFloat(play_time - @floor(play_time / 60) * 60));
        draw_hud_text_from_right("time: {}:{:0>2}", .{ play_min, play_sec }, 0 * line_height);
    }
    {
        _ = pdapi.draw_fmt("deaths: {}", .{game.deaths}, 0, 0 * line_height);
        //_ = pdapi.draw_fmt("DT: {}ms", .{game.dt}, 0, 2 * line_height);
    }
    if (game.least_deaths >= 0) {
        _ = pdapi.draw_fmt(
            "best: {}",
            .{game.least_deaths},
            0,
            1 * line_height,
        );
    }
    if (game.best_time >= 0) {
        const play_min = @as(u32, @intFromFloat(game.best_time / 60));
        const play_sec = @as(u32, @intFromFloat(game.best_time - @floor(game.best_time / 60) * 60));
        draw_hud_text_from_right(
            "best: {}:{:0>2}",
            .{ play_min, play_sec },
            1 * line_height,
        );
    }
}
fn draw_hud_text_from_right(comptime fmt: []const u8, args: anytype, y: pdapi.Pixel) void {
    var buffer: [64]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buffer, fmt, args) catch @panic("Failed to draw text");
    const text_width = pdapi.get_text_width(text);
    const right_side_x = pdapi.LCD_COLUMNS - text_width;
    _ = pdapi.draw_text(text, right_side_x, y);
}

fn show_debug(game: *Game) void {
    pdapi.set_draw_offset(0, 0);
    pdapi.clear_clip_rect();
    pdapi.set_draw_mode(.DrawModeFillWhite);

    _ = pdapi.draw_fmt("level: {}", .{game.level_number}, 0, 0);
    _ = pdapi.draw_fmt("entities: {}", .{game.entities.len}, 0, wtop(6));
    _ = pdapi.draw_fmt("x: {d:.2}", .{game.blob.x}, 0, wtop(12));
    _ = pdapi.draw_fmt("y: {d:.2}", .{game.blob.y}, 0, wtop(18));

    set_main_game_clip_rect();
}
fn update_entity(e: *entity.Entity, game: *Game) void {
    var blob = &game.blob;
    var level = &game.level;
    switch (e.class) {
        .Goal => {
            if (touches_object(blob, e)) {
                if (!level.won and blob.state != .Dead) {
                    level.won = true;
                    blob.state = .Won;
                    const particle1 = effects.create_particle(e.x, e.y + 4, -2, 0.4, 2.4, 9, 9);
                    const particle2 = effects.create_particle(e.x + 7, e.y + 4, 2, 0.4, 2.4, 9, 9);
                    const particle3 = effects.create_particle(e.x, e.y + 4, -1, 0.2, 2, 9, 7);
                    const particle4 = effects.create_particle(e.x + 7, e.y + 4, 1, 0.2, 2, 9, 7);
                    _ = game.particles.append(particle1, &game.level_arena);
                    _ = game.particles.append(particle2, &game.level_arena);
                    _ = game.particles.append(particle3, &game.level_arena);
                    _ = game.particles.append(particle4, &game.level_arena);
                    game.entities.remove(e);
                    music(0, game);
                }
            }
        },
        .Enemy => |*enemy| {
            switch (enemy.class) {
                .Black => anim_enemy_black(e),
                .White => anim_enemy_white(e),
            }
            if (!ledge_both(e, game) and e.spd_y == 0) {
                if ((!level.no_ledge and ledge_right(e, game)) or wall_right(e, game)) e.direction = .Left;
                if ((!level.no_ledge and ledge_left(e, game)) or wall_left(e, game)) e.direction = .Right;
                e.spd_x = switch (e.direction) {
                    .Left => -0.5,
                    .Right => 0.5,
                };
            } else {
                e.spd_x = 0;
            }
            if (e.spd_y > 0) enemy.has_landed = false;
            move_object(e);
            apply_gravity_enemy(e, enemy, game);
            if (touches_object(e, blob)) {
                if (blob.y + 7 < e.y + 5 and blob.spd_y > 0 and !enemy.is_killed and blob.state != .Dead) {
                    enemy.is_killed = true;
                    blob_jump(-2, game);
                    blob.invincible_t = 10;
                    const col_fill: P8Color = switch (enemy.class) {
                        .White => 7,
                        .Black => 0,
                    };
                    const particle1 = effects.create_particle(e.x, e.y + 6, -1, 0, 2.4, 0, col_fill);
                    const particle2 = effects.create_particle(e.x + 7, e.y + 6, 1, 0, 2.4, 0, col_fill);
                    _ = game.particles.append(particle1, &game.level_arena);
                    _ = game.particles.append(particle2, &game.level_arena);
                    if (enemy.class == .White and game.level_number < 5) level.show_hint = true;
                    game.entities.remove(e);
                }
                if (enemy.class == .Black and !enemy.is_killed and blob.invincible_t == 0) blob_die(game);
                if (enemy.class == .White and blob.spd_y == 0) {
                    if (e.x > blob.x and e.spd_x < 0) blob.spd_x = e.spd_x;
                    if (e.x < blob.x and e.spd_x > 0) blob.spd_x = e.spd_x;
                    if (!level.move_sound) {
                        level.move_sound = true;
                        sfx(6, game);
                        const e_x: WorldDim = switch (e.direction) {
                            .Left => 8,
                            .Right => 0,
                        };
                        const particle1 = effects.create_particle(
                            e.x + e_x,
                            e.y + 7,
                            //this is correct.  sign is flipped
                            if (e.direction == .Left) 0.5 else -0.5,
                            0,
                            2,
                            0,
                            7,
                        );
                        _ = game.particles.append(particle1, &game.level_arena);
                    }
                }
            }
        },
        .KeyWhite => {
            if (touches_object(e, blob)) {
                level.unlock_white = true;
                level.no_ledge = true;
                const particle1 = effects.create_particle(e.x, e.y + 4, -1, 0, 2, 0, 7);
                const particle2 = effects.create_particle(e.x + 7, e.y + 4, 1, 0, 2, 0, 7);
                _ = game.particles.append(particle1, &game.level_arena);
                _ = game.particles.append(particle2, &game.level_arena);
                game.entities.remove(e);
                sfx(5, game);
            }
        },
        .LockWhite => {
            if (level.unlock_white) {
                const particle1 = effects.create_particle(e.x + 4, e.y, 0, -2, 2, 0, 7);
                const particle2 = effects.create_particle(e.x + 4, e.y + 7, 0, 2, 2, 0, 7);
                _ = game.particles.append(particle1, &game.level_arena);
                _ = game.particles.append(particle2, &game.level_arena);
                mset(wtot(e.x) + game.map_x, wtot(e.y) + game.map_y, 38, game);
                game.entities.remove(e);
            }
        },
        .KeyBlack => {
            if (touches_object(e, blob)) {
                level.unlock_black = true;
                level.no_ledge = true;
                const particle1 = effects.create_particle(e.x, e.y + 4, -1, 0, 2, 0, 0);
                const particle2 = effects.create_particle(e.x + 7, e.y + 4, 1, 0, 2, 0, 0);
                _ = game.particles.append(particle1, &game.level_arena);
                _ = game.particles.append(particle2, &game.level_arena);
                game.entities.remove(e);
                sfx(5, game);
            }
        },
        .LockBlack => {
            if (level.unlock_black) {
                const particle1 = effects.create_particle(e.x + 4, e.y, 0, -2, 2, 0, 0);
                const particle2 = effects.create_particle(e.x + 4, e.y + 7, 0, 2, 2, 0, 0);
                _ = game.particles.append(particle1, &game.level_arena);
                _ = game.particles.append(particle2, &game.level_arena);
                mset(wtot(e.x) + game.map_x, wtot(e.y) + game.map_y, 27, game);
                game.entities.remove(e);
            }
        },
        .ConveyorLeft => {
            e.t += 0.5;
            e.spr = @as(Sprite, @intFromFloat(@mod((e.t / 4), 4) + 40));
        },
        .ConveyorRight => {
            e.t += 0.5;
            e.spr = @as(Sprite, @intFromFloat(@mod((e.t / 4), 4) + 44));
        },
        .BrokenGround => |*broken_ground| {
            if (blob.y + 8 == e.y and (blob.x - blob.pad_left < e.x + 8) and (blob.x + 8 + blob.pad_right > e.x)) {
                broken_ground.has_triggered = true;
            }
            if (broken_ground.has_triggered) {
                //NOTE: in the orignal code, this value is 1,
                //      but this seems to be too fast on the Playdate.
                //      Even though the frame rate is the same 🙃
                e.t += 0.8;
                e.spr = @as(Sprite, @intFromFloat(49 + (e.t * 0.125)));
                if (e.spr > 54) e.spr = 54;
                if (e.t > 40) {
                    broken_ground.has_triggered = false;
                    mset(wtot(e.x) + game.map_x, wtot(e.y) + game.map_y, 39, game);
                    game.entities.remove(e);
                }
            }
        },
        .BulletSpawn => {
            //NOTE: in the orignal code, this value is 1,
            //      But honestly, even in the original game, it's bit too fast and
            //      I can't get past level 14 if don't dial it down to 0.8.  Maybe I'm just a scrub though
            e.t += 0.8;
            if (e.t > 30) {
                switch (e.direction) {
                    .Left => {
                        const new_bullet = entity.create_bullet(e.x - 4, e.y, e.direction, game);
                        _ = game.entities.append(new_bullet, &game.level_arena);
                    },
                    .Right => {
                        const new_bullet = entity.create_bullet(e.x + 4, e.y, e.direction, game);
                        _ = game.entities.append(new_bullet, &game.level_arena);
                    },
                }
                e.t = 0;
                sfx(7, game);
            }
        },
        .Bullet => |*bullet| {
            if (touches_object(e, blob)) blob_die(game);
            e.x += bullet.spd;
            if (e.x < -10 or e.x > 138) {
                var it = game.entities.iterator();
                while (it.next()) |f| {
                    switch (f.class) {
                        .Bullet => |b2| {
                            if (b2.id == bullet.id) game.entities.remove(f);
                        },
                        else => {},
                    }
                }
            }
        },
        .Spike => {
            if (touches_object(e, blob)) blob_die(game);
        },
        .Medicine => |*medicine| {
            switch (medicine.state) {
                .Use => {
                    e.spd_y = 0;
                    if (e.y > 92) {
                        e.spd_y = -0.25;
                    } else {
                        medicine.use = true;
                    }
                    if (medicine.use) {
                        e.t += 1;
                        if (e.t > 60) {
                            medicine_particles(e, game);
                            sfx(20, game);
                            level.cutscene = 2;
                            game.t = 0;
                            game.entities.remove(e);
                        }
                    }
                    move_object(e);
                },
                .Normal => {
                    if (touches_object(e, blob)) {
                        level.got_medicine = true;
                        blob.state = .None;
                        blob.medicine = true;
                        medicine_particles(e, game);
                        sfx(20, game);
                        music(11, game);
                        game.entities.remove(e);
                    }
                },
            }
        },
        .BouncePad => |*bounce_pad| {
            if (touches_object(e, blob) and blob.state != .Dead) {
                blob_jump(-7, game);
                e.spr = 201;
                bounce_pad.has_triggered = true;
            }
            if (bounce_pad.has_triggered) {
                e.t += 1;
                if (e.t > 10) {
                    e.spr = 200;
                    //NOTE: actually misspelled in the P8 code
                    //      but, it doesn't functionally affect anything
                    //      since activating the bounce bad doesn't depend on
                    //      has_triggered.
                    //bounce_pad.has_triggerd = false;
                    //      Fixing it here:
                    bounce_pad.has_triggered = false;
                    e.t = 0;
                }
            }
        },
        .MsBlob => |*ms_blob| {
            if (touches_object(e, blob) and !level.game_won) {
                level.game_won = true;

                const play_time = game.clock;
                const play_min = @as(i32, @intFromFloat(play_time / 60));
                const play_sec = @as(i32, @intFromFloat(play_time - @floor(play_time / 60) * 60));
                const buffer = game.level_arena.push_slice(u8, 128);
                game.clock_s = toolbox.string8_fmt(buffer, "{} min {} sec", .{ play_min, play_sec }) catch
                    toolbox.string8_literal("Error calculating time");
                level.ms_blob = e;
                music(7, game);

                if (game.least_deaths < 0 or game.least_deaths > game.deaths) {
                    game.least_deaths = game.deaths;
                    game.new_record = true;
                }
                if (game.best_time < 0 or game.best_time > play_time) {
                    game.best_time = play_time;
                    game.new_record = true;
                }
                if (game.new_record) {
                    game_savedata_save(game);
                }
            }
            if (ms_blob.state != .Lying) {
                e.t += 0.5;
                e.spr = @as(Sprite, @intFromFloat(@mod(e.t / 2, 2) + 10));
            }
            if (ms_blob.state == .Moving) {
                e.x += 0.5;
                if (!level.move_sound) {
                    level.move_sound = true;
                    sfx(6, game);
                    const particle1 = effects.create_particle(e.x, e.y + 7, -0.5, 0, 2, 0, 7);
                    _ = game.particles.append(particle1, &game.level_arena);
                }
            }
        },
    }
}

fn medicine_particles(e: *const entity.Entity, game: *Game) void {
    const particles = .{
        effects.create_particle(e.x, e.y + 4, -2, 0, 3, 8, 9),
        effects.create_particle(e.x + 7, e.y + 4, 2, 0, 3, 8, 9),
        effects.create_particle(e.x, e.y + 4, -1, 0, 2, 8, 9),
        effects.create_particle(e.x + 7, e.y + 4, 1, 0, 2, 8, 9),
        effects.create_particle(e.x, e.y + 4, -3, 0, 1, 8, 9),
        effects.create_particle(e.x + 7, e.y + 4, 3, 0, 1, 8, 9),
    };
    inline for (particles) |p| {
        _ = game.particles.append(p, &game.level_arena);
    }
}
fn anim_enemy_black(e: *entity.Entity) void {
    e.t += 0.5;
    e.spr = @as(Sprite, @intFromFloat(@mod((e.t / 2), 2) + 60));
}
fn anim_enemy_white(e: *entity.Entity) void {
    e.t += 0.5;
    e.spr = @as(Sprite, @intFromFloat(@mod((e.t / 2), 2) + 55));
}

fn update_and_render_menu(game: *Game) void {
    var blob = &game.blob;
    ////update/////

    if (game.start_t == 0) {
        music(1, game);
    }
    game.start_t += 1;
    if (!game.launch and
        game.start_t > 60 and
        ((game.mode == .Start and (btnp(2) or btnp(5))) or
        (game.mode == .StartDownward and (btnp(3) or btnp(5)))))
    {
        music(-1, game);
        game.launch = true;
        sfx(8, game);
    }
    if (game.launch) {
        game.launch_t += 1;
        if (game.launch_t > 90) {
            if (game.mode == .StartDownward) {
                game.downward = true;
                blob.state = .Downward;
            }
            set_mode(.Play, game);
            game.start_t = -64;
            game.launch_t = 0;
            game.launch = false;

            //NOTE: this is not from the original game.
            //the original game included time on the menu in the total run time
            game.clock_start = time() - game.clock;

            menuitem(1, "retry level", menu_item_level_retry, game);
            menuitem(2, "main menu", menu_item_main_menu, game);
        }
    }

    if (game.level_number > 1 and game.start_t > 60 and btnp(4)) {
        game.level.game_reset += 1;
    }
    if (game.level_number > 1 and game.start_t > 60 and game.level.game_reset == 3) {
        game_savedata_reset(game);
        game.level_number = 1;
        game.downward = false;
        set_mode(.Start, game);
        level_load(game);

        music(-1, game);

        game.launch = true;
        sfx(8, game);
    }

    //////draw////
    map(game.map_x, game.map_y, game);
    if (game.blob.medicine and game.level_number == 15) {
        spr(14, blob.x - 3, blob.y - 2, game);
    }
    spr(blob.spr, blob.x, blob.y, game);
    const y1 = @as(WorldDim, @floatFromInt(if (game.start_t > 8) 8 else game.start_t));
    const y2 = @as(WorldDim, @floatFromInt(if (game.start_t > 16) 16 else game.start_t));

    if (game.mode == .StartDownward) rectfill(22, 0 + y1, 105, 16 + y1 + 1, 0);
    if (game.mode == .Start) sspr(0, 96, 64, 16, 32, 1 + y1, game);
    if (game.mode == .StartDownward) sspr(0, 112, 80, 16, 24, 1 + y1, game);
    {
        const s = if (game.mode != .StartDownward)
            toolbox.string8_literal("jump: a/↑")
        else
            toolbox.string8_literal("down: a/↓");
        const rune_length_f32 = @as(f32, @floatFromInt(s.rune_length));
        const textbox_x1 = 64 - rune_length_f32 * 2 - 1;
        const textbox_y1: f32 = 76 - 3;
        const textbox_x2 = 64 + rune_length_f32 * 2 + 1;
        const textbox_y2: f32 = 82;
        if (game.start_t > 60) {
            rectfill(textbox_x1, textbox_y1, textbox_x2, textbox_y2, 7);
            rect(textbox_x1, textbox_y1, textbox_x2, textbox_y2, 0);

            if (@mod(game.launch_t, 3) == 0) {
                print(s, textbox_x1 + 3, textbox_y1 + 2, 0);
            }
        }
    }
    {
        const s = toolbox.string8_literal("new game? push bbb");
        const rune_length_f32 = @as(f32, @floatFromInt(s.rune_length));
        const textbox_x1 = 64 - rune_length_f32 * 2 - 1;
        const textbox_y1: f32 = 97;
        const textbox_x2 = 64 + rune_length_f32 * 2 - 1;
        const textbox_y2: f32 = 106;
        if (game.level_number > 1 and game.start_t > 60 and !game.launch) {
            rectfill(textbox_x1, textbox_y1, textbox_x2, textbox_y2, 7);
            rect(textbox_x1, textbox_y1, textbox_x2, textbox_y2, 0);
            print(s, textbox_x1 + 3, textbox_y1 + 2, 0);
        }
    }
    {
        const s = toolbox.string8_literal("ported by daniel bokser");
        const rune_length_f32 = @as(f32, @floatFromInt(s.rune_length));
        const textbox_x1 = 64 - rune_length_f32 * 2 + 1;
        const textbox_y1: f32 = 135 - y2;
        const textbox_x2 = 64 + rune_length_f32 * 2;
        const textbox_y2: f32 = textbox_y1 + 8;

        rectfill(textbox_x1, textbox_y1, textbox_x2, textbox_y2, 7);
        rect(textbox_x1, textbox_y1, textbox_x2, textbox_y2, 0);
        print(s, textbox_x1 + 2, textbox_y1 + 2, 0);
    }
    {
        const s = toolbox.string8_literal("original game by matthias falk");
        const rune_length_f32 = @as(f32, @floatFromInt(s.rune_length));
        const textbox_x1 = 64 - rune_length_f32 * 2 + 1;
        const textbox_y1: f32 = 127 - y2;
        const textbox_x2 = 64 + rune_length_f32 * 2;
        const textbox_y2: f32 = textbox_y1 + 8;

        rectfill(textbox_x1, textbox_y1, textbox_x2, textbox_y2, 7);
        rect(textbox_x1, textbox_y1, textbox_x2, textbox_y2, 0);
        print(s, textbox_x1 + 2, textbox_y1 + 1, 0);
    }
    if (!game.hide_hud and (game.level_number > 1 or game.least_deaths >= 0)) {
        draw_hud(game);
    }
}

fn game_savedata_load(game: *Game) void {
    dload(game);
    game.level_number = dget(0, @TypeOf(game.level_number), game);
    if (game.level_number > 15) {
        set_mode(.StartDownward, game);
    }
    game.clock = dget(1, @TypeOf(game.clock), game);

    if (game.level_number == 0) {
        game_savedata_reset(game);
    }

    game.deaths = dget(2, @TypeOf(game.deaths), game);
    game.best_time = dget(3, @TypeOf(game.best_time), game);
    game.least_deaths = dget(4, @TypeOf(game.least_deaths), game);
    game.hide_hud = if (dget(5, u32, game) != 0) true else false;
}
fn game_savedata_reset(game: *Game) void {
    game.level_number = 1;
    dset(0, game.level_number, game);
    game.clock = 0;
    dset(1, game.clock, game);
    game.deaths = 0;
    dset(2, game.deaths, game);

    dsave(game);
}
fn game_savedata_save(game: *Game) void {
    dset(0, game.level_number, game);
    dset(1, game.clock, game);
    dset(2, game.deaths, game);
    dset(3, game.best_time, game);
    dset(4, game.least_deaths, game);
    dset(5, @as(u32, if (game.hide_hud) 1 else 0), game);
    dsave(game);
}
fn hit_detection(obj: anytype, x1: WorldDim, y1: WorldDim, x2: WorldDim, y2: WorldDim, comptime flag_id: u8, game: *const Game) bool {
    if (obj.y < 0) return false;
    const flag1 = fget(
        mget(
            wtot(obj.x + x1 + ttow(game.map_x)),
            wtot(obj.y + y1 + ttow(game.map_y)),
            game,
        ),
        flag_id,
    );
    const flag2 = fget(
        mget(
            wtot(obj.x + x2 + ttow(game.map_x)),
            wtot(obj.y + y2 + ttow(game.map_y)),
            game,
        ),
        flag_id,
    );
    return flag1 or flag2;
}

fn is_on_(obj: anytype, comptime flag_id: u8, game: *const Game) bool {
    const x1 = -obj.pad_left;
    const x2 = 7 + obj.pad_right;
    const y1 = 8;
    const y2 = 8;
    return hit_detection(obj, x1, y1, x2, y2, flag_id, game);
}

fn is_on_ground(obj: anytype, game: *const Game) bool {
    return is_on_(obj, 0, game);
}

fn is_on_con_left(obj: anytype, game: *const Game) bool {
    return is_on_(obj, 1, game);
}

fn is_on_con_right(obj: anytype, game: *const Game) bool {
    return is_on_(obj, 2, game);
}

fn is_on_semi_ground(obj: anytype, game: *const Game) bool {
    return is_on_(obj, 4, game) and
        mget(wtot(obj.x + ttow(game.map_x)), wtot(obj.y + 16 + ttow(game.map_y)), game) != 0;
}

fn ceiling_(obj: anytype, y: WorldDim, game: *const Game) bool {
    const x1 = -obj.pad_left;
    const x2 = 7 + obj.pad_right;
    const y1 = y;
    const y2 = y;
    const flag_id = 3;
    return hit_detection(obj, x1, y1, x2, y2, flag_id, game);
}

fn hits_ceiling(obj: anytype, game: *const Game) bool {
    return ceiling_(obj, 0, game);
}

fn will_hit_ceiling(obj: anytype, game: *const Game) bool {
    return ceiling_(obj, -8, game);
}
fn ledge_(obj: anytype, x: WorldDim, game: *const Game) bool {
    const x1 = x;
    const x2 = x;
    const y1 = 8;
    const y2 = 8;
    const flag_id = 0;
    return !hit_detection(obj, x1, y1, x2, y2, flag_id, game);
}

fn ledge_right(obj: anytype, game: *const Game) bool {
    return ledge_(obj, 8, game);
}

fn ledge_left(obj: anytype, game: *const Game) bool {
    return ledge_(obj, -1, game);
}

fn ledge_both(obj: anytype, game: *const Game) bool {
    return ledge_(obj, -1, game) and ledge_(obj, 8, game);
}

fn wall_(obj: anytype, x: WorldDim, game: *const Game) bool {
    const x1 = x;
    const x2 = x;
    const y1 = 0;
    const y2 = 7;
    const flag_id = 3;
    return hit_detection(obj, x1, y1, x2, y2, flag_id, game);
}
fn wall_left(obj: anytype, game: *const Game) bool {
    return wall_(obj, -1, game);
}

fn wall_right(obj: anytype, game: *const Game) bool {
    return wall_(obj, 8, game);
}
fn touches_object(a: anytype, b: anytype) bool {
    return (a.x - a.pad_left <= b.x + 8 + b.pad_right) and
        (a.x + 8 + a.pad_right >= b.x - b.pad_left) and
        (a.y - a.pad_top <= b.y + 8 + b.pad_bottom) and
        (a.y + 8 + a.pad_bottom >= b.y - b.pad_top);
}
fn level_load(game: *Game) void {
    game.level_arena.reset();
    game.entities.clear();
    game.particles.clear();

    var level_descriptor = level_data.levels[@as(usize, @intCast(game.level_number - 1))];
    game.map_x = level_descriptor.map_x;
    game.map_y = level_descriptor.map_y;
    game.start_x = level_descriptor.start_x;
    game.start_y = level_descriptor.start_y;
    game.level = new_level();
    game.t = 0;
    game.blob = new_blob(game.start_x, game.start_y);
    game.downward = false;
    if (level_descriptor.downward) {
        game.downward = true;
        game.blob.state = .Downward;
        game.blob.medicine = true;
    }
    spawn_entities_map(game);
    if (level_descriptor.entities) |*entities| {
        spawn_entities_code(entities.items(), game);
    }
}

fn new_level() Level {
    return .{
        .won = false,
        .lost = false,
        .give_up = false,
        .next = false,
        .next2 = false,
        .unlock_white = false,
        .unlock_black = false,
        .no_ledge = false,
        .move_sound = false,
        .move_t = 0,
        .t = 0,
        .got_medicine = false,
        .game_won = false,
        .cutscene = 1,
        .the_end = false,
        .stats = false,
        .ms_blob = null,
        .wait_t = 0,
        .waited = false,
        .show_hint = false,
        .show_hint_t = 0,
        .game_reset = 0,
    };
}
fn spawn_entities_map(game: *Game) void {
    var map_row: TileDim = 0;
    while (map_row < 16) : (map_row += 1) {
        var map_column: TileDim = 0;
        while (map_column < 16) : (map_column += 1) {
            const mapx = map_column + game.map_x;
            const mapy = map_row + game.map_y;
            const worldx = ttow(map_column);
            const worldy = ttow(map_row);
            const map_sprite = mget(mapx, mapy, game);
            switch (map_sprite) {
                16...19 => {
                    //goal
                    var off_x: WorldDim = 0;
                    var new_tile: Sprite = 16;
                    if (map_sprite == 18 or map_sprite == 19) {
                        off_x = 4;
                        new_tile = 18;
                    }
                    if (!game.downward) {
                        const goal = entity.create_goal(worldx + off_x, worldy);
                        _ = game.entities.append(goal, &game.level_arena);
                    }
                    mset(mapx, mapy, new_tile, game);
                },
                29 => {
                    // bullet spawner (right)
                    const bullet_spawner = entity.create_bulspwn_right(worldx, worldy);
                    _ = game.entities.append(bullet_spawner, &game.level_arena);
                },
                31 => {
                    // bullet spawner (left)
                    const bullet_spawner = entity.create_bulspwn_left(worldx, worldy);
                    _ = game.entities.append(bullet_spawner, &game.level_arena);
                },
                44 => {
                    // conveyor (right)
                    const conveyor = entity.create_con_right(worldx, worldy);
                    _ = game.entities.append(conveyor, &game.level_arena);
                },
                40 => {
                    // conveyor (left)
                    const conveyor = entity.create_con_left(worldx, worldy);
                    _ = game.entities.append(conveyor, &game.level_arena);
                },
                54...58 => {
                    // enemy (white)
                    var enemy_dir: entity.Direction = .Right;
                    var set_map: Sprite = 54;
                    if (map_sprite == 57 or map_sprite == 58) {
                        enemy_dir = .Left;
                        set_map = 57;
                    }
                    if (!game.downward) {
                        const enemy = entity.create_enemy_white(worldx, worldy, enemy_dir);
                        _ = game.entities.append(enemy, &game.level_arena);
                    }
                    mset(mapx, mapy, set_map, game);
                },
                59...63 => {
                    // enemy (black)
                    var enemy_dir: entity.Direction = .Right;
                    var set_map: Sprite = 59;
                    if (map_sprite == 62 or map_sprite == 63) {
                        enemy_dir = .Left;
                        set_map = 62;
                    }
                    if (!game.downward) {
                        const enemy = entity.create_enemy_black(worldx, worldy, enemy_dir);
                        _ = game.entities.append(enemy, &game.level_arena);
                    }
                    mset(mapx, mapy, set_map, game);
                },
                48, 49, 39 => {
                    // broken ground
                    var new_tile: Sprite = 39;
                    if (!game.downward) {
                        const broken = entity.create_broken_ground(worldx, worldy);
                        _ = game.entities.append(broken, &game.level_arena);
                        new_tile = 48;
                    }
                    mset(mapx, mapy, new_tile, game);
                },
                20, 21 => {
                    // white key
                    if (!game.downward) {
                        const key = entity.create_key_white(worldx, worldy);
                        _ = game.entities.append(key, &game.level_arena);
                    }
                    mset(mapx, mapy, 20, game);
                },
                36...38 => {
                    // white lock
                    var new_tile: Sprite = 38;
                    if (!game.downward) {
                        const lock = entity.create_lock_white(worldx, worldy);
                        _ = game.entities.append(lock, &game.level_arena);
                        new_tile = 36;
                    }
                    mset(mapx, mapy, new_tile, game);
                },
                22, 23 => {
                    // black key
                    if (!game.downward) {
                        const key = entity.create_key_black(worldx, worldy);
                        _ = game.entities.append(key, &game.level_arena);
                    }
                    mset(mapx, mapy, 22, game);
                },
                25...27 => {
                    // white lock
                    var new_tile: Sprite = 27;
                    if (!game.downward) {
                        const lock = entity.create_lock_black(worldx, worldy);
                        _ = game.entities.append(lock, &game.level_arena);
                        new_tile = 25;
                    }
                    mset(mapx, mapy, new_tile, game);
                },
                7 => {
                    // spikes
                    const spike = entity.create_spike(worldx, worldy);
                    _ = game.entities.append(spike, &game.level_arena);
                },
                13, 14 => {
                    // medicine
                    const medicine = entity.create_medicine(worldx + 4, worldy);
                    _ = game.entities.append(medicine, &game.level_arena);
                    mset(mapx, mapy, 13, game);
                },
                200 => {
                    // bounce pad
                    const bounce = entity.create_bounce_pad(worldx, worldy);
                    _ = game.entities.append(bounce, &game.level_arena);
                },
                else => {},
            }
        }
    }
}
fn spawn_entities_code(entities: []const entity.Entity, game: *Game) void {
    for (entities) |e| {
        switch (e.class) {
            .Enemy => |enemy_data| {
                switch (enemy_data.class) {
                    .Black => {
                        const enemy = entity.create_enemy_black(e.x, e.y, e.direction);
                        _ = game.entities.append(enemy, &game.level_arena);
                    },
                    .White => {
                        const enemy = entity.create_enemy_white(e.x, e.y, e.direction);
                        _ = game.entities.append(enemy, &game.level_arena);
                    },
                }
            },
            .BrokenGround => {
                const broken = entity.create_broken_ground(e.x, e.y);
                _ = game.entities.append(broken, &game.level_arena);
                mset(
                    wtot(e.x) + game.map_x,
                    wtot(e.y) + game.map_y,
                    48,
                    game,
                );
            },
            .MsBlob => {
                const ms_blob = entity.create_ms_blob(e.x, e.y);
                _ = game.entities.append(ms_blob, &game.level_arena);
            },
            else => {},
        }
    }
}
pub fn level_update(game: *Game) void {
    var level = &game.level;
    if (level.no_ledge) {
        level.t += 1;
        if (level.t > 3) {
            level.no_ledge = false;
            level.t = 0;
        }
    }
    if (level.move_sound) {
        level.move_t += 1;
        if (level.move_t > 15) {
            level.move_sound = false;
            level.move_t = 0;
        }
    }
    if (game.level_number == 24 and level.waited == false) {
        level.wait_t += 1;
        if (level.wait_t > 120) {
            level.waited = true;
            const enemy = entity.create_enemy_white(120, 32, .Left);
            _ = game.entities.append(enemy, &game.level_arena);
        }
    }
}
fn level_retry(game: *Game) void {
    blob_die(game);
    game.level.give_up = true;
}

fn level_next(game: *Game) void {
    game.level_number = mid(@as(i32, 1), game.level_number + 1, MAX_LEVELS);
    game_savedata_save(game);
    level_load(game);
    game.clock_start = time() - game.clock;
}

fn level_prior(game: *Game) void {
    game.level_number = mid(@as(i32, 1), game.level_number - 1, MAX_LEVELS);
    level_load(game);
}
fn blob_die(game: *Game) void {
    if (!game.level.lost) {
        game.level.lost = true;
        sfx(4, game);
        game.blob.state = .Dead;
        game.blob.spd_y = -2.5;
    }
}
fn blob_jump(height: WorldDim, game: *Game) void {
    var blob = &game.blob;
    sfx(0, game);
    if (!will_hit_ceiling(blob, game)) {
        blob.spd_y = height;
    } else {
        blob.spd_y = -1;
    }
}

fn menu_item_hide_hud(userdata: ?*anyopaque) callconv(.C) void {
    var game = @as(*Game, @ptrCast(@alignCast(userdata.?)));
    game.hide_hud = pdapi.get_menu_item_value_bool(game.hide_hud_menu_item);
    dset(5, @as(u32, if (game.hide_hud) 1 else 0), game);
    dsave(game);
}

fn menu_item_level_retry(userdata: ?*anyopaque) callconv(.C) void {
    const game = @as(*Game, @ptrCast(@alignCast(userdata.?)));
    level_retry(game);
}

fn menu_item_main_menu(userdata: ?*anyopaque) callconv(.C) void {
    const game = @as(*Game, @ptrCast(@alignCast(userdata.?)));
    init(game.initial_state);
}

fn message(text: toolbox.String8, comptime clr: P8Color) void {
    //NOTE: unused, from original code
    _ = clr;
    rectfill(0, 56, 127, 72, 0);
    print(text, 64 - @as(WorldDim, @floatFromInt(text.rune_length)) * 2 + 3, 62, 7);
}

//world to pixel dimension
inline fn wtop(n: WorldDim) pdapi.Pixel {
    const MULTIPLIER = 1.875; //(SCREEN_SIZE_PX / 128);
    return @as(pdapi.Pixel, @intFromFloat(n * MULTIPLIER));
}
//PICO-8 to Playdate Color
inline fn p8topdcol(p8col: P8Color) pdapi.LCDColor {
    return pdapi.solid_color_to_color(if (p8col == 7) .ColorWhite else .ColorBlack);
}
//world to tile dimension
inline fn wtot(n: WorldDim) TileDim {
    return @as(TileDim, @intFromFloat(n / 8));
}

//tile to world dimension
inline fn ttow(n: TileDim) WorldDim {
    return @as(WorldDim, @floatFromInt(n * 8));
}

//PICO-8 API
pub inline fn btnp(comptime button: i32) bool {
    const pd_button = switch (button) {
        0 => pdapi.BUTTON_LEFT,
        1 => pdapi.BUTTON_RIGHT,
        2 => pdapi.BUTTON_UP,
        3 => pdapi.BUTTON_DOWN,
        4 => pdapi.BUTTON_B,
        5 => pdapi.BUTTON_A,
        else => @compileError("Invalid button number"),
    };
    return pdapi.is_button_pressed(pd_button);
}
pub inline fn btn(comptime button: i32) bool {
    const pd_button = switch (button) {
        0 => pdapi.BUTTON_LEFT,
        1 => pdapi.BUTTON_RIGHT,
        2 => pdapi.BUTTON_UP,
        3 => pdapi.BUTTON_DOWN,
        4 => pdapi.BUTTON_B,
        5 => pdapi.BUTTON_A,
        else => @compileError("Invalid button number"),
    };
    return pdapi.is_button_down(pd_button);
}

pub inline fn fget(sprite: Sprite, comptime flag: u8) bool {
    return level_data.map_flags[sprite] & (1 << flag) != 0;
}

pub fn map(tile_x: TileDim, tile_y: TileDim, game: *Game) void {
    var y = tile_y;
    while (y < tile_y + MAP_SCREEN_SIZE) : (y += 1) {
        var x = tile_x;
        while (x < tile_x + MAP_SCREEN_SIZE) : (x += 1) {
            const sprite = mget(x, y, game);
            const bitmap = pdapi.get_table_bitmap(game.sprites, sprite).?;
            pdapi.draw_bitmap(bitmap, @as(i32, @intCast((x - tile_x) * TILE_SIZE)), @as(i32, @intCast((y - tile_y) * TILE_SIZE)), .BitmapUnflipped);
        }
    }
}

pub fn mid(a: anytype, b: @TypeOf(a), c: @TypeOf(a)) @TypeOf(a) {
    if (a >= b and a <= c) {
        return a;
    }
    if (b >= a and b <= c) {
        return b;
    }

    if (c >= a and c <= b) {
        return c;
    }

    return a;
}

pub inline fn mget(x: TileDim, y: TileDim, game: *const Game) Sprite {
    return game.map_sprites[@as(usize, @intCast(y * level_data.MAP_STRIDE + x))];
}
pub inline fn mset(x: TileDim, y: TileDim, sprite: Sprite, game: *Game) void {
    game.map_sprites[@as(usize, @intCast(y * level_data.MAP_STRIDE + x))] = sprite;
}

pub inline fn spr(sprite: Sprite, x: WorldDim, y: WorldDim, game: *Game) void {
    const bitmap = pdapi.get_table_bitmap(game.sprites, sprite).?;
    pdapi.draw_bitmap(bitmap, wtop(x), wtop(y), .BitmapUnflipped);
}
pub inline fn sprflip(
    sprite: Sprite,
    x: WorldDim,
    y: WorldDim,
    is_flipped: bool,
    game: *Game,
) void {
    const bitmap = pdapi.get_table_bitmap(game.sprites, sprite).?;
    pdapi.draw_bitmap(bitmap, wtop(x), wtop(y), if (is_flipped) .BitmapFlippedX else .BitmapUnflipped);
}

pub fn sspr(sx: WorldDim, sy: WorldDim, w: WorldDim, h: WorldDim, dx: WorldDim, dy: WorldDim, game: *Game) void {
    const _sx = wtop(sx);
    const _sy = wtop(sy);
    const _w = wtop(w);
    const _h = wtop(h);
    const _dx = wtop(dx);
    const _dy = wtop(dy);

    const clip_x = @max(0, _dx);
    const clip_y = @max(0, _dy);

    pdapi.set_clip_rect(clip_x, clip_y, _w - (clip_x - _dx), _h - (clip_y - _dy));
    pdapi.draw_bitmap(game.sprites_bitmap, _dx - _sx, _dy - _sy, .BitmapUnflipped);
    pdapi.clear_clip_rect();
}

pub fn menuitem(index: usize, title: [:0]const u8, callback: *const fn (game: ?*anyopaque) callconv(.C) void, game: *Game) void {
    _ = index; //unused
    _ = pdapi.add_menu_item(title, callback, game);
}

pub fn dget(comptime index: usize, comptime ReturnType: type, game: *Game) ReturnType {
    if (@sizeOf(ReturnType) != 4) {
        @compileError("dget can only return 4 byte types");
    }
    var ret: [4]u8 = undefined;
    const save_data = game.save_data[index * 4 .. index * 4 + 4];
    for (&ret, 0..) |*dest, i| dest.* = save_data[i];
    return @as(ReturnType, @bitCast(ret));
}
pub fn dset(comptime index: usize, data: anytype, game: *Game) void {
    if (@sizeOf(@TypeOf(data)) != 4) {
        @compileError("dset can only store 4 byte types");
    }
    const bytes: [4]u8 = @bitCast(data);
    for (bytes, 0..) |byte, i| {
        game.save_data[index * 4 + i] = byte;
    }
}
//made up API to save data to file
pub fn dsave(game: *Game) void {
    const open_result = pdapi.open_file(SAVE_DATA_FILENAME, pdapi.FILE_WRITE);
    var file: *pdapi.SDFile = undefined;
    switch (open_result) {
        .Ok => |f| {
            file = f;
        },
        .Error => |msg| {
            toolbox.println(
                "Failed to open " ++ SAVE_DATA_FILENAME ++ " for writing.  Reason: {s}",
                .{msg},
            );
            return;
        },
    }
    defer pdapi.close_file(file);

    const write_result = pdapi.write_file(file, &game.save_data);
    switch (write_result) {
        .Ok => {},
        .Error => |msg| {
            toolbox.println(
                "Failed to write to " ++ SAVE_DATA_FILENAME ++ ".  Reason: {s}",
                .{msg},
            );
        },
    }
}
pub fn dload(game: *Game) void {
    const open_result = pdapi.open_file(SAVE_DATA_FILENAME, pdapi.FILE_READ_DATA);
    var file: *pdapi.SDFile = undefined;
    switch (open_result) {
        .Ok => |f| {
            file = f;
        },
        .Error => |msg| {
            toolbox.println(
                "Failed to open " ++ SAVE_DATA_FILENAME ++ " for reading.  Reason: {s}",
                .{msg},
            );
            return;
        },
    }
    defer pdapi.close_file(file);

    const write_result = pdapi.read_file(file, &game.save_data);
    switch (write_result) {
        .Ok => {},
        .Error => |msg| {
            toolbox.println(
                "Failed to read from " ++ SAVE_DATA_FILENAME ++ ".  Reason: {s}",
                .{msg},
            );
        },
    }
}
pub inline fn rnd(comptime max: comptime_float, game: *Game) f32 {
    return toolbox.randomf_range(0, max, &game.random_state);
}
pub fn rectfill(x0: WorldDim, y0: WorldDim, x1: WorldDim, y1: WorldDim, comptime color: P8Color) void {
    const _x0 = wtop(x0);
    const _y0 = wtop(y0);
    const _x1 = wtop(x1);
    const _y1 = wtop(y1);
    const w = _x1 - _x0 + 1;
    const h = _y1 - _y0 + 1;
    pdapi.fill_rect(_x0, _y0, w, h, p8topdcol(color));
}
pub fn rect(x0: WorldDim, y0: WorldDim, x1: WorldDim, y1: WorldDim, comptime color: P8Color) void {
    const _x0 = wtop(x0);
    const _y0 = wtop(y0);
    const _x1 = wtop(x1);
    const _y1 = wtop(y1);
    const w = _x1 - _x0 + 1;
    const h = _y1 - _y0 + 1;
    // pdapi.draw_rect(_x0, _y0, w, h, p8topdcol(color));
    // pdapi.draw_rect(_x0 + 1, _y0 + 1, w - 1, h - 1, p8topdcol(color));
    pdapi.draw_rect(_x0, _y0, w - 1, h - 1, p8topdcol(color));
    //drawRoundRect(_x0, _y0, w - 1, h - 1, 5, p8topdcol(color));
    // _ = color;
    // fillRoundRect(_x0, _y0, w - 1, h - 1, 5, p8topdcol(0));

    // const offset = 1;
    // fillRoundRect(_x0 + offset, _y0 + offset, w - 1 - 2, h - 1 - 2, 5, p8topdcol(7));
}
pub inline fn circ(x: WorldDim, y: WorldDim, r: WorldDim, color: P8Color) void {
    const pd_color = p8topdcol(color);
    const _x = wtop(x);
    const _y = wtop(y);
    const _r = wtop(r) + 1;

    pdapi.draw_ellipse(_x, _y, _r, _r, 1, 0, 0, pd_color);
}
pub inline fn circfill(x: WorldDim, y: WorldDim, r: WorldDim, color: P8Color) void {
    const pd_color = p8topdcol(color);
    const _x = wtop(x);
    const _y = wtop(y);
    const _r = wtop(r) + 1;

    pdapi.fill_ellipse(_x, _y, _r, _r, 0, 0, pd_color);
}
pub fn print(s: toolbox.String8, x: WorldDim, y: WorldDim, color: P8Color) void {
    switch (color) {
        7 => pdapi.set_draw_mode(.DrawModeFillWhite),
        else => pdapi.set_draw_mode(.DrawModeFillBlack),
    }

    _ = pdapi.draw_text(s.bytes, wtop(x), wtop(y));

    pdapi.set_draw_mode(.DrawModeCopy);
}

pub inline fn time() toolbox.Seconds {
    return toolbox.seconds();
}

pub fn music(m: P8Music, game: *Game) void {
    if (game.playing_music != null) {
        pdapi.stop_sample_player(game.music_player);
        game.playing_music = null;
    }
    if (m < 0) {
        return;
    }
    const music_index = @as(usize, @intCast(m));
    game.playing_music = &game.music[music_index];
    pdapi.set_sample_for_sample_player(game.music_player, game.music[music_index].sample);
    pdapi.play_sample_player(game.music_player, 0, 1);
}
pub fn sfx(s: P8Sfx, game: *Game) void {
    pdapi.play_sample_player(game.sfx[s], 1, 1);
}

fn drawRoundRect(
    x: pdapi.Pixel,
    y: pdapi.Pixel,
    width: pdapi.Pixel,
    height: pdapi.Pixel,
    radius: pdapi.Pixel,
    color: pdapi.LCDColor,
) void {
    const r2 = radius * 2;

    pdapi.draw_rect(x, y + radius, radius, height - r2, color);
    pdapi.draw_rect(x + radius, y, width - r2, height, color);
    pdapi.draw_rect(x + width - radius, y + radius, radius, height - r2, color);

    pdapi.draw_ellipse(x, y, r2, r2, 1, -90, 0, color);
    pdapi.draw_ellipse(x + width - r2, y, r2, r2, 1, 0, 90, color);
    pdapi.draw_ellipse(x + width - r2, y + height - r2, r2, r2, 1, 90, 180, color);
    pdapi.draw_ellipse(x, y + height - r2, r2, r2, 1, -180, -90, color);
}

fn fillRoundRect(
    x: pdapi.Pixel,
    y: pdapi.Pixel,
    width: pdapi.Pixel,
    height: pdapi.Pixel,
    radius: pdapi.Pixel,
    color: pdapi.LCDColor,
) void {
    const r2 = radius * 2;

    pdapi.fill_rect(x, y + radius, radius, height - r2, color);
    pdapi.fill_rect(x + radius, y, width - r2, height, color);
    pdapi.fill_rect(x + width - radius, y + radius, radius, height - r2, color);

    pdapi.fill_ellipse(x, y, r2, r2, -90, 0, color);
    pdapi.fill_ellipse(x + width - r2, y, r2, r2, 0, 90, color);
    pdapi.fill_ellipse(x + width - r2, y + height - r2, r2, r2, 90, 180, color);
    pdapi.fill_ellipse(x, y + height - r2, r2, r2, -180, -90, color);
}
