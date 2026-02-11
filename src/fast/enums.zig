const actions = @import("./actions.zig");
const std = @import("std");

pub const OperationTag = enum(u8) {
    /// Operation types.
    action = 1,
    sync = 2,
    viewlock = 3,
    chat = 4,
    start = 5,
    postgame = 6,
    save = 7,
};

pub const value_type = struct {
    total_res: u32,
    dp_obj_count: u32,
    dp_obj_ttl: u32,
    obj_count: u32,
};

pub const payload_type = struct { current_time: ?u32, values: ?std.AutoHashMap(u32, value_type) };

pub const sync_result = struct {
    increment: u32,
    checksum: ?u32,
    payload: payload_type,
};

pub const viewlock_result = struct {
    x: f32,
    y: f32,
};

pub const postgame_player = struct {
    number: i32,
    rank: i32,
    rating: i32,
};

pub const postgame_leaderboard = struct { id: u32, players: []postgame_player };

pub const postgame_result = struct { world_time: ?u32, leaderboards: ?[]postgame_leaderboard };

pub const Operation = union(OperationTag) {
    action: actions.action_result,
    sync: sync_result,
    viewlock: viewlock_result,
    chat: []const u8,
    start: void,
    postgame: postgame_result,
    save: void,
};

pub const ActionEnum = enum(i16) {
    /// Action types.
    @"error" = -1,
    order = 0,
    stop = 1,
    work = 2,
    move = 3,
    create = 4,
    add_attribute = 5,
    give_attribute = 6,
    ai_order = 10,
    resign = 11,
    spectate = 15,
    add_waypoint = 16,
    stance = 18,
    guard = 19,
    follow = 20,
    patrol = 21,
    formation = 23,
    save = 27,
    group_multi_waypoints = 31,
    chapter = 32,
    de_attack_move = 33,
    hd_unknown_34 = 34,
    de_retreat = 35,
    de_unknown_37 = 37,
    de_autoscout = 38,
    de_unknown_39 = 39,
    de_unknown_40 = 40,
    de_transform = 41,
    ratha_ability = 43,
    de_107_a = 44,
    de_multi_gatherpoint = 45,
    ai_command = 53,
    de_unknown_80 = 80,
    make = 100,
    research = 101,
    build = 102,
    game = 103,
    wall = 105,
    delete = 106,
    attack_ground = 107,
    tribute = 108,
    de_unknown_109 = 109,
    repair = 110,
    ungarrison = 111,
    multiqueue = 112,
    gate = 114,
    flare = 115,
    special = 117,
    queue = 119,
    gather_point = 120,
    sell = 122,
    buy = 123,
    drop_relic = 126,
    town_bell = 127,
    back_to_work = 128,
    de_queue = 129,
    de_unknown_130 = 130,
    de_unknown_131 = 131,
    de_unknown_134 = 134,
    de_unknown_135 = 135,
    de_unknown_136 = 136,
    de_unknown_137 = 137,
    de_unknown_138 = 138,
    de_107_b = 140,
    de_tribute = 196,
    postgame = 255,
};

const Postgame = enum(u8) {
    /// Postgame types.
    world_time = 1,
    leaderboards = 2,
};
