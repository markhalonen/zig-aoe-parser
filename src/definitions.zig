const std = @import("std");
const enums = @import("fast/enums.zig");
const actions = @import("fast/actions.zig");
const util = @import("util.zig");

pub const Position = struct { x: f32, y: f32 };

/// Serialize a Match to JSON, handling circular references.
/// Returns a nested data structure appropriate for JSON output.
/// Caller owns the returned memory.
pub fn serialize(match: Match, allocator: std.mem.Allocator) ![]u8 {
    var seen_players = std.AutoHashMap(*const Player, void).init(allocator);
    defer seen_players.deinit();

    var output = std.ArrayList(u8).init(allocator);
    errdefer output.deinit();

    const writer = output.writer();
    try serializeMatch(match, writer, &seen_players);

    return output.toOwnedSlice();
}

fn serializeMatch(match: Match, writer: anytype, seen_players: *std.AutoHashMap(*const Player, void)) !void {
    try writer.writeAll("{");

    // players
    try writer.writeAll("\"players\":");
    try serializePlayerSlice(match.players, writer, seen_players);

    // teams
    try writer.writeAll(",\"teams\":[");
    for (match.teams, 0..) |team, i| {
        if (i > 0) try writer.writeAll(",");
        try serializePlayerSlice(team, writer, seen_players);
    }
    try writer.writeAll("]");

    // gaia
    try writer.writeAll(",\"gaia\":");
    try serializeObjectSlice(match.gaia, writer);

    // map
    try writer.writeAll(",\"map\":");
    try serializeMap(match.map, writer);

    // file
    try writer.writeAll(",\"file\":");
    try serializeFile(match.file, writer, seen_players);

    // simple fields
    try writer.print(",\"restored\":{}", .{match.restored});
    try writer.print(",\"restored_at_ms\":{}", .{match.restored_at_ms});
    try serializeOptionalString(",\"speed\":", match.speed, writer);
    try writer.print(",\"speed_id\":{}", .{match.speed_id});
    try writer.print(",\"cheats\":{}", .{match.cheats});
    try writer.print(",\"lock_teams\":{}", .{match.lock_teams});
    try writer.print(",\"population\":{}", .{match.population});

    // chat
    try writer.writeAll(",\"chat\":");
    try serializeChatSlice(match.chat, writer, seen_players);

    // guid
    if (match.guid) |guid| {
        try writer.writeAll(",\"guid\":\"");
        try writer.writeAll(&guid);
        try writer.writeAll("\"");
    }

    try serializeOptionalString(",\"lobby\":", match.lobby, writer);
    try serializeOptionalBool(",\"rated\":", match.rated, writer);
    try writer.writeAll(",\"dataset\":\"");
    try writeJsonEscaped(match.dataset, writer);
    try writer.writeAll("\"");
    try serializeOptionalString(",\"game_type\":", match.game_type, writer);
    try writer.print(",\"game_type_id\":{}", .{match.game_type_id});
    try serializeOptionalString(",\"map_reveal\":", match.map_reveal, writer);
    try writer.print(",\"map_reveal_id\":{}", .{match.map_reveal_id});
    try serializeOptionalString(",\"difficulty\":", match.difficulty, writer);
    try writer.print(",\"difficulty_id\":{}", .{match.difficulty_id});
    try serializeOptionalString(",\"starting_age\":", match.starting_age, writer);
    if (match.starting_age_id) |id| try writer.print(",\"starting_age_id\":{}", .{id});
    try serializeOptionalBool(",\"team_together\":", match.team_together, writer);
    try serializeOptionalBool(",\"lock_speed\":", match.lock_speed, writer);
    try serializeOptionalBool(",\"all_technologies\":", match.all_technologies, writer);
    try serializeOptionalBool(",\"multiqueue\":", match.multiqueue, writer);
    try writer.print(",\"duration_ms\":{}", .{match.duration_ms});
    try writer.writeAll(",\"diplomacy_type\":\"");
    try writeJsonEscaped(match.diplomacy_type, writer);
    try writer.writeAll("\"");
    try writer.print(",\"completed\":{}", .{match.completed});
    try writer.print(",\"dataset_id\":{}", .{match.dataset_id});
    try writer.writeAll(",\"version\":\"");
    try writer.writeAll(@tagName(match.version));
    try writer.writeAll("\"");
    try writer.writeAll(",\"game_version\":\"");
    try writeJsonEscaped(match.game_version, writer);
    try writer.writeAll("\"");
    try writer.writeAll(",\"save_version\":");
    try writeFloat(match.save_version, writer);
    try writer.print(",\"log_version\":{}", .{match.log_version});
    if (match.build_version) |v| try writer.print(",\"build_version\":{}", .{v});
    if (match.timestamp) |ts| try writer.print(",\"timestamp\":{}", .{ts});
    if (match.spec_delay_seconds) |d| try writer.print(",\"spec_delay_seconds\":{}", .{d});
    try serializeOptionalBool(",\"allow_specs\":", match.allow_specs, writer);
    try serializeOptionalBool(",\"hidden_civs\":", match.hidden_civs, writer);
    try serializeOptionalBool(",\"private\":", match.private, writer);
    try serializeOptionalString(",\"hash\":", match.hash, writer);

    // actions
    try writer.writeAll(",\"actions\":");
    try serializeActionSlice(match.actions, writer, seen_players);

    // inputs
    try writer.writeAll(",\"inputs\":");
    try serializeInputSlice(match.inputs, writer, seen_players);

    try writer.writeAll("}");
}

fn serializePlayerSlice(players: []Player, writer: anytype, seen_players: *std.AutoHashMap(*const Player, void)) !void {
    try writer.writeAll("[");
    for (players, 0..) |*player, i| {
        if (i > 0) try writer.writeAll(",");
        try serializePlayer(player, writer, seen_players);
    }
    try writer.writeAll("]");
}

fn serializePlayer(player: *const Player, writer: anytype, seen_players: *std.AutoHashMap(*const Player, void)) !void {
    // Handle circular reference - return player number as reference
    if (seen_players.contains(player)) {
        try writer.print("{}", .{player.number});
        return;
    }
    try seen_players.put(player, {});

    try writer.writeAll("{");
    try writer.print("\"number\":{}", .{player.number});
    try writer.writeAll(",\"name\":\"");
    try writeJsonEscaped(player.name, writer);
    try writer.writeAll("\"");
    try writer.writeAll(",\"color\":\"");
    try writeJsonEscaped(player.color, writer);
    try writer.writeAll("\"");
    try writer.print(",\"color_id\":{}", .{player.color_id});
    try writer.writeAll(",\"civilization\":\"");
    try writeJsonEscaped(player.civilization, writer);
    try writer.writeAll("\"");
    try writer.print(",\"civilization_id\":{}", .{player.civilization_id});

    if (player.position) |pos| {
        try writer.writeAll(",\"position\":{\"x\":");
        try writeFloat(pos.x, writer);
        try writer.writeAll(",\"y\":");
        try writeFloat(pos.y, writer);
        try writer.writeAll("}");
    }

    try writer.writeAll(",\"objects\":");
    try serializeObjectSlice(player.objects, writer);

    try writer.print(",\"profile_id\":{}", .{player.profile_id});
    try writer.print(",\"prefer_random\":{}", .{player.prefer_random});

    // team - serialize as array of player numbers to avoid circular refs
    if (player.team) |team| {
        try writer.writeAll(",\"team\":[");
        for (team, 0..) |*p, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("{}", .{p.number});
        }
        try writer.writeAll("]");
    }

    if (player.team_id) |ids| {
        try writer.writeAll(",\"team_id\":[");
        for (ids, 0..) |id, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("{}", .{id});
        }
        try writer.writeAll("]");
    }

    if (player.winner) |w| try writer.print(",\"winner\":{}", .{w});
    if (player.eapm) |e| try writer.print(",\"eapm\":{}", .{e});
    if (player.rate_snapshot) |r| try writer.print(",\"rate_snapshot\":{}", .{r});

    try writer.writeAll("}");
}

fn serializeObjectSlice(objects: []Object, writer: anytype) !void {
    try writer.writeAll("[");
    for (objects, 0..) |obj, i| {
        if (i > 0) try writer.writeAll(",");
        try serializeObject(obj, writer);
    }
    try writer.writeAll("]");
}

fn serializeObject(obj: Object, writer: anytype) !void {
    try writer.writeAll("{");
    if (obj.name) |name| {
        try writer.writeAll("\"name\":\"");
        try writeJsonEscaped(name, writer);
        try writer.writeAll("\",");
    }
    try writer.print("\"class_id\":{}", .{obj.class_id});
    try writer.print(",\"object_id\":{}", .{obj.object_id});
    try writer.print(",\"instance_id\":{}", .{obj.instance_id});
    try writer.print(",\"index\":{}", .{obj.index});
    try writer.writeAll(",\"position\":{\"x\":");
    try writeFloat(obj.position.x, writer);
    try writer.writeAll(",\"y\":");
    try writeFloat(obj.position.y, writer);
    try writer.writeAll("}}");
}

fn serializeMap(map: Map, writer: anytype) !void {
    try writer.writeAll("{");
    try writer.print("\"id\":{}", .{map.id});
    try writer.writeAll(",\"name\":\"");
    try writeJsonEscaped(map.name, writer);
    try writer.writeAll("\"");
    try writer.print(",\"dimension\":{}", .{map.dimension});
    try serializeOptionalString(",\"size\":", map.size, writer);
    try writer.print(",\"custom\":{}", .{map.custom});
    try writer.print(",\"seed\":{}", .{map.seed});
    if (map.mod_id) |id| try writer.print(",\"mod_id\":{}", .{id});
    try writer.print(",\"zr\":{}", .{map.zr});
    try serializeOptionalString(",\"modes\":", map.modes, writer);
    try writer.writeAll(",\"tiles\":[");
    for (map.tiles, 0..) |tile, i| {
        if (i > 0) try writer.writeAll(",");
        try writer.print("{{\"terrain_id\":{},\"elevation\":{},\"position\":{{\"x\":", .{ tile.terrain_id, tile.elevation });
        try writeFloat(tile.position.x, writer);
        try writer.writeAll(",\"y\":");
        try writeFloat(tile.position.y, writer);
        try writer.writeAll("}}");
    }
    try writer.writeAll("]}");
}

fn serializeFile(file: File, writer: anytype, seen_players: *std.AutoHashMap(*const Player, void)) !void {
    try writer.writeAll("{");
    try writer.writeAll("\"encoding\":\"");
    try writeJsonEscaped(file.encoding, writer);
    try writer.writeAll("\"");
    try serializeOptionalString(",\"language\":", file.language, writer);
    try writer.writeAll(",\"hash\":\"");
    try writer.writeAll(&file.hash);
    try writer.writeAll("\"");
    try writer.print(",\"size\":{}", .{file.size});
    if (file.device_type) |dt| try writer.print(",\"device_type\":{}", .{dt});
    try writer.writeAll(",\"perspective\":");
    try serializePlayer(&file.perspective, writer, seen_players);
    try writer.writeAll(",\"viewlocks\":[");
    for (file.viewlocks, 0..) |vl, i| {
        if (i > 0) try writer.writeAll(",");
        try writer.print("{{\"timestampMs\":{},\"position\":{{\"x\":", .{vl.timestampMs});
        try writeFloat(vl.position.x, writer);
        try writer.writeAll(",\"y\":");
        try writeFloat(vl.position.y, writer);
        try writer.writeAll("},\"player\":");
        try serializePlayer(&vl.player, writer, seen_players);
        try writer.writeAll("}");
    }
    try writer.writeAll("]}");
}

fn serializeChatSlice(chats: []Chat, writer: anytype, seen_players: *std.AutoHashMap(*const Player, void)) !void {
    try writer.writeAll("[");
    for (chats, 0..) |chat, i| {
        if (i > 0) try writer.writeAll(",");
        try writer.writeAll("{");
        try writer.print("\"timestampMs\":{}", .{chat.timestampMs});
        try writer.writeAll(",\"message\":\"");
        try writeJsonEscaped(chat.message, writer);
        try writer.writeAll("\"");
        try writer.writeAll(",\"origination\":\"");
        try writeJsonEscaped(chat.origination, writer);
        try writer.writeAll("\"");
        try writer.writeAll(",\"audience\":\"");
        try writeJsonEscaped(chat.audience, writer);
        try writer.writeAll("\"");
        try writer.writeAll(",\"player\":");
        try serializePlayer(&chat.player, writer, seen_players);
        try writer.writeAll("}");
    }
    try writer.writeAll("]");
}

fn serializePayload(payload: actions.action_result, writer: anytype) !void {
    try writer.writeAll("{");
    var first = true;

    // Enrichment fields (strings)
    if (payload.command) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"command\":\"");
        try writeJsonEscaped(v, writer);
        try writer.writeAll("\"");
    }
    if (payload.technology) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"technology\":\"");
        try writeJsonEscaped(v, writer);
        try writer.writeAll("\"");
    }
    if (payload.formation) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"formation\":\"");
        try writeJsonEscaped(v, writer);
        try writer.writeAll("\"");
    }
    if (payload.stance) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"stance\":\"");
        try writeJsonEscaped(v, writer);
        try writer.writeAll("\"");
    }
    if (payload.building) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"building\":\"");
        try writeJsonEscaped(v, writer);
        try writer.writeAll("\"");
    }
    if (payload.unit) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"unit\":\"");
        try writeJsonEscaped(v, writer);
        try writer.writeAll("\"");
    }
    if (payload.order) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"order\":\"");
        try writeJsonEscaped(v, writer);
        try writer.writeAll("\"");
    }
    if (payload.resource) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"resource\":\"");
        try writeJsonEscaped(v, writer);
        try writer.writeAll("\"");
    }

    // Sequence
    if (payload.sequence) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"sequence\":{}", .{v});
    }

    // ID fields
    if (payload.command_id) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"command_id\":{}", .{v});
    }
    if (payload.technology_id) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"technology_id\":{}", .{v});
    }
    if (payload.unit_id) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"unit_id\":{}", .{v});
    }
    if (payload.building_id) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"building_id\":{}", .{v});
    }
    if (payload.stance_id) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"stance_id\":{}", .{v});
    }
    if (payload.order_id) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"order_id\":{}", .{v});
    }
    if (payload.slot_id) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"slot_id\":{}", .{v});
    }
    if (payload.formation_id) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"formation_id\":{}", .{v});
    }
    if (payload.resource_id) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"resource_id\":{}", .{v});
    }

    // Numeric fields
    if (payload.target_player_id) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"target_player_id\":{}", .{v});
    }
    if (payload.diplomacy_mode) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"diplomacy_mode\":{}", .{v});
    }
    if (payload.speed) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"speed\":");
        try writeFloat(v, writer);
    }
    if (payload.number) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"number\":{}", .{v});
    }
    if (payload.amount) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"amount\":{}", .{v});
    }
    if (payload.target_id) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"target_id\":{}", .{v});
    }
    if (payload.target_type) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"target_type\":{}", .{v});
    }
    if (payload.mode) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"mode\":{}", .{v});
    }
    if (payload.wood) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"wood\":");
        try writeFloat(v, writer);
    }
    if (payload.food) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"food\":");
        try writeFloat(v, writer);
    }
    if (payload.gold) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"gold\":");
        try writeFloat(v, writer);
    }
    if (payload.stone) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"stone\":");
        try writeFloat(v, writer);
    }
    if (payload.x_end) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"x_end\":{}", .{v});
    }
    if (payload.y_end) |v| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.print("\"y_end\":{}", .{v});
    }

    // Object IDs array
    if (payload.object_ids) |ids| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"object_ids\":[");
        for (ids, 0..) |id, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("{}", .{id});
        }
        try writer.writeAll("]");
    }

    // Targets array
    if (payload.targets) |tgts| {
        if (!first) try writer.writeAll(",");
        first = false;
        try writer.writeAll("\"targets\":[");
        for (tgts, 0..) |t, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("{}", .{t});
        }
        try writer.writeAll("]");
    }

    try writer.writeAll("}");
}

fn formatTimestamp(ms: u32, writer: anytype) !void {
    const total_seconds = ms / 1000;
    const hours = total_seconds / 3600;
    const minutes = (total_seconds % 3600) / 60;
    const seconds = total_seconds % 60;
    const micros = (ms % 1000) * 1000;
    try writer.print("\"{}:{d:0>2}:{d:0>2}.{d:0>6}\"", .{ hours, minutes, seconds, micros });
}

fn serializeActionSlice(act: []Action, writer: anytype, _: *std.AutoHashMap(*const Player, void)) !void {
    try writer.writeAll("[");
    for (act, 0..) |a, i| {
        if (i > 0) try writer.writeAll(",");
        try writer.writeAll("{");
        try writer.writeAll("\"timestamp\":");
        try formatTimestamp(a.timestamp, writer);
        try writer.writeAll(",\"type\":\"");
        for (@tagName(a.action)) |c| {
            try writer.writeByte(std.ascii.toUpper(c));
        }
        try writer.writeAll("\"");
        try writer.writeAll(",\"payload\":");
        try serializePayload(a.payload, writer);
        if (a.player) |p| {
            try writer.print(",\"player\":{}", .{p.number});
        }
        if (a.position) |pos| {
            try writer.writeAll(",\"position\":{\"x\":");
            try writeFloat(pos.x, writer);
            try writer.writeAll(",\"y\":");
            try writeFloat(pos.y, writer);
            try writer.writeAll("}");
        }
        try writer.writeAll("}");
    }
    try writer.writeAll("]");
}

fn serializeInputSlice(inputs: []Input, writer: anytype, seen_players: *std.AutoHashMap(*const Player, void)) !void {
    try writer.writeAll("[");
    for (inputs, 0..) |inp, i| {
        if (i > 0) try writer.writeAll(",");
        try writer.writeAll("{");
        try writer.print("\"timestamp\":{}", .{inp.timestamp});
        try writer.writeAll(",\"input_type\":\"");
        try writeJsonEscaped(inp.input_type, writer);
        try writer.writeAll("\"");
        if (inp.param) |param| {
            try writer.writeAll(",\"param\":\"");
            try writeJsonEscaped(param, writer);
            try writer.writeAll("\"");
        }
        // payload serialization depends on action_result type - simplified here
        try writer.writeAll(",\"payload\":{}");
        if (inp.player) |*p| {
            try writer.writeAll(",\"player\":");
            try serializePlayer(p, writer, seen_players);
        }
        if (inp.position) |pos| {
            try writer.writeAll(",\"position\":{\"x\":");
            try writeFloat(pos.x, writer);
            try writer.writeAll(",\"y\":");
            try writeFloat(pos.y, writer);
            try writer.writeAll("}");
        }
        try writer.writeAll("}");
    }
    try writer.writeAll("]");
}

fn serializeOptionalString(prefix: []const u8, value: ?[]const u8, writer: anytype) !void {
    if (value) |v| {
        try writer.writeAll(prefix);
        try writer.writeAll("\"");
        try writeJsonEscaped(v, writer);
        try writer.writeAll("\"");
    }
}

fn serializeOptionalBool(prefix: []const u8, value: ?bool, writer: anytype) !void {
    if (value) |v| {
        try writer.writeAll(prefix);
        try writer.print("{}", .{v});
    }
}

fn writeFloat(value: f32, writer: anytype) !void {
    // Ensure floats always have a decimal point for JSON compatibility
    const rounded = @round(value);
    if (value == rounded and @abs(value) < 1e9) {
        // It's a whole number - add .0
        try writer.print("{d}.0", .{@as(i64, @intFromFloat(value))});
    } else {
        // Use f64 for full precision output matching Python
        try writer.print("{d}", .{@as(f64, value)});
    }
}

fn writeJsonEscaped(s: []const u8, writer: anytype) !void {
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    try writer.print("\\u{x:0>4}", .{c});
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
}

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

pub const Tile = struct {
    terrain_id: u8,
    elevation: u8,
    position: Position,
};

pub const Map = struct {
    id: u32,
    name: []const u8,
    dimension: u32,
    size: ?[]const u8,
    custom: bool,
    seed: i32,
    mod_id: ?u32,
    zr: bool,
    modes: ?[]const u8,
    tiles: []Tile,
};

pub const File = struct {
    encoding: []const u8,
    language: ?[]const u8,
    hash: [40]u8,
    size: u64,
    device_type: ?u8,
    perspective: Player,
    viewlocks: []Viewlock,
};

pub const Match = struct {
    players: []Player,
    teams: [][]Player,
    gaia: []Object,
    map: Map,
    file: File,
    restored: bool,
    restored_at_ms: u32,
    speed: ?[]const u8,
    speed_id: u32,
    cheats: bool,
    lock_teams: bool,
    population: u32,
    chat: []Chat,
    guid: ?[36]u8,
    lobby: ?[]const u8,
    rated: ?bool,
    dataset: []const u8,
    game_type: ?[]const u8,
    game_type_id: u32,
    map_reveal: ?[]const u8,
    map_reveal_id: u32,
    difficulty: ?[]const u8,
    difficulty_id: u32,
    starting_age: ?[]const u8,
    starting_age_id: ?u32,
    team_together: ?bool,
    lock_speed: ?bool,
    all_technologies: ?bool,
    multiqueue: ?bool,
    duration_ms: u32,
    diplomacy_type: []const u8,
    completed: bool,
    dataset_id: u32,
    version: util.Version,
    game_version: []const u8,
    save_version: f32,
    log_version: u32,
    build_version: ?u32,
    timestamp: ?i64,
    spec_delay_seconds: ?u32,
    allow_specs: ?bool,
    hidden_civs: ?bool,
    private: ?bool,
    hash: ?[]const u8,
    actions: []Action,
    inputs: []Input,
};
