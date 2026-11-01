const std = @import("std");

pub const Context = struct {
    title: []const u8 = "",
    date: []const u8 = "", // "YYYY-MM-DD"
    author: []const u8 = "Jason Eveleth",
    last_modified: []const u8 = "", // for fd_mtime
    githubsource: ?[]const u8 = null,
    description: []const u8 = "",
    hasmath: bool = false,
    hascode: bool = false,
    descr: bool = false,

    fn fillValue(ctx: *const Context, key: []const u8) []const u8 {
        if (std.mem.eql(u8, key, "title")) return ctx.title;
        if (std.mem.eql(u8, key, "date")) return ctx.date;
        if (std.mem.eql(u8, key, "author")) return ctx.author;
        if (std.mem.eql(u8, key, "fd_mtime")) return ctx.last_modified;
        if (std.mem.eql(u8, key, "githubsource")) return ctx.githubsource orelse "";
        if (std.mem.eql(u8, key, "description")) return ctx.description;
        return "";
    }

    fn evalCondition(ctx: *const Context, directive: []const u8) bool {
        if (std.mem.startsWith(u8, directive, "if ")) {
            const key = std.mem.trim(u8, directive[3..], " \t");
            if (std.mem.eql(u8, key, "hasmath")) return ctx.hasmath;
            if (std.mem.eql(u8, key, "hascode")) return ctx.hascode;
            if (std.mem.eql(u8, key, "description")) return ctx.description.len > 0;
            return false;
        }
        if (std.mem.startsWith(u8, directive, "ifdef ")) {
            const key = std.mem.trim(u8, directive[6..], " \t");
            if (std.mem.eql(u8, key, "descr")) return ctx.descr;
            return false;
        }
        if (std.mem.startsWith(u8, directive, "isdef ")) {
            const key = std.mem.trim(u8, directive[6..], " \t");
            if (std.mem.eql(u8, key, "githubsource")) return ctx.githubsource != null;
            return false;
        }
        if (std.mem.startsWith(u8, directive, "isnotpage ")) {
            return true; // for posts, we're never on /tag/* or other excluded pages
        }
        if (std.mem.startsWith(u8, directive, "ispage ")) {
            return false; // posts aren't search.md
        }
        return false;
    }
};

fn isBlockStart(directive: []const u8) bool {
    return std.mem.startsWith(u8, directive, "if ") or
        std.mem.startsWith(u8, directive, "ifdef ") or
        std.mem.startsWith(u8, directive, "isdef ") or
        std.mem.startsWith(u8, directive, "isnotpage ") or
        std.mem.startsWith(u8, directive, "ispage ");
}

// Skip forward past the matching {{end}}, handling nested blocks.
fn skipToEnd(tmpl: []const u8, pos: *usize) void {
    var depth: usize = 1;
    while (pos.* < tmpl.len) {
        if (std.mem.startsWith(u8, tmpl[pos.*..], "{{")) {
            const start = pos.* + 2;
            var j = start;
            while (j + 1 < tmpl.len and !(tmpl[j] == '}' and tmpl[j + 1] == '}')) j += 1;
            const directive = std.mem.trim(u8, tmpl[start..j], " \t\n");
            pos.* = j + 2;
            if (isBlockStart(directive)) {
                depth += 1;
            } else if (std.mem.eql(u8, directive, "end")) {
                depth -= 1;
                if (depth == 0) return;
            }
        } else {
            pos.* += 1;
        }
    }
}

// Process a template string, appending output to buf.
// If until_end is true, stop when {{end}} is encountered (used for conditional bodies).
fn processInner(
    tmpl: []const u8,
    pos: *usize,
    ctx: *const Context,
    buf: *std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,
    template_dir: []const u8,
    io: std.Io,
    until_end: bool,
) !void {
    while (pos.* < tmpl.len) {
        if (!std.mem.startsWith(u8, tmpl[pos.*..], "{{")) {
            try buf.append(allocator, tmpl[pos.*]);
            pos.* += 1;
            continue;
        }

        const dir_start = pos.* + 2;
        var j = dir_start;
        while (j + 1 < tmpl.len and !(tmpl[j] == '}' and tmpl[j + 1] == '}')) j += 1;
        const raw = tmpl[dir_start..j];
        const directive = std.mem.trim(u8, raw, " \t\n");
        pos.* = j + 2;

        if (std.mem.eql(u8, directive, "end")) {
            if (until_end) return;
            // extra {{end}} at top level: ignore
        } else if (std.mem.startsWith(u8, directive, "fill ")) {
            const key = std.mem.trim(u8, directive[5..], " \t");
            try buf.appendSlice(allocator, ctx.fillValue(key));
        } else if (std.mem.startsWith(u8, directive, "insert ")) {
            const filename = std.mem.trim(u8, directive[7..], " \t");
            const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ template_dir, filename });
            defer allocator.free(full_path);
            const included = try std.Io.Dir.cwd().readFileAlloc(io, full_path, allocator, .limited(64 * 1024));
            defer allocator.free(included);
            var inner_pos: usize = 0;
            try processInner(included, &inner_pos, ctx, buf, allocator, template_dir, io, false);
        } else if (isBlockStart(directive)) {
            if (ctx.evalCondition(directive)) {
                try processInner(tmpl, pos, ctx, buf, allocator, template_dir, io, true);
            } else {
                skipToEnd(tmpl, pos);
            }
        } else {
            // Bare {{key}} — treat as fill
            try buf.appendSlice(allocator, ctx.fillValue(directive));
        }
    }
}

pub fn process(
    tmpl: []const u8,
    ctx: *const Context,
    buf: *std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,
    template_dir: []const u8,
    io: std.Io,
) !void {
    var pos: usize = 0;
    try processInner(tmpl, &pos, ctx, buf, allocator, template_dir, io, false);
}
