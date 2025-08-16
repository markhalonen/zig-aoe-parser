//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    // @cInclude("zlib.h");
});

const util = @import("util.zig");

pub fn main() !void {
    try bufferedPrint();

    // const gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // try basicFlateExample();
    // try testing.expectEqualSlices(u8, expected_plain, out.items);

    // Allocator for managing memory
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    // const allocator = gpa.allocator();

    // // Create a buffer for the decompressed data
    // var decompressed_buffer = try allocator.alloc(u8, 1024); // Adjust size as needed
    // defer allocator.free(decompressed_buffer);

    // // Set up the decompression stream
    // var stream = std.io.fixedBufferStream(&compressed_data);
    // var decompressor = std.compress.flate.decompressor(stream.reader());
    // defer decompressor.deinit();

    // // Read the decompressed data
    // const bytes_read = try decompressor.read(decompressed_buffer);
    // const decompressed_data = decompressed_buffer[0..bytes_read];

    // Print the decompressed data as a string
    // std.debug.print("Decompressed data: {s}\n", .{decompressed_data});

    // const ret = c.printf("hello from c world!\n");
    // std.debug.print("C call return value: {d}\n", .{ret});

    // const buf = c.malloc(10);
    // if (buf == null) {
    //     std.debug.print("ERROR while allocating memory!\n", .{});
    //     return;
    // }
    // std.debug.print("buf address: {any}\n", .{buf});
    // c.free(buf);

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    // try stdout.print("Run `zig build test` to run the tests.\n", .{});

    // try bw.flush(); // Don't forget to flush!
}

pub fn basicFlateExample() !void {
    const allocator = std.heap.page_allocator;
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // Example compressed data (Flate-compressed "Hello, Zig!")

    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();

    const plain = "I am not a complete moron!!!";
    var in = std.io.fixedBufferStream(plain[0..plain.len]);
    try std.compress.flate.compress(in.reader(), out.writer(), .{});

    for (out.items) |byte| {
        std.debug.print("{x:0>2} ", .{byte});
    }

    // const compressed_data = [_]u8{
    //     0xf3, 0x54, 0x48, 0xcc, 0x55, 0xc8, 0xcb, 0x2f, 0x51, 0x48, 0x54, 0x48, 0xce, 0xcf, 0x2d, 0xc8, 0x49, 0x2d, 0x49, 0x55, 0xc8, 0xcd, 0x2f, 0xca, 0xcf, 0xd3, 0x03, 0x00,
    // };

    var in2 = std.io.fixedBufferStream(out.items);

    var out2 = std.ArrayList(u8).init(allocator);
    defer out2.deinit();

    try std.compress.flate.decompress(in2.reader(), out2.writer());

    for (out2.items) |byte| {
        std.debug.print("{c}", .{byte});
    }
}

pub const ByteReader = struct {
    buffer: []const u8,
    position: usize,

    pub fn init(buffer: []const u8) ByteReader {
        return ByteReader{
            .buffer = buffer,
            .position = 0,
        };
    }

    pub fn read_bytes(self: *ByteReader, count: u64) []const u8 {
        if (self.position + count > self.buffer.len) {
            std.process.exit(1);
        }

        const start = self.position;
        self.position += count;
        return self.buffer[start..self.position];
    }
};

const parse_version_retval = struct { version: util.Version, game: *const [7]u8, save: f32, log: u32 };

fn parse_version(headerReader: *ByteReader, dataReader: *ByteReader) !parse_version_retval {
    const slice = dataReader.read_bytes(4);
    const log: u32 = std.mem.readInt(u32, slice[0..4], .little);

    const gameSlice = headerReader.read_bytes(7);

    _ = headerReader.read_bytes(1);

    const saveSlice = headerReader.read_bytes(4);
    var save: f32 = std.mem.bytesToValue(f32, saveSlice);

    if (save == -1) {
        const s = headerReader.read_bytes(4);
        const sInt: u32 = std.mem.readInt(u32, s[0..4], .little);

        if (sInt == 37) {
            save = 37.0;
        } else {
            save = @as(f32, @floatFromInt(sInt)) / @as(f32, @floatFromInt((1 << 16)));
        }
    }

    const version = try util.getVersion(gameSlice[0..7], save, log);

    return .{ .version = version, .game = gameSlice[0..7], .save = save, .log = log };
}

pub fn bufferedPrint() !void {
    // Get the allocator
    const allocator = std.heap.page_allocator;

    // Open the file
    const file = try std.fs.cwd().openFile("archers.aoe2record", .{});
    defer file.close();

    // Get file size
    const file_size = try file.getEndPos();

    // Allocate buffer to hold file contents
    const buffer_full = try allocator.alloc(u8, std.math.cast(usize, file_size) orelse return error.FileTooLarge);
    defer allocator.free(buffer_full);

    // Read the file into the buffer
    _ = try file.readAll(buffer_full);

    var bufferReader = ByteReader.init(buffer_full);

    const slice = bufferReader.read_bytes(8);

    // Read a u32 from the buffer (assuming little-endian format)
    const header_len = std.mem.readInt(u64, slice[0..8], .little);

    // read compressed header.
    const compressed_header = bufferReader.read_bytes(header_len - 8); //buffer[8..header_len];

    var in2 = std.io.fixedBufferStream(compressed_header);

    var out2 = std.ArrayList(u8).init(allocator);
    defer out2.deinit();

    try std.compress.flate.decompress(in2.reader(), out2.writer());
    var headerReader = ByteReader.init(out2.items);
    const res = try parse_version(&headerReader, &bufferReader);
    std.debug.print("version from parse_version is {}\n", .{res.version});
    std.debug.print("game from parse_version is {s}\n", .{res.game});
    std.debug.print("save from parse_version is {}\n", .{res.save});
    std.debug.print("log from parse_version is {}\n", .{res.log});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("zig14_basic_lib");
