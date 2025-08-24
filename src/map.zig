const std = @import("std");
const util = @import("util.zig");
const mvzr = @import("mvzr");
const header = @import("header.zig");
const aoe_consts = @import("aoe_consts.zig");

const EncodingMarker = struct {
    marker: []const u8,
    encoding: []const u8,
    lang: ?[]const u8,
};

const ENCODING_MARKERS = [_]EncodingMarker{
    .{ .marker = "Map Type: ", .encoding = "latin-1", .lang = "en" },
    .{ .marker = "Map type: ", .encoding = "latin-1", .lang = "en" },
    .{ .marker = "Location: ", .encoding = "utf-8", .lang = "en" },
    .{ .marker = "Tipo de mapa: ", .encoding = "latin-1", .lang = "es" },
    .{ .marker = "Ubicación: ", .encoding = "utf-8", .lang = "es" },
    .{ .marker = "Ubicaci: ", .encoding = "utf-8", .lang = "es" },
    .{ .marker = "Local: ", .encoding = "utf-8", .lang = "es" },
    .{ .marker = "Kartentyp: ", .encoding = "latin-1", .lang = "de" },
    .{ .marker = "Karte: ", .encoding = "utf-8", .lang = "de" },
    .{ .marker = "Art der Karte: ", .encoding = "latin-1", .lang = "de" },
    .{ .marker = "Type de carte\xa0: ", .encoding = "latin-1", .lang = "fr" },
    .{ .marker = "Emplacement : ", .encoding = "utf-8", .lang = "fr" },
    .{ .marker = "Type de carte : ", .encoding = "latin-1", .lang = "fr" },
    .{ .marker = "Tipo di mappa: ", .encoding = "latin-1", .lang = "it" },
    .{ .marker = "Posizione: ", .encoding = "utf-8", .lang = "it" },
    .{ .marker = "Tipo de Mapa: ", .encoding = "latin-1", .lang = "pt" },
    .{ .marker = "Kaarttype", .encoding = "latin-1", .lang = "nl" },
    .{ .marker = "Lokalizacja: ", .encoding = "utf-8", .lang = "pl" },
    .{ .marker = "Harita Türü: ", .encoding = "ISO-8859-1", .lang = "tr" },
    .{ .marker = "Harita Sitili", .encoding = "ISO-8859-1", .lang = "tr" },
    .{ .marker = "Harita tipi", .encoding = "ISO-8859-1", .lang = "tr" },
    .{ .marker = "Konum: ", .encoding = "ISO-8859-1", .lang = "tr" },
    .{ .marker = "??? ?????: ", .encoding = "ascii", .lang = "tr" },
    .{ .marker = "Térkép tipusa", .encoding = "ISO-8859-1", .lang = "hu" },
    .{ .marker = "Typ mapy: ", .encoding = "ISO-8859-2", .lang = null },
    .{ .marker = "Тип карты: ", .encoding = "windows-1251", .lang = "ru" },
    .{ .marker = "Тип Карты: ", .encoding = "windows-1251", .lang = "ru" },
    .{ .marker = "Расположение: ", .encoding = "utf-8", .lang = "ru" },
    .{ .marker = "マップの種類: ", .encoding = "SHIFT_JIS", .lang = "jp" },
    .{ .marker = "マップ ", .encoding = "utf-8", .lang = "jp" },
    .{ .marker = "지도 종류: ", .encoding = "cp949", .lang = "kr" },
    .{ .marker = "地??型", .encoding = "big5", .lang = "zh" },
    .{ .marker = "地图类型: ", .encoding = "cp936", .lang = "zh" },
    .{ .marker = "地圖類別：", .encoding = "cp936", .lang = "zh" },
    .{ .marker = "地圖類別：", .encoding = "big5", .lang = "zh" },
    .{ .marker = "地图类别：", .encoding = "cp936", .lang = "zh" },
    .{ .marker = "地图类型：", .encoding = "GB2312", .lang = "zh" },
    .{ .marker = "颌玉拙墁：", .encoding = "cp936", .lang = "zh" },
    .{ .marker = "位置：", .encoding = "utf-8", .lang = "zh" },
    .{ .marker = "舞台: ", .encoding = "utf-8", .lang = "zh" },
    .{ .marker = "Vị trí: ", .encoding = "utf-8", .lang = "vi" },
    .{ .marker = "위치: ", .encoding = "utf-8", .lang = "kr" },
    .{ .marker = "Τύπος Χάρτη: ", .encoding = "utf-8", .lang = "gr" },
    .{ .marker = "Emplacement: ", .encoding = "utf-8", .lang = "fr" },
    .{ .marker = "Local: ", .encoding = "utf-8", .lang = "pt" },
    .{ .marker = "Mapa: ", .encoding = "utf-8", .lang = "cs" },
    .{ .marker = "Plats: ", .encoding = "utf-8", .lang = "se" },
};

pub fn extract_from_instructions(instructions: []const u8) struct {
    encoding: []const u8,
    language: []const u8,
    name: []const u8,
} {
    const language: ?[]const u8 = "en";
    const encoding: []const u8 = "utf-8";
    var name: []const u8 = "Unknown";

    // Create a split iterator
    var iter = std.mem.splitAny(u8, instructions, "\n");
    const e_m = "Location: ";
    // Iterate over the split substrings

    while (iter.next()) |line| {
        if (std.mem.eql(u8, line[0..e_m.len], e_m)) {
            const pos = 0;
            name = line[pos + e_m.len ..];
            if (std.mem.eql(u8, name[name.len - 4 .. name.len], ".rms")) {
                name = name[0 .. name.len - 4];
            }
        }
    }
    return .{ .encoding = encoding, .language = language.?, .name = name };
}

pub const get_map_data_type = struct {
    id: ?u32,
    name: []const u8,
    size: ?[]const u8,
    dimension: u32,
    seed: ?i32,
    mod_id: ?u32,
    modes: modes_type,
    custom: bool,
    zr: bool,
    tiles: []tile_type,
    water: ?f32,
};

pub fn get_map_data(
    allocator: std.mem.Allocator,
    map_id: u32,
    instructions: []const u8,
    dimension: u32,
    version: util.Version,
    dataset_id: u32,
    reference: std.json.Value,
    tiles: []struct { i8, i8 },
    de_seed: ?i32,
) get_map_data_type {
    const ef = extract_from_instructions(instructions);
    const name = ef.name;
    const ln = lookup_name(map_id, name, version, reference);
    const custom = ln.custom;
    const seed = get_map_seed(instructions);
    const m = get_modes(ln.name);
    const modes = m.modes;

    const tiles2 = get_tiles(allocator, tiles, dimension);

    const water_percent = get_water_percent(tiles, dataset_id);

    return .{
        .id = if (!custom) map_id else null,
        .name = header.strip(allocator, name, ' '),
        .size = aoe_consts.MAP_SIZES.get(dimension),
        .dimension = dimension,
        .seed = if (de_seed) |s| s else seed,
        .mod_id = null,
        .modes = modes,
        .custom = custom,
        .zr = std.mem.eql(u8, name[0..3], "ZR@"),
        .tiles = tiles2,
        .water = water_percent,
    };
}

fn get_water_percent(tiles: []struct { i8, i8 }, dataset_id: u32) ?f32 {
    var count: u32 = 0;
    const terrainOpt = aoe_consts.WATER_TERRAIN.get(dataset_id);
    if (terrainOpt) |terrain| {
        for (tiles) |tile| {
            if (std.mem.indexOf(i8, terrain, &[_]i8{tile[0]})) |_| {
                count += 1;
            }
        }
        const res: f32 = @as(f32, @floatFromInt(count)) / @as(f32, @floatFromInt(tiles.len));
        return res;
    }
    return null;
}

const tile_type = struct {
    x: u32,
    y: u32,
    terrain_id: i8,
    elevation: i8,
};

fn get_tiles(allocator: std.mem.Allocator, tiles: []struct { i8, i8 }, dimension: u32) []tile_type {
    var res = std.ArrayList(tile_type).init(allocator);
    var tile_x: u32 = 0;
    var tile_y: u32 = 0;

    for (tiles) |tile| {
        if (tile_x == dimension) {
            tile_x = 0;
            tile_y += 1;
        }
        res.append(.{ .x = tile_x, .y = tile_y, .terrain_id = tile[0], .elevation = tile[1] }) catch @panic("naosdau aisd");
        tile_x += 1;
    }
    return res.items;
}

pub fn lookup_name(map_id: u32, nameInput: []const u8, version: util.Version, reference: std.json.Value) struct {
    name: []const u8,
    custom: bool,
} {
    var custom = true;
    const is_de = version == util.Version.DE;
    const is_hd = version == util.Version.HD;
    var name: []const u8 = nameInput;

    if ((map_id != 44 and !(is_de or is_hd)) or ((map_id != 59 and map_id != 137 and map_id != 138)) and (is_de or is_hd)) {
        const keys_strings = reference.object.get("maps").?.object.keys();
        // const map_keys: [keys_strings.len]u32 = [_]u32{0} ** keys_strings.len;
        // const map_keys = std.ArrayList(u32).initCapacity(allocator, keys_strings.len);
        for (keys_strings) |k| {
            const int_val = std.fmt.parseInt(u32, k, 10) catch @panic("asdasdasda asd");
            // map_keys[idx] = int_val;

            if (map_id == int_val) {
                name = reference.object.get("maps").?.object.get(k).?.string;
            }

            if (name.len == 0 and version == util.Version.AOK) {
                return .{ .name = name, .custom = false };
            }
        }
        custom = false;
    }

    return .{ .name = name, .custom = custom };
}

pub fn get_map_seed(instructions: []const u8) ?i32 {
    // TODO my regex lib doesn't support capture groups.
    _ = instructions;
    return null;
}

const modes_type = struct {
    direct_placement: bool,
    effect_quantity: bool,
    guard_state: bool,
    fixed_positions: bool,
};

pub fn get_modes(nameInput: []const u8) struct { name: []const u8, modes: modes_type } {
    const has_modesOpt = std.mem.indexOf(u8, nameInput, ": !");
    var mode_string: []const u8 = "";
    var name: []const u8 = nameInput;
    if (has_modesOpt) |has_modes| {
        mode_string = name[has_modes + 3 ..];
        name = nameInput[0..has_modes];
    }

    return .{
        .name = name,
        .modes = .{
            .direct_placement = std.mem.containsAtLeast(u8, mode_string, 1, "P"),
            .effect_quantity = std.mem.containsAtLeast(u8, mode_string, 1, "C"),
            .guard_state = std.mem.containsAtLeast(u8, mode_string, 1, "G"),
            .fixed_positions = std.mem.containsAtLeast(u8, mode_string, 1, "F"),
        },
    };
}
