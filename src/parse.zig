const std = @import("std");
const types = @import("types.zig");

// ── Frontmatter ─────────────────────────────────────────────────────────────

fn parseDate(s: []const u8) ?types.Date {
    if (s.len < 10) return null;
    const year = std.fmt.parseInt(u16, s[0..4], 10) catch return null;
    if (s[4] != '-') return null;
    const month = std.fmt.parseInt(u8, s[5..7], 10) catch return null;
    if (s[7] != '-') return null;
    const day = std.fmt.parseInt(u8, s[8..10], 10) catch return null;
    return .{ .year = year, .month = month, .day = day };
}

fn parseFrontmatter(src: []const u8, allocator: std.mem.Allocator) struct { fm: types.Frontmatter, body_start: usize } {
    var fm = types.Frontmatter{};

    if (!std.mem.startsWith(u8, src, "+++\n")) return .{ .fm = fm, .body_start = 0 };

    var i: usize = 4;
    while (i < src.len) {
        if (src[i] == '\n') { i += 1; continue; }
        if (std.mem.startsWith(u8, src[i..], "+++")) {
            i += 3;
            if (i < src.len and src[i] == '\n') i += 1;
            return .{ .fm = fm, .body_start = i };
        }
        if (src[i] == '#') { while (i < src.len and src[i] != '\n') i += 1; continue; }

        const key_start = i;
        while (i < src.len and src[i] != '=' and src[i] != '\n') i += 1;
        if (i >= src.len or src[i] == '\n') { i += 1; continue; }
        const key = std.mem.trim(u8, src[key_start..i], " \t");
        i += 1; // skip =
        while (i < src.len and src[i] == ' ') i += 1;

        const val_start = i;
        while (i < src.len and src[i] != '\n') i += 1;
        const val_raw = std.mem.trim(u8, src[val_start..i], " \t");
        if (i < src.len) i += 1;

        if (std.mem.eql(u8, key, "title") or std.mem.eql(u8, key, "rss") or std.mem.eql(u8, key, "githubsource")) {
            var v = val_raw;
            if (v.len >= 2 and v[0] == '"' and v[v.len - 1] == '"') v = v[1 .. v.len - 1];
            if (std.mem.eql(u8, key, "title")) fm.title = v
            else if (std.mem.eql(u8, key, "rss")) fm.rss = v
            else fm.githubsource = v;
        } else if (std.mem.eql(u8, key, "date")) {
            if (parseDate(val_raw)) |d| fm.date = d;
        } else if (std.mem.eql(u8, key, "updated")) {
            fm.updated = parseDate(val_raw);
        } else if (std.mem.eql(u8, key, "descr")) {
            fm.descr = std.mem.eql(u8, val_raw, "true");
        } else if (std.mem.eql(u8, key, "draft")) {
            fm.draft = std.mem.eql(u8, val_raw, "true");
        } else if (std.mem.eql(u8, key, "tags")) {
            fm.tags = parseTags(val_raw, allocator) catch &.{};
        }
    }
    return .{ .fm = fm, .body_start = i };
}

fn parseTags(s: []const u8, allocator: std.mem.Allocator) ![]const []const u8 {
    _ = allocator;
    const trimmed = std.mem.trim(u8, s, " \t[]");
    if (trimmed.len == 0) return &.{};
    // non-empty tags: placeholder until step 5
    return &.{};
}

// ── Helpers ──────────────────────────────────────────────────────────────────

fn findLineEnd(parser: *const types.Parser) usize {
    var i = parser.pos;
    while (i < parser.src.len and parser.src[i] != '\n') i += 1;
    return i;
}

/// Returns end position (before terminating \n or EOF) of the current paragraph.
/// Stops at blank lines and block-level markers on a new line.
fn findParaEnd(parser: *const types.Parser) usize {
    var i = parser.pos;
    while (i < parser.src.len) {
        while (i < parser.src.len and parser.src[i] != '\n') i += 1;
        if (i >= parser.src.len) return i;
        const nl_pos = i;
        i += 1;
        if (i >= parser.src.len) return nl_pos;
        // blank line (possibly whitespace only)
        var j = i;
        while (j < parser.src.len and (parser.src[j] == ' ' or parser.src[j] == '\t')) j += 1;
        if (j >= parser.src.len or parser.src[j] == '\n') return nl_pos;
        // block-level markers that interrupt a paragraph
        const c = parser.src[i];
        if (c == '#') return nl_pos;
        if (c == '@' and i + 1 < parser.src.len and parser.src[i + 1] == '@') return nl_pos;
        if (c == '`' and i + 2 < parser.src.len and parser.src[i + 1] == '`' and parser.src[i + 2] == '`') return nl_pos;
        if (c == '~' and i + 2 < parser.src.len and parser.src[i + 1] == '~' and parser.src[i + 2] == '~') {
            // bare ~~~ line?
            var k = i + 3;
            while (k < parser.src.len and (parser.src[k] == ' ' or parser.src[k] == '\t')) k += 1;
            if (k >= parser.src.len or parser.src[k] == '\n') return nl_pos;
        }
        if ((c == '*' or c == '-') and i + 1 < parser.src.len and parser.src[i + 1] == ' ') return nl_pos;
        if (c >= '0' and c <= '9') {
            var k = i;
            while (k < parser.src.len and parser.src[k] >= '0' and parser.src[k] <= '9') k += 1;
            if (k < parser.src.len and parser.src[k] == '.' and k + 1 < parser.src.len and parser.src[k + 1] == ' ') return nl_pos;
        }
        if (c == '[' and i + 1 < parser.src.len and parser.src[i + 1] == '^') {
            var k = i + 2;
            while (k < parser.src.len and parser.src[k] != ']' and parser.src[k] != '\n') k += 1;
            if (k < parser.src.len and parser.src[k] == ']' and k + 1 < parser.src.len and parser.src[k + 1] == ':') return nl_pos;
        }
    }
    return i;
}

/// Visual column of `pos` in its line (tab = 4).
fn visualColAt(src: []const u8, pos: usize) usize {
    var line_start = pos;
    while (line_start > 0 and src[line_start - 1] != '\n') line_start -= 1;
    var col: usize = 0;
    var k = line_start;
    while (k < pos) {
        if (src[k] == '\t') col = ((col / 4) + 1) * 4 else col += 1;
        k += 1;
    }
    return col;
}

fn isRawBlockStart(parser: *const types.Parser) bool {
    if (!parser.startsWith("~~~")) return false;
    const after = parser.pos + 3;
    if (after >= parser.src.len) return true;
    const c = parser.src[after];
    return c == '\n' or c == '\r';
}

fn isFootnoteDef(parser: *const types.Parser) bool {
    if (!parser.startsWith("[^")) return false;
    var i: usize = parser.pos + 2;
    while (i < parser.src.len and parser.src[i] != ']' and parser.src[i] != '\n') i += 1;
    return i < parser.src.len and parser.src[i] == ']' and
        i + 1 < parser.src.len and parser.src[i + 1] == ':';
}

/// True if the current line has a list marker at visual indent >= min_col.
fn isListMarkerAt(parser: *const types.Parser, min_col: usize) bool {
    var i = parser.pos;
    var col: usize = 0;
    while (i < parser.src.len) {
        if (parser.src[i] == ' ') { col += 1; i += 1; }
        else if (parser.src[i] == '\t') { col = ((col / 4) + 1) * 4; i += 1; }
        else break;
    }
    if (col < min_col or i >= parser.src.len) return false;
    const c = parser.src[i];
    if ((c == '*' or c == '-') and i + 1 < parser.src.len and parser.src[i + 1] == ' ') return true;
    if (c >= '0' and c <= '9') {
        var j = i;
        while (j < parser.src.len and parser.src[j] >= '0' and parser.src[j] <= '9') j += 1;
        return j < parser.src.len and parser.src[j] == '.' and
            j + 1 < parser.src.len and parser.src[j + 1] == ' ';
    }
    return false;
}

fn isOrderedMarker(parser: *const types.Parser) bool {
    var i = parser.pos;
    while (i < parser.src.len and (parser.src[i] == ' ' or parser.src[i] == '\t')) i += 1;
    if (i >= parser.src.len or parser.src[i] < '0' or parser.src[i] > '9') return false;
    while (i < parser.src.len and parser.src[i] >= '0' and parser.src[i] <= '9') i += 1;
    return i < parser.src.len and parser.src[i] == '.' and
        i + 1 < parser.src.len and parser.src[i + 1] == ' ';
}

// ── Block parsers ─────────────────────────────────────────────────────────────

fn parseOneBlock(parser: *types.Parser) anyerror!?types.NodeID {
    if (parser.atEnd()) return null;
    const c = parser.src[parser.pos];
    if (c == '#') return try parseHeading(parser);
    if (parser.startsWith("```")) return try parseFencedCode(parser);
    if (isRawBlockStart(parser)) return try parseRawBlock(parser);
    if (parser.startsWith("@@")) return try parseAtDirective(parser);
    if (c == '>') return try parseBlockquote(parser);
    if (isFootnoteDef(parser)) return try parseFootnoteDef(parser);
    if (isListMarkerAt(parser, 0)) return try parseList(parser, 0);
    return try parseParagraph(parser);
}

fn parseHeading(parser: *types.Parser) !types.NodeID {
    const start = parser.pos;
    var level: u8 = 0;
    while (!parser.atEnd() and parser.src[parser.pos] == '#') { parser.advance(); level += 1; }
    if (!parser.atEnd() and parser.src[parser.pos] == ' ') parser.advance();
    const line_end = findLineEnd(parser);
    const content = try parseInlineSequence(parser, line_end);
    parser.pos = line_end;
    parser.skipNewline();
    return parser.new_node(.{
        .kind = .{ .heading = .{ .level = level, .content = content } },
        .start = types.BufInd.from(start),
        .len = @intCast(parser.pos - start),
    });
}

fn parseFencedCode(parser: *types.Parser) !types.NodeID {
    parser.advanceBy(3); // skip ```
    const lang_start = parser.pos;
    parser.skipToEOL();
    const lang = types.BufSlice{
        .start = types.BufInd.from(lang_start),
        .end = types.BufInd.from(parser.pos),
    };
    parser.skipNewline();
    const body_start = parser.pos;
    while (!parser.atEnd()) {
        if (parser.startsWith("```")) {
            const body_end = parser.pos;
            parser.advanceBy(3);
            parser.skipToEOL();
            parser.skipNewline();
            return parser.new_node(.{
                .kind = .{ .code_block = lang },
                .start = types.BufInd.from(body_start),
                .len = @intCast(body_end - body_start),
            });
        }
        parser.skipToEOL();
        parser.skipNewline();
    }
    return parser.new_node(.{
        .kind = .{ .code_block = lang },
        .start = types.BufInd.from(body_start),
        .len = @intCast(parser.pos - body_start),
    });
}

fn parseRawBlock(parser: *types.Parser) !types.NodeID {
    parser.advanceBy(3);
    parser.skipNewline();
    const body_start = parser.pos;
    while (!parser.atEnd()) {
        if (isRawBlockStart(parser)) {
            const body_end = parser.pos;
            parser.advanceBy(3);
            parser.skipNewline();
            return parser.new_node(.{
                .kind = .raw_block,
                .start = types.BufInd.from(body_start),
                .len = @intCast(body_end - body_start),
            });
        }
        parser.skipToEOL();
        parser.skipNewline();
    }
    return parser.new_node(.{
        .kind = .raw_block,
        .start = types.BufInd.from(body_start),
        .len = @intCast(parser.pos - body_start),
    });
}

fn parseAtDirective(parser: *types.Parser) !types.NodeID {
    const dir_start = parser.pos;
    parser.advanceBy(2); // skip @@
    const name_start = parser.pos;
    while (!parser.atEnd() and parser.src[parser.pos] != '\n' and parser.src[parser.pos] != '@') {
        parser.advance();
    }
    // Trim trailing whitespace from name (e.g. "@@warn  \n" → name "warn")
    var name_end = parser.pos;
    while (name_end > name_start and (parser.src[name_end - 1] == ' ' or parser.src[name_end - 1] == '\t')) {
        name_end -= 1;
    }
    const name = types.BufSlice{
        .start = types.BufInd.from(name_start),
        .end = types.BufInd.from(name_end),
    };
    const name_str = parser.src[name_start..name_end];

    // self-closing: @@name@@
    if (!parser.atEnd() and parser.src[parser.pos] == '@') {
        parser.advanceBy(2); // skip @@
        parser.skipToEOL();
        parser.skipNewline();
        if (std.mem.eql(u8, name_str, "toc")) {
            return parser.new_node(.{ .kind = .toc, .start = types.BufInd.from(dir_start), .len = @intCast(parser.pos - dir_start) });
        }
        if (std.mem.eql(u8, name_str, "comments")) {
            return parser.new_node(.{ .kind = .comments, .start = types.BufInd.from(dir_start), .len = @intCast(parser.pos - dir_start) });
        }
        var sc = types.Scratch.init(parser);
        const children = try sc.finish();
        return parser.new_node(.{ .kind = .{ .div = .{ .name = name, .children = children } }, .start = types.BufInd.from(dir_start), .len = @intCast(parser.pos - dir_start) });
    }

    // block div: @@name … @@
    parser.skipToEOL();
    parser.skipNewline();
    var scratch = types.Scratch.init(parser);
    while (!parser.atEnd()) {
        parser.skipBlankLines();
        if (parser.atEnd()) break;
        // bare @@ closes the block
        if (parser.startsWith("@@")) {
            const after = parser.pos + 2;
            if (after >= parser.src.len or parser.src[after] == '\n') {
                parser.advanceBy(2);
                parser.skipNewline();
                break;
            }
        }
        if (try parseOneBlock(parser)) |id| try scratch.add(id);
    }
    const children = try scratch.finish();
    return parser.new_node(.{
        .kind = .{ .div = .{ .name = name, .children = children } },
        .start = types.BufInd.from(dir_start),
        .len = @intCast(parser.pos - dir_start),
    });
}

fn parseBlockquote(parser: *types.Parser) !types.NodeID {
    const start = parser.pos;
    var scratch = types.Scratch.init(parser);
    while (!parser.atEnd() and parser.src[parser.pos] == '>') {
        parser.advance();
        if (!parser.atEnd() and parser.src[parser.pos] == ' ') parser.advance();
        const line_end = findLineEnd(parser);
        const inlines = try parseInlineSequence(parser, line_end);
        parser.pos = line_end;
        parser.skipNewline();
        const para_id = try parser.new_node(.{
            .kind = .{ .para = inlines },
            .start = types.BufInd.from(start),
            .len = 0,
        });
        try scratch.add(para_id);
        parser.skipBlankLines();
    }
    const children = try scratch.finish();
    return parser.new_node(.{
        .kind = .{ .blockquote = children },
        .start = types.BufInd.from(start),
        .len = @intCast(parser.pos - start),
    });
}

fn parseFootnoteDef(parser: *types.Parser) !types.NodeID {
    const start = parser.pos;
    parser.advanceBy(2); // skip [^
    const label_start = parser.pos;
    while (!parser.atEnd() and parser.src[parser.pos] != ']') parser.advance();
    const label = types.BufSlice{ .start = types.BufInd.from(label_start), .end = types.BufInd.from(parser.pos) };
    if (!parser.atEnd()) parser.advance(); // skip ]
    if (!parser.atEnd() and parser.src[parser.pos] == ':') parser.advance();
    if (!parser.atEnd() and parser.src[parser.pos] == ' ') parser.advance();
    const end_pos = findParaEnd(parser);
    const content = try parseInlineSequence(parser, end_pos);
    parser.pos = end_pos;
    parser.skipNewline();
    return parser.new_node(.{
        .kind = .{ .footnote_def = .{ .label = label, .content = content } },
        .start = types.BufInd.from(start),
        .len = @intCast(parser.pos - start),
    });
}

fn parseList(parser: *types.Parser, marker_indent: usize) anyerror!types.NodeID {
    const start = parser.pos;
    const ordered = isOrderedMarker(parser);
    var items_scratch = types.Scratch.init(parser);
    while (!parser.atEnd() and isListMarkerAt(parser, marker_indent)) {
        // Do not nest if indent exactly matches — check it's not a deeper level
        // (deeper levels are handled by parseListItem's recursive call)
        const item_id = try parseListItem(parser, marker_indent);
        try items_scratch.add(item_id);
        // Allow a single blank line between items
        const saved = parser.pos;
        parser.skipBlankLines();
        if (!isListMarkerAt(parser, marker_indent)) {
            parser.pos = saved;
            break;
        }
    }
    const items = try items_scratch.finish();
    return parser.new_node(.{
        .kind = .{ .list = .{ .ordered = ordered, .items = items } },
        .start = types.BufInd.from(start),
        .len = @intCast(parser.pos - start),
    });
}

fn parseListItem(parser: *types.Parser, _marker_indent: usize) anyerror!types.NodeID {
    _ = _marker_indent;
    const start = parser.pos;
    // Skip whitespace to marker
    while (!parser.atEnd() and (parser.src[parser.pos] == ' ' or parser.src[parser.pos] == '\t')) {
        parser.advance();
    }
    // Skip marker
    const c = parser.src[parser.pos];
    if (c == '*' or c == '-') {
        parser.advanceBy(2);
    } else {
        while (!parser.atEnd() and parser.src[parser.pos] >= '0' and parser.src[parser.pos] <= '9') parser.advance();
        if (!parser.atEnd() and parser.src[parser.pos] == '.') parser.advance();
        if (!parser.atEnd() and parser.src[parser.pos] == ' ') parser.advance();
    }
    // Content column = where we are now (visually)
    const content_col = visualColAt(parser.src, parser.pos);

    // Parse inline content of the item (single line)
    const line_end = findLineEnd(parser);
    const inlines = try parseInlineSequence(parser, line_end);
    parser.pos = line_end;
    parser.skipNewline();

    // Wrap inlines in a para node
    const para_id = try parser.new_node(.{
        .kind = .{ .para = inlines },
        .start = types.BufInd.from(start),
        .len = 0,
    });

    var item_scratch = types.Scratch.init(parser);
    try item_scratch.add(para_id);

    // Check for nested list at content_col
    const saved = parser.pos;
    parser.skipBlankLines();
    if (isListMarkerAt(parser, content_col)) {
        const nested = try parseList(parser, content_col);
        try item_scratch.add(nested);
    } else {
        parser.pos = saved;
    }

    const children = try item_scratch.finish();
    return parser.new_node(.{
        .kind = .{ .list_item = children },
        .start = types.BufInd.from(start),
        .len = @intCast(parser.pos - start),
    });
}

fn parseParagraph(parser: *types.Parser) !types.NodeID {
    const start = parser.pos;
    const end_pos = findParaEnd(parser);
    const inlines = try parseInlineSequence(parser, end_pos);
    parser.pos = end_pos;
    parser.skipNewline();
    return parser.new_node(.{
        .kind = .{ .para = inlines },
        .start = types.BufInd.from(start),
        .len = @intCast(end_pos - start),
    });
}

// ── Inline parsers ────────────────────────────────────────────────────────────

fn parseInlineSequence(parser: *types.Parser, end_pos: usize) anyerror!types.NodeSlice {
    var scratch = types.Scratch.init(parser);
    while (parser.pos < end_pos and !parser.atEnd()) {
        if (try parseOneInline(parser, end_pos)) |id| try scratch.add(id);
    }
    return scratch.finish();
}

fn parseOneInline(parser: *types.Parser, end_pos: usize) anyerror!?types.NodeID {
    if (parser.pos >= end_pos or parser.atEnd()) return null;
    const c = parser.src[parser.pos];
    if (c == '\n') { parser.advance(); return null; }
    if (c == '`') return try parseCodeInline(parser);
    if (c == '$') return try parseMath(parser);
    if (parser.startsWith("~~~")) return try parseRawInline(parser, end_pos);
    if (c == '*') return try parseBold(parser, end_pos);
    if (c == '_') return try parseItalic(parser, end_pos);
    if (c == '[') {
        if (parser.peekAt(1) == '^') return try parseFootnoteRef(parser);
        return try parseLink(parser, end_pos);
    }
    if (c == '!' and parser.peekAt(1) == '[') return try parseImage(parser);
    if (c == '\\') return try parseEscape(parser);
    return try parseTextRun(parser, end_pos);
}

fn parseTextRun(parser: *types.Parser, end_pos: usize) !types.NodeID {
    const start = parser.pos;
    while (parser.pos < end_pos and !parser.atEnd()) {
        const c = parser.src[parser.pos];
        switch (c) {
            '`', '$', '*', '_', '\\', '\n' => break,
            '[' => break,
            // only stop at ! when followed by [
            '!' => if (parser.peekAt(1) == '[') break else parser.advance(),
            '~' => if (parser.startsWith("~~~")) break else parser.advance(),
            else => parser.advance(),
        }
    }
    // guarantee progress: if no bytes consumed, eat one char as literal text
    if (parser.pos == start and parser.pos < end_pos and !parser.atEnd()) parser.advance();
    return parser.new_node(.{
        .kind = .text,
        .start = types.BufInd.from(start),
        .len = @intCast(parser.pos - start),
    });
}

fn parseCodeInline(parser: *types.Parser) !types.NodeID {
    parser.advance(); // skip `
    const content_start = parser.pos;
    while (!parser.atEnd() and parser.src[parser.pos] != '`' and parser.src[parser.pos] != '\n') {
        parser.advance();
    }
    const content_end = parser.pos;
    if (!parser.atEnd() and parser.src[parser.pos] == '`') parser.advance();
    return parser.new_node(.{
        .kind = .code_inline,
        .start = types.BufInd.from(content_start),
        .len = @intCast(content_end - content_start),
    });
}

fn parseMath(parser: *types.Parser) !types.NodeID {
    const is_display = parser.startsWith("$$");
    const delim_len: usize = if (is_display) 2 else 1;
    parser.advanceBy(delim_len);
    const content_start = parser.pos;
    while (!parser.atEnd()) {
        if (is_display) {
            if (parser.startsWith("$$")) break;
            // display math spans multiple lines; do NOT stop at \n
        } else {
            if (parser.src[parser.pos] == '$' and !parser.startsWith("$$")) break;
            if (parser.src[parser.pos] == '\n') break;
        }
        parser.advance();
    }
    const content_end = parser.pos;
    if (!parser.atEnd() and parser.src[parser.pos] == '$') parser.advanceBy(delim_len);
    return parser.new_node(.{
        .kind = if (is_display) .math_display else .math_inline,
        .start = types.BufInd.from(content_start),
        .len = @intCast(content_end - content_start),
    });
}

fn parseRawInline(parser: *types.Parser, end_pos: usize) !types.NodeID {
    parser.advanceBy(3); // skip ~~~
    const content_start = parser.pos;
    while (parser.pos < end_pos and !parser.atEnd()) {
        if (parser.startsWith("~~~")) break;
        parser.advance();
    }
    const content_end = parser.pos;
    if (parser.startsWith("~~~")) parser.advanceBy(3);
    return parser.new_node(.{
        .kind = .raw_inline,
        .start = types.BufInd.from(content_start),
        .len = @intCast(content_end - content_start),
    });
}

// Scan ahead to check if there's a matching delimiter before \n or end_pos.
// Skips inline math spans ($ ... $) so * inside math is not mistaken for close.
fn hasInlineClose(parser: *const types.Parser, start: usize, end_pos: usize, delim: u8) bool {
    var i = start + 1;
    var in_math = false;
    while (i < end_pos and i < parser.src.len) {
        const c = parser.src[i];
        if (c == '\n') break;
        if (c == '$') {
            in_math = !in_math;
        } else if (!in_math and c == delim) {
            return true;
        }
        i += 1;
    }
    return false;
}

fn parseBold(parser: *types.Parser, end_pos: usize) !types.NodeID {
    const start = parser.pos;
    // If no matching * before \n, treat * as literal text.
    if (!hasInlineClose(parser, start, end_pos, '*')) {
        parser.advance();
        return parser.new_node(.{ .kind = .text, .start = types.BufInd.from(start), .len = 1 });
    }
    parser.advance(); // skip opening *
    var scratch = types.Scratch.init(parser);
    while (parser.pos < end_pos and !parser.atEnd()) {
        const c = parser.src[parser.pos];
        if (c == '*' or c == '\n') break;
        if (try parseOneInline(parser, end_pos)) |id| try scratch.add(id);
    }
    if (!parser.atEnd() and parser.src[parser.pos] == '*') parser.advance();
    const content = try scratch.finish();
    return parser.new_node(.{
        .kind = .{ .bold = content },
        .start = types.BufInd.from(start),
        .len = @intCast(parser.pos - start),
    });
}

fn parseItalic(parser: *types.Parser, end_pos: usize) !types.NodeID {
    const start = parser.pos;
    // If no matching _ before \n, treat _ as literal text.
    if (!hasInlineClose(parser, start, end_pos, '_')) {
        parser.advance();
        return parser.new_node(.{ .kind = .text, .start = types.BufInd.from(start), .len = 1 });
    }
    parser.advance(); // skip opening _
    var scratch = types.Scratch.init(parser);
    while (parser.pos < end_pos and !parser.atEnd()) {
        const c = parser.src[parser.pos];
        if (c == '_' or c == '\n') break;
        if (try parseOneInline(parser, end_pos)) |id| try scratch.add(id);
    }
    if (!parser.atEnd() and parser.src[parser.pos] == '_') parser.advance();
    const content = try scratch.finish();
    return parser.new_node(.{
        .kind = .{ .italic = content },
        .start = types.BufInd.from(start),
        .len = @intCast(parser.pos - start),
    });
}

fn parseLink(parser: *types.Parser, end_pos: usize) !types.NodeID {
    const start = parser.pos;
    parser.advance(); // skip [
    // Find matching ]
    const text_start = parser.pos;
    var depth: usize = 1;
    var text_end = parser.pos;
    {
        var i = parser.pos;
        while (i < parser.src.len and i < end_pos) {
            if (parser.src[i] == '[') depth += 1
            else if (parser.src[i] == ']') {
                depth -= 1;
                if (depth == 0) { text_end = i; break; }
            } else if (parser.src[i] == '\n') break;
            i += 1;
        }
    }
    parser.pos = text_end;
    if (!parser.atEnd() and parser.src[parser.pos] == ']') parser.advance();
    // Expect (url)
    if (parser.atEnd() or parser.src[parser.pos] != '(') {
        return parser.new_node(.{ .kind = .text, .start = types.BufInd.from(start), .len = @intCast(parser.pos - start) });
    }
    parser.advance(); // skip (
    const url_start = parser.pos;
    while (!parser.atEnd() and parser.src[parser.pos] != ')' and parser.src[parser.pos] != '\n') {
        parser.advance();
    }
    const url_end = parser.pos;
    if (!parser.atEnd() and parser.src[parser.pos] == ')') parser.advance();
    // Parse link text as inlines (save/restore pos)
    const saved_pos = parser.pos;
    parser.pos = text_start;
    const content = try parseInlineSequence(parser, text_end);
    parser.pos = saved_pos;
    return parser.new_node(.{
        .kind = .{ .link = .{
            .url = .{ .start = types.BufInd.from(url_start), .end = types.BufInd.from(url_end) },
            .content = content,
        }},
        .start = types.BufInd.from(start),
        .len = @intCast(parser.pos - start),
    });
}

fn parseImage(parser: *types.Parser) !types.NodeID {
    const start = parser.pos;
    parser.advanceBy(2); // skip ![
    const alt_start = parser.pos;
    while (!parser.atEnd() and parser.src[parser.pos] != ']' and parser.src[parser.pos] != '\n') {
        parser.advance();
    }
    const alt_end = parser.pos;
    if (!parser.atEnd() and parser.src[parser.pos] == ']') parser.advance();
    var url_start = parser.pos;
    var url_end = parser.pos;
    if (!parser.atEnd() and parser.src[parser.pos] == '(') {
        parser.advance();
        url_start = parser.pos;
        // Allow ) on the next line (e.g. data: URIs with long base64)
        while (!parser.atEnd() and parser.src[parser.pos] != ')') {
            parser.advance();
        }
        url_end = parser.pos;
        // Trim trailing whitespace from URL (newline before closing ))
        while (url_end > url_start and (parser.src[url_end - 1] == '\n' or parser.src[url_end - 1] == '\r' or parser.src[url_end - 1] == ' ' or parser.src[url_end - 1] == '\t')) {
            url_end -= 1;
        }
        if (!parser.atEnd() and parser.src[parser.pos] == ')') parser.advance();
        if (!parser.atEnd() and parser.src[parser.pos] == '\n') parser.advance();
    }
    return parser.new_node(.{
        .kind = .{ .image = .{
            .url = .{ .start = types.BufInd.from(url_start), .end = types.BufInd.from(url_end) },
            .alt = .{ .start = types.BufInd.from(alt_start), .end = types.BufInd.from(alt_end) },
        }},
        .start = types.BufInd.from(start),
        .len = @intCast(parser.pos - start),
    });
}

fn parseFootnoteRef(parser: *types.Parser) !types.NodeID {
    const start = parser.pos;
    parser.advanceBy(2); // skip [^
    const label_start = parser.pos;
    while (!parser.atEnd() and parser.src[parser.pos] != ']' and parser.src[parser.pos] != '\n') {
        parser.advance();
    }
    const label_end = parser.pos;
    if (!parser.atEnd() and parser.src[parser.pos] == ']') parser.advance();
    return parser.new_node(.{
        .kind = .{ .footnote_ref = .{ .start = types.BufInd.from(label_start), .end = types.BufInd.from(label_end) } },
        .start = types.BufInd.from(start),
        .len = @intCast(parser.pos - start),
    });
}

fn parseEscape(parser: *types.Parser) !types.NodeID {
    parser.advance(); // skip \
    const char_start = parser.pos;
    if (!parser.atEnd()) parser.advance();
    return parser.new_node(.{
        .kind = .escape,
        .start = types.BufInd.from(char_start),
        .len = 1,
    });
}

// ── Entry point ───────────────────────────────────────────────────────────────

pub fn parse(src: []const u8, allocator: std.mem.Allocator) !types.Parsed {
    const fm_result = parseFrontmatter(src, allocator);
    var parser = try types.Parser.init(allocator, src);
    parser.pos = fm_result.body_start;

    var scratch = types.Scratch.init(&parser);
    parser.skipBlankLines();
    while (!parser.atEnd()) {
        if (try parseOneBlock(&parser)) |id| try scratch.add(id);
        parser.skipBlankLines();
    }

    const range = try scratch.finish();
    const doc_id = try parser.new_node(.{
        .kind = .{ .doc = range },
        .start = types.BufInd.from(0),
        .len = @intCast(src.len),
    });
    var parsed = parser.finish(doc_id);
    parsed.frontmatter = fm_result.fm;
    return parsed;
}
