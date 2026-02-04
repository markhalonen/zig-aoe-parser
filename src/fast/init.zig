const util = @import("../util.zig");
const enums = @import("./enums.zig");
const std = @import("std");
const actions = @import("./actions.zig");

const MAX_PLAYERS = 8;
const SYNC_LEN_PER_PLAYER = 11;

fn sync(allocator: std.mem.Allocator, reader: *util.ByteReader) enums.sync_result {
    const increment = reader.read_int(u32);
    const marker = reader.read_int(u32);

    var checksum: ?u32 = null;

    var payload: enums.payload_type = .{ .current_time = null, .values = null };

    if (marker != 0) {
        reader.seek(-4, .Current);
        return .{ .increment = increment, .checksum = checksum, .payload = payload };
    }

    _ = reader.read_bytes(4);
    checksum = reader.read_int(u32);
    _ = reader.read_bytes(4);
    const is_de = reader.read_int(u32);
    if (is_de == 0) {
        _ = reader.read_bytes(8);
        return .{ .increment = increment, .checksum = checksum, .payload = payload };
    }

    reader.seek(-16, .Current);

    var values = std.ArrayList(u32).init(allocator);
    for (0..(MAX_PLAYERS * SYNC_LEN_PER_PLAYER)) |_| {
        values.append(reader.read_int(u32)) catch @panic("asd12sada");
    }

    var checksum2: u32 = 0;
    for (values.items) |v| {
        checksum2 += v;
    }

    const current_time = reader.read_int(u32);

    payload.current_time = current_time;
    var valuesMap = std.AutoHashMap(u32, enums.value_type).init(allocator);

    for (0..MAX_PLAYERS * SYNC_LEN_PER_PLAYER) |ptr| {
        if (ptr % SYNC_LEN_PER_PLAYER == 0) {
            const v = values.items[ptr + 1];
            if (v != 0) {
                // const k = std.fmt.allocPrint(allocator, "{}", values.items[ptr+8]);
                valuesMap.put(values.items[ptr + 8], .{
                    .total_res = values.items[ptr + 1],
                    .dp_obj_count = values.items[ptr + 3],
                    .dp_obj_ttl = values.items[ptr + 4],
                    .obj_count = values.items[ptr + 6],
                }) catch @panic("123asdac123");
            }
        }
    }

    payload.values = valuesMap;
    return .{
        .increment = increment,
        .checksum = checksum2,
        .payload = payload,
    };
}

fn viewlock(reader: *util.ByteReader) enums.viewlock_result {
    const x = reader.read_to_value(f32);
    const y = reader.read_to_value(f32);
    _ = reader.read_int(u32);
    return .{ .x = x, .y = y };
}

fn chat(reader: *util.ByteReader) []const u8 {
    _ = reader.read_int(u32);
    const length = reader.read_int(u32);
    const msg = reader.read_bytes(length);
    return msg;
}

fn reverseSliceAlloc(comptime T: type, allocator: std.mem.Allocator, slice: []const T) ![]T {
    var result = try allocator.alloc(T, slice.len);
    for (slice, 0..) |item, i| {
        result[slice.len - 1 - i] = item;
    }
    return result;
}

fn postgame(allocator: std.mem.Allocator, reader: *util.ByteReader) enums.postgame_result {
    std.debug.print("postgame is {}\n", .{reader.get_position()});
    const bytes = reader.read();
    var data = util.ByteReader.init(reverseSliceAlloc(u8, allocator, bytes) catch @panic("123123"));
    _ = data.read_bytes(8);
    _ = data.read_int_endian(u32, .big);
    const num_blocks = data.read_int_endian(u32, .big);
    var out: enums.postgame_result = .{ .world_time = null, .leaderboards = null };
    for (0..num_blocks) |_| {
        const identifier = data.read_int_endian(u32, .big);
        const length = data.read_int_endian(u32, .big);
        var block = util.ByteReader.init(reverseSliceAlloc(u8, allocator, data.read_bytes(length)) catch @panic("12312asd"));
        if (identifier == 1) {
            // World Time.
            out.world_time = block.read_int(u32);
        } else if (identifier == 2) {
            // Leaderboards

            const num_leaderboards = block.read_int(u32);

            var leaderboards = std.ArrayList(enums.postgame_leaderboard).init(allocator);

            for (0..num_leaderboards) |_| {
                const leaderboard_id = block.read_int(u32);
                _ = block.read_int(u16);

                const num_players = block.read_int(u32);
                var player_data = std.ArrayList(enums.postgame_player).init(allocator);

                for (0..num_players) |_| {
                    const player_num = block.read_int(i32);
                    const rank = block.read_int(i32);
                    const rating = block.read_int(i32);
                    player_data.append(.{
                        .number = player_num,
                        .rank = rank,
                        .rating = rating,
                    }) catch @panic("123asdzc");
                }

                leaderboards.append(.{ .id = leaderboard_id, .players = player_data.items }) catch @panic("12adq12");
            }

            out.leaderboards = leaderboards.items;
        }
    }
    return out;
}

pub fn meta(reader: *util.ByteReader) void {
    const first = reader.read_int(u32);
    if (first != 500) {
        _ = reader.read_bytes(4);
    }

    _ = reader.read_bytes(20);

    const a = reader.read_int(u32);
    const b = reader.read_int(u32);

    _ = reader.read_int(u32);

    if (a != 0) {
        reader.seek(-12, .Current);
    }

    if (b == 2) {
        reader.seek(-8, .Current);
    }
}

fn save(reader: *util.ByteReader) void {
    std.debug.print("at save and pos is {}\n\n", .{reader.get_position()});
    reader.seek(-4, .Current);
    const pos = reader.get_position();
    const length = reader.read_int(u32);
    _ = reader.read_int(u32);

    _ = reader.read_bytes(length - pos - 8);
}

fn parse_action(allocator: std.mem.Allocator, action_type: enums.ActionEnum, data: []const u8) actions.action_result {
    var reader = util.ByteReader.init(data);
    const player_id = reader.read_int(i8);
    const length = reader.read_int(i16);

    if (data.len == length + 3) {
        return actions.parse_action_71094(allocator, action_type, player_id, data[3..]);
    }
    @panic("only de supported");
}

fn concatSlices(allocator: std.mem.Allocator, slice1: []const u8, slice2: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, slice1.len + slice2.len);
    @memcpy(result[0..slice1.len], slice1);
    @memcpy(result[slice1.len..], slice2);
    return result;
}

fn action(allocator: std.mem.Allocator, reader: *util.ByteReader, sequenceInput: ?u32) actions.action_result {
    const length = reader.read_int(u32);

    const action_id = reader.read_int(u8);

    const action_bytes = reader.read_bytes(length - 1);

    var sequence = sequenceInput;
    if (sequenceInput) |_| {} else {
        sequence = reader.read_int(u32);
    }

    const action_type = std.meta.intToEnum(enums.ActionEnum, action_id) catch @panic("asd23123");
    var payload: actions.action_result = .{
        .bytes = null,
        .sequence = null,
        .player_id = null,
        .object_ids = null,
        .command_id = null,
        .target_player_id = null,
        .diplomacy_mode = null,
        .speed = null,
        .number = null,
        .amount = null,
        .unit_id = null,
        .x = null,
        .y = null,
        .building_id = null,
        .target_id = null,
        .target_type = null,
        .stance_id = null,
        .order_id = null,
        .slot_id = null,
        .formation_id = null,
        .resource_id = null,
        .x_end = null,
        .y_end = null,
        .targets = null,
        .mode = null,
        .wood = null,
        .food = null,
        .gold = null,
        .stone = null,
        .technology_id = null,
        .action_type = action_type,
        .technology = null,
        .formation = null,
        .stance = null,
        .building = null,
        .unit = null,
        .command = null,
        .order = null,
        .resource = null,
    };

    if (action_type == enums.ActionEnum.postgame) {
        payload.bytes = concatSlices(allocator, action_bytes, reader.read()) catch @panic("123qasd");
    } else {
        // Parse action here...
        payload = parse_action(allocator, action_type, action_bytes);
    }
    payload.sequence = sequence;
    return payload;
}

pub fn operation(allocator: std.mem.Allocator, reader: *util.ByteReader) enums.Operation {
    const op_id = reader.read_int(u32);
    const op_type = std.meta.intToEnum(enums.OperationTag, op_id) catch {
        _ = save(reader);
        return .{ .save = {} };
    };

    if (op_type == enums.Operation.action) {
        return .{
            .action = action(allocator, reader, null),
        };
    }
    if (op_type == enums.Operation.sync) {
        return .{
            .sync = sync(allocator, reader),
        };
    }
    if (op_type == enums.Operation.viewlock) {
        return .{ .viewlock = viewlock(reader) };
    }
    if (op_type == enums.Operation.chat) {
        return .{ .chat = chat(reader) };
    }
    if (op_type == enums.Operation.postgame) {
        return .{ .postgame = postgame(allocator, reader) };
    }
    @panic("not implemented");
    // return .{ .operation = enums.Operation.action, .op_data = null };
}
