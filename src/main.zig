//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const util = @import("util.zig");
const header = @import("header.zig");
const std = @import("std");
const reference = @import("reference.zig");
const map = @import("map.zig");
const aoe_consts = @import("aoe_consts.zig");
const definitions = @import("definitions.zig");
const inputs = @import("inputs.zig");
const diplomacy = @import("diplomacy.zig");
const chatModule = @import("chat.zig");
const fastInit = @import("fast/init.zig");
const enums = @import("fast/enums.zig");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("zig14_basic_lib");

pub fn main() !void {
    try aoe_consts.initMaps();
    try parseMatch();
}

fn enrichAction(action: *definitions.Action, dataset: reference.DatasetResult, consts: std.json.Value) void {
    // Enrich action data with lookups
    const action_data = &action.payload;

    // Set position if x and y are present and valid
    if (action_data.x) |x| {
        if (action_data.y) |y| {
            if (x >= 0 and y >= 0) {
                // If not SPECIAL action, or has target_id > 0
                if (action.action != enums.ActionEnum.special or (action_data.target_id != null and action_data.target_id.? > 0)) {
                    action.position = .{ .x = x, .y = y };
                    action.payload.x = null;
                    action.payload.y = null;
                }
            }
        }
    }

    // Enrich technology_id
    if (action_data.technology_id) |tech_id| {
        var buffer: [20]u8 = undefined;
        const tech_id_str = std.fmt.bufPrint(&buffer, "{}", .{tech_id}) catch unreachable;
        if (dataset.json.object.get("technologies")) |techs| {
            if (techs.object.get(tech_id_str)) |tech| {
                action.payload.technology = tech.string;
            }
        }
    }

    // Enrich formation_id
    if (action_data.formation_id) |formation_id| {
        var buffer: [20]u8 = undefined;
        const formation_id_str = std.fmt.bufPrint(&buffer, "{}", .{formation_id}) catch unreachable;
        if (consts.object.get("formations")) |formations| {
            if (formations.object.get(formation_id_str)) |formation| {
                action.payload.formation = formation.string;
            }
        }
    }

    // Enrich stance_id
    if (action_data.stance_id) |stance_id| {
        var buffer: [20]u8 = undefined;
        const stance_id_str = std.fmt.bufPrint(&buffer, "{}", .{stance_id}) catch unreachable;
        if (consts.object.get("stances")) |stances| {
            if (stances.object.get(stance_id_str)) |stance| {
                action.payload.stance = stance.string;
            }
        }
    }

    // Enrich building_id
    if (action_data.building_id) |building_id| {
        var buffer: [20]u8 = undefined;
        const building_id_str = std.fmt.bufPrint(&buffer, "{}", .{building_id}) catch unreachable;
        if (dataset.json.object.get("objects")) |objects| {
            if (objects.object.get(building_id_str)) |building| {
                action.payload.building = building.string;
            }
        }
    }

    // Enrich unit_id
    if (action_data.unit_id) |unit_id| {
        var buffer: [20]u8 = undefined;
        const unit_id_str = std.fmt.bufPrint(&buffer, "{}", .{unit_id}) catch unreachable;
        if (dataset.json.object.get("objects")) |objects| {
            if (objects.object.get(unit_id_str)) |unit| {
                action.payload.unit = unit.string;
            }
        }
    }

    // Enrich command_id
    if (action_data.command_id) |command_id| {
        var buffer: [20]u8 = undefined;
        const command_id_str = std.fmt.bufPrint(&buffer, "{}", .{command_id}) catch unreachable;
        if (consts.object.get("commands")) |commands| {
            if (commands.object.get(command_id_str)) |command| {
                action.payload.command = command.string;
            }
        }
    }

    // Enrich order_id
    if (action_data.order_id) |order_id| {
        var buffer: [20]u8 = undefined;
        const order_id_str = std.fmt.bufPrint(&buffer, "{}", .{order_id}) catch unreachable;
        if (consts.object.get("orders")) |orders| {
            if (orders.object.get(order_id_str)) |order| {
                action.payload.order = order.string;
            }
        }
    }

    // Enrich resource_id
    if (action_data.resource_id) |resource_id| {
        var buffer: [20]u8 = undefined;
        const resource_id_str = std.fmt.bufPrint(&buffer, "{}", .{resource_id}) catch unreachable;
        if (consts.object.get("resources")) |resources| {
            if (resources.object.get(resource_id_str)) |resource| {
                action.payload.resource = resource.string;
            }
        }
    }
}

pub fn parseMatch() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    // Open the file
    const file = try std.fs.cwd().openFile("archers.aoe2record", .{});
    defer file.close();

    // Get file size
    const file_size = try file.getEndPos();

    // Allocate buffer to hold file contents
    const buffer_full = try allocator.alloc(u8, std.math.cast(usize, file_size) orelse return error.FileTooLarge);
    // defer allocator.free(buffer_full);

    // Read the file into the buffer
    _ = try file.readAll(buffer_full);

    var bufferReader = util.ByteReader.init(buffer_full);

    const data = parse(allocator, &bufferReader) catch @panic("failed to parse");
    _ = data.mod;
    const pos = bufferReader.get_position();
    _ = pos;
    const consts = reference.get_consts(allocator);
    const d = reference.get_dataset(allocator, data.version, data.mod);
    const dataset = d.json;
    // _ = consts;
    const map_id = get_map_id(data);
    //_ = map_id;
    const md = map.get_map_data(
        allocator,
        map_id,
        data.scenario.instructions,
        data.map.dimension,
        data.version,
        d.dataset_id,
        d.json,
        data.map.tiles,
        data.lobby.seed,
    );

    var rated: ?bool = null;
    var lobby: ?[]const u8 = null;
    var guid: ?[36]u8 = null;

    var de_players = std.AutoHashMap(i32, header.player_type).init(allocator);

    for (data.de.players) |p| {
        de_players.put(@as(i32, @intCast(p.number)), p) catch @panic("asd123ads");
    }
    lobby = data.de.lobby;
    guid = data.de.guid;
    rated = data.de.rated;

    var gaia = std.ArrayList(definitions.Object).init(allocator);

    for (data.players[0].objects) |obj| {
        var buffer: [20]u8 = undefined; // Enough space for u64 in decimal
        const result = try std.fmt.bufPrint(&buffer, "{}", .{obj.object_id});

        gaia.append(
            .{
                .name = if (d.json.object.get("objects")) |ob| (if (ob.object.get(result)) |s| s.string else null) else null,
                .class_id = obj.class_id,
                .object_id = obj.object_id,
                .instance_id = obj.instance_id,
                .index = obj.index,
                .position = .{ .x = obj.position.x, .y = obj.position.y },
            },
        ) catch @panic("asd123asdqsd");
    }

    var gaiaMap = std.AutoHashMap(i32, ?[]const u8).init(allocator);
    for (gaia.items) |g| {
        gaiaMap.put(@intCast(g.instance_id), g.name) catch @panic("asd123asd1a");
    }

    var inputsVariable = inputs.Inputs.init(allocator, gaiaMap);

    var playersMap = std.AutoHashMap(i32, definitions.Player).init(allocator);

    var alliesMap = std.AutoHashMap(i32, std.AutoHashMap(i32, void)).init(allocator);

    for (1..data.players.len) |playerIdx| {
        var player = data.players[playerIdx];
        var alliesSet = std.AutoHashMap(i32, void).init(allocator);
        alliesSet.put(player.number, {}) catch @panic("123asd12asd");
        alliesMap.put(player.number, alliesSet) catch @panic("123asd12asd");

        for (player.diplomacy, 0..) |stance, idx| {
            if (stance == 2) {
                var m = alliesMap.get(player.number).?;
                m.put(@as(i32, @intCast(idx)), {}) catch @panic("123asd124dsad");
            }
        }

        const de_playerOpt = de_players.get(player.number);

        if (de_playerOpt) |de_player| {
            player.update(de_player);
        } else {
            std.debug.print("de player does not exist at idx {}!\n\n", .{player.number});
        }

        var pos_x: ?f32 = null;
        var pos_y: ?f32 = null;

        for (player.objects) |obj| {
            if (std.mem.indexOfScalar(u64, &[_]u64{ 71, 109, 141, 142 }, obj.object_id)) |_| {
                pos_x = obj.position.x;
                pos_y = obj.position.y;
            }
        }

        var buffer1: [20]u8 = undefined; // Enough space for u64 in decimal
        const color_id_str = try std.fmt.bufPrint(&buffer1, "{}", .{player.color_id});

        var buffer2: [20]u8 = undefined;
        const civilization_id_string = try std.fmt.bufPrint(&buffer2, "{}", .{player.civilization_id});

        var objects = std.ArrayList(definitions.Object).init(allocator);

        for (player.objects) |obj| {
            var buffer3: [20]u8 = undefined;
            const object_id_string = try std.fmt.bufPrint(&buffer3, "{}", .{obj.object_id});

            var name: ?[]const u8 = null;
            if (dataset.object.get("objects")) |ob| {
                if (ob.object.get(object_id_string)) |ob2| {
                    name = ob2.string;
                }
            }

            objects.append(.{
                .name = name,
                .class_id = obj.class_id,
                .object_id = obj.object_id,
                .instance_id = obj.instance_id,
                .index = obj.index,
                .position = .{ .x = obj.position.x, .y = obj.position.y },
            }) catch @panic("123a21afsd");
        }

        const p: definitions.Player = .{
            .number = @as(usize, @intCast(player.number)),
            .name = player.name,
            .color = consts.object.get("player_colors").?.object.get(color_id_str).?.string,
            .color_id = @as(u32, @intCast(player.color_id)),
            .civilization = dataset.object.get("civilizations").?.object.get(civilization_id_string).?.object.get("name").?.string,
            .civilization_id = player.civilization_id,
            .position = if (pos_x) |x| if (pos_y) |y| .{ .x = x, .y = y } else null else null,
            .objects = objects.items,
            .profile_id = player.profile_id.?,
            .prefer_random = player.prefer_random.?,
            .team = null,
            .team_id = null,
            .winner = null,
            .eapm = null,
            .rate_snapshot = null,
            // left off on objects
        };

        playersMap.put(player.number, p) catch @panic("Asdasd2123");
    }

    // Assign teams.

    var team_ids = std.ArrayList(std.ArrayList(i32)).init(allocator);

    if (de_players.count() > 0) {
        var by_team = std.AutoHashMap(i32, std.ArrayList(i32)).init(allocator);

        var iter = de_players.iterator();
        while (iter.next()) |entry| {
            const player = entry.value_ptr.*;
            const number = entry.key_ptr.*;
            if (player.team_id > 1) {
                if (by_team.get(player.team_id) == null) {
                    by_team.put(player.team_id, std.ArrayList(i32).init(allocator)) catch @panic("asd123adcca");
                }
                var l = by_team.get(player.team_id).?;

                l.append(number) catch @panic("123asdc121s");
                by_team.put(player.team_id, l) catch @panic("asda123asd");
            } else if (player.team_id == 1) {
                if (by_team.get(number + 9) == null) {
                    by_team.put(number + 9, std.ArrayList(i32).init(allocator)) catch @panic("1eqsdxc123");
                }
                var l = by_team.get(number + 9).?;
                l.append(number) catch @panic("0a0ac;21");
                by_team.put(number + 9, l) catch @panic("asda123asd");
            }
        }

        var iter2 = by_team.iterator();
        while (iter2.next()) |entry| {
            team_ids.append(entry.value_ptr.*) catch @panic("asd1231sac");
        }
    } else {
        var iter = alliesMap.iterator();
        while (iter.next()) |entry| {
            _ = entry;
            @panic("not implemented");
            // team_ids.append(entry.value_ptr);
        }
    }

    // teams = []

    var teams = std.ArrayList(std.ArrayList(definitions.Player)).init(allocator);

    for (team_ids.items) |team| {
        var t = std.ArrayList(definitions.Player).init(allocator);
        for (team.items) |x| {
            t.append(playersMap.get(x).?) catch @panic("Asd213");
        }
        for (team.items) |x| {
            var p = playersMap.get(x).?;
            p.team = t.items;
            p.team_id = team.items;
        }
        teams.append(t) catch @panic("Asd21aas3");
    }

    const diplomacy_type = diplomacy.get_diplomacy_type(teams, playersMap);

    var pd = std.ArrayList(chatModule.PlayerMinimal).init(allocator);

    var it = playersMap.iterator();
    while (it.next()) |kv| {
        pd.append(.{ .name = kv.value_ptr.name, .number = kv.key_ptr.* }) catch @panic("1203asld");
    }

    for (data.lobby.chat) |c| {
        const chat = chatModule.parse_chat(allocator, c, md.encoding, 0, pd.items, diplomacy_type, "lobby");
        _ = chat;
        // TODO: Skipped some chat stuff.
    }

    fastInit.meta(&bufferReader);

    var timestamp: u32 = 0;
    var resigned = std.ArrayList(u32).init(allocator);
    var actions = std.ArrayList(definitions.Action).init(allocator);
    var last_viewlock: ?enums.viewlock_result = null;
    var viewlocks = std.ArrayList(definitions.Viewlock).init(allocator);
    var chats = std.ArrayList(definitions.Chat).init(allocator);
    var eapm = std.AutoHashMap(i32, u32).init(allocator);
    var postgame: ?enums.postgame_result = null;

    while (true) {
        if (bufferReader.get_position() >= bufferReader.buffer.len) {
            break;
        }
        const op = fastInit.operation(allocator, &bufferReader);
        switch (op) {
            .sync => |r| {
                timestamp += r.increment;
            },
            .viewlock => |r| {
                if (last_viewlock) |lv| {
                    if (lv.x == r.x and lv.y == r.y) {
                        continue;
                    }
                }
                const viewlock: definitions.Viewlock = .{
                    .timestampMs = timestamp,
                    .position = .{ .x = r.x, .y = r.y },
                    .player = playersMap.get(data.metadata.owner_id).?,
                };
                viewlocks.append(viewlock) catch @panic("123sd11213");
                last_viewlock = r;
            },
            .chat => |r| {
                const chat = chatModule.parse_chat(allocator, r, md.encoding, timestamp, pd.items, diplomacy_type, "game");

                if (chat.type == chatModule.Chat.Message) {
                    chats.append(.{
                        .timestampMs = chat.timestamp + data.map.restore_time,
                        .message = chat.message.?,
                        .origination = chat.origination.?,
                        .audience = chat.audience.?,
                        .player = playersMap.get(chat.player_number.?).?,
                    }) catch @panic("123asd");
                }
            },
            .action => |r| {
                const action_type = r.action_type;
                const action_data = r;

                //  _ = action_type;
                // _ = action_data;
                var a: definitions.Action = .{
                    .timestamp = timestamp,
                    .action = action_type,
                    .payload = action_data,
                    .player = null,
                    .position = null,
                };
                std.debug.print("\n\n{}\n\n", .{a.action});

                // Check for resign action and add to resigned list
                if (action_type == enums.ActionEnum.resign and action_data.player_id != null) {
                    const player_id = @as(i32, @intCast(action_data.player_id.?));
                    if (playersMap.get(player_id)) |player| {
                        resigned.append(@as(u32, @intCast(player.number))) catch @panic("resign_failed");
                    }
                }

                if (action_data.player_id) |pid| {
                    const player_id = @as(i32, @intCast(pid));
                    if (playersMap.get(player_id)) |player| {
                        if (action_type != enums.ActionEnum.ai_order) {
                            const current = eapm.get(player_id) orelse 0;
                            eapm.put(player_id, current + 1) catch @panic("eapm_failed");
                        }
                        a.player = player;
                        a.payload.player_id = null;
                    }
                }

                enrichAction(&a, d, consts);
                actions.append(a) catch @panic("asdia123asd");
                _ = inputsVariable.addAction(a) catch @panic("add_action_failed");
            },
            .postgame => |r| {
                postgame = r;

                // Update player ratings from postgame leaderboard data
                if (r.leaderboards) |lbs| {
                    if (lbs.len > 0) {
                        // Create a map from player number to rating from the first leaderboard
                        var by_number = std.AutoHashMap(i32, i32).init(allocator);
                        for (lbs[0].players) |pg_player| {
                            by_number.put(pg_player.number, pg_player.rating) catch @panic("by_number_failed");
                        }

                        // Update each player's rate_snapshot
                        var player_iter = playersMap.iterator();
                        while (player_iter.next()) |entry| {
                            const player_id = entry.key_ptr.*;
                            var player = entry.value_ptr.*;

                            // Player numbers in leaderboard are 0-indexed, but our player.number is 1-indexed
                            const lb_number = @as(i32, @intCast(player.number)) - 1;
                            if (by_number.get(lb_number)) |rating| {
                                player.rate_snapshot = @as(u32, @intCast(rating));
                                // Update the player in the map
                                playersMap.put(player_id, player) catch @panic("update_player_failed");
                            }
                        }
                    }
                }
            },
            .save => |r| {
                _ = r;
            },
            .start => |r| {
                _ = r;
            },
        }
    }

    // Print summary
    std.debug.print("\n\n=== Match Summary ===\n", .{});
    std.debug.print("Total actions: {}\n", .{actions.items.len});
    std.debug.print("Total inputs: {}\n", .{inputsVariable.inputs.items.len});
    std.debug.print("Viewlocks: {}\n", .{viewlocks.items.len});
    std.debug.print("Chats: {}\n", .{chats.items.len});
    std.debug.print("Players resigned: {}\n", .{resigned.items.len});

    if (postgame) |pg| {
        if (pg.world_time) |wt| {
            std.debug.print("Match duration (world time): {} ms\n", .{wt});
        }
        if (pg.leaderboards) |lbs| {
            std.debug.print("Leaderboards: {}\n", .{lbs.len});
            for (lbs) |lb| {
                std.debug.print("  Leaderboard ID {}: {} players\n", .{ lb.id, lb.players.len });
            }
        }
    } else {
        std.debug.print("No postgame data\n", .{});
    }

    std.debug.print("\n=== EAPM (Effective Actions Per Minute) ===\n", .{});
    var eapm_iter = eapm.iterator();
    while (eapm_iter.next()) |entry| {
        const player_id = entry.key_ptr.*;
        const action_count = entry.value_ptr.*;
        if (playersMap.get(player_id)) |player| {
            std.debug.print("Player {s} ({}): {} actions\n", .{ player.name, player_id, action_count });
        }
    }
}

const parse_type = struct {
    version: util.Version,
    game_version: *const [7]u8,
    save_version: f32,
    log_version: u32,
    players: []header.player_info_type,
    map: header.parse_map_result,
    de: header.parse_de_type,
    mod: []u32,
    metadata: header.parse_metadata_type,
    scenario: header.parse_scenario_type,
    lobby: header.parse_lobby_type,
    device: ?u8,
};

pub fn parse(allocator: std.mem.Allocator, bufferReader: *util.ByteReader) !parse_type {
    // Get the allocator

    var out2 = std.ArrayList(u8).init(allocator);
    // defer out2.deinit();

    var headerReader = header.decompress(&out2, bufferReader);

    const res = try header.parse_version(&headerReader, bufferReader);

    if (res.version != util.Version.DE) {
        std.debug.print("only DE supported.", .{});
        std.process.exit(1);
    }

    const de = header.parse_de(allocator, &headerReader, res.version, res.save, false);

    const parsed_meta = header.parse_metadata(&headerReader, res.save, false);
    const metadata = parsed_meta.metadata;
    const num_players = parsed_meta.num_players;

    const pm = header.parse_map(allocator, &headerReader, res.version, res.save);

    const el = header.parse_players(allocator, &headerReader, res.version, res.save, num_players);

    const s = header.parse_scenario(allocator, &headerReader, num_players, res.version, res.save);

    const lobby = header.parse_lobby(allocator, &headerReader, res.version, res.save);

    return .{
        .version = res.version,
        .game_version = res.game,
        .save_version = res.save,
        .log_version = res.log,
        .players = el.player_infos,
        .map = pm,
        .de = de,
        .mod = de.dlc_ids,
        .metadata = metadata,
        .scenario = s,
        .lobby = lobby,
        .device = el.device,
    };
}

pub fn get_map_id(data: parse_type) u32 {
    if (data.version == util.Version.HD) {
        @panic("HD not implemented");
    }
    if (data.version == util.Version.DE) {
        return data.de.rms_map_id;
    }
    return data.scenario.map_id;
}
