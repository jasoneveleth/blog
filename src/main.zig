const std = @import("std");
const parse = @import("parse.zig");
const render = @import("render.zig");
const types = @import("types.zig");


pub fn main() !void {
    std.debug.print("`Node` size: {}\n`NodeKind` size: {}\n", .{
        @sizeOf(types.Node),
        @sizeOf(types.NodeKind),
    });
    var buffer2: [4096]u8 = undefined;

    // we don't use a Reader object here because we'd end up providing it the buffer (for use internally)
    // and then also have to read into that same buffer, which is silly

    const head_file = try std.fs.cwd().openFile("content/2023/07/20/why-a-blog.md", .{ });
    defer head_file.close();
    const bytes_read = try head_file.read(&buffer2);
    if (bytes_read > 4000) {
        return error.FileTooLarge;
    }
    const input = buffer2[0..bytes_read];

    const parsed: types.Parsed = parse.parse(input) catch |err| {
        std.debug.print("Error during parsing: {}\n", .{err});
        return err;
    };

    const out_file = try std.fs.cwd().createFile("dist/index.html", .{.truncate = true, .mode = 0o644});
    defer out_file.close();

    var buffer: [4096]u8 = undefined;
    var out_writer: std.fs.File.Writer = out_file.writer(&buffer);
    var writer_ptr = &out_writer.interface;
    try render.render(writer_ptr, parsed);
    writer_ptr.flush() catch |err| {
        std.debug.print("Error during rendering: {}\n", .{err});
        return err;
    };
}