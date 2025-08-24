const std = @import("std");

pub const SeekFrom = enum {
    Start,
    Current,
    End,
};

pub const ByteReader = struct {
    buffer: []const u8,
    position: usize,

    pub fn init(buffer: []const u8) ByteReader {
        return ByteReader{
            .buffer = buffer,
            .position = 0,
        };
    }

    pub fn read(self: *ByteReader) []const u8 {
        const start = self.position;
        self.position = self.buffer.len;
        return self.buffer[start..];
    }

    pub fn read_int(self: *ByteReader, comptime T: type) T {
        return std.mem.readInt(T, self.read_bytes(@sizeOf(T))[0..@sizeOf(T)], .little);
    }

    pub fn read_bytes(self: *ByteReader, count: u64) []const u8 {
        if (self.position + count > self.buffer.len) {
            std.debug.print("tried to read past buffer length. Buffer length is {}, tried to read {}", .{ self.buffer.len, self.position + count });
            std.debug.panic("aasd", .{});
            std.process.exit(1);
        }

        const start = self.position;
        self.position += count;

        return self.buffer[start..self.position];
    }

    pub fn get_position(self: *ByteReader) usize {
        return self.position;
    }

    pub fn seek(self: *ByteReader, offset: i128, whence: SeekFrom) void {
        var new_position: i128 = undefined;

        switch (whence) {
            .Start => {
                new_position = offset;
            },
            .Current => {
                new_position = @as(i128, @intCast(self.position)) + offset;
            },
            .End => {
                new_position = @as(i128, @intCast(self.buffer.len)) + offset;
            },
        }

        // Ensure new_position is within bounds
        if (new_position < 0 or new_position > self.buffer.len) {
            std.debug.panic("at the disco", .{});
            std.process.exit(1);
        }

        self.position = @as(usize, @intCast(new_position));
    }
};

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

pub fn de_string(reader: *ByteReader) []const u8 {
    // Check for the magic bytes '\x60\x0a'
    const header = reader.read_bytes(2);
    if (!std.mem.eql(u8, header, &[_]u8{ 0x60, 0x0a })) {
        std.debug.panic("here", .{});
        std.debug.print("did not find expected de string header", .{});
        std.process.exit(1);
    }

    // Read 2 bytes for length (little-endian short)
    const length_bytes = reader.read_bytes(2);
    const length = std.mem.readInt(i16, length_bytes[0..2], .little);
    if (length < 0) {
        std.debug.print("expected positive value in de_string", .{});
        std.process.exit((1));
    }
    const length_u64: u64 = @intCast(length);
    // Read the string data based on length
    return reader.read_bytes(length_u64);
}

pub fn string_block(reader: *ByteReader, allocator: std.mem.Allocator) std.ArrayList([][]const u8) {
    var strings = std.ArrayList([][]const u8).init(allocator);
    // defer strings.deinit();
    // std.debug.print("position is {}\n\n", reader.get_position());
    while (true) {
        // Read 4 bytes for CRC (little-endian u32)
        const crc_bytes = reader.read_bytes(4);
        const crc = std.mem.readInt(u32, crc_bytes[0..4], .little);

        // Check if CRC is between 0 and 255
        if (crc > 0 and crc < 255) {
            break;
        }

        // Read and decode the string, then split by ':'
        const raw_string = de_string(reader);

        // Split the string by ':'
        var split_iter = std.mem.splitAny(u8, raw_string, ":");
        var split_strings = std.ArrayList([]const u8).init(allocator);

        while (split_iter.next()) |part| {
            split_strings.append(part) catch {
                std.debug.panic("here", .{});
                std.process.exit(1);
            };
        }
        strings.append(split_strings.items) catch {
            std.debug.panic("here", .{});
            std.process.exit(1);
        };
    }

    return strings;
}
