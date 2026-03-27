const std = @import("std");

const Io = std.Io;
const Reader = Io.Reader;
const Parser = @This();

const testing = std.testing;

pub const Value = struct {
    data: []const u8,
};

pub const Command = struct {
    args: []Value,

    pub fn deinit(self: *Command, allocator: std.mem.Allocator) void {
        for (self.args) |value| {
            allocator.free(value.data);
        }

        allocator.free(self.args);
    }

    pub fn get_arg(self: *Command, index: usize) Value {
        return self.args[index];
    }

    pub fn count(self: Command) usize {
        return self.args.len;
    }
};

pub fn parseCommand(reader: *Reader, allocator: std.mem.Allocator) !Command {
    const line = try Parser.read_line(reader);

    if (line.len == 0 or line[0] != '*') {
        return error.InvalidProtocol;
    }

    const arg_count = try std.fmt.parseInt(u16, line[1..], 10);
    const args = try allocator.alloc(Value, arg_count);

    var cmd = Command{ .args = args };
    errdefer cmd.deinit(allocator);

    for (0..arg_count) |i| {
        const bulk_line = try Parser.read_line(reader);
        const data = try readBulk(reader, bulk_line, allocator);
        args[i] = Value{ .data = data };
    }

    return cmd;
}

pub fn read_line(reader: *Reader) ![]const u8 {
    const line_clrf = reader.takeDelimiterInclusive('\n') catch |err| {
        if (err == error.ReadFailed) return error.EndOfStream;
        return err;
    };

    var len = line_clrf.len;

    if (line_clrf.len < 2 or line_clrf[len - 1] != '\n' or line_clrf[len - 2] != '\r') {
        return error.InvalidProtocol;
    }

    len -= 2;

    return line_clrf[0..len];
}

pub fn readBulk(reader: *Reader, line: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    if (line.len == 0 or line[0] != '$') {
        return error.InvalidProtocol;
    }

    const len = try std.fmt.parseInt(u32, line[1..], 10);

    const usize_len: usize = @intCast(len);
    const data = try allocator.alloc(u8, usize_len);
    errdefer allocator.free(data);

    try reader.readSliceAll(data);

    const cr = try reader.takeByte();
    const rl = try reader.takeByte();

    if (cr != '\r' or rl != '\n') {
        return error.InvalidProtocol;
    }

    return data;
}

test "parser: simple ping command" {
    const allocator = testing.allocator;

    const data = "*1\r\n$4\r\nPING\r\n";
    var fixed_reader = Reader.fixed(data);

    var command = try parseCommand(&fixed_reader, allocator);
    defer command.deinit(allocator);

    try testing.expectEqual(command.count(), 1);
    try testing.expectEqualStrings("PING", command.get_arg(0).data);
}

test "parser: multiple arguments" {
    const allocator = std.testing.allocator;

    const data = "*3\r\n$3\r\nSET\r\n$7\r\nkeytest\r\n$5\r\nvalue\r\n";

    var fixed_reader = Reader.fixed(data);

    var command = try parseCommand(&fixed_reader, allocator);
    defer command.deinit(allocator);

    try testing.expectEqual(command.count(), 3);

    try testing.expectEqualStrings("SET", command.get_arg(0).data);
    try testing.expectEqualStrings("keytest", command.get_arg(1).data);
    try testing.expectEqualStrings("value", command.get_arg(2).data);
}

test "parser: invalid starting byte" {
    const allocator = std.testing.allocator;

    const data = "+OK\r\n";

    var fixed_reader = Reader.fixed(data);

    try testing.expectError(error.InvalidProtocol, parseCommand(&fixed_reader, allocator));
}

test "parser: truncated bulk string" {
    const allocator = std.testing.allocator;

    const data = "$100\r\nsamibagpulainemasf\r\n";

    var fixed_reader = Reader.fixed(data);

    try testing.expectError(error.EndOfStream, readBulk(&fixed_reader, "$100", allocator));
}
