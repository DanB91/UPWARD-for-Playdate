const pdapi = @import("playdate_api.zig");
const game = @import("game.zig");
pub const Particle = struct {
    x: game.WorldDim,
    y: game.WorldDim,
    spd_x: game.WorldDim,
    spd_y: game.WorldDim,
    r: game.WorldDim,

    col_out: game.P8Color,
    col_fill: game.P8Color,
};
pub fn create_particle(
    x: game.WorldDim,
    y: game.WorldDim,
    spd_x: game.WorldDim,
    spd_y: game.WorldDim,
    r: game.WorldDim,
    col_out: game.P8Color,
    col_fill: game.P8Color,
) Particle {
    return .{
        .x = x,
        .y = y,
        .spd_x = spd_x,
        .spd_y = spd_y,
        .r = r,
        .col_out = col_out,
        .col_fill = col_fill,
    };
}

pub fn update_particle(p: *Particle, game_state: *game.Game) void {
    p.x += p.spd_x;
    p.y += p.spd_y;
    p.r -= 0.1;
    if (p.r <= 0) game_state.particles.remove(p);
}

pub fn draw_particle(p: *Particle) void {
    game.circfill(p.x, p.y, p.r, p.col_fill);
    game.circ(p.x, p.y, p.r, p.col_out);
}
