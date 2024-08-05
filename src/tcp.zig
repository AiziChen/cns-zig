const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const tools = @import("tools.zig");
const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("posix-extends.c");
});

pub fn process_tcp(clientStream: *const std.net.Stream, header: []const u8) !void {
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
            var tcpStream = tcpConnectToAddress(try std.net.Address.parseIp(host, uport)) catch {
                try clientStream.writeAll(try std.fmt.bufPrint(&proxy_buffer, "Proxy address [{s}:{s}] ResolveTCP() error", .{ host, port }));
                return;
            };
            defer tcpStream.close();
            _ = try std.Thread.spawn(.{}, tcp_forward, .{ &tcpStream, clientStream });
            try tcp_forward(clientStream, &tcpStream);
        } else {
            try clientStream.writeAll("No proxy host");
        }
    } else {
        try clientStream.writeAll("No proxy host");
    }
}

fn tcp_forward(fromStream: *const std.net.Stream, toStream: *const std.net.Stream) !void {
    var buffer: [8192]u8 = undefined;
    var subi: u8 = 0;
    while (true) {
        const rsize = try fromStream.read(&buffer);
        if (rsize == 0) {
            break;
        }
        subi = tools.xor_cipher(&buffer, rsize, subi);
        try toStream.writeAll(buffer[0..rsize]);
    }
}

pub fn get_proxy(header: []const u8) ?[]const u8 {
    if (std.mem.containsAtLeast(u8, header, 1, "Meng:")) {
        var firstSplit = std.mem.split(u8, header, "Meng:");
        _ = firstSplit.first();
        const proxyLastOrNull = firstSplit.next();
        if (proxyLastOrNull) |proxyLast| {
            var nextSplit = std.mem.split(u8, proxyLast, "\r");
            return std.mem.trim(u8, nextSplit.first(), " ");
        }
    }
    return null;
}

fn tcpConnectToAddress(address: std.net.Address) std.net.TcpConnectToAddressError!std.net.Stream {
    const nonblock = 0;
    const sock_flags = posix.SOCK.STREAM | nonblock |
        (if (builtin.os.tag == .windows) 0 else posix.SOCK.CLOEXEC);
    const sockfd = try posix.socket(address.any.family, sock_flags, posix.IPPROTO.TCP);
    errdefer std.net.Stream.close(.{ .handle = sockfd });

    posix.setsockopt(
        sockfd,
        posix.SOL.SOCKET,
        posix.SO.KEEPALIVE,
        &std.mem.toBytes(@as(c_int, 0)),
    ) catch return error.Unexpected;

    if (c.so_rectimeo2zero(sockfd) < 0) {
        return error.Unexpected;
    }
    if (c.so_sndtimeo2zero(sockfd) < 0) {
        return error.Unexpected;
    }
    try posix.connect(sockfd, &address.any, address.getOsSockLen());

    return std.net.Stream{ .handle = sockfd };
}
