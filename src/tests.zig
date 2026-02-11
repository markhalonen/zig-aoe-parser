const std = @import("std");
const util = @import("util.zig");
const header = @import("header.zig");
const fastInit = @import("fast/init.zig");
const main = @import("main.zig");
const definitions = @import("definitions.zig");
const aoe_consts = @import("aoe_consts.zig");

// Parse just the version info from a recording file (fast version check)
// Uses arena allocator internally to avoid memory management issues
pub fn parseVersion(file_path: []const u8) !struct {
    version: util.Version,
    save_version: f32,
} {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer_full = try allocator.alloc(u8, std.math.cast(usize, file_size) orelse return error.FileTooLarge);

    _ = try file.readAll(buffer_full);

    var bufferReader = util.ByteReader.init(buffer_full);

    var out2 = std.ArrayList(u8).init(allocator);

    var headerReader = header.decompress(&out2, &bufferReader);

    const res = try header.parse_version(&headerReader, &bufferReader);

    return .{
        .version = res.version,
        .save_version = res.save,
    };
}

// Parse header with full DE data
// Uses arena allocator internally to avoid memory management issues
pub fn parseHeaderFast(file_path: []const u8) !struct {
    version: util.Version,
    save_version: f32,
    num_players: usize,
} {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer_full = try allocator.alloc(u8, std.math.cast(usize, file_size) orelse return error.FileTooLarge);

    _ = try file.readAll(buffer_full);

    var bufferReader = util.ByteReader.init(buffer_full);

    var out2 = std.ArrayList(u8).init(allocator);

    var headerReader = header.decompress(&out2, &bufferReader);

    const res = try header.parse_version(&headerReader, &bufferReader);

    // Parse DE header to get player count
    const de = header.parse_de(allocator, &headerReader, res.version, res.save, false);
    _ = de;

    const parsed_meta = header.parse_metadata(&headerReader, res.save, false);

    return .{
        .version = res.version,
        .save_version = res.save,
        .num_players = @intCast(parsed_meta.num_players),
    };
}

// Test version detection for all DE recording files
test "detect DE version for all DE files" {
    const de_files = [_][]const u8{
        "tests/recs/de-12.97-6byte-tile.aoe2record",
        "tests/recs/de-12.97-8byte-tile.aoe2record",
        "tests/recs/de-13.03.aoe2record",
        "tests/recs/de-13.06.aoe2record",
        "tests/recs/de-13.07.aoe2record",
        "tests/recs/de-13.08.aoe2record",
        "tests/recs/de-13.13.aoe2record",
        "tests/recs/de-13.15.aoe2record",
        "tests/recs/de-13.17.aoe2record",
        "tests/recs/de-13.20.aoe2record",
        "tests/recs/de-13.34.aoe2record",
        "tests/recs/de-20.06.aoe2record",
        "tests/recs/de-20.16.aoe2record",
        "tests/recs/de-25.01.aoe2record",
        "tests/recs/de-25.02.aoe2record",
        "tests/recs/de-25.06.aoe2record",
        "tests/recs/de-25.22.aoe2record",
        "tests/recs/de-26.16.aoe2record",
        "tests/recs/de-26.18.aoe2record",
        "tests/recs/de-26.21.aoe2record",
        "tests/recs/de-37-int.aoe2record",
        "tests/recs/de-37.0.aoe2record",
        "tests/recs/de-50.2.aoe2record",
        "tests/recs/de-50.3.aoe2record",
        "tests/recs/de-50.4.aoe2record",
        "tests/recs/de-61.5.aoe2record",
        "tests/recs/de-62.0.aoe2record",
        "tests/recs/de-63.0.aoe2record",
        "tests/recs/de-64.3.aoe2record",
    };

    for (de_files) |file_path| {
        const result = parseVersion(file_path) catch |err| {
            std.debug.print("Failed to parse {s}: {}\n", .{ file_path, err });
            return err;
        };

        // All DE files should have DE version
        try std.testing.expectEqual(util.Version.DE, result.version);
    }
}

// Test full parsing for a DE 64.3 file from the test suite
test "parse de-64.3 with full header" {
    const result = parseHeaderFast("tests/recs/de-64.3.aoe2record") catch |err| {
        std.debug.print("Failed to parse de-64.3.aoe2record: {}\n", .{err});
        return err;
    };

    // Should be DE version
    try std.testing.expectEqual(util.Version.DE, result.version);

    // Should have at least 2 players (excluding gaia)
    try std.testing.expect(result.num_players >= 2);
}

// Test full header parsing for newer DE files (save >= 25.22)
test "parse newer DE files with full header" {
    const de_files = [_][]const u8{
        "tests/recs/de-25.22.aoe2record",
        "tests/recs/de-26.16.aoe2record",
        "tests/recs/de-26.18.aoe2record",
        "tests/recs/de-26.21.aoe2record",
        "tests/recs/de-37-int.aoe2record",
        "tests/recs/de-37.0.aoe2record",
        "tests/recs/de-50.2.aoe2record",
        "tests/recs/de-50.3.aoe2record",
        "tests/recs/de-50.4.aoe2record",
        "tests/recs/de-61.5.aoe2record",
        "tests/recs/de-62.0.aoe2record",
        "tests/recs/de-63.0.aoe2record",
        "tests/recs/de-64.3.aoe2record",
    };

    for (de_files) |file_path| {
        const result = parseHeaderFast(file_path) catch |err| {
            std.debug.print("Failed to parse {s}: {}\n", .{ file_path, err });
            return err;
        };

        // All DE files should have DE version
        try std.testing.expectEqual(util.Version.DE, result.version);

        // Should have at least 1 player
        try std.testing.expect(result.num_players >= 1);
    }
}

// Test parsing specific DE file version
test "parse de-13.34 version" {
    const result = try parseVersion("tests/recs/de-13.34.aoe2record");

    try std.testing.expectEqual(util.Version.DE, result.version);
    // save version should be approximately 13.34
    try std.testing.expect(result.save_version >= 13.34 and result.save_version < 13.35);
}

// Test full header parsing for older DE files (13.13 <= save < 25.22)
// Note: Files with save < 13.13 have a different format and are not yet supported
test "parse older DE files with full header" {
    const de_files = [_][]const u8{
        // Old DE files (13.13 <= save < 13.34)
        "tests/recs/de-13.13.aoe2record",
        "tests/recs/de-13.15.aoe2record",
        "tests/recs/de-13.17.aoe2record",
        "tests/recs/de-13.20.aoe2record",
        // Old DE files (13.34 <= save < 25.22)
        "tests/recs/de-13.34.aoe2record",
        "tests/recs/de-20.06.aoe2record",
        "tests/recs/de-20.16.aoe2record",
        "tests/recs/de-25.01.aoe2record",
        "tests/recs/de-25.02.aoe2record",
        "tests/recs/de-25.06.aoe2record",
    };

    for (de_files) |file_path| {
        const result = parseHeaderFast(file_path) catch |err| {
            std.debug.print("Failed to parse {s}: {}\n", .{ file_path, err });
            return err;
        };

        try std.testing.expectEqual(util.Version.DE, result.version);
        try std.testing.expect(result.num_players >= 1);
    }
}

// Test that HD files are detected as HD version
test "detect HD version for HD files" {
    const hd_files = [_][]const u8{
        "tests/recs/hd-4.6.aoe2record",
        "tests/recs/hd-4.7.aoe2record",
        "tests/recs/hd-4.8.aoe2record",
        "tests/recs/hd-5.0.aoe2record",
        "tests/recs/hd-5.1.aoe2record",
        "tests/recs/hd-5.1a.aoe2record",
        "tests/recs/hd-5.3.aoe2record",
        "tests/recs/hd-5.5.aoe2record",
        "tests/recs/hd-5.6.aoe2record",
        "tests/recs/hd-5.7.aoe2record",
        "tests/recs/hd-5.8.aoe2record",
    };

    for (hd_files) |file_path| {
        const result = parseVersion(file_path) catch |err| {
            std.debug.print("Failed to parse {s}: {}\n", .{ file_path, err });
            return err;
        };

        try std.testing.expectEqual(util.Version.HD, result.version);
    }
}

// Parse HD header with full data
pub fn parseHeaderFastHD(file_path: []const u8) !struct {
    version: util.Version,
    save_version: f32,
    num_players: usize,
} {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer_full = try allocator.alloc(u8, std.math.cast(usize, file_size) orelse return error.FileTooLarge);

    _ = try file.readAll(buffer_full);

    var bufferReader = util.ByteReader.init(buffer_full);

    var out2 = std.ArrayList(u8).init(allocator);

    var headerReader = header.decompress(&out2, &bufferReader);

    const res = try header.parse_version(&headerReader, &bufferReader);

    // Parse HD header to get player count
    const hd = header.parse_hd(allocator, &headerReader, res.version, res.save);

    const parsed_meta = header.parse_metadata(&headerReader, res.save, false);

    return .{
        .version = res.version,
        .save_version = hd.save_version,
        .num_players = @intCast(parsed_meta.num_players),
    };
}

// Test full header parsing for HD files
test "parse HD files with full header" {
    // Test all HD files
    const hd_files = [_][]const u8{
        "tests/recs/hd-4.6.aoe2record", // version 1000
        "tests/recs/hd-4.7.aoe2record", // version 1000
        "tests/recs/hd-4.8.aoe2record", // version 1004
        "tests/recs/hd-5.0.aoe2record", // version 1005
        "tests/recs/hd-5.1.aoe2record", // version 1005
        "tests/recs/hd-5.1a.aoe2record",
        "tests/recs/hd-5.3.aoe2record",
        "tests/recs/hd-5.5.aoe2record",
        "tests/recs/hd-5.6.aoe2record",
        "tests/recs/hd-5.7.aoe2record", // version 1006
        "tests/recs/hd-5.8.aoe2record", // version 1006
    };

    for (hd_files) |file_path| {
        const result = parseHeaderFastHD(file_path) catch |err| {
            std.debug.print("Failed to parse {s}: {}\n", .{ file_path, err });
            return err;
        };

        // All HD files should have HD version
        try std.testing.expectEqual(util.Version.HD, result.version);

        // Should have at least 1 player
        try std.testing.expect(result.num_players >= 1);
    }
}

// Test UserPatch files
test "detect UserPatch version" {
    const result = parseVersion("tests/recs/small.mgz") catch |err| {
        std.debug.print("Failed to parse small.mgz: {}\n", .{err});
        return err;
    };

    try std.testing.expectEqual(util.Version.USERPATCH15, result.version);
}

// Parse a recording file with header, meta, and all operations until EOF
// Returns the number of operations parsed
pub fn parseFileFast(file_path: []const u8) !usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer_full = try allocator.alloc(u8, std.math.cast(usize, file_size) orelse return error.FileTooLarge);

    _ = try file.readAll(buffer_full);

    var bufferReader = util.ByteReader.init(buffer_full);

    var out2 = std.ArrayList(u8).init(allocator);

    var headerReader = header.decompress(&out2, &bufferReader);

    const res = try header.parse_version(&headerReader, &bufferReader);

    // Parse version-specific header
    if (res.version == util.Version.HD) {
        _ = header.parse_hd(allocator, &headerReader, res.version, res.save);
    } else if (res.version == util.Version.DE) {
        _ = header.parse_de(allocator, &headerReader, res.version, res.save, false);
    }
    // UserPatch doesn't need additional header parsing

    _ = header.parse_metadata(&headerReader, res.save, false);

    // Call fast.meta on the body reader (bufferReader, not headerReader)
    fastInit.meta(&bufferReader);

    // Parse all operations until EOF
    var operation_count: usize = 0;
    while (bufferReader.get_position() < bufferReader.buffer.len) {
        _ = fastInit.operation(allocator, &bufferReader);
        operation_count += 1;
    }

    return operation_count;
}

// Test all recording files (like Python's test_files_fast)
test "test_files_fast - parse all recording files" {
    // Files to skip (unsupported formats)
    const skip_files = [_][]const u8{
        "de-50.6-scenario.aoe2record", // scenario format not supported
        "de-50.6-scenario-with-triggers.aoe2record", // scenario format not supported
        "aok-2.0a.mgl", // AOK format uses different header structure
        // Old DE files with save < 13.13 have different string_block format
        "de-12.97-6byte-tile.aoe2record",
        "de-12.97-8byte-tile.aoe2record",
        "de-13.03.aoe2record",
        "de-13.06.aoe2record",
        "de-13.07.aoe2record",
        "de-13.08.aoe2record",
    };

    // Open the test recordings directory
    var dir = std.fs.cwd().openDir("aoc-mgz/tests/recs", .{ .iterate = true }) catch |err| {
        std.debug.print("Failed to open tests/recs directory: {}\n", .{err});
        return err;
    };
    defer dir.close();

    var file_count: usize = 0;
    var success_count: usize = 0;

    // Iterate through all files in the directory
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;

        // Check if this file should be skipped
        var should_skip = false;
        for (skip_files) |skip_name| {
            if (std.mem.eql(u8, entry.name, skip_name)) {
                should_skip = true;
                break;
            }
        }
        if (should_skip) continue;

        file_count += 1;

        // Build full path
        var path_buf: [256]u8 = undefined;
        const full_path = std.fmt.bufPrint(&path_buf, "tests/recs/{s}", .{entry.name}) catch {
            std.debug.print("Path too long: {s}\n", .{entry.name});
            continue;
        };

        // Parse the file
        const op_count = parseFileFast(full_path) catch |err| {
            std.debug.print("Failed to parse {s}: {}\n", .{ full_path, err });
            return err;
        };

        success_count += 1;
        _ = op_count;
    }

    // Ensure we tested some files
    try std.testing.expect(file_count > 0);
    try std.testing.expectEqual(file_count, success_count);
}
