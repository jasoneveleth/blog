const std = @import("std");
const io = std.io;
const types = @import("types.zig");

pub fn render(writer: *io.Writer, parsed: types.Parsed) !void {
    var buffer: [4096]u8 = undefined;
    const head_file = try std.fs.cwd().openFile("content/html/head.html", .{});
    defer head_file.close();
    var head_file_reader = head_file.reader(&buffer);
    var head_reader = &head_file_reader.interface;
    _ = try head_reader.streamRemaining(writer);

    try renderNode(writer, &parsed, parsed.root);

    const foot = try std.fs.cwd().openFile("content/html/foot_logging.html", .{});
    defer foot.close();
    var foot_file_reader = foot.reader(&buffer);
    var foot_reader = &foot_file_reader.interface;
    _ = try foot_reader.streamRemaining(writer);
}

fn renderNode(writer: *io.Writer, parsed: *const types.Parsed, node_id: types.NodeID) std.io.Writer.Error!void {
    const node: types.Node = parsed.getNode(node_id);

    switch (node.kind) {
        .para => |slice| {
            try renderParagraph(writer, parsed, slice);
        },
        .heading => |heading| {
            try renderHeading(writer, parsed, heading.content);
        },
        .text => {
            const text_slice = parsed.text[node.start.into() .. node.start.into() + node.len];
            try writer.writeAll(text_slice);
        },
        else => {},
    }
}

fn renderParagraph(writer: *io.Writer, parsed: *const types.Parsed, slice: types.NodeSlice) !void {
    try writer.writeAll("<p>");
    for (parsed.getSlice(slice)) |child_id| {
        try renderNode(writer, parsed, child_id);
    }
    try writer.writeAll("</p>\n");
}

fn renderHeading(writer: *io.Writer, parsed: *const types.Parsed, heading: types.NodeSlice) !void {
    try writer.writeAll("<h1>");
    for (parsed.getSlice(heading)) |child_id| {
        try renderNode(writer, parsed, child_id);
    }
    try writer.writeAll("</h1>\n");
}
