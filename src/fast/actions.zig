const enums = @import("./enums.zig");
const util = @import("../util.zig");
const std = @import("std");

pub const action_result = struct {
    bytes: ?[]const u8,
    sequence: ?u32,
    player_id: ?i8,
    technology_id: ?i16,
    object_ids: ?[]u32,
    command_id: ?i16,
    target_player_id: ?i16,
    diplomacy_mode: ?i8,
    speed: ?f32,
    number: ?i16,
    amount: ?i16,
    unit_id: ?i16,
    x: ?f32,
    y: ?f32,
    building_id: ?u32,
    target_id: ?i32,
    target_type: ?i32,
    stance_id: ?u32,
    order_id: ?i16,
    slot_id: ?i16,
    formation_id: ?u32,
    resource_id: ?i16,
    x_end: ?u16,
    y_end: ?u16,
    targets: ?[]i8,
    mode: ?i8,
    wood: ?f32,
    food: ?f32,
    gold: ?f32,
    stone: ?f32,
    action_type: enums.ActionEnum,
    // Enrichment fields
    technology: ?[]const u8,
    formation: ?[]const u8,
    stance: ?[]const u8,
    building: ?[]const u8,
    unit: ?[]const u8,
    command: ?[]const u8,
    order: ?[]const u8,
    resource: ?[]const u8,
};

pub fn parse_action_71094(
    allocator: std.mem.Allocator,
    action_type: enums.ActionEnum,
    player_id: i8,
    data: []const u8,
) action_result {
    var reader = util.ByteReader.init(data);
    var payload: action_result = .{
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

    if (action_type == enums.ActionEnum.resign) {
        _ = reader.read_bytes(1);
    }

    var object_ids = std.ArrayList(u32).init(allocator);

    if (action_type == enums.ActionEnum.research) {
        const object_id = reader.read_int(u32);
        const selected = reader.read_int(i16);
        const technology_id = reader.read_int(i16);
        _ = reader.read_bytes(5);
        for (0..@as(usize, @intCast(selected))) |_| {
            _ = reader.read_bytes(4);
        }
        payload.technology_id = technology_id;
        object_ids.append(object_id) catch @panic("haoi12323");
        payload.object_ids = object_ids.items;
    }

    if (action_type == enums.ActionEnum.game) {
        const command_id = reader.read_int(i16);
        payload.command_id = command_id;
        if (command_id == 0) {
            _ = reader.read_bytes(2);
            const source_player = reader.read_int(i16);
            _ = source_player;
            const target_player = reader.read_int(i16);
            const mode_float = std.mem.bytesToValue(f32, reader.read_bytes(4));
            _ = mode_float;
            const mode = reader.read_int(i8);

            payload.target_player_id = target_player;
            payload.diplomacy_mode = mode;
        } else if (command_id == 1) {
            _ = reader.read_bytes(6);
            payload.speed = std.mem.bytesToValue(f32, reader.read_bytes(4));
        } else if (command_id == 13 or command_id == 14 or command_id == 17 or command_id == 18) {
            _ = reader.read_bytes(4);
            payload.number = reader.read_int(i16);
        }
    }

    if (action_type == enums.ActionEnum.de_queue) {
        const selected = reader.read_int(i16);
        _ = reader.read_bytes(4);
        _ = reader.read_int(i16); // building_type - not used in output
        const unit_id = reader.read_int(i16);
        const amount = reader.read_int(i16);
        for (0..@as(usize, @intCast(selected))) |_| {
            object_ids.append(reader.read_int(u32)) catch @panic("13qdsq2eqsd");
        }

        payload.object_ids = object_ids.items;
        payload.amount = amount;
        payload.unit_id = unit_id;
    }

    if (action_type == enums.ActionEnum.move) {
        _ = reader.read_bytes(4);
        const x = reader.read_to_value(f32);
        const y = reader.read_to_value(f32);
        const selected = reader.read_int(i16);
        object_ids.clearRetainingCapacity();
        _ = reader.read_bytes(4);

        if (selected > 0) {
            for (0..@as(usize, @intCast(selected))) |_| {
                object_ids.append(reader.read_int(u32)) catch @panic("123asd12asd");
            }
        }

        payload.object_ids = object_ids.items;
        payload.x = x;
        payload.y = y;
    }

    if (action_type == enums.ActionEnum.order) {
        const target_id = reader.read_int(u32);
        const x = reader.read_to_value(f32);
        const y = reader.read_to_value(f32);
        const selected = reader.read_int(i16);
        _ = reader.read_bytes(4);
        if (selected > 0) {
            for (0..@as(usize, @intCast(selected))) |_| {
                object_ids.append(reader.read_int(u32)) catch @panic("order_failed");
            }
        }
        payload.object_ids = object_ids.items;
        payload.target_id = @as(i32, @intCast(target_id));
        payload.x = x;
        payload.y = y;
    }

    if (action_type == enums.ActionEnum.build) {
        const selected = reader.read_int(i16);
        _ = reader.read_bytes(2); // padding
        const x = reader.read_to_value(f32);
        const y = reader.read_to_value(f32);
        const building_id = reader.read_int(i32);
        _ = reader.read_bytes(8);
        const unk2 = reader.read_int(i16);
        _ = unk2;
        const unk3 = reader.read_int(i8);
        _ = unk3;
        const unk4 = reader.read_int(i8);
        _ = unk4;
        for (0..@as(usize, @intCast(selected))) |_| {
            object_ids.append(reader.read_int(u32)) catch @panic("build_failed");
        }
        payload.building_id = @as(u32, @intCast(building_id));
        payload.object_ids = object_ids.items;
        payload.x = x;
        payload.y = y;
    }

    if (action_type == enums.ActionEnum.gather_point) {
        const selected = reader.read_int(i16);
        _ = reader.read_bytes(2);
        const x = reader.read_to_value(f32);
        const y = reader.read_to_value(f32);
        const target_id = reader.read_int(i32);
        const target_type = reader.read_int(i32);
        for (0..@as(usize, @intCast(selected))) |_| {
            object_ids.append(reader.read_int(u32)) catch @panic("gather_point_failed");
        }
        payload.target_id = @as(i32, @intCast(target_id));
        payload.target_type = target_type;
        payload.x = x;
        payload.y = y;
        payload.object_ids = object_ids.items;
    }

    if (action_type == enums.ActionEnum.de_multi_gatherpoint) {
        const target_id = reader.read_int(u32);
        const x = reader.read_to_value(f32);
        const y = reader.read_to_value(f32);
        payload.target_id = @as(i32, @intCast(target_id));
        payload.x = x;
        payload.y = y;
    }

    if (action_type == enums.ActionEnum.stance) {
        const selected = reader.read_int(u32);
        const stance_id = reader.read_int(u32);
        for (0..selected) |_| {
            object_ids.append(reader.read_int(u32)) catch @panic("stance_failed");
        }
        payload.stance_id = stance_id;
        payload.object_ids = object_ids.items;
    }

    if (action_type == enums.ActionEnum.special) {
        const selected = reader.read_int(u32);
        const target_id = reader.read_int(i32);
        const x = reader.read_to_value(f32);
        const y = reader.read_to_value(f32);
        _ = reader.read_bytes(4);
        const slot_id = reader.read_int(i16);
        _ = reader.read_bytes(2);
        const order_id = reader.read_int(i16);
        _ = reader.read_bytes(2);
        for (0..selected) |_| {
            object_ids.append(reader.read_int(u32)) catch @panic("special_failed");
        }
        payload.order_id = order_id;
        payload.slot_id = slot_id;
        payload.target_id = @as(i32, @intCast(target_id));
        payload.x = x;
        payload.y = y;
        payload.object_ids = object_ids.items;
    }

    if (action_type == enums.ActionEnum.formation) {
        const selected = reader.read_int(u32);
        const formation_id = reader.read_int(u32);
        for (0..selected) |_| {
            object_ids.append(reader.read_int(u32)) catch @panic("formation_failed");
        }
        payload.formation_id = formation_id;
        payload.object_ids = object_ids.items;
    }

    if (action_type == enums.ActionEnum.buy or action_type == enums.ActionEnum.sell) {
        const resource_id = reader.read_int(i16);
        const amount = reader.read_int(i16);
        const object_id = reader.read_int(u32);
        object_ids.append(object_id) catch @panic("buy_sell_failed");
        payload.resource_id = resource_id;
        payload.amount = amount;
        payload.object_ids = object_ids.items;
    }

    if (action_type == enums.ActionEnum.de_transform) {
        const object_id = reader.read_int(u32);
        const y = reader.read_int(u32);
        _ = y;
        object_ids.append(object_id) catch @panic("de_transform_failed");
        payload.object_ids = object_ids.items;
    }

    if (action_type == enums.ActionEnum.ai_order) {
        const a = reader.read_int(u32);
        _ = a;
        const object_id = reader.read_int(u32);
        _ = reader.read_bytes(4);
        const x = reader.read_to_value(f32);
        const y = reader.read_to_value(f32);
        object_ids.append(object_id) catch @panic("ai_order_failed");
        payload.object_ids = object_ids.items;
        payload.x = x;
        payload.y = y;
    }

    if (action_type == enums.ActionEnum.back_to_work or action_type == enums.ActionEnum.delete) {
        const object_id = reader.read_int(u32);
        object_ids.append(object_id) catch @panic("back_to_work_delete_failed");
        payload.object_ids = object_ids.items;
    }

    if (action_type == enums.ActionEnum.wall) {
        const selected = reader.read_int(u32);
        const x1 = reader.read_int(u16);
        const y1 = reader.read_int(u16);
        const x2 = reader.read_int(u16);
        const y2 = reader.read_int(u16);
        const building_id = reader.read_int(u32);
        _ = reader.read_bytes(8);
        for (0..selected) |_| {
            object_ids.append(reader.read_int(u32)) catch @panic("wall_failed");
        }
        payload.object_ids = object_ids.items;
        payload.x = @as(f32, @floatFromInt(x1));
        payload.y = @as(f32, @floatFromInt(y1));
        payload.x_end = x2;
        payload.y_end = y2;
        payload.building_id = building_id;
    }

    if (action_type == enums.ActionEnum.patrol or action_type == enums.ActionEnum.de_attack_move) {
        const selected = reader.read_int(u32);
        _ = reader.read_bytes(4);
        const x = reader.read_to_value(f32);
        _ = reader.read_bytes(36);
        const y = reader.read_to_value(f32);
        _ = reader.read_bytes(36);
        for (0..selected) |_| {
            object_ids.append(reader.read_int(u32)) catch @panic("patrol_attack_move_failed");
        }
        payload.object_ids = object_ids.items;
        payload.x = x;
        payload.y = y;
    }

    if (action_type == enums.ActionEnum.ungarrison) {
        const selected = reader.read_int(u32);
        const x = reader.read_to_value(f32);
        const y = reader.read_to_value(f32);
        const target_id = reader.read_int(i32);
        const unk = reader.read_int(u32);
        _ = unk;
        for (0..selected) |_| {
            object_ids.append(reader.read_int(u32)) catch @panic("ungarrison_failed");
        }
        payload.object_ids = object_ids.items;
        payload.x = x;
        payload.y = y;
        payload.target_id = @as(i32, @intCast(target_id));
    }

    if (action_type == enums.ActionEnum.flare) {
        _ = reader.read_bytes(4);
        const x = reader.read_to_value(f32);
        const y = reader.read_to_value(f32);
        const num = reader.read_int(i8);
        var targets = std.ArrayList(i8).init(allocator);
        defer targets.deinit();
        for (0..@as(usize, @intCast(num))) |_| {
            targets.append(reader.read_int(i8)) catch @panic("flare_failed");
        }
        payload.x = x;
        payload.y = y;
        payload.targets = targets.items;
    }

    if (action_type == enums.ActionEnum.town_bell) {
        const building_id = reader.read_int(u32);
        const mode = reader.read_int(i8);
        payload.building_id = building_id;
        payload.mode = mode;
    }

    if (action_type == enums.ActionEnum.stop) {
        const selected = reader.read_int(u32);
        for (0..selected) |_| {
            object_ids.append(reader.read_int(u32)) catch @panic("stop_failed");
        }
        payload.object_ids = object_ids.items;
    }

    if (action_type == enums.ActionEnum.follow or action_type == enums.ActionEnum.guard) {
        const selected = reader.read_int(u32);
        const target_id = reader.read_int(u32);
        for (0..selected) |_| {
            object_ids.append(reader.read_int(u32)) catch @panic("follow_guard_failed");
        }
        payload.object_ids = object_ids.items;
        payload.target_id = @as(i32, @intCast(target_id));
    }

    if (action_type == enums.ActionEnum.attack_ground) {
        const selected = reader.read_int(u32);
        const x = reader.read_to_value(f32);
        const y = reader.read_to_value(f32);
        _ = reader.read_bytes(4);
        for (0..selected) |_| {
            object_ids.append(reader.read_int(u32)) catch @panic("attack_ground_failed");
        }
        payload.object_ids = object_ids.items;
        payload.x = x;
        payload.y = y;
    }

    if (action_type == enums.ActionEnum.repair) {
        const selected = reader.read_int(u32);
        const target_id = reader.read_int(u32);
        _ = reader.read_bytes(4);
        for (0..selected) |_| {
            object_ids.append(reader.read_int(u32)) catch @panic("repair_failed");
        }
        payload.object_ids = object_ids.items;
        payload.target_id = @as(i32, @intCast(target_id));
    }

    if (action_type == enums.ActionEnum.de_tribute) {
        const wood = reader.read_to_value(f32);
        const food = reader.read_to_value(f32);
        const gold = reader.read_to_value(f32);
        const stone = reader.read_to_value(f32);
        _ = reader.read_bytes(16); // cost[4]
        _ = reader.read_bytes(8); // attribute id[4]
        const target_id = reader.read_int(u8);
        payload.target_player_id = @as(i16, @intCast(target_id));
        payload.food = food;
        payload.wood = wood;
        payload.stone = stone;
        payload.gold = gold;
    }

    if (action_type == enums.ActionEnum.gate or action_type == enums.ActionEnum.drop_relic) {
        const object_id = reader.read_int(u32);
        object_ids.append(object_id) catch @panic("gate_drop_relic_failed");
        payload.object_ids = object_ids.items;
    }

    if (action_type == enums.ActionEnum.de_autoscout or action_type == enums.ActionEnum.ratha_ability) {
        const selected = reader.read_int(u32);
        for (0..selected) |_| {
            object_ids.append(reader.read_int(u32)) catch @panic("autoscout_ratha_failed");
        }
        payload.object_ids = object_ids.items;
    }

    if (action_type == enums.ActionEnum.make) {
        const building_id = reader.read_int(u16);
        _ = reader.read_bytes(6);
        const unit_id = reader.read_int(i16);
        payload.building_id = @as(u32, @intCast(building_id));
        payload.unit_id = unit_id;
    }

    payload.player_id = player_id;
    return payload;
    // return action_result{
    //     .bytes = null,
    //     .sequence = null,
    //     .player_id = player_id,
    //     .object_ids = object_ids.items,
    //     .technology_id = payload.technology_id,
    //     .command_id = payload.command_id,
    //     .target_player_id = payload.target_player_id,
    //     .diplomacy_mode = payload.diplomacy_mode,
    //     .speed = payload.speed,
    //     .number = payload.number,
    //     .amount = payload.amount,
    //     .unit_id = payload.unit_id,
    //     .x = payload.x,
    //     .y = payload.y,
    //     .building_id = payload.building_id,
    //     .target_id = payload.target_id,
    //     .target_type = payload.target_type,
    //     .stance_id = payload.stance_id,
    //     .order_id = payload.order_id,
    //     .slot_id = payload.slot_id,
    //     .formation_id = payload.formation_id,
    //     .resource_id = payload.resource_id,
    //     .x_end = payload.x_end,
    //     .y_end = payload.y_end,
    //     .targets = payload.targets,
    //     .mode = payload.mode,
    //     .wood = payload.wood,
    //     .food = payload.food,
    //     .gold = payload.gold,
    //     .stone = payload.stone,
    // };
}
