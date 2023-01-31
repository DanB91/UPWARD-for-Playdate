pub const RandomState = u32;
pub fn init_random(seed: u32) RandomState {
    return seed;
}
pub fn random32(state: *RandomState) u32 {
    state.* +%= 0x6D2B79F5;
    var z = state.*;
    z = (z ^ z >> 15) *% (1 | z);
    z ^= z +% (z ^ z >> 7) *% (61 | z);
    return z ^ z >> 14;
}

pub fn randomf_range(comptime min: comptime_float, comptime max: comptime_float, state: *RandomState) f32 {
    const value = @intToFloat(f32, random32(state));
    return min + ((value - 0) * (max - min) / (0xFFFF_FFFF - 0));
}
