const std = @import("std");
const Allocator = std.mem.Allocator;
const tools = @import("tools.zig");
const tcp = @import("tcp.zig");

pub fn main() !void {
    const address = try std.net.Address.parseIp("0.0.0.0", 1080);
    var http_server = try address.listen(.{
        .reuse_address = true,
    });

    while (true) {
        const conn = try http_server.accept();
        _ = try std.Thread.spawn(.{}, handle_connection, .{conn});
    }
}

fn handle_connection(conn: std.net.Server.Connection) void {
    var buffer: [4096]u8 = undefined;

    while (true) {
        const size: usize = conn.stream.readAll(&buffer) catch |err| {
            std.debug.print("read error: {any}\n", .{err});
            return;
        };
        if (size <= 0) {
            std.debug.print("connection has been closed\n", .{});
            return;
        } else {
            std.debug.print("Handle http request...\n", .{});
            conn.stream.writeAll(tools.response_header(&buffer[0..size])) catch continue;
            if (!std.mem.containsAtLeast(u8, buffer[0..size], 1, "httpUDP")) {
                tcp.process_tcp(conn, &buffer[0..size]) catch continue;
            }
        }
    }
}
