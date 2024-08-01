const std = @import("std");
const tools = @import("tools.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn process_tcp(server: std.net.Server.Connection, header: *const []const u8) !void {
    const proxyOrNull = get_proxy(header);
    if (proxyOrNull) |proxy| {
        var proxy_buffer = try allocator.alloc(u8, 128);
        defer allocator.free(proxy_buffer);
        const decoder = std.base64.standard.Decoder;
        const decoded_size = try decoder.calcSizeForSlice(proxy);
        try decoder.decode(proxy_buffer[0..decoded_size], proxy);
        _ = tools.xor_cipher(&proxy_buffer, decoded_size, 0);
        var host_port = std.mem.split(u8, proxy_buffer[0..decoded_size], ":");
        const host = host_port.first();
        const portOrNull = host_port.next();
        if (portOrNull) |port| {
            const uport = try std.fmt.parseInt(u16, port[0 .. port.len - 1], 10);
            var client = std.http.Client{
                .allocator = allocator,
            };
            defer client.deinit();
            const connection = try client.connect(host, uport, .plain);
            const t1 = try std.Thread.spawn(.{}, tcp_forward, .{ connection.stream, server.stream });
            const t2 = try std.Thread.spawn(.{}, tcp_forward, .{ server.stream, connection.stream });
            t1.join();
            t2.join();
            connection.stream.close();
            server.stream.close();
        }
    }
}

fn tcp_forward(clientStream: std.net.Stream, serverStream: std.net.Stream) !void {
    var buffer = try allocator.alloc(u8, 32768);
    defer allocator.free(buffer);
    var subi: u8 = 0;
    while (true) {
        const rsize = try clientStream.read(buffer);
        if (rsize <= 0) {
            break;
        }
        subi = tools.xor_cipher(&buffer, rsize, subi);
        _ = try serverStream.write(buffer[0..rsize]);
    }
}

pub fn get_proxy(header: *const []const u8) ?[]const u8 {
    if (std.mem.containsAtLeast(u8, header.*, 1, "Meng:")) {
        var firstSplit = std.mem.split(u8, header.*, "Meng:");
        _ = firstSplit.first();
        const proxyLastOrNull = firstSplit.next();
        if (proxyLastOrNull) |proxyLast| {
            var nextSplit = std.mem.split(u8, proxyLast, "\r");
            return std.mem.trim(u8, nextSplit.first(), " ");
        }
    }
    return null;
}
