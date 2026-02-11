const std = @import("std");
const definitions = @import("definitions.zig");
const enums = @import("fast/enums.zig");
const actions = @import("fast/actions.zig");
const chatModule = @import("chat.zig");

// Helper to hash a position
fn hashPosition(pos: definitions.Position) u64 {
    var hasher = std.hash.Wyhash.init(0);
    const x_bytes = std.mem.asBytes(&pos.x);
    const y_bytes = std.mem.asBytes(&pos.y);
    hasher.update(x_bytes);
    hasher.update(y_bytes);
    return hasher.final();
}

// Helper to convert enum name to title case
fn enumToTitleCase(allocator: std.mem.Allocator, action_type: enums.ActionEnum) ![]const u8 {
    const name = @tagName(action_type);
    var result = std.ArrayList(u8).init(allocator);
    var capitalize_next = true;

    for (name) |c| {
        if (c == '_') {
            try result.append(' ');
            capitalize_next = true;
        } else if (capitalize_next) {
            try result.append(std.ascii.toUpper(c));
            capitalize_next = false;
        } else {
            try result.append(std.ascii.toLower(c));
        }
    }

    return result.toOwnedSlice();
}

pub const Inputs = struct {
    allocator: std.mem.Allocator,
    gaia: std.AutoHashMap(i32, ?[]const u8),
    buildings: std.AutoHashMap(u64, []const u8),
    oid_cache: std.AutoHashMap(enums.ActionEnum, []u32),
    inputs: std.ArrayList(definitions.Input),

    pub fn init(allocator: std.mem.Allocator, gaia: std.AutoHashMap(i32, ?[]const u8)) Inputs {
        return .{
            .allocator = allocator,
            .gaia = gaia,
            .buildings = std.AutoHashMap(u64, []const u8).init(allocator),
            .oid_cache = std.AutoHashMap(enums.ActionEnum, []u32).init(allocator),
            .inputs = std.ArrayList(definitions.Input).init(allocator),
        };
    }

    pub fn addChat(self: *Inputs, chat: definitions.Chat) !void {
        const input = definitions.Input{
            .timestamp = chat.timestampMs,
            .input_type = "Chat",
            .param = null,
            .chat_message = chat.message,
            .player = chat.player,
            .position = null,
        };
        try self.inputs.append(input);
    }

    pub fn addAction(self: *Inputs, action: definitions.Action) !?definitions.Input {
        // Skip certain action types
        if (action.action == enums.ActionEnum.de_transform or action.action == enums.ActionEnum.postgame) {
            return null;
        }

        var name: ?[]const u8 = undefined;
        var param: ?[]const u8 = null;
        var payload = action.payload;

        // Translate action name
        if (action.action == enums.ActionEnum.de_queue) {
            name = "Queue";
        } else if (action.action == enums.ActionEnum.de_attack_move) {
            name = "Attack Move";
        } else {
            name = try enumToTitleCase(self.allocator, action.action);
        }

        // Cache object_ids if present
        if (payload.object_ids) |oids| {
            if (oids.len > 0) {
                try self.oid_cache.put(action.action, oids);
            }
        } else if (self.oid_cache.get(action.action)) |cached_oids| {
            payload.object_ids = cached_oids;
        }

        // Handle special cases - match Python where name can become None
        if (action.action == enums.ActionEnum.special) {
            name = payload.order;
        } else if (action.action == enums.ActionEnum.game) {
            name = payload.command;
            if (payload.command) |command| {
                if (std.mem.eql(u8, command, "Speed")) {
                    if (payload.speed) |speed| {
                        var buf: [32]u8 = undefined;
                        param = try std.fmt.bufPrint(&buf, "{d}", .{speed});
                    }
                }
            }
        } else if (action.action == enums.ActionEnum.stance) {
            name = "Stance";
            param = payload.stance;
        } else if (action.action == enums.ActionEnum.formation) {
            name = "Formation";
            param = payload.formation;
        } else if (action.action == enums.ActionEnum.order) {
            if (payload.target_id) |target_id| {
                if (self.gaia.get(target_id)) |gaia_obj| {
                    name = "Gather";
                    param = gaia_obj;
                }
            }
            if (action.position) |pos| {
                const pos_hash = hashPosition(pos);
                if (self.buildings.get(pos_hash)) |building| {
                    name = "Target";
                    param = building;
                }
            }
        } else if (action.action == enums.ActionEnum.gather_point) {
            if (payload.target_id) |target_id| {
                if (self.gaia.get(target_id)) |gaia_obj| {
                    param = gaia_obj;
                } else if (action.position) |pos| {
                    const pos_hash = hashPosition(pos);
                    if (self.buildings.get(pos_hash)) |building| {
                        if (payload.object_ids) |oids| {
                            if (oids.len == 1 and oids[0] == @as(u32, @intCast(target_id))) {
                                name = "Spawn";
                            }
                        }
                        param = building;
                    }
                }
            }
        } else if (action.action == enums.ActionEnum.buy or action.action == enums.ActionEnum.sell) {
            // amount already multiplied by 100 in parser
        } else if (action.action == enums.ActionEnum.build) {
            param = payload.building;
            if (action.position) |pos| {
                const pos_hash = hashPosition(pos);
                if (self.buildings.get(pos_hash)) |existing_building| {
                    if (payload.building) |new_building| {
                        if (std.mem.eql(u8, existing_building, "Farm") and std.mem.eql(u8, new_building, "Farm")) {
                            name = "Reseed";
                        }
                    }
                }
                if (payload.building) |building| {
                    try self.buildings.put(pos_hash, building);
                }
            }
        } else if (action.action == enums.ActionEnum.queue or action.action == enums.ActionEnum.de_queue) {
            param = payload.unit;
        } else if (action.action == enums.ActionEnum.research) {
            param = payload.technology;
        }

        const new_input = definitions.Input{
            .timestamp = action.timestamp,
            .input_type = name,
            .param = param,
            .payload = payload,
            .player = action.player,
            .position = action.position,
        };

        try self.inputs.append(new_input);
        return new_input;
    }
};
