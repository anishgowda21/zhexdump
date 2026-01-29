const std = @import("std");

pub fn main() !u8 {
    var args = std.process.args();

    _ = args.skip();

    var filename: [:0]const u8 = undefined;

    if (args.next()) |name| {
        filename = name;
    } else {
        std.log.err("File name needed", .{});
        return 1;
    }

    //const filename = args.next().?;
    const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();

    const file_size = try file.getEndPos();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    _ = try file.readAll(buffer);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var offset: usize = 0;
    while (offset < buffer.len) {
        const bytes_read = @min(16, buffer.len - offset);
        const chunk = buffer[offset .. offset + bytes_read];

        try stdout.print("{x:0>8} ", .{offset});
        if (bytes_read == 0) break;

        for (0..bytes_read) |i| {
            if (i == 8) try stdout.print(" ", .{});
            try stdout.print(" {x:0>2}", .{chunk[i]});
        }

        var rem = 16 - @as(u8, @intCast(bytes_read));

        while (rem > 0) {
            try stdout.print("   ", .{});
            if (rem == 8) try stdout.print(" ", .{});
            rem -= 1;
        }

        try stdout.print("  |", .{});
        for (0..bytes_read) |i| {
            const char = if (std.ascii.isPrint(chunk[i])) chunk[i] else '.';
            try stdout.print("{c}", .{char});
        }
        try stdout.print("|\n", .{});

        offset += @intCast(bytes_read);
    }
    try stdout.print("\n", .{});
    try stdout.flush();

    return 0;
}
