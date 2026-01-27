const std = @import("std");
const definitions = @import("definitions.zig");

pub fn get_diplomacy_type(teams: std.ArrayList(std.ArrayList(definitions.Player)), players: std.AutoHashMap(
    i32,
    definitions.Player,
)) []const u8 {
    if (teams.items.len == 2 and players.count() > 2) {
        return "TG";
    } else if (players.count() == 2) {
        return "1v1";
    } else if ((teams.items.len == players.count() or teams.items.len == 1) and players.count() > 2) {
        return "FFA";
    }
    return "Other";
}
