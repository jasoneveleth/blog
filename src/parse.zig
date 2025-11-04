const types = @import("types.zig");
const std = @import("std");

fn anyMatchSeq(
    iter: *types.GraphemeIterator,
    stop_tokens: []const []const u8,
) bool {
    for (stop_tokens) |stop| {
        if (iter.startsWith(stop)) {
            return true;
        }
    }
    return false;
}

fn parseHeading(parser: *types.Parser) !types.NodeID {
    types.enter("parseHeading");
    defer types.exit();

    const start = parser.iter.pos;

    var level: u8 = 0;
    while (parser.iter.startsWith("#")) {
        _ = parser.iter.next();
        level += 1;
    }

    // Consume any leading space
    if (parser.iter.startsWith(" ")) {
        _ = parser.iter.next();
    }

    var inlines_scratch = types.Scratch.init(parser);
    while (parser.iter.hasNext(1)) {
        if (parser.iter.startsWith("\n")) {
            _ = parser.iter.next();
            break;
        }
        const nodeID = try parseInline(parser);
        try inlines_scratch.add(nodeID);
    }
    const inlines = try inlines_scratch.finish();

    const end = parser.iter.pos;
    const heading: types.NodeKind = .{ .heading = .{ .level = level, .content = inlines } };
    return parser.new_node(types.Node{ .kind = heading, .start = types.BufInd.from(start), .len = end - start });
}

fn parseText(parser: *types.Parser) !types.NodeID {
    types.enter("parseText");
    defer types.exit();

    const start = parser.iter.pos;
    var offset: u32 = 0;

    while (parser.iter.hasNext(1)) {
        if (anyMatchSeq(&parser.iter, &.{ "\n", "*", "_" })) { // "$", "[", "`",
            _ = parser.iter.next(); 
            break;
        }
        const g = parser.iter.next() orelse break;
        offset += @intCast(g.len);
    }

    const node = types.Node{ .kind = .text, .start = types.BufInd.from(start), .len = offset };
    return try parser.new_node(node);
}

fn parseBold(parser: *types.Parser) ParseError!types.NodeID {
    types.enter("parseBold");
    defer types.exit();

    const start = parser.iter.pos;

    std.debug.assert(parser.iter.startsWith("*"));
    _ = parser.iter.next(); // consume '*'

    var inlines_scratch = types.Scratch.init(parser);
    while (parser.iter.hasNext(1)) {
        if (!parser.iter.startsWith("\n")) {
            const id = try parseInline(parser);
            try inlines_scratch.add(id);
        }
    }

    if (!parser.iter.startsWith("*")) {
        return error.UnterminatedBold;
    }
    _ = parser.iter.next(); // consume '*'

    const inlines = try inlines_scratch.finish();

    const end = parser.iter.pos;
    const node_id = parser.new_node(types.Node{ .start = types.BufInd.from(start), .len = end - start, .kind = .{ .bold = inlines } });
    return node_id;
}

fn parseItalic(parser: *types.Parser) !types.NodeID {
    types.enter("parseItalic");
    defer types.exit();

    const start = parser.iter.pos;

    std.debug.assert(parser.iter.startsWith("_"));
    _ = parser.iter.next(); // consume '_'

    var inlines_scratch = types.Scratch.init(parser);
    while (!parser.iter.startsWith("_")) {
        const id = try parseInline(parser);
        try inlines_scratch.add(id);
    }

    if (!parser.iter.startsWith("_")) {
        return error.UnterminatedItalic;
    }
    _ = parser.iter.next(); // consume '_'
    const inlines = try inlines_scratch.finish();

    const end = parser.iter.pos;
    const node_id = parser.new_node(types.Node{ .start = types.BufInd.from(start), .len = end - start, .kind = .{ .italic = inlines } });
    return node_id;
}

const ParseError = error{
    UnterminatedBold,
    UnterminatedItalic,
    TooManyChildren,
    OutOfMemory,
};

fn parseInline(parser: *types.Parser) ParseError!types.NodeID {
    types.enter("parseInline");
    defer types.exit();

    if (parser.iter.startsWith("*")) {
        return try parseBold(parser);
    } else if (parser.iter.startsWith("_")) {
        return try parseItalic(parser);
    } else {
        return parseText(parser);
    }
}

fn parsePara(parser: *types.Parser) !types.NodeID {
    types.enter("parsePara");
    defer types.exit();

    const start = parser.iter.pos;

    var inlines_scratch = types.Scratch.init(parser);
    while (parser.iter.hasNext(1)) {
        if (parser.iter.startsWith("\n")) {
            while (parser.iter.startsWith("\n")) {
                _ = parser.iter.next();
            }
            break;
        }
        const nodeID = try parseInline(parser);
        try inlines_scratch.add(nodeID);
    }
    const inlines = try inlines_scratch.finish();

    const end = parser.iter.pos;
    const node_id = parser.new_node(types.Node{ .start = types.BufInd.from(start), .len = end - start, .kind = .{ .para = inlines } });
    return node_id;
}

pub fn parse(text: []const u8) !types.Parsed {
    if (text.len > std.math.maxInt(usize)) {
        return error.FileTooLarge;
    }
    const iter = types.GraphemeIterator.init(text);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    var parser = types.Parser{
        .iter = iter,
        .text = text,
        .nodes = try std.ArrayList(types.Node).initCapacity(arena.allocator(), 100),
        .indices = try std.ArrayList(types.NodeID).initCapacity(arena.allocator(), 100),
        .arena = arena,
    };

    var scratch = types.Scratch.init(&parser);

    while (parser.iter.hasNext(1)) {
        if (parser.iter.startsWith("#")) {
            const heading = try parseHeading(&parser);
            try scratch.add(heading);
        } else {
            const paragraph = try parsePara(&parser);
            try scratch.add(paragraph);
        }
    }

    const range = try scratch.finish();
    const docID = try parser.new_node(types.Node{ .start = types.BufInd.from(0), .len = @intCast(text.len), .kind = .{ .para = range } });
    return parser.finish(docID);
}
