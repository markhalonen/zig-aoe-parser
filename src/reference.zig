const std = @import("std");
const util = @import("util.zig");

pub const DatasetResult = struct {
    dataset_id: u32,
    json: std.json.Value,
};

fn contains(slice: []const u32, value: u32) bool {
    for (slice) |item| {
        if (item == value) return true;
    }
    return false;
}

pub fn get_dataset(allocator: std.mem.Allocator, version: util.Version, mod: []u32) DatasetResult {
    var dataset_id: ?u32 = null;
    if (version == util.Version.DE) {
        if (contains(mod, 11)) {
            dataset_id = 101;
        } else {
            dataset_id = 100;
        }
    } else if (version == util.Version.HD) {
        dataset_id = 300;
    } else if (mod.len > 0) {
        dataset_id = mod[0];
    } else {
        dataset_id = 0;
    }

    const result = std.fmt.allocPrint(std.heap.page_allocator, "{}.json", .{dataset_id.?}) catch @panic("heheheh");
    defer std.heap.page_allocator.free(result);

    const file = std.fs.cwd().openFile(result, .{}) catch @panic("failed to open constants.json");
    defer file.close();

    // Get file size
    const file_size = file.getEndPos() catch @panic("Failed to find file eend");

    // Allocate buffer to hold file contents
    const buffer_full = allocator.alloc(u8, std.math.cast(usize, file_size).?) catch @panic("asdasds");
    defer allocator.free(buffer_full);

    // Read the file into the buffer
    _ = file.readAll(buffer_full) catch @panic("failed to read");

    return .{
        .dataset_id = dataset_id.?,
        .json = std.json.parseFromSliceLeaky(std.json.Value, allocator, buffer_full, .{}) catch @panic("failed to parse"),
    };
}

pub fn get_consts(allocator: std.mem.Allocator) std.json.Value {
    const file = std.fs.cwd().openFile("constants.json", .{}) catch @panic("failed to open constants.json");
    defer file.close();

    // Get file size
    const file_size = file.getEndPos() catch @panic("Failed to find fil eend");

    // Allocate buffer to hold file contents
    const buffer_full = allocator.alloc(u8, std.math.cast(usize, file_size).?) catch @panic("asdasds");
    defer allocator.free(buffer_full);

    // Read the file into the buffer
    _ = file.readAll(buffer_full) catch @panic("failed to read");

    return std.json.parseFromSliceLeaky(std.json.Value, allocator, buffer_full, .{}) catch @panic("failed to parse");
}
