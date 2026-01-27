const std = @import("std");
const enums = @import("./fast/enums.zig");

const AGE_MARKERS = [_][]const u8{
    "advanced to the",
    "a progressé vers",
    "升级至",
    "avanzó a la",
    "đã phát triển lên",
    "시대에 발전했습니다",
    "vorangeschritten",
    "переход в",
    "avançou para a Idade",
    "wkroczyło w Erę",
    "升級至",
    "passaggio",
    "geçti",
    "進化し",
    "avançou para",
    "новую эпоху",
    "avanzó a Edad",
    "avanzado a la Edad",
    "ha raggiunto",
    "avanzó a Ed",
    "đã nâng cấp",
};

const SAVE_MARKERS = [_][]const u8{
    "Continuar con la partida en vez de guardar y salir",
    "Voto iniciado para guardar y salir del juego",
    "Chose to continue the game instead of save and exit",
    "Initiated vote to save and exit the game",
    "Vyber pokračovat ve hře místo ulo",
    "Escolha para continuar o jogo em vez de salvá-lo e fechá-lo",
    "Выберете Продолжить Игру вместо Сохранить и Выйти.",
    "Choisir pour continuer la partie au lieu d'enregistrer et quitter.",
};

pub const Chat = enum(u8) {
    /// Chat types.
    Ladder = 0,
    Voobly = 1,
    Rating = 2,
    Injected = 3,
    Age = 4,
    Save = 5,
    Message = 6,
    Help = 7,
    Discard = 8,
};

const parse_chat_type = struct {
    timestamp: u32,
    origination: ?[]const u8,
    type: ?Chat,
    ladder: ?[]const u8,
    player_number: ?i32,
    message: ?[]const u8,
    audience: ?[]const u8,
};

pub const PlayerMinimal = struct { name: []const u8, number: i32 };

fn parse_ladder(pct: *parse_chat_type, line: []const u8) void {
    const start = std.mem.indexOf(u8, line, "'").? + 1;
    const end = std.mem.indexOf(u8, line[start..], "'").?;
    pct.type = Chat.Ladder;
    pct.ladder = line[start..end];
}

fn _parse_chat(
    allocator: std.mem.Allocator,
    data: *parse_chat_type,
    line: []const u8,
    players: []PlayerMinimal,
    diplomacyType: ?[]const u8,
) void {
    if (line.len < 5) {
        data.type = Chat.Discard;
        return;
    }

    var player_start = std.mem.indexOf(u8, line, "#").? + 2;

    if (line[4] == ' ') {
        player_start = std.mem.indexOf(u8, line, " ").? + 1;
    }
    const player_end = std.mem.indexOfPos(u8, line, player_start, ":");
    var player = line[player_start..player_end.?];

    var groupOpt: ?[]const u8 = null;
    if (data.timestamp == 0) {
        groupOpt = "All";
    } else if (std.mem.eql(u8, "TG", diplomacyType orelse "")) {
        groupOpt = "Team";
    } else {
        groupOpt = "All";
    }

    const idxOpt = std.mem.indexOf(u8, player, ">");
    if (idxOpt) |idx| {
        if (idx > 0) {
            groupOpt = player[1..idx];
            player = player[idx + 1 ..];
        }
    }

    if (groupOpt) |group| {
        const groupLower = std.ascii.allocLowerString(allocator, group) catch @panic("13qdsda2");
        if (std.mem.eql(u8, groupLower, "todos") or std.mem.eql(u8, groupLower, "всем") or std.mem.eql(u8, groupLower, "tous")) {
            groupOpt = "All";
        } else if (std.mem.eql(u8, groupLower, "隊伍") or std.mem.eql(u8, groupLower, "squadra")) {
            groupOpt = "Team";
        }
    }

    const message = line[player_end.? + 2 ..];
    var number: ?i32 = null;
    // players needs to get passed here.
    for (players) |player_h| {
        if (std.mem.indexOf(u8, player, player_h.name)) |_| {
            number = player_h.number;
        }
    }
    data.type = Chat.Message;
    data.player_number = number;
    data.message = std.mem.trim(u8, message, " ");
    if (groupOpt) |group| {
        data.audience = std.ascii.allocLowerString(allocator, group) catch @panic("123asda");
    }
}

pub fn parse_chat(
    allocator: std.mem.Allocator,
    line: []const u8,
    encoding: []const u8,
    timestamp: u32,
    players: []PlayerMinimal,
    diplomacyType: ?[]const u8,
    origination: ?[]const u8,
) parse_chat_type {
    _ = encoding;
    var retval: parse_chat_type = .{
        .timestamp = timestamp,
        .origination = origination,
        .type = null,
        .ladder = null,
        .player_number = null,
        .message = null,
        .audience = null,
    };

    const lineOut = std.mem.trim(u8, line, "\x00");
    for (SAVE_MARKERS) |sm| {
        if (std.mem.indexOf(u8, lineOut, sm)) |_| {
            retval.type = Chat.Save;
            return retval;
        }
    }

    for (AGE_MARKERS) |am| {
        if (std.mem.indexOf(u8, lineOut, am)) |_| {
            retval.type = Chat.Age;
            return retval;
        }
    }

    if ((std.mem.indexOf(u8, lineOut, "Voobly: Ratings provided") orelse 0) > 0) {
        parse_ladder(&retval, lineOut);
    } else if ((std.mem.indexOf(u8, lineOut, "Voobly") orelse 0) == 3) {
        @panic("not implemented");
    } else if ((std.mem.indexOf(u8, lineOut, "<Rating>") orelse 0) > 0) {
        @panic("not implemented");
    } else if ((std.mem.indexOf(u8, lineOut, "@#0<") orelse 1000) == 0) {
        @panic("not implemented");
    } else if ((std.mem.indexOf(u8, lineOut, "--") orelse 1000) == 3) {
        @panic("not implemented");
    } else if (std.mem.startsWith(u8, lineOut, "{")) {
        _parse_json(allocator, &retval, lineOut, diplomacyType);
    } else {
        _parse_chat(allocator, &retval, lineOut, players, diplomacyType);
    }
    // TODO left off a bunch here...

    std.debug.print("{s}", .{lineOut});
    return retval;
}

fn _parse_json(allocator: std.mem.Allocator, data: *parse_chat_type, line: []const u8, diplomacy_type: ?[]const u8) void {
    const payload = std.json.parseFromSliceLeaky(std.json.Value, allocator, line, .{}) catch @panic("failed to parse");

    if (payload.object.get("messageAGP")) |v| {
        if (v.string.len == 0) {
            data.type = Chat.Discard;
            return;
        }
    }

    var audience: []const u8 = "team";
    if (payload.object.get("channel")) |v| {
        if (v.integer == 0) {
            if (std.mem.eql(u8, "1v1", diplomacy_type orelse "")) {
                audience = "all";
            }
        } else if (v.integer == 1) {
            audience = "all";
        }
    }

    data.type = Chat.Message;
    data.player_number = @as(i32, @intCast(payload.object.get("player").?.integer));
    data.message = std.mem.trim(u8, payload.object.get("message").?.string, " ");
    data.audience = audience;
}
