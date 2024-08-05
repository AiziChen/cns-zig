const std = @import("std");
const posix = std.posix;
const builtin = @import("builtin");
const tools = @import("tools.zig");
const tcp = @import("tcp.zig");
const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("posix-extends.c");
});

pub fn main() !void {
    const address = try std.net.Address.parseIp("0.0.0.0", 1080);
    var http_server = try listen(&address, .{
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
    defer std.debug.print("Connection has been closed\n", .{});
    var buffer: [4096]u8 = undefined;
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
                tcp.process_tcp(&conn, data) catch {
                    return;
                };
            }
        } else {
            // handle tcp request
            defer conn.close();
        }
    }
}

pub const ListenError = posix.SocketError || posix.BindError || posix.ListenError ||
    posix.SetSockOptError || posix.GetSockNameError;
fn listen(address: *const std.net.Address, options: std.net.Address.ListenOptions) ListenError!std.net.Server {
    const nonblock: u32 = if (options.force_nonblocking) posix.SOCK.NONBLOCK else 0;
    const sock_flags = posix.SOCK.STREAM | posix.SOCK.CLOEXEC | nonblock;
    const proto: u32 = if (address.any.family == posix.AF.UNIX) 0 else posix.IPPROTO.TCP;

    const sockfd = try posix.socket(address.any.family, sock_flags, proto);
    var s: std.net.Server = .{
        .listen_address = undefined,
        .stream = .{ .handle = sockfd },
    };
    errdefer s.stream.close();

    if (options.reuse_address or options.reuse_port) {
        try posix.setsockopt(
            sockfd,
            posix.SOL.SOCKET,
            posix.SO.REUSEADDR,
            &std.mem.toBytes(@as(c_int, 1)),
        );
        switch (builtin.os.tag) {
            .windows => {},
            else => try posix.setsockopt(
                sockfd,
                posix.SOL.SOCKET,
                posix.SO.REUSEPORT,
                &std.mem.toBytes(@as(c_int, 1)),
            ),
        }
    }
    try posix.setsockopt(
        sockfd,
        posix.SOL.SOCKET,
        posix.SO.KEEPALIVE,
        &std.mem.toBytes(@as(c_int, 0)),
    );

    if (c.so_rectimeo2zero(sockfd) < 0) {
        return error.Unexpected;
    }
    if (c.so_sndtimeo2zero(sockfd) < 0) {
        return error.Unexpected;
    }

    var socklen = address.getOsSockLen();
    try posix.bind(sockfd, &address.any, socklen);
    try posix.listen(sockfd, options.kernel_backlog);
    try posix.getsockname(sockfd, &s.listen_address.any, &socklen);
    return s;
}
