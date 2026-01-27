const enums = @import("fast/enums.zig");
const actions = @import("fast/actions.zig");

pub const Position = struct { x: f32, y: f32 };

pub const Object = struct {
    name: ?[]const u8,
    class_id: i8,
    object_id: u64,
    instance_id: u32,
    index: u32,
    position: Position,
};

pub const Player = struct {
    number: usize,
    name: []const u8,
    color: []const u8,
    color_id: u32,
    civilization: []const u8,
    civilization_id: u32,
    position: ?Position,
    objects: []Object,
    profile_id: u32,
    prefer_random: bool,
    team: ?[]Player,
    team_id: ?[]i32,
    winner: ?bool,
    eapm: ?u32,
    rate_snapshot: ?u32,
};

pub const Viewlock = struct {
    timestampMs: u32,
    position: Position,
    player: Player,
};

pub const Chat = struct {
    timestampMs: u32,
    message: []const u8,
    origination: []const u8,
    audience: []const u8,
    player: Player,
};

pub const Action = struct {
    timestamp: u32,
    action: enums.ActionEnum,
    payload: actions.action_result,
    player: ?Player,
    position: ?Position,
};

pub const Input = struct {
    timestamp: u32,
    input_type: []const u8,
    param: ?[]const u8,
    payload: actions.action_result,
    player: ?Player,
    position: ?Position,
};
