const std = @import("std");
const Io = std.Io;

const zigdis = @import("zigdis");

const Server = @import("server.zig").Server;

pub fn main(init: std.process.Init) !void {
    const host = "127.0.0.1";
    const port: u16 = 6379;

    const io = init.io;

    const server = try Server.init(host, port, io);
    var listening = try server.listen();

    while (true) {
        var connection = listening.accept(io) catch |err| {
            std.debug.print("Connection to client interrupted: {}\n", .{err});
            continue;
        };

        defer connection.close(io);

        var read_buffer: [1024]u8 = undefined;
        var reader = connection.reader(io, &read_buffer);
        const reader_interface = &reader.interface;

        const line = try reader_interface.takeDelimiterInclusive('\n');

        std.debug.print("Hello: {s}\n", .{line});
    }
}
