const std = @import("std");
const Io = std.Io;

const zigdis = @import("zigdis");

const Server = @import("server.zig").Server;
const Parser = @import("parser.zig");

pub fn main(init: std.process.Init) !void {
    const host = "127.0.0.1";
    const port: u16 = 6379;

    const io = init.io;

    const server = try Server.init(host, port, io);
    var listening = try server.listen();

    while (true) {
        const gpa = init.gpa;
        var arena = std.heap.ArenaAllocator.init(gpa);
        defer arena.deinit();

        const allocator = arena.allocator();

        var connection = listening.accept(io) catch |err| {
            std.debug.print("Connection to client interrupted: {}\n", .{err});
            continue;
        };

        defer connection.close(io);

        var read_buffer: [1024]u8 = undefined;
        var reader = connection.reader(io, &read_buffer);
        const reader_interface = &reader.interface;

        var command = Parser.parseCommand(reader_interface, allocator) catch |err| {
            std.debug.print("Failed to parse command: {}\n", .{err});
            continue;
        };

        const count = command.count();

        const first_arg = command.get_arg(0).data;

        std.debug.print("Arg_count: {d}\n", .{count});
        std.debug.print("first arg: {s}\n", .{first_arg});
    }
}
