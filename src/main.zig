//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    // @cInclude("zlib.h");
});

const util = @import("util.zig");
const header = @import("header.zig");
const std = @import("std");
const reference = @import("reference.zig");
const map = @import("map.zig");
const aoe_consts = @import("aoe_consts.zig");
const definitions = @import("definitions.zig");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("zig14_basic_lib");

pub fn main() !void {
    try aoe_consts.initMaps();
    try parseMatch();
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
    _ = consts;
    const d = reference.get_dataset(allocator, data.version, data.mod);
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
    _ = md;

    const rated: ?bool = null;
    const lobby: ?[]const u8 = null;
    const guid: ?[36]u8 = null;
    const rated: ?bool = null;

    const de_players = std.AutoHashMap(i32, header.player_type).init(allocator);

    if (data.de) {
        for (data.de.players) |p| {
            de_players.put(p.number, p);
        }
        lobby = data.de.lobby;
        guid = data.de.guid;
        rated = data.de.rated;
    }

    const gaia = std.ArrayList(definitions.Object).init(allocator);

    for (data.players[0].objects) |obj| {
        gaia.append(.{
            .name = d.json.object.get("objects").?.object.get(obj.object_id).?.string,
        });
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
