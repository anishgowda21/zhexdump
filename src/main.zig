const std = @import("std");

const FormatType = enum {
    octal_byte, // -b
    char, // -c
    canonical, // -C
    decimal_unsigned, // -d
    octal_short, // -o
    decimal_signed, // -v
    hex, // -x
    custom, // -e
};

const Options = struct {
    formats: std.ArrayList(FormatType),
    format_string: ?[]const u8 = null, // -e
    format_file: ?[]const u8 = null, // -f
    length: ?usize = null,
    offset: usize = 0,
    no_squeezing: bool = false,

    pub fn init() Options {
        return .{
            .formats = .empty,
        };
    }

    pub fn deinit(self: *Options, allocator: std.mem.Allocator) void {
        self.formats.deinit(allocator);
    }
};

const HexDump = struct {
    file_contents: []u8,
    file_size: u64,
    options: Options,
    allocator: std.mem.Allocator,
};

fn processArgs(args: [][:0]u8, allocator: std.mem.Allocator) !Options {
    var options = Options.init();
    errdefer options.deinit(allocator);

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (arg.len > 0 and arg[0] == '-') {
            for (arg[1..]) |flag| {
                switch (flag) {
                    'b' => try options.formats.append(allocator, .octal_byte),
                    'c' => try options.formats.append(allocator, .char),
                    'C' => try options.formats.append(allocator, .canonical),
                    'd' => try options.formats.append(allocator, .decimal_unsigned),
                    'o' => try options.formats.append(allocator, .octal_short),
                    'v' => options.no_squeezing = true,
                    'x' => try options.formats.append(allocator, .hex),
                    'n' => {
                        i += 1;

                        if (i >= args.len) return error.MissingArgument;

                        const len_str = args[i];

                        const len = std.fmt.parseInt(usize, len_str, 10) catch {
                            return error.InvalidNumber;
                        };

                        options.length = len;
                    },
                    else => {},
                }
            }
        }
    }

    return options;
}

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var opts = try processArgs(args, allocator);
    defer opts.deinit(allocator);

    std.debug.print("args len {d}\n", .{opts.formats.items.len});

    for (opts.formats.items) |f| {
        std.debug.print("{}\n", .{f});
    }

    // var filename: [:0]const u8 = undefined;
    //
    // if (args.next()) |name| {
    //     filename = name;
    // } else {
    //     std.log.err("File name needed", .{});
    //     return 1;
    // }
    //
    // //const filename = args.next().?;
    // const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    // defer file.close();
    //
    // const file_size = try file.getEndPos();
    //
    // var buffer = try allocator.alloc(u8, file_size);
    // defer allocator.free(buffer);
    // _ = try file.readAll(buffer);
    //
    // var stdout_buffer: [4096]u8 = undefined;
    // var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    // const stdout = &stdout_writer.interface;
    //
    // var offset: usize = 0;
    // while (offset < buffer.len) {
    //     const bytes_read = @min(16, buffer.len - offset);
    //     const chunk = buffer[offset .. offset + bytes_read];
    //
    //     try stdout.print("{x:0>8} ", .{offset});
    //     if (bytes_read == 0) break;
    //
    //     for (0..bytes_read) |i| {
    //         if (i == 8) try stdout.print(" ", .{});
    //         try stdout.print(" {x:0>2}", .{chunk[i]});
    //     }
    //
    //     var rem = 16 - @as(u8, @intCast(bytes_read));
    //
    //     while (rem > 0) {
    //         try stdout.print("   ", .{});
    //         if (rem == 8) try stdout.print(" ", .{});
    //         rem -= 1;
    //     }
    //
    //     try stdout.print("  |", .{});
    //     for (0..bytes_read) |i| {
    //         const char = if (std.ascii.isPrint(chunk[i])) chunk[i] else '.';
    //         try stdout.print("{c}", .{char});
    //     }
    //     try stdout.print("|\n", .{});
    //
    //     offset += @intCast(bytes_read);
    // }
    // try stdout.print("\n", .{});
    // try stdout.flush();
    //
    return 0;
}
