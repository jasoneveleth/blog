const std = @import("std");
const parse = @import("parse.zig");
const render = @import("render.zig");
const template = @import("template.zig");
const types = @import("types.zig");

pub fn main(init: std.process.Init) !void {
    var args = std.process.Args.iterate(init.minimal.args);
    _ = args.next();

    const cmd = args.next() orelse {
        usage();
        return;
    };

    if (std.mem.eql(u8, cmd, "build")) {
        const content_dir = args.next() orelse "content";
        const dist_dir = args.next() orelse "dist";
        const tmpl_dir = args.next() orelse "content/html";
        const prepath = args.next() orelse "";
        try buildAll(init, content_dir, dist_dir, tmpl_dir, prepath);
    } else {
        const out_path = args.next();
        const tmpl_dir = args.next() orelse "content/html";
        if (out_path == null) {
            const src = try std.Io.Dir.cwd().readFileAlloc(init.io, cmd, init.gpa, .limited(4 * 1024 * 1024));
            defer init.gpa.free(src);
            const parsed = try parse.parse(src, init.gpa);
            const body_result = try render.renderBody(&parsed, init.gpa, "");
            defer init.gpa.free(body_result.html);
            std.debug.print("title: {s}\n", .{parsed.frontmatter.title});
            std.debug.print("nodes: {d}  html bytes: {d}  hasmath={} hascode={}\n", .{
                parsed.nodes.items.len, body_result.html.len, body_result.hasmath, body_result.hascode,
            });
        } else {
            try renderPost(init, cmd, out_path.?, tmpl_dir, "");
        }
    }
}

fn usage() void {
    std.debug.print(
        \\usage:
        \\  blog <file.md> [out.html] [template_dir]
        \\  blog build [content_dir] [dist_dir] [template_dir] [prepath]
        \\
    , .{});
}

fn renderPost(
    init: std.process.Init,
    md_path: []const u8,
    out_path: []const u8,
    tmpl_dir: []const u8,
    prepath: []const u8,
) !void {
    const src = try std.Io.Dir.cwd().readFileAlloc(init.io, md_path, init.gpa, .limited(4 * 1024 * 1024));
    defer init.gpa.free(src);

    const parsed = try parse.parse(src, init.gpa);

    // Always render with empty prepath; apply prepath substitution as post-process.
    const body_result = try render.renderBody(&parsed, init.gpa, "");
    defer init.gpa.free(body_result.html);

    const date_str = try std.fmt.allocPrint(init.gpa, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        parsed.frontmatter.date.year,
        parsed.frontmatter.date.month,
        parsed.frontmatter.date.day,
    });
    defer init.gpa.free(date_str);

    const last_modified = if (parsed.frontmatter.updated) |u|
        try std.fmt.allocPrint(init.gpa, "{d:0>4}-{d:0>2}-{d:0>2}", .{ u.year, u.month, u.day })
    else
        try init.gpa.dupe(u8, date_str);
    defer init.gpa.free(last_modified);

    const ctx = template.Context{
        .title = parsed.frontmatter.title,
        .date = date_str,
        .last_modified = last_modified,
        .githubsource = parsed.frontmatter.githubsource,
        .hasmath = body_result.hasmath,
        .hascode = body_result.hascode,
        .descr = parsed.frontmatter.descr,
    };

    var page_buf: std.ArrayListUnmanaged(u8) = .empty;
    defer page_buf.deinit(init.gpa);

    try processTemplate(init, &ctx, tmpl_dir, "head.html", &page_buf);
    try page_buf.appendSlice(init.gpa, "\n<div class=\"franklin-content\">");
    try page_buf.appendSlice(init.gpa, body_result.html);
    try processTemplate(init, &ctx, tmpl_dir, "page_foot.html", &page_buf);
    try page_buf.appendSlice(init.gpa, "\n</div>\n");
    try processTemplate(init, &ctx, tmpl_dir, "foot.html", &page_buf);

    // Apply prepath: insert /prepath before absolute paths in href/src attributes.
    const final_html = if (prepath.len > 0)
        try applyPrepath(page_buf.items, prepath, init.gpa)
    else
        page_buf.items;
    defer if (prepath.len > 0) init.gpa.free(final_html);

    // Ensure output directory exists.
    // Ignore NotDir: on macOS /tmp is a symlink; the dir is still accessible.
    if (std.fs.path.dirname(out_path)) |dir_path| {
        std.Io.Dir.cwd().createDirPath(init.io, dir_path) catch |e| switch (e) {
            error.NotDir => {},
            else => return e,
        };
    }

    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = out_path, .data = final_html });
    std.debug.print("wrote {s}\n", .{out_path});
}

fn processTemplate(
    init: std.process.Init,
    ctx: *const template.Context,
    tmpl_dir: []const u8,
    filename: []const u8,
    buf: *std.ArrayListUnmanaged(u8),
) !void {
    const path = try std.fmt.allocPrint(init.gpa, "{s}/{s}", .{ tmpl_dir, filename });
    defer init.gpa.free(path);
    const tmpl = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(64 * 1024));
    defer init.gpa.free(tmpl);
    try template.process(tmpl, ctx, buf, init.gpa, tmpl_dir, init.io);
}

// Insert /prepath before absolute paths in href="/" and src="/" attributes.
// Skips protocol-relative URLs (href="//") and external URLs.
fn applyPrepath(html: []const u8, prepath: []const u8, gpa: std.mem.Allocator) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    var i: usize = 0;
    while (i < html.len) {
        // href="/ but not href="//
        if (i + 7 <= html.len and std.mem.eql(u8, html[i .. i + 6], "href=\"") and
            html[i + 6] == '/' and !(i + 8 <= html.len and html[i + 7] == '/'))
        {
            try out.appendSlice(gpa, "href=\"/");
            try out.appendSlice(gpa, prepath);
            i += 6; // consume href=" only; leave the / for next iteration
            continue;
        }
        // src="/ but not src="//
        if (i + 6 <= html.len and std.mem.eql(u8, html[i .. i + 5], "src=\"") and
            html[i + 5] == '/' and !(i + 7 <= html.len and html[i + 6] == '/'))
        {
            try out.appendSlice(gpa, "src=\"/");
            try out.appendSlice(gpa, prepath);
            i += 5; // consume src=" only; leave the /
            continue;
        }
        try out.append(gpa, html[i]);
        i += 1;
    }
    return out.toOwnedSlice(gpa);
}

fn buildAll(
    init: std.process.Init,
    content_dir: []const u8,
    dist_dir: []const u8,
    tmpl_dir: []const u8,
    prepath: []const u8,
) !void {
    // Copy static asset directories verbatim.
    for ([_][]const u8{ "css", "libs", "assets" }) |sub| {
        const src_path = try std.fmt.allocPrint(init.gpa, "{s}/{s}", .{ content_dir, sub });
        defer init.gpa.free(src_path);
        const dst_path = try std.fmt.allocPrint(init.gpa, "{s}/{s}", .{ dist_dir, sub });
        defer init.gpa.free(dst_path);
        copyDirRecursive(init, src_path, dst_path) catch |e| {
            std.debug.print("warning: skipping {s}: {}\n", .{ src_path, e });
        };
    }

    // Walk content dir and render markdown files.
    var dir = try std.Io.Dir.cwd().openDir(init.io, content_dir, .{ .iterate = true });
    defer dir.close(init.io);
    var walker = try dir.walk(init.gpa);
    defer walker.deinit();

    while (try walker.next(init.io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".md")) continue;
        // Skip non-post subdirectories.
        if (std.mem.startsWith(u8, entry.path, "html/") or
            std.mem.startsWith(u8, entry.path, "css/") or
            std.mem.startsWith(u8, entry.path, "libs/") or
            std.mem.startsWith(u8, entry.path, "assets/")) continue;

        // Walker entry memory is invalidated by next call; copy the path.
        const rel = try init.gpa.dupe(u8, entry.path);
        defer init.gpa.free(rel);

        const md_path = try std.fmt.allocPrint(init.gpa, "{s}/{s}", .{ content_dir, rel });
        defer init.gpa.free(md_path);
        const out_path = try getOutPath(init.gpa, dist_dir, rel);
        defer init.gpa.free(out_path);

        renderPost(init, md_path, out_path, tmpl_dir, prepath) catch |e| {
            std.debug.print("error rendering {s}: {}\n", .{ md_path, e });
        };
    }
}

// Map a content-relative md path to a dist output path.
// YYYY/MM/DD/slug.md  →  dist/YYYY/MM/DD/slug/index.html  (pretty URL)
// index.md            →  dist/index.html
// 404.md              →  dist/404.html
fn getOutPath(gpa: std.mem.Allocator, dist_dir: []const u8, rel_path: []const u8) ![]u8 {
    const stem = rel_path[0 .. rel_path.len - 3]; // strip .md
    var slash_count: usize = 0;
    for (rel_path) |c| if (c == '/') { slash_count += 1; };
    if (slash_count == 3) {
        return std.fmt.allocPrint(gpa, "{s}/{s}/index.html", .{ dist_dir, stem });
    } else {
        return std.fmt.allocPrint(gpa, "{s}/{s}.html", .{ dist_dir, stem });
    }
}

fn copyDirRecursive(init: std.process.Init, src_dir: []const u8, dst_dir: []const u8) !void {
    var dir = try std.Io.Dir.cwd().openDir(init.io, src_dir, .{ .iterate = true });
    defer dir.close(init.io);
    try std.Io.Dir.cwd().createDirPath(init.io, dst_dir);
    var walker = try dir.walk(init.gpa);
    defer walker.deinit();
    while (try walker.next(init.io)) |entry| {
        if (entry.kind != .file) continue;
        const rel = try init.gpa.dupe(u8, entry.path);
        defer init.gpa.free(rel);
        const src_file = try std.fmt.allocPrint(init.gpa, "{s}/{s}", .{ src_dir, rel });
        defer init.gpa.free(src_file);
        const dst_file = try std.fmt.allocPrint(init.gpa, "{s}/{s}", .{ dst_dir, rel });
        defer init.gpa.free(dst_file);
        try std.Io.Dir.copyFile(
            std.Io.Dir.cwd(), src_file,
            std.Io.Dir.cwd(), dst_file,
            init.io, .{ .make_path = true, .replace = true },
        );
    }
}
