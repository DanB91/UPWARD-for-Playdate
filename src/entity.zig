const game = @import("game.zig");
const toolbox = @import("toolbox");

pub const Entity = struct {
    x: game.WorldDim,
    y: game.WorldDim,
    spd_x: game.WorldDim = 0,
    spd_y: game.WorldDim = 0,
    spr: game.Sprite = 0,
    t: f32 = 0,

    direction: Direction = .Right,
    pad_left: game.WorldDim = 0,
    pad_right: game.WorldDim = 0,
    pad_top: game.WorldDim = 0,
    pad_bottom: game.WorldDim = 0,

    class: Class,
};

pub const ClassType = enum { Goal, BulletSpawn, ConveyorLeft, ConveyorRight, Enemy, Spike, BouncePad, BrokenGround, KeyWhite, LockWhite, KeyBlack, LockBlack, Medicine, MsBlob, Bullet };

pub const Class = union(ClassType) {
    Goal: void,
    BulletSpawn: void,
    ConveyorLeft: void,
    ConveyorRight: void,
    Enemy: Enemy,
    Spike: void,
    BouncePad: BouncePad,
    BrokenGround: BrokenGround,
    KeyWhite: void,
    LockWhite: void,
    KeyBlack: void,
    LockBlack: void,
    Medicine: Medicine,
    MsBlob: MsBlob,
    Bullet: Bullet,
};
pub const Direction = enum {
    Right, //corresponds to 1 in the PICO-8 code
    Left, //corresponds to -1 in the PICO-8 code
};
pub const Enemy = struct {
    class: EnemyClass,
    spd_x_old: game.WorldDim = 0,
    grav_down: game.WorldDim = 0,
    grav_down_max: game.WorldDim = 0,
    is_killed: bool = false,
    has_landed: bool = false,

    pub const EnemyClass = enum {
        Black,
        White,
    };
};
pub const BouncePad = struct {
    has_triggered: bool = false,
};

pub const BrokenGround = struct {
    has_triggered: bool = false,
};

pub const Medicine = struct {
    state: State,
    use: bool,

    pub const State = enum {
        Normal,
        Use,
    };
};

pub const MsBlob = struct {
    state: State = .Lying,

    //TODO: this is referenced, but looks like its not used?
    //spd_x: WorldDim,
    pub const State = enum {
        Lying,
        Moving,
        Idle,
    };
};

pub inline fn create_goal(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
) Entity {
    return .{
        .class = .Goal,
        .x = spawn_x,
        .y = spawn_y,
        .spd_x = 0,
        .spd_y = 0,
        .spr = 17,
        .t = 0,
        .pad_left = 0,
        .pad_right = 0,
        .pad_top = 0,
        .pad_bottom = 0,
    };
}

pub inline fn create_bulspwn_right(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
) Entity {
    return .{
        //NOTE: direction is inverted in the original code for some reason.
        //      so following that here
        .direction = .Left,
        .class = .BulletSpawn,
        .x = spawn_x,
        .y = spawn_y,
        .spd_x = 0,
        .spd_y = 0,
        .spr = 29,
        .t = 0,
        .pad_left = 0,
        .pad_right = 0,
        .pad_top = 0,
        .pad_bottom = 0,
    };
}

pub inline fn create_bulspwn_left(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
) Entity {
    return .{
        //NOTE: direction is inverted in the original code for some reason.
        //      so following that here
        .direction = .Right,
        .class = .BulletSpawn,
        .x = spawn_x,
        .y = spawn_y,
        .spd_x = 0,
        .spd_y = 0,
        .spr = 31,
        .t = 0,
        .pad_left = 0,
        .pad_right = 0,
        .pad_top = 0,
        .pad_bottom = 0,
    };
}
//coveyor (left)
pub inline fn create_con_left(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
) Entity {
    return .{
        .class = .ConveyorLeft,
        .x = spawn_x,
        .y = spawn_y,
        .spd_x = 0,
        .spd_y = 0,
        .spr = 40,
        .t = 0,
        .pad_left = 0,
        .pad_right = 0,
        .pad_top = 0,
        .pad_bottom = 0,
    };
}

//coveyor (right)
pub inline fn create_con_right(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
) Entity {
    return .{
        .class = .ConveyorRight,
        .x = spawn_x,
        .y = spawn_y,
        .spd_x = 0,
        .spd_y = 0,
        .spr = 44,
        .t = 0,
        .pad_left = 0,
        .pad_right = 0,
        .pad_top = 0,
        .pad_bottom = 0,
    };
}

//spike
pub inline fn create_spike(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
) Entity {
    return .{
        .class = .Spike,
        .x = spawn_x,
        .y = spawn_y,
        .spd_x = 0,
        .spd_y = 0,
        .spr = 7,
        .t = 0,
        .pad_left = -1,
        .pad_right = -1,
        .pad_top = -4,
        .pad_bottom = 0,
    };
}

//bounce pad
pub inline fn create_bounce_pad(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
) Entity {
    return .{
        .class = .{ .BouncePad = .{
            .has_triggered = false,
        } },
        .x = spawn_x,
        .y = spawn_y,
        .spd_x = 0,
        .spd_y = 0,
        .spr = 200,
        .t = 0,
        .pad_left = -1,
        .pad_right = -1,
        .pad_top = -4,
        .pad_bottom = 0,
    };
}
//broken ground
pub inline fn create_broken_ground(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
) Entity {
    return .{
        .class = .{ .BrokenGround = .{
            .has_triggered = false,
        } },
        .x = spawn_x,
        .y = spawn_y,
        .spd_x = 0,
        .spd_y = 0,
        .spr = 49,
        .t = 0,
        .pad_left = 0,
        .pad_right = 0,
        .pad_top = 0,
        .pad_bottom = 0,
    };
}
//key (white)
pub inline fn create_key_white(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
) Entity {
    return .{
        .class = .KeyWhite,
        .x = spawn_x,
        .y = spawn_y,

        .spd_x = 0,
        .spd_y = 0,
        .spr = 21,
        .t = 0,
        .pad_left = 0,
        .pad_right = 0,
        .pad_top = 0,
        .pad_bottom = 0,
    };
}
//lock (white)
pub inline fn create_lock_white(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
) Entity {
    return .{
        .class = .LockWhite,
        .x = spawn_x,
        .y = spawn_y,
        .spd_x = 0,
        .spd_y = 0,
        .spr = 37,
        .t = 0,
        .pad_left = 0,
        .pad_right = 0,
        .pad_top = 0,
        .pad_bottom = 0,
    };
}
//key (black)
pub inline fn create_key_black(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
) Entity {
    return .{
        .class = .KeyBlack,
        .x = spawn_x,
        .y = spawn_y,
        .spd_x = 0,
        .spd_y = 0,
        .spr = 23,
        .t = 0,
        .pad_left = 0,
        .pad_right = 0,
        .pad_top = 0,
        .pad_bottom = 0,
    };
}
//lock (black)
pub inline fn create_lock_black(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
) Entity {
    return .{
        .class = .LockBlack,
        .x = spawn_x,
        .y = spawn_y,
        .spd_x = 0,
        .spd_y = 0,
        .spr = 26,
        .t = 0,
        .pad_left = 0,
        .pad_right = 0,
        .pad_top = 0,
        .pad_bottom = 0,
    };
}
//medicine
pub inline fn create_medicine(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
) Entity {
    return .{
        .class = .{ .Medicine = .{
            .state = .Normal,
            .use = false,
        } },
        .x = spawn_x,
        .y = spawn_y,
        .spd_x = 0,
        .spd_y = 0,
        .spr = 14,
        .t = 0,
        .pad_left = 0,
        .pad_right = 0,
        .pad_top = 0,
        .pad_bottom = 0,
    };
}
//ms blob
pub inline fn create_ms_blob(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
) Entity {
    return .{
        .class = .{ .MsBlob = .{
            .state = .Lying,
        } },
        .x = spawn_x,
        .y = spawn_y,
        .spd_x = 0,
        .spd_y = 0,
        .spr = 12,
        .t = 0,
        .pad_left = 0,
        .pad_right = 0,
        .pad_top = -4,
        .pad_bottom = 0,
    };
}

///enemies////
//black
pub inline fn create_enemy_black(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
    direction: Direction,
) Entity {
    return .{
        .class = .{ .Enemy = .{
            .class = .Black,
            .spd_x_old = 0,
            .grav_down = 0.6,
            .grav_down_max = 4,
            .is_killed = false,
            .has_landed = true,
        } },
        .direction = direction,
        .x = spawn_x,
        .y = spawn_y,
        .spd_x = 0.5 * @as(game.WorldDim, if (direction == .Left) -1 else 1),
        .spd_y = 0,
        .spr = 60,
        .t = 0,
        .pad_left = -1,
        .pad_right = -1,
        .pad_top = -2,
        .pad_bottom = 0,
    };
}

//white
pub inline fn create_enemy_white(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
    direction: Direction,
) Entity {
    var enemy = create_enemy_black(spawn_x, spawn_y, direction);
    enemy.class.Enemy.class = .White;
    enemy.spr = 55;
    return enemy;
}

//bullet
pub const Bullet = struct {
    id: f32,
    spd: game.WorldDim,
};
pub fn create_bullet(
    spawn_x: game.WorldDim,
    spawn_y: game.WorldDim,
    direction: Direction,
    game_state: *game.Game,
) Entity {
    var new_spr: u8 = 0;
    var new_spd: game.WorldDim = 0;
    var new_pad_left: game.WorldDim = 0;
    var new_pad_right: game.WorldDim = 0;
    switch (direction) {
        .Left => {
            new_spr = 28;
            new_spd = -2;
            new_pad_left = 0;
            new_pad_right = -3;
            if (game_state.level_number == 14) new_spd = -1;
        },
        .Right => {
            new_spr = 30;
            new_spd = 2;
            new_pad_left = -3;
            new_pad_right = 0;
            if (game_state.level_number == 14) new_spd = 1;
        },
    }
    return .{
        .class = .{ .Bullet = .{
            .id = toolbox.randomf_range(0, 128, &game_state.random_state),
            .spd = new_spd,
        } },
        .x = spawn_x,
        .y = spawn_y,
        .spr = new_spr,
        .t = 0,
        .pad_left = new_pad_left,
        .pad_right = new_pad_right,
        .pad_top = -2,
        .pad_bottom = -2,
    };
}
