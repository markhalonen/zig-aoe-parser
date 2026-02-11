const util = @import("util.zig");
const std = @import("std");
const uuid = @import("uuid");
const mvzr = @import("mvzr");

pub const parse_version_retval = struct { version: util.Version, game: *const [7]u8, save: f32, log: u32 };

pub fn parse_version(headerReader: *util.ByteReader, dataReader: *util.ByteReader) !parse_version_retval {
    const slice = dataReader.read_bytes(4);
    const log: u32 = std.mem.readInt(u32, slice[0..4], .little);

    const gameSlice = headerReader.read_bytes(7);

    _ = headerReader.read_bytes(1);

    const saveSlice = headerReader.read_bytes(4);
    var save: f32 = std.mem.bytesToValue(f32, saveSlice);

    if (save == -1) {
        const s = headerReader.read_bytes(4);
        const sInt: u32 = std.mem.readInt(u32, s[0..4], .little);

        if (sInt == 37) {
            save = 37.0;
        } else {
            save = @as(f32, @floatFromInt(sInt)) / @as(f32, @floatFromInt((1 << 16)));
        }
    }

    const version = try util.getVersion(gameSlice[0..7], save, log);

    return .{ .version = version, .game = gameSlice[0..7], .save = save, .log = log };
}

pub fn decompress(out2: *std.ArrayListAligned(u8, null), dataReader: *util.ByteReader) util.ByteReader {
    const slice = dataReader.read_bytes(8);

    // Read a u32 from the buffer (assuming little-endian format)
    const header_len = std.mem.readInt(u64, slice[0..8], .little);

    // read compressed header.
    const compressed_header = dataReader.read_bytes(header_len - 8); //buffer[8..header_len];

    var in2 = std.io.fixedBufferStream(compressed_header);

    std.compress.flate.decompress(in2.reader(), out2.writer()) catch {
        std.process.exit(1);
    };
    const headerReader = util.ByteReader.init(out2.items);
    return headerReader;
}

pub const player_type = struct {
    number: i32,
    color_id: i32,
    team_id: i32,
    ai_name: []const u8,
    name: []const u8,
    type: u32,
    profile_id: u32,
    civilization_id: u32,
    custom_civ_selection: ?[]u32,
    prefer_random: bool,
};

pub const parse_de_type = struct {
    players: []player_type,
    guid: [36]u8,
    hash: std.crypto.hash.Sha1,
    lobby: []const u8,
    mod: []const u8,
    difficulty_id: ?u32,
    victory_type_id: u32,
    starting_resources_id: u32,
    starting_age_id: u32,
    ending_age_id: u32,
    speed: f32,
    population_limit: u32,
    treaty_length: u32,
    team_together: bool,
    lock_teams: bool,
    lock_speed: bool,
    multiplayer: bool,
    cheats: bool,
    record_game: bool,
    animals_enabled: bool,
    predators_enabled: bool,
    turbo_enabled: bool,
    shared_exploration: bool,
    team_positions: bool,
    all_technologies: bool,
    build: ?u32,
    timestamp: ?u32,
    spec_delay: i32,
    rated: bool,
    allow_specs: bool,
    hidden_civs: bool,
    visibility_id: i32,
    rms_mod_id: ?[]const u8,
    rms_map_id: u32,
    rms_filename: ?[]const u8,
    dlc_ids: []u32,

    allocator: std.mem.Allocator, // Allocator reference for cleanup

    // Deinit method to free allocated memory
    pub fn deinit(self: *const parse_de_type) void {
        self.allocator.free(self.players);
    }
};

pub fn parse_de(allocator: std.mem.Allocator, headerReader: *util.ByteReader, version: util.Version, save: f32, skip: bool) parse_de_type {
    _ = version;
    var build: ?u32 = null;
    if (save > 25.22) {
        const s = headerReader.read_bytes(4);
        build = std.mem.readInt(u32, s[0..4], .little);
    }

    var timestamp: ?u32 = null;
    if (save > 26.16) {
        timestamp = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    }
    _ = headerReader.read_bytes(12);

    const dlc_count = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    const dlc_ids = allocator.alloc(u32, dlc_count) catch {
        std.process.exit(1);
    };
    for (0..dlc_count) |idx| {
        dlc_ids[idx] = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    }
    _ = headerReader.read_bytes(4);

    var difficulty_id: ?u32 = null;
    if (save > 61.5) {
        const map_dimension = headerReader.read_bytes(4);
        _ = map_dimension;
    } else {
        difficulty_id = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    }
    _ = headerReader.read_bytes(4);

    const rms_map_id = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    _ = headerReader.read_bytes(4);

    const victory_type_id = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    const starting_resources_id = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    const starting_age_id = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    const ending_age_id = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);

    _ = headerReader.read_bytes(12);

    const speed = std.mem.bytesToValue(f32, headerReader.read_bytes(4));

    const treaty_length = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    const population_limit = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    const num_players = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    _ = headerReader.read_bytes(14);

    if (save > 61.5) {
        difficulty_id = std.mem.readInt(u8, headerReader.read_bytes(1)[0..1], .little);
    }

    const random_positions = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    const all_technologies = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);

    _ = headerReader.read_bytes(1);

    const lock_teams = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    const lock_speed = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    const multiplayer = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    const cheats = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    // good
    const record_game = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    const animals_enabled = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    const predators_enabled = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    const turbo_enabled = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    const shared_exploration = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    const team_positions = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);

    _ = headerReader.read_bytes(12);

    if (save > 25.06) {
        _ = headerReader.read_bytes(1);
    }

    if (save > 50) {
        _ = headerReader.read_bytes(1);
    }

    const players = allocator.alloc(player_type, num_players) catch {
        std.process.exit(1);
    };

    for (0..(if (save > 37) num_players else 8)) |player_idx| {
        _ = headerReader.read_bytes(4);

        const color_id = std.mem.readInt(i32, headerReader.read_bytes(4)[0..4], .little);
        _ = headerReader.read_bytes(2);
        const team_id = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
        _ = headerReader.read_bytes(9);
        const civilization_id = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);

        var custom_civ_selection_optional: ?[]u32 = null;
        if (save > 61.5) {
            const custom_civ_count = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
            if (save > 63 and custom_civ_count > 0) {
                custom_civ_selection_optional = allocator.alloc(u32, custom_civ_count) catch {
                    std.process.exit(1);
                };
                if (custom_civ_selection_optional) |custom_civ_selection| {
                    for (0..custom_civ_count) |idx| {
                        custom_civ_selection[idx] = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
                    }
                }
            }
        }
        _ = util.de_string(headerReader);

        _ = headerReader.read_bytes(1);
        const ai_name = util.de_string(headerReader);
        const name = util.de_string(headerReader);
        const typeVal = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
        const profile_id = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
        _ = headerReader.read_bytes(4);
        const number = std.mem.readInt(i32, headerReader.read_bytes(4)[0..4], .little);

        if (save < 25.22) {
            _ = headerReader.read_bytes(8);
        }

        const prefer_random = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);

        _ = headerReader.read_bytes(1);

        if (save >= 25.06) {
            _ = headerReader.read_bytes(8);
        }
        if (save >= 64.3) {
            _ = headerReader.read_bytes(4);
        }

        const playa: player_type = .{
            .number = number,
            .color_id = color_id,
            .team_id = team_id,
            .ai_name = ai_name,
            .name = name,
            .type = typeVal,
            .profile_id = profile_id,
            .civilization_id = civilization_id,
            .custom_civ_selection = custom_civ_selection_optional,
            .prefer_random = prefer_random == 1,
        };
        players[player_idx] = playa;
    }
    _ = headerReader.read_bytes(12);

    if (save >= 37) {
        for (0..8 - num_players) |_| {
            if (save >= 61.5) {
                _ = headerReader.read_bytes(4);
            }
            _ = headerReader.read_bytes(12);
            _ = util.de_string(headerReader);
            _ = headerReader.read_bytes(1);
            _ = util.de_string(headerReader);
            _ = util.de_string(headerReader);
            _ = headerReader.read_bytes(38);
            if (save >= 64.3) {
                _ = headerReader.read_bytes(4);
            }
        }
    }

    _ = headerReader.read_bytes(4);

    const rated = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    const allow_specs = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    const visibility = std.mem.readInt(i32, headerReader.read_bytes(4)[0..4], .little);

    const hidden_civs = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    _ = headerReader.read_bytes(1);

    const spec_delay = std.mem.readInt(i32, headerReader.read_bytes(4)[0..4], .little);
    _ = headerReader.read_bytes(1);

    var strings = util.string_block(headerReader, allocator);

    _ = headerReader.read_bytes(8);

    for (0..20) |_| {
        const moreStrings = util.string_block(headerReader, allocator);
        for (moreStrings.items) |s| {
            strings.append(s) catch {
                std.debug.panic("oxygen", .{});
                std.process.exit(1);
            };
        }
    }

    _ = headerReader.read_bytes(4);

    if (save < 25.22) {
        _ = headerReader.read_bytes(236);
    }

    if (save >= 25.22) {
        _ = headerReader.seek(-4, .Current);
        const l = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
        _ = headerReader.read_bytes(l * 4);
    }

    const c = std.mem.readInt(u64, headerReader.read_bytes(8)[0..8], .little);
    for (0..c) |_| {
        _ = headerReader.read_bytes(4);
        _ = util.de_string(headerReader);
        _ = headerReader.read_bytes(4);
    }

    if (save > 25.02) {
        _ = headerReader.read_bytes(8);
    }

    const guid = headerReader.read_bytes(16);

    const lobby = util.de_string(headerReader);

    if (save > 25.22) {
        _ = headerReader.read_bytes(8);
    }

    const mod = util.de_string(headerReader);

    _ = headerReader.read_bytes(33);

    if (save >= 20.06) {
        _ = headerReader.read_bytes(1);
    }
    if (save >= 20.16) {
        _ = headerReader.read_bytes(8);
    }
    if (save >= 25.06) {
        _ = headerReader.read_bytes(21);
    }
    if (save >= 25.22) {
        _ = headerReader.read_bytes(4);
    }
    if (save >= 26.16) {
        _ = headerReader.read_bytes(8);
    }
    if (save >= 37) {
        _ = headerReader.read_bytes(3);
    }
    if (save > 50) {
        _ = headerReader.read_bytes(8);
    }
    if (save >= 61.5) {
        _ = headerReader.read_bytes(1);
    }
    if (save >= 63) {
        _ = headerReader.read_bytes(5);
    }

    var x: ?u32 = null;

    if (!skip) {
        _ = util.de_string(headerReader);
        _ = headerReader.read_bytes(8);
        if (save >= 37) {
            timestamp = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
            x = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
        }
    }

    var rms_mod_id: ?[]const u8 = null;
    var rms_filename: ?[]const u8 = null;

    for (0..strings.items.len) |idx| {
        const item = strings.items[idx];
        if (std.mem.eql(u8, item[0], "SUBSCRIBEDMODS") and std.mem.eql(u8, item[1], "RANDOM_MAPS")) {
            var split_thingy = std.mem.splitAny(u8, item[3], ",");
            rms_mod_id = split_thingy.next();
            rms_filename = item[2];
        }
    }
    const guidInt: u128 = std.mem.readInt(u128, guid[0..16], .little);
    var guidHash = std.crypto.hash.Sha1.init(.{});
    guidHash.update(guid);
    const res: parse_de_type = .{
        .players = players,
        .guid = uuid.urn.serialize(guidInt),
        .hash = guidHash,
        .lobby = lobby,
        .mod = mod,
        .difficulty_id = difficulty_id,
        .victory_type_id = victory_type_id,
        .starting_resources_id = starting_resources_id,
        .starting_age_id = if (starting_age_id > 0) starting_age_id - 2 else 0,
        .ending_age_id = if (ending_age_id > 0) ending_age_id - 2 else 0,
        .speed = speed,
        .population_limit = population_limit,
        .treaty_length = treaty_length,
        .team_together = random_positions == 0,
        .all_technologies = all_technologies != 0,
        .lock_teams = lock_teams != 0,
        .lock_speed = lock_speed != 0,
        .multiplayer = multiplayer != 0,
        .cheats = cheats != 0,
        .record_game = record_game != 0,
        .animals_enabled = animals_enabled != 0,
        .predators_enabled = predators_enabled != 0,
        .turbo_enabled = turbo_enabled != 0,
        .shared_exploration = shared_exploration != 0,
        .team_positions = team_positions != 0,
        .build = build,
        .timestamp = timestamp,
        .spec_delay = spec_delay,
        .rated = rated == 1,
        .allow_specs = allow_specs != 0,
        .hidden_civs = hidden_civs != 0,
        .visibility_id = visibility,
        .rms_mod_id = rms_mod_id,
        .rms_map_id = rms_map_id,
        .rms_filename = rms_filename,
        .dlc_ids = dlc_ids,
        .allocator = allocator,
    };
    return res;
}

pub const parse_metadata_type = struct {
    speed: f32,
    owner_id: i16,
    cheats: bool,
};

pub fn parse_metadata(headerReader: *util.ByteReader, save: f32, skip_ai: bool) struct {
    metadata: parse_metadata_type,
    num_players: i8,
} {
    const ai = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);

    if (ai > 0) {
        if (!skip_ai) {
            std.debug.panic("defeated by ai", .{});
        }
        const offset = headerReader.get_position();
        _ = offset;
        // TODO: Finish parsing AI stuff.
    }

    _ = headerReader.read_bytes(24);
    const game_speed: f32 = std.mem.bytesToValue(f32, headerReader.read_bytes(4));
    _ = headerReader.read_bytes(17);
    const owner_id: i16 = std.mem.readInt(i16, headerReader.read_bytes(2)[0..2], .little);
    const num_players: i8 = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    _ = headerReader.read_bytes(1);
    const cheats: i8 = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);

    if (save < 61.5) {
        _ = headerReader.read_bytes(60);
    } else {
        _ = headerReader.read_bytes(24 + (@as(u64, @intCast(num_players)) * 4));
    }

    const retval: parse_metadata_type = .{
        .speed = game_speed,
        .owner_id = owner_id,
        .cheats = cheats == 1,
    };
    return .{ .metadata = retval, .num_players = num_players };
}

pub const parse_map_result = struct {
    all_visible: bool,
    restore_time: u32,
    dimension: u32,
    tiles: []struct { i8, i8 },
};

pub fn parse_map(allocator: std.mem.Allocator, headerReader: *util.ByteReader, version: util.Version, save: f32) parse_map_result {
    if (version == util.Version.DE) {
        _ = headerReader.read_bytes(8);
    }

    const size_x = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    const size_y = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    const zone_num = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    const tile_num = size_x * size_y;

    for (0..zone_num) |_| {
        if (version == util.Version.DE or version == util.Version.HD) {
            _ = headerReader.read_bytes(2048 + (tile_num * 2));
        } else {
            _ = headerReader.read_bytes(1275 + tile_num);
        }
        const num_floats = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
        _ = headerReader.read_bytes(num_floats * 4);
        _ = headerReader.read_bytes(4);
    }

    const all_visible = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
    _ = headerReader.read_bytes(1);

    const tiles = allocator.alloc(struct { i8, i8 }, tile_num) catch {
        std.process.exit(1);
    };

    for (0..tile_num) |idx| {
        if (version == util.Version.DE and save >= 62) {
            const v1 = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
            _ = headerReader.read_bytes(2);
            const v2 = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
            _ = headerReader.read_bytes(6);
            tiles[idx] = .{ v1, v2 };
        } else if (version == util.Version.DE) {
            const v1 = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
            _ = headerReader.read_bytes(1);
            const v2 = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
            _ = headerReader.read_bytes(6);
            tiles[idx] = .{ v1, v2 };
        } else {
            _ = headerReader.read_bytes(1);
            const v1 = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
            const v2 = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);
            _ = headerReader.read_bytes(1);
            tiles[idx] = .{ v1, v2 };
        }
    }

    const num_data = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    _ = headerReader.read_bytes(4 + num_data * 4);
    // wrong here

    for (0..num_data) |_| {
        const num_obs = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
        _ = headerReader.read_bytes(num_obs * 8);
    }

    const x2 = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    const y2 = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);

    _ = headerReader.read_bytes(x2 * y2 * 4);

    if (save > 61.5) {
        _ = headerReader.read_bytes(x2 * y2 * 4);
    }

    const restore_time = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);

    const retval: parse_map_result = .{
        .all_visible = all_visible == 1,
        .restore_time = restore_time,
        .dimension = size_x,
        .tiles = tiles,
    };
    return retval;
}
pub const player_info_type = struct {
    number: i32,
    type_: u32,
    name: []const u8,
    diplomacy: []i32,
    civilization_id: u32,
    color_id: i32,
    objects: []object,
    position: struct { x: f32, y: f32 },
    team_id: ?i32,
    profile_id: ?u32,
    custom_civ_selection: ?[]u32,
    prefer_random: ?bool,
    ai_name: ?[]const u8,

    pub fn update(self: *player_info_type, de_player: player_type) void {
        // handle all of these fields.
        //         number: i32,
        // color_id: i32,
        // team_id: i32,
        // ai_name: []const u8,
        // name: []const u8,
        // type: u32,
        // profile_id: u32,
        // civilization_id: u32,
        // custom_civ_selection: ?[]u32,
        // prefer_random: bool

        self.number = de_player.number;
        self.color_id = de_player.color_id;
        self.team_id = de_player.team_id;
        self.ai_name = de_player.ai_name;
        self.name = de_player.name;
        self.type_ = de_player.type;
        self.profile_id = de_player.profile_id;
        self.civilization_id = de_player.civilization_id;
        self.custom_civ_selection = de_player.custom_civ_selection;
        self.prefer_random = de_player.prefer_random;
    }
};

const parse_player_result = struct {
    player_info: player_info_type,
    device: ?u8,
};

pub fn parse_player(allocator: std.mem.Allocator, headerReader: *util.ByteReader, player_number: usize, num_players: usize, save: f32) parse_player_result {
    parse_player_calls += 1;
    var t_total = std.time.Timer.start() catch @panic("timer");

    var rep: usize = 9;
    if (save > 61.5) {
        rep = num_players;
    }
    const type_ = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);

    _ = headerReader.read_bytes(1 + num_players);
    const diplomacy = allocator.alloc(i32, rep) catch {
        std.process.exit(1);
    };
    for (0..rep) |idx| {
        const d = std.mem.readInt(i32, headerReader.read_bytes(4)[0..4], .little);
        diplomacy[idx] = d;
    }
    _ = headerReader.read_bytes(5);
    const name_length = std.mem.readInt(i16, headerReader.read_bytes(2)[0..2], .little);

    const name = headerReader.read_bytes(@as(u64, @intCast(name_length)) - 1);
    _ = headerReader.read_bytes(2);
    const resources = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);

    const resources_len: u32 = if (save >= 63) 8 else 4;
    _ = headerReader.read_bytes(resources_len * resources);
    _ = headerReader.read_bytes(1);

    _ = headerReader.read_bytes(1);

    const start_x = std.mem.bytesToValue(f32, headerReader.read_bytes(4));

    const start_y = std.mem.bytesToValue(f32, headerReader.read_bytes(4));

    _ = headerReader.read_bytes(9);

    const civilization_id: i8 = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);

    _ = headerReader.read_bytes(3);

    const color_id = std.mem.readInt(i8, headerReader.read_bytes(1)[0..1], .little);

    _ = headerReader.read_bytes(1);

    var offset = headerReader.get_position();

    const all_bytes = headerReader.read();

    // Combined needle: \x0b\x00 + any byte + \x00\x00\x00\x02\x00\x00
    var t_needle = std.time.Timer.start() catch @panic("timer");
    const needle1: []const u8 = "\x0b\x00";
    const needle2: []const u8 = "\x00\x00\x00\x02\x00\x00";
    var startOpt: ?usize = null;

    // Use indexOf to find needle1, then verify needle2
    var search_pos: usize = 0;
    while (search_pos < all_bytes.len - 9) {
        if (std.mem.indexOf(u8, all_bytes[search_pos..], needle1)) |rel_idx| {
            const idx = search_pos + rel_idx;
            if (idx + 9 <= all_bytes.len and std.mem.eql(u8, all_bytes[idx + 3 .. idx + 9], needle2)) {
                startOpt = idx + 9;
                break;
            }
            search_pos = idx + 1;
        } else {
            break;
        }
    }
    parse_player_needle_search_time += t_needle.read();

    if (startOpt) |start| {
        var t_obj_block = std.time.Timer.start() catch @panic("timer");

        // Pre-compute all BLOCK_END positions once
        var block_ends = std.ArrayList(usize).init(allocator);
        var be_search: usize = 0;
        while (std.mem.indexOfPos(u8, all_bytes, be_search, BLOCK_END)) |found_pos| {
            block_ends.append(found_pos) catch break;
            be_search = found_pos + 1;
        }

        var r1 = object_block(allocator, all_bytes, start, player_number, 0, block_ends.items);

        const r2 = object_block(allocator, all_bytes, r1.position, player_number, 1, block_ends.items);

        const r3 = object_block(allocator, all_bytes, r2.position, player_number, 2, block_ends.items);
        parse_player_object_block_time += t_obj_block.read();

        var end = r3.position;
        if (std.mem.eql(u8, all_bytes[end + 8 .. end + 10], BLOCK_END)) {
            end += 10;
        }

        if (std.mem.eql(u8, all_bytes[end .. end + 2], BLOCK_END)) {
            end += 2;
        }

        headerReader.seek(offset + end, .Start);

        var device: ?u8 = null;

        if (save >= 37) {
            var t_end_regex = std.time.Timer.start() catch @panic("timer");
            offset = headerReader.get_position();
            const data = headerReader.read_bytes(100);
            device = data[8];
            const r = mvzr.compile("\xff\xff\xff\xff\xff\xff\xff\xff.\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x0b").?;
            const player_end_match = r.match(data);
            parse_player_end_regex_time += t_end_regex.read();

            if (player_end_match) |player_end| {
                headerReader.seek(offset + player_end.end, .Start);
            } else {
                if (player_number < num_players - 1) {
                    std.debug.panic("could not find player end", .{});
                }
            }
        }

        r1.objects.appendSlice(r2.objects.items) catch {
            std.debug.panic("asda121asd", .{});
        };
        r1.objects.appendSlice(r3.objects.items) catch {
            std.debug.panic("asda12asdasfa1asd", .{});
        };

        const res: parse_player_result = .{
            .player_info = .{
                .number = @as(i32, @intCast(player_number)),
                .type_ = @as(u32, @intCast(type_)),
                .name = name,
                .diplomacy = diplomacy,
                .civilization_id = @as(u32, @intCast(civilization_id)),
                .color_id = color_id,
                .objects = r1.objects.items,
                .position = .{ .x = start_x, .y = start_y },
                .team_id = null,
                .profile_id = null,
                .prefer_random = null,
                .custom_civ_selection = null,
                .ai_name = null,
            },
            .device = device,
        };
        parse_player_time += t_total.read();
        return res;
    } else {
        std.debug.panic("failed to find start", .{});
    }
}

// Manual byte scan replacement for regex pattern:
// (\n|\x1e|F|P|\x14)\xNN(?!\xff\xff)(?!\x00\x00)....\xff\xff\xff\xff[^\xff]
fn findObjectMatch(data: []const u8, player_byte: u8) ?usize {
    if (data.len < 11) return null;
    const limit = data.len - 10;
    var i: usize = 0;
    while (i < limit) : (i += 1) {
        const b0 = data[i];
        // Check first byte is one of: \n (0x0a), \x1e, F (0x46), P (0x50), \x14
        if (b0 == 0x0a or b0 == 0x1e or b0 == 0x46 or b0 == 0x50 or b0 == 0x14) {
            // Check player byte
            if (data[i + 1] == player_byte) {
                // Negative lookaheads: not \xff\xff and not \x00\x00
                const b2 = data[i + 2];
                const b3 = data[i + 3];
                if (b2 == 0xff and b3 == 0xff) continue;
                if (b2 == 0x00 and b3 == 0x00) continue;
                // Check \xff\xff\xff\xff at offset +6
                if (data[i + 6] == 0xff and data[i + 7] == 0xff and
                    data[i + 8] == 0xff and data[i + 9] == 0xff)
                {
                    // Last byte not \xff
                    if (data[i + 10] != 0xff) return i;
                }
            }
        }
    }
    return null;
}

const BLOCK_END = "\x00\x0b";

// const Point = struct { x: i32, y: i32 };

// var map = std.AutoHashMap(u32, Point).init(
//     std.mem.alloc,
// );

// var dict = std.AutoHashMap(i32, mvzr.SizedRegex).init(std.heap.page_allocator);
// defer dict.deinit(); // Clean up memory

// // Add key-value pairs
// try dict.put(0, mvzr.compile("(\n|\x1e|F|P|\x14)\x00(?!\xff\xff)(?!\x00\x00)....\xff\xff\xff\xff[^\\xff]").?);

const object = struct { class_id: i8, object_id: u64, instance_id: u32, position: struct { x: f32, y: f32 }, index: u8 };

pub fn parse_object(data: []const u8, pos: usize) object {
    var reader = util.ByteReader.init(data[pos..]);
    const class_id = std.mem.readInt(i8, reader.read_bytes(1)[0..1], .little);
    _ = reader.read_bytes(1);
    const object_id = std.mem.readInt(u16, reader.read_bytes(2)[0..2], .little);
    _ = reader.read_bytes(14);
    const instance_id = std.mem.readInt(u32, reader.read_bytes(4)[0..4], .little);
    _ = reader.read_bytes(1);
    const x = std.mem.bytesToValue(f32, reader.read_bytes(4));
    const y = std.mem.bytesToValue(f32, reader.read_bytes(4));
    return .{
        .class_id = class_id,
        .object_id = object_id,
        .instance_id = instance_id,
        .position = .{ .x = x, .y = y },
        .index = 0,
    };
}

const object_block_result = struct {
    position: usize,
    objects: std.ArrayList(object),
};

var object_block_time: u64 = 0;
var object_block_calls: u64 = 0;
var object_block_iterations: u64 = 0;
var regex_calls: u64 = 0;
var regex_match_time: u64 = 0;
var indexof_time: u64 = 0;
var parse_object_time: u64 = 0;

// parse_player timing
var parse_player_time: u64 = 0;
var parse_player_calls: u64 = 0;
var parse_player_needle_search_time: u64 = 0;
var parse_player_object_block_time: u64 = 0;
var parse_player_end_regex_time: u64 = 0;

pub fn print_perf_times() void {
    std.debug.print("\n=== parse_player performance ===\n", .{});
    std.debug.print("total time:           {d:>8.2} ms\n", .{@as(f64, @floatFromInt(parse_player_time)) / 1_000_000.0});
    std.debug.print("calls:                {d}\n", .{parse_player_calls});
    std.debug.print("needle search:        {d:>8.2} ms\n", .{@as(f64, @floatFromInt(parse_player_needle_search_time)) / 1_000_000.0});
    std.debug.print("object_block calls:   {d:>8.2} ms\n", .{@as(f64, @floatFromInt(parse_player_object_block_time)) / 1_000_000.0});
    std.debug.print("end regex:            {d:>8.2} ms\n", .{@as(f64, @floatFromInt(parse_player_end_regex_time)) / 1_000_000.0});

    std.debug.print("\n=== object_block internals ===\n", .{});
    std.debug.print("total time:           {d:>8.2} ms\n", .{@as(f64, @floatFromInt(object_block_time)) / 1_000_000.0});
    std.debug.print("calls:                {d}\n", .{object_block_calls});
    std.debug.print("iterations:           {d}\n", .{object_block_iterations});
    std.debug.print("regex calls:          {d}\n", .{regex_calls});
    std.debug.print("regex matchPos time:  {d:>8.2} ms\n", .{@as(f64, @floatFromInt(regex_match_time)) / 1_000_000.0});
    std.debug.print("indexOf time:         {d:>8.2} ms\n", .{@as(f64, @floatFromInt(indexof_time)) / 1_000_000.0});
    std.debug.print("parse_object time:    {d:>8.2} ms\n", .{@as(f64, @floatFromInt(parse_object_time)) / 1_000_000.0});
    std.debug.print("================================\n", .{});
}

pub fn object_block(allocator: std.mem.Allocator, data: []const u8, posInput: usize, player_number: usize, index: u8, block_ends: []const usize) object_block_result {
    object_block_calls += 1;
    var t_total = std.time.Timer.start() catch @panic("timer");
    var objects = std.ArrayList(object).init(allocator);
    var offsetOpt: ?usize = null;
    var pos = posInput;
    var end: ?usize = null;
    var iteration: u32 = 0;
    var be_idx: usize = 0; // Current index into block_ends

    // Advance be_idx to first position >= posInput
    while (be_idx < block_ends.len and block_ends[be_idx] < posInput) : (be_idx += 1) {}

    // std.debug.print("calling object_block\n", .{});
    while (true) {
        object_block_iterations += 1;
        iteration += 1;
        if (offsetOpt) |_| {
            // NOOP
        } else {
            regex_calls += 1;
            var t_regex = std.time.Timer.start() catch @panic("timer");
            const search_end = @min(pos + 10000, data.len);
            const matchOpt = findObjectMatch(data[pos..search_end], @intCast(player_number));
            regex_match_time += t_regex.read();

            var matchStartOpt: ?usize = null;
            if (matchOpt) |match| {
                matchStartOpt = match + pos;
            }
            // std.debug.print("searching data of size {} at pos {}\n", .{ data.len, pos });
            var t_indexof = std.time.Timer.start() catch @panic("timer");

            // Find first block_end >= pos using pre-computed positions
            while (be_idx < block_ends.len and block_ends[be_idx] < pos) : (be_idx += 1) {}
            end = block_ends[be_idx] - pos + BLOCK_END.len;

            if (matchStartOpt) |matchStart| {
                offsetOpt = matchStart - pos;
                if (offsetOpt) |offset| {
                    while (end.? + 8 < offset) {
                        be_idx += 1;
                        end = block_ends[be_idx] - pos + BLOCK_END.len;
                    }
                }
            }
            indexof_time += t_indexof.read();
            if (matchStartOpt == null) {
                break;
            }
        }
        if (end.? + 8 == offsetOpt.?) {
            break;
        }
        pos = pos + offsetOpt.?;

        const test_ = data[pos .. pos + 4];
        if (!std.mem.eql(u8, test_, "\x1e\x00\x87\x02")) {
            // Parse object here.
            var t_parse = std.time.Timer.start() catch @panic("timer");
            var ob = parse_object(data, pos);
            ob.index = index;
            objects.append(ob) catch {
                std.debug.panic("failed to append", .{});
            };
            parse_object_time += t_parse.read();
        }
        offsetOpt = null;
        pos += 31;
    }
    object_block_time += t_total.read();
    // std.debug.panic("asd", .{});
    return .{
        .position = pos + end.?,
        .objects = objects,
    };
}

const parse_players_result = struct { player_infos: []player_info_type, device: ?u8 };

pub fn parse_players(
    allocator: std.mem.Allocator,
    headerReader: *util.ByteReader,
    version: util.Version,
    save: f32,
    num_players_i8: i8,
) parse_players_result {
    const num_players = @as(usize, @intCast(num_players_i8));
    var cur = headerReader.get_position();

    var anchorOptional: ?usize = null;
    const all_bytes = headerReader.read();

    if (version == util.Version.DE) {
        const needle: []const u8 = "\x05\x00Gaia\x00";
        for (0..all_bytes.len - 7) |idx| {
            if (std.mem.eql(u8, all_bytes[idx .. idx + 7], needle)) {
                anchorOptional = idx;
                break;
            }
        }
    } else {
        const needle: []const u8 = "\x05\x00GAIA\x00";
        for (0..all_bytes.len - 7) |idx| {
            if (std.mem.eql(u8, all_bytes[idx .. idx + 7], needle)) {
                anchorOptional = idx;
                break;
            }
        }
    }

    if (anchorOptional) |anchor| {
        var rev: usize = 43;
        if (save >= 61.5) {
            rev = 7 + (num_players * 4);
        }

        headerReader.seek(cur + anchor - @as(usize, @intCast(num_players)) - rev, .Start);
        _ = parse_mod(headerReader, num_players, version);
        var players = std.ArrayList(parse_player_result).init(allocator);
        var player_infos = std.ArrayList(player_info_type).init(allocator);

        for (0..num_players) |number| {
            const p = parse_player(allocator, headerReader, number, num_players, save);
            players.append(p) catch {
                std.debug.panic("asdasfasf", .{});
            };
            player_infos.append(p.player_info) catch {
                std.debug.panic("asasasfasfa", .{});
            };
        }
        cur = headerReader.get_position();
        var pv: []const u8 = "\x00\x00\x00@";
        if (save > 61.5) {
            pv = "\x66\x66\x06\x40";
        }
        const points_version = std.mem.indexOf(u8, headerReader.read(), pv);
        headerReader.seek(cur, .Start);
        _ = headerReader.read_bytes(points_version.?);

        for (0..num_players) |_| {
            _ = std.mem.bytesToValue(f32, headerReader.read_bytes(4));

            const entries = std.mem.readInt(i32, headerReader.read_bytes(4)[0..4], .little);
            _ = headerReader.read_bytes(5 + @as(u64, @intCast(entries)) * 44);
            const points = std.mem.readInt(i32, headerReader.read_bytes(4)[0..4], .little);
            _ = headerReader.read_bytes(8 + @as(u64, @intCast(points)) * 32);
        }
        return .{ .player_infos = player_infos.items, .device = players.items[0].device };
    } else {
        std.debug.panic("aljsijqi12da9cja", .{});
    }
}

fn parse_mod(headerReader: *util.ByteReader, num_players: usize, version: util.Version) ?struct { u32, []u8 } {
    // TODO: this only matters for user patch 15.
    _ = headerReader;
    _ = num_players;
    _ = version;
    return null;
    // const cur = headerReader.get_position();
    // _ = headerReader.read_bytes(2 + num_players + 36 + 5);
    // const name_length = std.mem.readInt(i16, headerReader.read_bytes(2)[0..2], .little);
    // _ = headerReader.read_bytes(name_length + 1);
    // const resources = std.mem.readInt(u32, headerReader.read_bytes(4)[0..4], .little);
    // const values_slice = headerReader.read_bytes(resources * 4);
}

fn aoc_string(reader: *util.ByteReader) []const u8 {
    const length = reader.read_int(i16);
    return reader.read_bytes(@as(u64, @intCast(length)));
}

fn int_prefixed_string(reader: *util.ByteReader) []const u8 {
    const length = reader.read_int(u32);
    return reader.read_bytes(length);
}

pub const parse_scenario_type = struct {
    map_id: u32,
    difficulty_id: u32,
    instructions: []const u8,
    scenario_filename: ?[]const u8,
};

pub fn parse_scenario(allocator: std.mem.Allocator, headerReader: *util.ByteReader, num_players: i8, version: util.Version, save: f32) parse_scenario_type {
    _ = allocator;
    _ = num_players;

    const next_uid = headerReader.read_int(u32);
    _ = next_uid;
    const scenario_version = headerReader.read_int(u32);
    _ = scenario_version;

    if (save > 61.5) {
        _ = headerReader.read_bytes(72);
    }
    _ = headerReader.read_bytes(4447);

    var scenario_filename: ?[]const u8 = null;
    if (version == util.Version.DE) {
        _ = headerReader.read_bytes(102);
        scenario_filename = aoc_string(headerReader);
        _ = headerReader.read_bytes(24);
    }
    const instructions = aoc_string(headerReader);

    for (0..9) |_| {
        _ = aoc_string(headerReader);
    }
    _ = headerReader.read_bytes(78);

    for (0..16) |_| {
        _ = aoc_string(headerReader);
    }
    _ = headerReader.read_bytes(196);

    for (0..16) |_| {
        _ = headerReader.read_bytes(24);
        if (version == util.Version.DE or version == util.Version.HD) {
            _ = headerReader.read_bytes(4);
        }
    }

    _ = headerReader.read_bytes(12672);

    if (version == util.Version.DE) {
        _ = headerReader.read_bytes(196);
    } else {
        for (0..16) |_| {
            _ = headerReader.read_bytes(332);
        }
    }

    if (version == util.Version.HD) {
        _ = headerReader.read_bytes(644);
    }
    _ = headerReader.read_bytes(88);

    if (version == util.Version.HD) {
        _ = headerReader.read_bytes(16);
    }

    const map_id = headerReader.read_int(u32);

    const difficulty_id = headerReader.read_int(u32);

    const remainder = headerReader.read();

    var end: ?usize = null;
    if (version == util.Version.DE) {
        var settings_version: f64 = 2.2;
        if (save >= 64.3) {
            settings_version = 4.1;
        } else if (save >= 63.0) {
            settings_version = 3.9;
        } else if (save >= 61.5) {
            settings_version = 3.6;
        } else if (save >= 37.0) {
            settings_version = 3.5;
        } else if (save >= 26.21) {
            settings_version = 3.2;
        } else if (save >= 26.16) {
            settings_version = 3.0;
        } else if (save >= 25.22) {
            settings_version = 2.6;
        } else if (save >= 25.06) {
            settings_version = 2.5;
        } else if (save >= 13.34) {
            settings_version = 2.4;
        }
        const val: [8]u8 = @bitCast(settings_version);

        end = std.mem.indexOf(u8, remainder, &val).? + 8;
    } else {
        end = std.mem.indexOf(u8, remainder, "\x9a\x99\x99\x99\x99\x99\xf9\x3f").? + 13;
    }

    const change = @as(i128, @intCast(end.?)) - @as(i128, @intCast(remainder.len));

    headerReader.seek(change, .Current);

    if (version == util.Version.DE) {
        _ = headerReader.read_bytes(1);
        const n_triggers = headerReader.read_int(u32);
        for (0..n_triggers) |_| {
            _ = headerReader.read_bytes(22);
            _ = headerReader.read_bytes(4);

            _ = int_prefixed_string(headerReader);
            _ = int_prefixed_string(headerReader);
            _ = int_prefixed_string(headerReader);

            const n_effects = headerReader.read_int(u32);

            for (0..n_effects) |_| {
                _ = headerReader.read_bytes(126);
                _ = int_prefixed_string(headerReader);
                _ = int_prefixed_string(headerReader);
            }

            _ = headerReader.read_bytes(n_effects * 4);

            const n_condition = headerReader.read_int(u32);

            _ = headerReader.read_bytes(n_condition * 125);
        }

        for (0..n_triggers) |_| {
            _ = headerReader.read_int(u32);
        }

        _ = headerReader.read_bytes(1032);
    }

    return .{
        .map_id = map_id,
        .difficulty_id = difficulty_id,
        .instructions = instructions,
        .scenario_filename = scenario_filename,
    };
}

pub fn strip(allocator: std.mem.Allocator, input: []const u8, char: u8) []u8 {
    if (input.len == 0) return allocator.dupe(u8, "") catch @panic("ahsdasoid");

    // Find the start index (first non-matching character)
    var start: usize = 0;
    while (start < input.len and input[start] == char) {
        start += 1;
    }

    // If all characters were the target char, return empty slice
    if (start == input.len) return allocator.dupe(u8, "") catch @panic("asdasdee1qdda");

    // Find the end index (last non-matching character)
    var end: usize = input.len;
    while (end > start and input[end - 1] == char) {
        end -= 1;
    }

    // Return the trimmed slice
    return allocator.dupe(u8, input[start..end]) catch @panic("oh noooo");
}

pub const parse_lobby_type = struct {
    reveal_map_id: u32,
    map_size: u32,
    population: u32,
    game_type_id: i8,
    lock_teams: bool,
    chat: [][]const u8,
    seed: ?i32,
};

pub fn parse_lobby(
    allocator: std.mem.Allocator,
    headerReader: *util.ByteReader,
    version: util.Version,
    save: f32,
) parse_lobby_type {
    if (version == util.Version.DE) {
        _ = headerReader.read_bytes(5);
        if (save >= 20.06) {
            _ = headerReader.read_bytes(9);
        }
        if (save >= 26.16) {
            _ = headerReader.read_bytes(5);
        }
        if (save >= 37) {
            _ = headerReader.read_bytes(8);
        }
        if (save >= 64.3) {
            _ = headerReader.read_bytes(16);
        }
    }
    _ = headerReader.read_bytes(8);

    if (version != util.Version.DE and version != util.Version.HD) {
        _ = headerReader.read_bytes(1);
    }

    const reveal_map_id = headerReader.read_int(u32);
    _ = headerReader.read_bytes(4);
    const map_size = headerReader.read_int(u32);
    const population = headerReader.read_int(u32);
    const game_type_id = headerReader.read_int(i8);
    const lock_teams = headerReader.read_int(i8);

    if (version == util.Version.DE or version == util.Version.HD) {
        _ = headerReader.read_bytes(5);
        if (save >= 13.13) {
            _ = headerReader.read_bytes(4);
        }
        if (save >= 25.22) {
            _ = headerReader.read_bytes(1);
        }
    }

    const chat_message_count = headerReader.read_int(u32);

    var chat = std.ArrayList([]const u8).init(allocator);

    for (0..chat_message_count) |_| {
        const message_length = headerReader.read_bytes(headerReader.read_int(u32));
        const message = strip(allocator, message_length, 0);
        if (message.len > 0) {
            chat.append(message) catch @panic("at the discooo");
        }
    }

    var seed: ?i32 = null;
    if (version == util.Version.DE) {
        seed = headerReader.read_int(i32);
    }

    return .{
        .reveal_map_id = reveal_map_id,
        .map_size = map_size,
        .population = (if (version != util.Version.DE and version != util.Version.HD) population * 25 else population),
        .game_type_id = game_type_id,
        .lock_teams = lock_teams == 1,
        .chat = chat.items,
        .seed = seed,
    };
}
