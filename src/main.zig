const std = @import("std");
const tools = @import("tools.zig");
const tcp = @import("tcp.zig");

pub fn main() !void {
    const address = try std.net.Address.parseIp("0.0.0.0", 1080);
    var http_server = try address.listen(.{
        .kernel_backlog = 1024,
        .reuse_address = true,
    });

    while (true) {
        const conn = try http_server.accept();
        _ = try std.Thread.spawn(.{}, handle_connection, .{conn.stream});
    }
}

fn handle_connection(conn: std.net.Stream) void {
    var buffer: [4096]u8 = undefined;
    defer conn.close();
    while (true) {
        const size: usize = conn.read(&buffer) catch |err| {
            std.debug.print("read error: {any}\n", .{err});
            return;
        };
        if (size <= 0) {
            std.debug.print("Connection closed earlier\n", .{});
            return;
        } else {
            if (tools.is_http_header(buffer[0..size])) {
                // handle http request
                std.debug.print("Handle http request...\n", .{});
                conn.writeAll(tools.response_header(buffer[0..size])) catch continue;
                if (!std.mem.containsAtLeast(u8, buffer[0..size], 1, "httpUDP")) {
                    tcp.process_tcp(conn, &buffer[0..size]) catch continue;
                    std.debug.print("Connection has been closed\n", .{});
                }
            } else {
                // handle tcp request
            }
        }
    }
}
