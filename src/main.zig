const std = @import("std");

const ParseError = error{
    MissingLengthArgument,
    MissingOffsetArgument,
    InvalidNumber,
    InvalidOffset,
    InputFileMissing,
};

const FormatType = enum {
    octal_byte, // -b
    char, // -c
    canonical, // -C
    decimal_unsigned, // -d
    octal_short, // -o
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
    file: ?std.fs.File,
    read_buffer: []u8,
    options: Options,
    allocator: std.mem.Allocator,

    fn init(file_name: ?[]const u8, opts: Options, allocator: std.mem.Allocator) !HexDump {
        var file: ?std.fs.File = null;
        if (file_name) |f_name| {
            file = try std.fs.cwd().openFile(f_name, .{ .mode = .read_only });
            errdefer file.close();
        }

        const buffer = try allocator.alloc(u8, 1024 * 1024 * 10);
        errdefer allocator.free(buffer);

        return HexDump{
            .file = file,
            .read_buffer = buffer,
            .options = opts,
            .allocator = allocator,
        };
    }

    fn deinit(self: *HexDump) void {
        if (self.file) |f| {
            f.close();
        }
        self.allocator.free(self.read_buffer);
        self.options.deinit(self.allocator);
    }

    fn process(self: *HexDump) !void {
        var file_reader: std.fs.File.Reader = undefined;

        if (self.file) |f| {
            file_reader = f.reader(self.read_buffer);
        } else {
            file_reader = std.fs.File.stdin().reader(self.read_buffer);
        }
        if (self.options.offset > 0) {
            try file_reader.seekTo(self.options.offset);
        }
        const reader = &file_reader.interface;
        var buffer: [16]u8 = undefined;
        var last_read_buffer: [16]u8 = undefined;
        var total_bytes_read: usize = self.options.offset;

        var stdout_buffer: [1024]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
        const stdout = &stdout_writer.interface;

        var read_length = self.options.length;

        while (true) {
            var to_read = buffer.len;

            if (read_length) |l| {
                if (l < 0) break;
                to_read = @min(l, buffer.len);
            }

            const bytes_read = try reader.readSliceShort(buffer[0..to_read]);
            if (bytes_read == 0) break;

            if (bytes_read == 16 and
                std.mem.eql(u8, buffer[0..16], last_read_buffer[0..16]) and
                !self.options.no_squeezing)
            {
                total_bytes_read += bytes_read;
                try stdout.print("*\n", .{});
                continue;
            }

            if (self.options.formats.items.len == 0) {
                try defaultDump(buffer, bytes_read, total_bytes_read, stdout);
            }

            for (self.options.formats.items) |f| {
                switch (f) {
                    FormatType.canonical => try canonicalDump(buffer, bytes_read, total_bytes_read, stdout),
                    FormatType.octal_byte => try octalByteDump(buffer, bytes_read, total_bytes_read, stdout),
                    FormatType.char => try charByteDump(buffer, bytes_read, total_bytes_read, stdout),
                    FormatType.decimal_unsigned => try decimalDump(buffer, bytes_read, total_bytes_read, stdout),
                    FormatType.octal_short => try octalTwoByteDump(buffer, bytes_read, total_bytes_read, stdout),
                    FormatType.hex => try hexTwoByteDump(buffer, bytes_read, total_bytes_read, stdout),

                    else => {},
                }
            }

            total_bytes_read += bytes_read;

            if (read_length) |l| {
                read_length = l - bytes_read;
            }

            if (bytes_read == 16)
                std.mem.copyForwards(u8, last_read_buffer[0..16], buffer[0..16]);
        }
        if (self.options.formats.items.len > 0 and self.options.formats.items[self.options.formats.items.len - 1] == FormatType.canonical) {
            try stdout.print("{x:0>8}\n", .{total_bytes_read});
        } else {
            try stdout.print("{x:0>7}\n", .{total_bytes_read});
        }
        try stdout.flush();
    }

    fn defaultDump(line: [16]u8, bytes_read: usize, total_bytes_read: usize, writer: *std.io.Writer) !void {
        var i: usize = 0;

        try writer.print("{x:0>7}", .{total_bytes_read});
        while (i < bytes_read) : (i += 2) {
            if (i + 1 < bytes_read) {
                try writer.print(" {x:0>2}{x:0>2}", .{ line[i + 1], line[i] });
            } else {
                try writer.print(" {x:0>4}", .{line[i]});
            }
        }
        try writer.print("\n", .{});
    }

    fn octalByteDump(line: [16]u8, bytes_read: usize, total_bytes_read: usize, writer: *std.io.Writer) !void {
        try writer.print("{x:0>7}", .{total_bytes_read});

        for (0..bytes_read) |i| {
            try writer.print(" {o:0>3}", .{line[i]});
        }
        try writer.print("\n", .{});
    }

    fn charByteDump(line: [16]u8, bytes_read: usize, total_bytes_read: usize, writer: *std.io.Writer) !void {
        try writer.print("{x:0>7}", .{total_bytes_read});

        for (0..bytes_read) |i| {
            const byte = line[i];
            if ((byte >= 0x20 and byte <= 0x7E) or (byte >= 0xA0)) {
                try writer.print("{c:>4}", .{byte});
            } else {
                switch (byte) {
                    0 => try writer.print("  \\0", .{}),
                    9 => try writer.print("  \\t", .{}),
                    10 => try writer.print("  \\n", .{}),
                    13 => try writer.print("  \\r", .{}),
                    else => try writer.print(" {o:0>3}", .{byte}),
                }
            }
        }
        try writer.print("\n", .{});
    }

    fn decimalDump(line: [16]u8, bytes_read: usize, total_bytes_read: usize, writer: *std.io.Writer) !void {
        var i: usize = 0;

        try writer.print("{x:0>7}", .{total_bytes_read});
        while (i < bytes_read) : (i += 2) {
            const first_byte = @as(u16, line[i]);
            const sec_byte = if (i + 1 < bytes_read) @as(u16, line[i + 1]) else 0;
            try writer.print("   {d:0>5}", .{sec_byte * 256 + first_byte});
        }
        try writer.print("\n", .{});
    }

    fn octalTwoByteDump(line: [16]u8, bytes_read: usize, total_bytes_read: usize, writer: *std.io.Writer) !void {
        var i: usize = 0;

        try writer.print("{x:0>7}", .{total_bytes_read});
        while (i < bytes_read) : (i += 2) {
            const first_byte = @as(u16, line[i]);
            const sec_byte = if (i + 1 < bytes_read) @as(u16, line[i + 1]) else 0;
            try writer.print("  {o:0>6}", .{sec_byte * 256 + first_byte});
        }
        try writer.print("\n", .{});
    }

    fn hexTwoByteDump(line: [16]u8, bytes_read: usize, total_bytes_read: usize, writer: *std.io.Writer) !void {
        var i: usize = 0;

        try writer.print("{x:0>7}", .{total_bytes_read});
        while (i < bytes_read) : (i += 2) {
            if (i + 1 < bytes_read) {
                try writer.print("    {x:0>2}{x:0>2}", .{ line[i + 1], line[i] });
            } else {
                try writer.print("    {x:0>4}", .{line[i]});
            }
        }
        try writer.print("\n", .{});
    }

    fn canonicalDump(line: [16]u8, bytes_read: usize, total_bytes_read: usize, writer: *std.io.Writer) !void {
        try writer.print("{x:0>8} ", .{total_bytes_read});

        for (0..bytes_read) |i| {
            if (i == 8) try writer.print(" ", .{});
            try writer.print(" {x:0>2}", .{line[i]});
        }

        var rem = 16 - @as(u8, @intCast(bytes_read));

        while (rem > 0) {
            try writer.print("   ", .{});
            if (rem == 8) try writer.print(" ", .{});
            rem -= 1;
        }

        try writer.print("  |", .{});
        for (0..bytes_read) |i| {
            const char = if (std.ascii.isPrint(line[i])) line[i] else '.';
            try writer.print("{c}", .{char});
        }
        try writer.print("|\n", .{});
    }
};

fn getSuffixMult(suffix: u8) usize {
    switch (suffix) {
        'b' => return 512,
        'k' => return 1024,
        'm' => return 1048576,
        'g' => return 1073741824,
        else => return 1,
    }
}

fn processArgs(args: [][:0]u8, allocator: std.mem.Allocator) (ParseError || std.mem.Allocator.Error)!struct {
    options: Options,
    filename: ?[]const u8,
} {
    var options = Options.init();
    errdefer options.deinit(allocator);
    var filename: ?[]u8 = null;

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

                        if (i >= args.len) return ParseError.MissingLengthArgument;

                        const len_str = args[i];

                        const len = std.fmt.parseInt(usize, len_str, 10) catch {
                            return ParseError.InvalidNumber;
                        };

                        options.length = len;
                    },
                    's' => {
                        i += 1;
                        if (i >= args.len) return ParseError.MissingOffsetArgument;
                        const off_set_arg = args[i];

                        var off_set_str: []u8 = off_set_arg;
                        const last = off_set_str[off_set_str.len - 1];
                        var off_set_num: usize = 0;
                        var multiplier: usize = 1;

                        switch (last) {
                            'b', 'k', 'm', 'g' => {
                                multiplier = getSuffixMult(last);
                                off_set_str = off_set_str[0 .. off_set_str.len - 1];
                            },
                            else => {},
                        }

                        if (off_set_str[0] == '0' and off_set_str.len >= 2) {
                            if (off_set_str[1] == 'x' or off_set_str[1] == 'X') {
                                off_set_num = std.fmt.parseInt(usize, off_set_str[2..], 16) catch {
                                    return ParseError.InvalidOffset;
                                };
                                if (last == 'b') {
                                    off_set_num = off_set_num * 16 + 11;
                                    multiplier = 1;
                                }
                            } else {
                                off_set_num = std.fmt.parseInt(usize, off_set_str[1..], 8) catch {
                                    return ParseError.InvalidOffset;
                                };
                            }
                        } else {
                            off_set_num = std.fmt.parseInt(usize, off_set_str, 10) catch {
                                return ParseError.InvalidOffset;
                            };
                        }
                        options.offset = off_set_num * multiplier;
                    },
                    else => {},
                }
            }
        } else {
            filename = arg;
        }
    }

    return .{
        .options = options,
        .filename = filename,
    };
}

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const processedArgs = try processArgs(args, allocator);
    const opts = processedArgs.options;

    const filename = processedArgs.filename;

    var hexDump = try HexDump.init(filename, opts, allocator);
    defer hexDump.deinit();

    // std.debug.print("File: {s}\n", .{filename});

    // std.debug.print("File len: {d}\n", .{hexDump.file_size});

    // std.debug.print("args len {d}\n", .{opts.formats.items.len});

    // std.debug.print("Offset: {d}\n", .{opts.offset});

    // for (opts.formats.items) |f| {
    //     std.debug.print("{}\n", .{f});
    // }

    try hexDump.process();

    return 0;
}
