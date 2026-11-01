const std = @import("std");
const types = @import("types.zig");

const COMMENTS_SCRIPT =
    \\<script src="https://utteranc.es/client.js"
    \\    repo="jasoneveleth/blog"
    \\    issue-term="pathname"
    \\    label="Comment"
    \\    theme="github-light"
    \\    crossorigin="anonymous"
    \\    async>
    \\</script>
;

pub const RenderResult = struct {
    html: []u8,
    hasmath: bool,
    hascode: bool,
};

const HeadingEntry = struct { level: u8, node_id: types.NodeID };

const Renderer = struct {
    parsed: *const types.Parsed,
    allocator: std.mem.Allocator,
    buf: std.ArrayListUnmanaged(u8),
    hasmath: bool,
    hascode: bool,
    has_comments: bool,
    fn_ref_labels: std.ArrayListUnmanaged(types.BufSlice),
    fn_defs: std.ArrayListUnmanaged(types.NodeID),
    headings: std.ArrayListUnmanaged(HeadingEntry),
    prepath: []const u8,

    fn init(parsed: *const types.Parsed, allocator: std.mem.Allocator, prepath: []const u8) Renderer {
        return .{
            .parsed = parsed,
            .allocator = allocator,
            .buf = .empty,
            .hasmath = false,
            .hascode = false,
            .has_comments = false,
            .fn_ref_labels = .empty,
            .fn_defs = .empty,
            .headings = .empty,
            .prepath = prepath,
        };
    }

    fn deinit(r: *Renderer) void {
        r.buf.deinit(r.allocator);
        r.fn_ref_labels.deinit(r.allocator);
        r.fn_defs.deinit(r.allocator);
        r.headings.deinit(r.allocator);
    }

    fn write(r: *Renderer, s: []const u8) !void {
        try r.buf.appendSlice(r.allocator, s);
    }

    fn writeByte(r: *Renderer, c: u8) !void {
        try r.buf.append(r.allocator, c);
    }

    fn print(r: *Renderer, comptime fmt: []const u8, args: anytype) !void {
        const tmp = try std.fmt.allocPrint(r.allocator, fmt, args);
        defer r.allocator.free(tmp);
        try r.buf.appendSlice(r.allocator, tmp);
    }

    fn writeEscaped(r: *Renderer, s: []const u8) !void {
        for (s) |c| switch (c) {
            '&' => try r.write("&amp;"),
            '<' => try r.write("&lt;"),
            '>' => try r.write("&gt;"),
            '"' => try r.write("&quot;"),
            else => try r.writeByte(c),
        };
    }

    fn writeText(r: *Renderer, s: []const u8) !void {
        var i: usize = 0;
        while (i < s.len) {
            if (i + 2 < s.len and s[i] == '-' and s[i + 1] == '-' and s[i + 2] == '-') {
                try r.write("\xe2\x80\x94"); // em dash —
                i += 3;
            } else if (i + 1 < s.len and s[i] == '-' and s[i + 1] == '-') {
                try r.write("\xe2\x80\x93"); // en dash –
                i += 2;
            } else {
                switch (s[i]) {
                    '&' => try r.write("&amp;"),
                    '<' => try r.write("&lt;"),
                    '>' => try r.write("&gt;"),
                    '"' => try r.write("&quot;"),
                    else => try r.writeByte(s[i]),
                }
                i += 1;
            }
        }
    }

    fn collectHeadings(r: *Renderer, ns: types.NodeSlice) !void {
        for (r.parsed.getSlice(ns)) |child_id| {
            const node = r.parsed.getNode(child_id);
            switch (node.kind) {
                .heading => |h| try r.headings.append(r.allocator, .{ .level = h.level, .node_id = child_id }),
                .div => |d| try r.collectHeadings(d.children),
                .blockquote => |children| try r.collectHeadings(children),
                else => {},
            }
        }
    }

    fn getPlainText(r: *Renderer, ns: types.NodeSlice) ![]const u8 {
        var out: std.ArrayListUnmanaged(u8) = .empty;
        errdefer out.deinit(r.allocator);
        for (r.parsed.getSlice(ns)) |child_id| {
            const node = r.parsed.getNode(child_id);
            switch (node.kind) {
                .text, .code_inline, .math_inline, .math_display => {
                    try out.appendSlice(r.allocator, r.parsed.getNodeText(node));
                },
                .bold => |inner| {
                    const s = try r.getPlainText(inner);
                    defer r.allocator.free(s);
                    try out.appendSlice(r.allocator, s);
                },
                .italic => |inner| {
                    const s = try r.getPlainText(inner);
                    defer r.allocator.free(s);
                    try out.appendSlice(r.allocator, s);
                },
                .link => |lk| {
                    const s = try r.getPlainText(lk.content);
                    defer r.allocator.free(s);
                    try out.appendSlice(r.allocator, s);
                },
                .escape => try out.appendSlice(r.allocator, r.parsed.getNodeText(node)),
                else => {},
            }
        }
        return out.toOwnedSlice(r.allocator);
    }

    fn slugify(r: *Renderer, text: []const u8) ![]const u8 {
        var out: std.ArrayListUnmanaged(u8) = .empty;
        errdefer out.deinit(r.allocator);
        for (text) |c| {
            const is_alpha = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
            const is_digit = c >= '0' and c <= '9';
            if (is_alpha or is_digit) {
                const lower: u8 = if (c >= 'A' and c <= 'Z') c + 32 else c;
                try out.append(r.allocator, lower);
            } else {
                try out.append(r.allocator, '_');
            }
        }
        return out.toOwnedSlice(r.allocator);
    }

    fn fnRefIndex(r: *Renderer, label: types.BufSlice) !usize {
        const label_str = r.parsed.getText(label);
        for (r.fn_ref_labels.items, 0..) |existing, i| {
            if (std.mem.eql(u8, r.parsed.getText(existing), label_str)) return i;
        }
        try r.fn_ref_labels.append(r.allocator, label);
        return r.fn_ref_labels.items.len - 1;
    }

    fn renderToc(r: *Renderer) !void {
        try r.write("<details class=\"toc\"><summary>Table of Contents</summary>\n");
        try r.write("<div class=\"franklin-toc\">");

        if (r.headings.items.len > 0) {
            var level_stack: std.ArrayListUnmanaged(u8) = .empty;
            defer level_stack.deinit(r.allocator);

            for (r.headings.items) |h| {
                const node = r.parsed.getNode(h.node_id);
                const text = try r.getPlainText(node.kind.heading.content);
                defer r.allocator.free(text);
                const slug = try r.slugify(text);
                defer r.allocator.free(slug);

                const top: u8 = if (level_stack.items.len > 0) level_stack.items[level_stack.items.len - 1] else 0;
                if (h.level > top) {
                    try r.write("<ol>");
                    try level_stack.append(r.allocator, h.level);
                } else {
                    while (level_stack.items.len > 0 and
                        level_stack.items[level_stack.items.len - 1] > h.level)
                    {
                        try r.write("</ol>");
                        _ = level_stack.pop();
                    }
                }
                try r.print("<li><a href=\"#{s}\">", .{slug});
                try r.writeEscaped(text);
                try r.write("</a>");
            }

            while (level_stack.items.len > 0) {
                try r.write("</ol>");
                _ = level_stack.pop();
            }
        }

        try r.write("</div>\n</details>\n");
    }

    fn renderBlock(r: *Renderer, node: types.Node) anyerror!void {
        switch (node.kind) {
            .doc => |ns| {
                for (r.parsed.getSlice(ns)) |child_id| {
                    try r.renderBlock(r.parsed.getNode(child_id));
                }
            },
            .para => |ns| {
                // Image-only paragraph: render the image directly without <p> wrapper
                const children = r.parsed.getSlice(ns);
                if (children.len == 1 and r.parsed.getNode(children[0]).kind == .image) {
                    try r.renderInline(r.parsed.getNode(children[0]));
                    try r.writeByte('\n');
                    return;
                }
                try r.write("<p>");
                try r.renderInlines(ns);
                try r.write("</p>\n");
            },
            .heading => |h| {
                const text = try r.getPlainText(h.content);
                defer r.allocator.free(text);
                const slug = try r.slugify(text);
                defer r.allocator.free(slug);
                try r.print("<h{d} id=\"{s}\"><a href=\"#{s}\" class=\"header-anchor\">", .{ h.level, slug, slug });
                try r.renderInlines(h.content);
                try r.print("</a></h{d}>\n", .{h.level});
            },
            .code_block => |lang| {
                r.hascode = true;
                const lang_str = r.parsed.getText(lang);
                var body = r.parsed.getNodeText(node);
                // Trim trailing newline (fence body includes the \n before closing ```)
                if (body.len > 0 and body[body.len - 1] == '\n') body = body[0 .. body.len - 1];
                if (lang_str.len > 0) {
                    try r.print("<pre><code class=\"language-{s}\">", .{lang_str});
                } else {
                    try r.write("<pre><code>");
                }
                try r.writeEscaped(body);
                try r.write("</code></pre>\n");
            },
            .list => |l| {
                const tag: []const u8 = if (l.ordered) "ol" else "ul";
                try r.print("<{s}>\n", .{tag});
                for (r.parsed.getSlice(l.items)) |item_id| {
                    try r.renderBlock(r.parsed.getNode(item_id));
                }
                try r.print("</{s}>\n", .{tag});
            },
            .list_item => |children| {
                try r.write("<li>");
                for (r.parsed.getSlice(children)) |child_id| {
                    try r.renderBlock(r.parsed.getNode(child_id));
                }
            },
            .blockquote => |children| {
                try r.write("<blockquote>\n");
                for (r.parsed.getSlice(children)) |child_id| {
                    try r.renderBlock(r.parsed.getNode(child_id));
                }
                try r.write("</blockquote>\n");
            },
            .div => |d| {
                const name = r.parsed.getText(d.name);
                try r.print("<div class=\"{s}\">\n", .{name});
                for (r.parsed.getSlice(d.children)) |child_id| {
                    try r.renderBlock(r.parsed.getNode(child_id));
                }
                try r.write("</div>\n");
            },
            .toc => try r.renderToc(),
            .comments => r.has_comments = true,
            .raw_block => {
                try r.write(r.parsed.getNodeText(node));
                try r.writeByte('\n');
            },
            .footnote_def => {}, // collected and rendered at end by renderBody
            else => {},
        }
    }

    fn renderInlines(r: *Renderer, ns: types.NodeSlice) anyerror!void {
        for (r.parsed.getSlice(ns)) |child_id| {
            try r.renderInline(r.parsed.getNode(child_id));
        }
    }

    fn renderInline(r: *Renderer, node: types.Node) anyerror!void {
        switch (node.kind) {
            .text => try r.writeText(r.parsed.getNodeText(node)),
            .bold => |ns| {
                try r.write("<strong>");
                try r.renderInlines(ns);
                try r.write("</strong>");
            },
            .italic => |ns| {
                try r.write("<em>");
                try r.renderInlines(ns);
                try r.write("</em>");
            },
            .code_inline => {
                r.hascode = true;
                try r.write("<code>");
                try r.writeEscaped(r.parsed.getNodeText(node));
                try r.write("</code>");
            },
            .math_inline => {
                r.hasmath = true;
                try r.writeByte('$');
                try r.write(r.parsed.getNodeText(node));
                try r.writeByte('$');
            },
            .math_display => {
                r.hasmath = true;
                try r.write("$$");
                try r.write(r.parsed.getNodeText(node));
                try r.write("$$");
            },
            .raw_inline => try r.write(r.parsed.getNodeText(node)),
            .link => |lk| {
                const url = r.parsed.getText(lk.url);
                try r.write("<a href=\"");
                if (url.len > 0 and url[0] == '/') try r.write(r.prepath);
                try r.writeEscaped(url);
                try r.write("\">");
                try r.renderInlines(lk.content);
                try r.write("</a>");
            },
            .image => |img| {
                const url = r.parsed.getText(img.url);
                const alt = r.parsed.getText(img.alt);
                try r.write("<img src=\"");
                if (url.len > 0 and url[0] == '/') try r.write(r.prepath);
                try r.writeEscaped(url);
                try r.write("\" alt=\"");
                try r.writeEscaped(alt);
                try r.write("\" />");
            },
            .footnote_ref => |label| {
                const idx = try r.fnRefIndex(label);
                const n = idx + 1;
                const label_str = r.parsed.getText(label);
                try r.print(
                    "<sup id=\"fnref:{s}\"><a href=\"#fndef:{s}\" class=\"fnref\">[{d}]</a></sup>",
                    .{ label_str, label_str, n },
                );
            },
            .escape => try r.writeEscaped(r.parsed.getNodeText(node)),
            else => {},
        }
    }

    fn renderFootnoteDefs(r: *Renderer) !void {
        for (r.fn_defs.items) |def_id| {
            const node = r.parsed.getNode(def_id);
            switch (node.kind) {
                .footnote_def => |fd| {
                    const label_str = r.parsed.getText(fd.label);
                    var n: usize = 0;
                    for (r.fn_ref_labels.items, 0..) |ref_label, i| {
                        if (std.mem.eql(u8, r.parsed.getText(ref_label), label_str)) {
                            n = i + 1;
                            break;
                        }
                    }
                    if (n == 0) continue;
                    try r.print(
                        "<table class=\"fndef\" id=\"fndef:{s}\"><tr>" ++
                            "<td class=\"fndef-backref\"><a href=\"#fnref:{s}\">[{d}]</a>" ++
                            "<td class=\"fndef-content\">",
                        .{ label_str, label_str, n },
                    );
                    try r.renderInlines(fd.content);
                    try r.write("</td></tr></table>\n");
                },
                else => {},
            }
        }
        if (r.has_comments) try r.write(COMMENTS_SCRIPT ++ "\n");
    }
};

pub fn renderBody(
    parsed: *const types.Parsed,
    allocator: std.mem.Allocator,
    prepath: []const u8,
) !RenderResult {
    var r = Renderer.init(parsed, allocator, prepath);

    const root = parsed.getNode(parsed.root);
    switch (root.kind) {
        .doc => |ns| try r.collectHeadings(ns),
        else => {},
    }

    switch (root.kind) {
        .doc => |ns| {
            for (parsed.getSlice(ns)) |child_id| {
                const node = parsed.getNode(child_id);
                switch (node.kind) {
                    // Collect footnote defs for rendering at end; skip for now
                    .footnote_def => try r.fn_defs.append(allocator, child_id),
                    else => try r.renderBlock(node),
                }
            }
        },
        else => {},
    }

    try r.renderFootnoteDefs();

    const html = try r.buf.toOwnedSlice(r.allocator);
    const hasmath = r.hasmath;
    const hascode = r.hascode;
    r.buf = .empty; // already transferred; prevent deinit double-free
    r.deinit();
    return .{ .html = html, .hasmath = hasmath, .hascode = hascode };
}
