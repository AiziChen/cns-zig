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
        errdefer conn.stream.close();
        _ = try std.Thread.spawn(.{}, handle_connection, .{conn.stream});
    }
}

fn handle_connection(conn: std.net.Stream) !void {
    errdefer conn.close();
    var buffer: [4096]u8 = undefined;
    defer std.debug.print("Connection has been closed\n", .{});
    const size = conn.read(&buffer) catch |err| {
        std.debug.print("read error: {any}\n", .{err});
        return;
    };
    if (size == 0) {
        std.debug.print("Connection closed earlier\n", .{});
        return error.ConnectionCloseEarlier;
    } else {
        const data = buffer[0..size];
        if (tools.is_http_header(data)) {
            // handle http request
            std.debug.print("Handle http request...\n", .{});
            try conn.writeAll(tools.response_header(data));
            if (!std.mem.containsAtLeast(u8, data, 1, "httpUDP")) {
                try tcp.process_tcp(&conn, data);
            }
        } else {
            // handle tcp request
            defer conn.close();
        }
    }
}
