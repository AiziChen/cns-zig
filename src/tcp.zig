const std = @import("std");
const tools = @import("tools.zig");

pub fn process_tcp(server: std.net.Stream, header: *const []const u8) !void {
    const proxyOrNull = get_proxy(header);
    if (proxyOrNull) |proxy| {
        var proxy_buffer: [128]u8 = undefined;
        const decoder = std.base64.standard.Decoder;
        const decoded_size = try decoder.calcSizeForSlice(proxy);
        try decoder.decode(proxy_buffer[0..decoded_size], proxy);
        _ = tools.xor_cipher(&proxy_buffer, decoded_size, 0);
        var host_port = std.mem.split(u8, proxy_buffer[0 .. decoded_size - 1], ":");
        const host = host_port.first();
        const portOrNull = host_port.next();
        if (portOrNull) |port| {
            const uport = try std.fmt.parseInt(u16, port[0..port.len], 10);
            var client = try std.net.tcpConnectToAddress(try std.net.Address.parseIp(host, uport));
            defer client.close();
            const t1 = try std.Thread.spawn(.{}, tcp_forward, .{ client, server });
            const t2 = try std.Thread.spawn(.{}, tcp_forward, .{ server, client });
            t1.join();
            t2.join();
        }
    }
}

fn tcp_forward(fromStream: std.net.Stream, toStream: std.net.Stream) !void {
    var buffer: [8192]u8 = undefined;
    var subi: u8 = 0;
    while (true) {
        const rsize = try fromStream.read(&buffer);
        if (rsize <= 0) {
            break;
        }
        subi = tools.xor_cipher(&buffer, rsize, subi);
        _ = try toStream.write(buffer[0..rsize]);
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
