const std = @import("std");

fn makeID(comptime T: type, comptime U: type) type {
    _ = U;
    return enum(T) {
        _,
        pub fn id(self: @This()) T { return @intFromEnum(self); }
        pub fn from(int: usize) @This() { return @enumFromInt(int); }
        pub fn into(self: @This()) usize { return @intFromEnum(self); }
    };
}

pub const NodeID = makeID(u32, Node);
pub const ChildrenID = makeID(u32, NodeID);
pub const BufInd = makeID(u32, u8);

pub const NodeSlice = struct { start: ChildrenID, end: ChildrenID };
pub const BufSlice = struct { start: BufInd, end: BufInd };

pub const NodeKind = union(enum) {
    // block nodes
    doc: NodeSlice,
    para: NodeSlice,
    heading: struct { level: u8, content: NodeSlice },
    /// lang slice in BufSlice; body bytes at Node.start/len
    code_block: BufSlice,
    list: struct { ordered: bool, items: NodeSlice },
    /// children: para node + optional trailing list node
    list_item: NodeSlice,
    blockquote: NodeSlice,
    div: struct { name: BufSlice, children: NodeSlice },
    toc,
    comments,
    /// opaque body at Node.start/len
    raw_block,
    footnote_def: struct { label: BufSlice, content: NodeSlice },
    // inline nodes
    /// bytes at Node.start/len
    text,
    bold: NodeSlice,
    italic: NodeSlice,
    /// opaque; bytes at Node.start/len (content only, no backtick)
    code_inline,
    /// opaque $…$; content bytes at Node.start/len
    math_inline,
    /// opaque $$…$$
    math_display,
    /// opaque ~~~…~~~
    raw_inline,
    link: struct { url: BufSlice, content: NodeSlice },
    image: struct { url: BufSlice, alt: BufSlice },
    footnote_ref: BufSlice,
    /// literal char at Node.start, len=1
    escape,
};

pub const Node = struct {
    kind: NodeKind,
    start: BufInd,
    len: u32,
};

pub const Date = struct { year: u16, month: u8, day: u8 };

pub const Frontmatter = struct {
    title: []const u8 = "",
    date: Date = .{ .year = 0, .month = 1, .day = 1 },
    updated: ?Date = null,
    rss: []const u8 = "",
    tags: []const []const u8 = &.{},
    descr: bool = false,
    draft: bool = false,
    githubsource: ?[]const u8 = null,
};

pub const Scratch = struct {
    parser: *Parser,
    scratch: [64]NodeID = undefined,
    count: usize = 0,

    pub fn init(parser: *Parser) Scratch {
        return .{ .parser = parser, .scratch = undefined, .count = 0 };
    }

    pub fn add(self: *@This(), node_id: NodeID) !void {
        if (self.count >= self.scratch.len) return error.TooManyChildren;
        self.scratch[self.count] = node_id;
        self.count += 1;
    }

    pub fn finish(self: *@This()) std.mem.Allocator.Error!NodeSlice {
        const start = self.parser.indices.items.len;
        try self.parser.indices.appendSlice(self.parser.arena.allocator(), self.scratch[0..self.count]);
        return NodeSlice{
            .start = ChildrenID.from(start),
            .end = ChildrenID.from(self.parser.indices.items.len),
        };
    }
};

pub const Parser = struct {
    src: []const u8,
    pos: usize,
    nodes: std.ArrayListUnmanaged(Node),
    indices: std.ArrayListUnmanaged(NodeID),
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator, src: []const u8) !Parser {
        var arena = std.heap.ArenaAllocator.init(allocator);
        return .{
            .src = src,
            .pos = 0,
            .nodes = try std.ArrayListUnmanaged(Node).initCapacity(arena.allocator(), 128),
            .indices = try std.ArrayListUnmanaged(NodeID).initCapacity(arena.allocator(), 256),
            .arena = arena,
        };
    }

    pub fn new_node(self: *@This(), node: Node) !NodeID {
        try self.nodes.append(self.arena.allocator(), node);
        return NodeID.from(self.nodes.items.len - 1);
    }

    pub fn finish(self: *@This(), root: NodeID) Parsed {
        return .{
            .root = root,
            .text = self.src,
            .nodes = self.nodes,
            .indices = self.indices,
            .arena = self.arena,
            .frontmatter = .{},
        };
    }

    pub fn atEnd(self: *const @This()) bool { return self.pos >= self.src.len; }

    pub fn peek(self: *const @This()) ?u8 {
        return if (self.pos < self.src.len) self.src[self.pos] else null;
    }

    pub fn peekAt(self: *const @This(), offset: usize) ?u8 {
        const i = self.pos + offset;
        return if (i < self.src.len) self.src[i] else null;
    }

    pub fn startsWith(self: *const @This(), s: []const u8) bool {
        if (self.pos + s.len > self.src.len) return false;
        return std.mem.eql(u8, self.src[self.pos .. self.pos + s.len], s);
    }

    pub fn advance(self: *@This()) void { if (self.pos < self.src.len) self.pos += 1; }

    pub fn advanceBy(self: *@This(), n: usize) void {
        self.pos = @min(self.pos + n, self.src.len);
    }

    pub fn skipToEOL(self: *@This()) void {
        while (self.pos < self.src.len and self.src[self.pos] != '\n') self.pos += 1;
    }

    pub fn skipNewline(self: *@This()) void {
        if (self.pos < self.src.len and self.src[self.pos] == '\n') self.pos += 1;
    }

    pub fn skipBlankLines(self: *@This()) void {
        while (self.pos < self.src.len) {
            const c = self.src[self.pos];
            if (c == '\n') {
                self.pos += 1;
            } else if (c == ' ' or c == '\t') {
                var i = self.pos;
                while (i < self.src.len and (self.src[i] == ' ' or self.src[i] == '\t')) i += 1;
                if (i >= self.src.len or self.src[i] == '\n') self.pos = i else break;
            } else break;
        }
    }
};

pub const Parsed = struct {
    root: NodeID,
    text: []const u8,
    nodes: std.ArrayListUnmanaged(Node),
    indices: std.ArrayListUnmanaged(NodeID),
    arena: std.heap.ArenaAllocator,
    frontmatter: Frontmatter,

    pub fn getSlice(self: *const @This(), slice: NodeSlice) []const NodeID {
        return self.indices.items[slice.start.into()..slice.end.into()];
    }

    pub fn getNode(self: *const @This(), id: NodeID) Node {
        return self.nodes.items[id.into()];
    }

    pub fn getText(self: *const @This(), slice: BufSlice) []const u8 {
        return self.text[slice.start.into()..slice.end.into()];
    }

    pub fn getNodeText(self: *const @This(), node: Node) []const u8 {
        const s = node.start.into();
        return self.text[s .. s + node.len];
    }
};
