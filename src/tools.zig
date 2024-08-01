const std = @import("std");

const WEBSOCKET = "websocket";

const HEADERS = .{ "CONNECT", "GET", "POST", "HEAD", "PUT", "COPY", "DELETE", "MOVE", "OPTIONS", "LINK", "UNLINK", "TRACE", "WRAPPER" };

pub fn is_http_header(header: *const []const u8) bool {
    for (HEADERS) |h| {
        if (std.mem.startsWith(u8, h, *header)) {
            return true;
        }
    }
    return false;
}

pub fn response_header(header: *const []const u8) []const u8 {
    var buffer: [4096]u8 = undefined;
    _ = std.ascii.lowerString(&buffer, header.*);
    if (std.mem.containsAtLeast(u8, &buffer, 1, WEBSOCKET)) {
        return "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: CuteBi Network Tunnel, (%>w<%)\r\n\r\n";
    } else if (std.mem.startsWith(u8, &buffer, "connect")) {
        return "HTTP/1.1 200 Connection established\r\nServer: CuteBi Network Tunnel, (%>w<%)\r\nConnection: keep-alive\r\n\r\n";
    } else {
        return "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nServer: CuteBi Network Tunnel, (%>w<%)\r\nConnection: keep-alive\r\n\r\n";
    }
}

pub fn xor_cipher(data: []u8, data_len: usize, pass_sub: u8) u8 {
    if (data_len <= 0) {
        return pass_sub;
    } else {
        const pass_len: u8 = "quanyec".len;
        var pi = pass_sub;
        for (0..data_len) |data_sub| {
            pi = @intCast((data_sub + pass_sub) % pass_len);
            data[data_sub] ^= "quanyec"[pi] | pi;
        }
        return pi + 1;
    }
}
