//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    // @cInclude("zlib.h");
});

pub fn main() !void {
    // const gpa = std.heap.GeneralPurposeAllocator(.{}){};
    try basicFlateExample();
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
    //try bufferedPrint();

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

// pub fn bufferedPrint() !void {
//     // Get the allocator
//     const allocator = std.heap.page_allocator;

//     // Open the file
//     const file = try std.fs.cwd().openFile("archers.aoe2record", .{});
//     defer file.close();

//     // Get file size
//     const file_size = try file.getEndPos();

//     // Allocate buffer to hold file contents
//     const buffer = try allocator.alloc(u8, std.math.cast(usize, file_size) orelse return error.FileTooLarge);
//     defer allocator.free(buffer);

//     // Read the file into the buffer
//     const bytes_read = try file.readAll(buffer);

//     const slice = buffer[0..4]; // Convert to a slice

//     // Read a u32 from the buffer (assuming little-endian format)
//     const header_len = std.mem.readInt(u32, slice, .little);
//     std.debug.print("Read u32 value: {}\n", .{header_len});

//     // read compressed header.
//     const compressed_header = buffer[8..header_len];

//     std.debug.print("Byte: 0x{x}\n", .{compressed_header[0]});
//     std.debug.print("Byte: 0x{x}\n", .{compressed_header[compressed_header.len - 1]});
//     std.debug.print("Size {}\n", .{compressed_header.len - 1});

//     // allocate another identical buffer with 2 extra bytes, set to 0
//     // const file_contents_plus_two = try allocator.alloc(u8, compressed_header.len + 2);
//     // defer allocator.free(file_contents_plus_two);
//     // @memcpy(file_contents_plus_two[0..compressed_header.len], compressed_header);
//     // file_contents_plus_two[compressed_header.len] = 0;
//     // file_contents_plus_two[compressed_header.len + 1] = 0;

//     // var reader: std.Io.Reader = .fixed(compressed_header);
//     var decompressBuffer: [1000]u8 = undefined;
//     //const

//     var stream = std.io.fixedBufferStream(&compressed_header);
//     var decompress: std.compress.flate.Decompress = .init(stream.reader(), .raw, &decompressBuffer);

//     const b = try decompress.reader.takeByte();
//     std.debug.print("length: {}\n", .{b});

//     // should decompress to 4160 bytes
//     var out_buffer: [4160]u8 = undefined;
//     var out_writer: std.Io.Writer = .fixed(&out_buffer);

//     const written = try decompress.reader.streamRemaining(&out_writer);
//     std.debug.print("decompressed {} bytes\n", .{written});

//     // Read the decompressed data into a buffer
//     var output_buffer = std.ArrayList(u8).init(allocator);
//     defer output_buffer.deinit();
//     //var out_writer: std.Io.Writer = .fixed(output_buffer);

//     //const written = try decompress.reader.streamRemaining(&out_writer);

//     //std.debug.print("{}", .{written});

//     // Verify we read the entire file
//     if (bytes_read != file_size) {
//         std.debug.print("Error: Could not read entire file\n", .{});
//         return error.IncompleteRead;
//     }

//     // The string to write
//     //const content = ".{}";

//     // Open or create a file
//     const outFile = try std.fs.cwd().createFile("output.txt", .{});
//     defer outFile.close();

//     // After
//     const formatted = try std.fmt.allocPrint(allocator, "{}", .{file_size});
//     defer allocator.free(formatted);
//     // Write the string to the file
//     try outFile.writeAll(formatted);
// }

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
