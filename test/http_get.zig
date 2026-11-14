const std = @import("std");
const print = std.debug.print;
const http = std.http;

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const arena = init.arena.allocator();

    var url: []const u8 = "https://edgebin.liujiacai.net/headers";
    const args = try init.minimal.args.toSlice(arena);
    if (args.len > 1) {
        url = args[1];
    }

    var client: http.Client = .{ .allocator = gpa, .io = io };
    defer client.deinit();

    const uri = try std.Uri.parse(url);
    var req = try client.request(.GET, uri, .{
        .extra_headers = &.{.{ .name = "Custom-header", .value = "Custom Value" }},
    });
    defer req.deinit();

    try req.sendBodiless();

    var redirect_buffer: [1024]u8 = undefined;
    var response = try req.receiveHead(&redirect_buffer);
    var iter = response.head.iterateHeaders();
    while (iter.next()) |header| {
        std.debug.print("Name:{s}, Value:{s}\n", .{ header.name, header.value });
    }

    // Occasionally, edgebin might time out or return non-200 in unstable network environments
    if (response.head.status != .ok) {
        std.debug.print("Response status: {s}\n", .{@tagName(response.head.status)});
        return;
    }
    var transfer_buffer: [4096]u8 = undefined;
    var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var decompress: http.Decompress = undefined;
    const body = try response.readerDecompressing(&transfer_buffer, &decompress, &decompress_buffer).allocRemaining(gpa, .unlimited);
    defer gpa.free(body);
    print("Body:\n{s}\n", .{body});

    const Resp = struct {
        @"custom-header": []const u8,
    };
    const json = try std.json.parseFromSlice(Resp, gpa, body, .{ .ignore_unknown_fields = true });
    defer json.deinit();

    try std.testing.expectEqualStrings("Custom Value", json.value.@"custom-header");
}
