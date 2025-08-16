const std = @import("std");

pub const Version = enum(u8) {
    /// Version enumeration.
    ///
    /// Using consts from https://github.com/goto-bus-stop/recanalyst/blob/master/src/Model/Version.php
    /// for consistency.
    AOK = 1,
    AOC = 4,
    AOC10 = 5,
    AOC10C = 8,
    USERPATCH12 = 12,
    USERPATCH13 = 13,
    USERPATCH14 = 11,
    USERPATCH15 = 20,
    DE = 21,
    USERPATCH14RC2 = 22,
    MCP = 30,
    HD = 19,
};

const VersionError = error{UnsupportedVersion};

pub fn getVersion(game_version: *const [7]u8, save_version: f32, log_version: ?u32) VersionError!Version {
    if (std.mem.eql(u8, game_version, "VER 9.3")) {
        return Version.AOK;
    }
    if (std.mem.eql(u8, game_version, "VER 9.4")) {
        if (log_version) |lv| {
            if (lv == 3) {
                return Version.AOC10;
            }
            if (lv == 5 or save_version >= 12.97) {
                return Version.DE;
            }
            if (save_version >= 12.36) {
                return Version.HD;
            }
            if (lv == 4) {
                return Version.AOC10C;
            }
        }
        return Version.AOC;
    }
    if (std.mem.eql(u8, game_version, "VER 9.8")) {
        return Version.USERPATCH12;
    }
    if (std.mem.eql(u8, game_version, "VER 9.9")) {
        return Version.USERPATCH13;
    }
    if (std.mem.eql(u8, game_version, "VER 9.A")) {
        return Version.USERPATCH14RC2;
    }
    if (std.mem.eql(u8, game_version, "VER 9.B") or
        std.mem.eql(u8, game_version, "VER 9.C") or
        std.mem.eql(u8, game_version, "VER 9.D"))
    {
        return Version.USERPATCH14;
    }
    if (std.mem.eql(u8, game_version, "VER 9.E") or
        std.mem.eql(u8, game_version, "VER 9.F"))
    {
        return Version.USERPATCH15;
    }
    if (std.mem.eql(u8, game_version, "MCP 9.F")) {
        return Version.MCP;
    }
    if (log_version != null or !std.mem.eql(u8, game_version, "VER 9.4")) {
        return VersionError.UnsupportedVersion;
    }
    return Version.AOC; // Default case for VER 9.4 with null log_version
}
