const std = @import("std");
const Regex = @import("regex").Regex;
const tools = @import("tools.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn process_tcp(_: std.net.Server.Connection, header: *const []const u8) !void {
    var regex = try Regex.compile(allocator, "Meng:\\s*(.+)\n");
    regex.deinit();
    const proxyOrNull = try get_proxy(&regex, header);
    if (proxyOrNull) |proxy| {
        var host_port = std.mem.split(u8, proxy, ":");
        const host = host_port.first();
        const portOrNull = host_port.next();
        if (portOrNull) |port| {
            const uport = try std.fmt.parseInt(u8, port, 10);
            // const uri = try std.Uri.parse(host_port);
            var client = std.http.Client{
                .allocator = allocator,
            };
            const connection = try client.connect(host, uport, .plain);
            _ = try std.Thread.spawn(.{}, tcp_forward, .{ &client, connection });
        }
    }
}

fn tcp_forward(client: *std.http.Client, connection: *std.http.Client.Connection) !void {
    defer client.deinit();
    defer connection.close(allocator);
    var buffer = try allocator.alloc(u8, 4096);
    defer allocator.free(buffer);
    var subi: usize = 0;
    while (true) {
        const rsize = try connection.read(buffer);
        if (rsize <= 0) {
            break;
        }
        subi = tools.xor_cipher(&buffer, rsize, subi);
        _ = try connection.write(buffer[0..rsize]);
        try connection.flush();
    }
}
fn get_proxy(regex: *Regex, header: *const []const u8) !?[]const u8 {
    if (try regex.captures(header.*)) |capture| {
        if (capture.len() == 2) {
            if (capture.sliceAt(1)) |content| {
                return content;
            }
        }
    }
    return null;
}
