const std = @import("std");
pub const GraphemeIterator = @import("blog").GraphemeIterator;

fn makeID(comptime T: type, comptime U: type) type {
    _ = U;
    return enum(T) {
        _,

        pub fn id(self: @This()) T {
            return @intFromEnum(self);
        }

        pub fn from(int: usize) @This() {
            return @enumFromInt(int);
        }

        pub fn into(self: @This()) usize {
            return @intFromEnum(self);
        }
    };
}

pub const NodeID = makeID(u32, Node);
pub const ChildrenID = makeID(u32, NodeID);
pub const BufInd = makeID(u32, GraphemeIterator);

// a slice into the array of NodeIDs
pub const NodeSlice = struct {
    start: ChildrenID,
    end: ChildrenID,
};

pub const BufSlice = struct {
    start: BufInd,
    end: BufInd,
};

pub const NodeKind = union(enum) {
    para: NodeSlice,
    text: void,
    codeI: void,
    bold: NodeSlice,
    italic: NodeSlice,
    math: void,
    link: struct {
        url: BufSlice,
        content: NodeSlice,
    },
    // wikilink: struct {
    //     target: []const u8,
    //     section: ?[]const u8,
    //     alias: ?[]const u8,
    // },
    // codeB: struct {
    //     language: []const u8,
    //     content: []struct {
    //         content: []const u8,
    //         decorator: []const u8,
    //     },
    // },
    // image: struct {
    //     url: []const u8,
    //     alt: []const u8,
    // },
    // video: struct {
    //     url: []const u8,
    //     alt: []const u8,
    // },
    heading: struct {
        level: u8,
        content: NodeSlice,
    },
    // list: struct {
    //     ordered: bool,
    //     items: NodeSlice,
    // },
};


pub const Node = struct {
    kind: NodeKind,
    start: BufInd,
    len: u32,
};

pub const Scratch = struct {
    parser: *Parser,
    scratch: [64]NodeID = undefined,
    count: usize = 0,

    pub fn init(parser: *Parser) Scratch {
        return Scratch{
            .parser = parser,
            .scratch = undefined,
            .count = 0,
        };
    }

    pub fn add(self: *@This(), node_id: NodeID) !void {
        if (self.count >= self.scratch.len) {
            return error.TooManyChildren; // Or dynamically grow
        }
        self.scratch[self.count] = node_id;
        self.count += 1;
    }

    pub fn finish(self: *@This()) std.mem.Allocator.Error!NodeSlice {
        const start = self.parser.indices.items.len;
        try self.parser.indices.appendSlice(self.parser.arena.allocator(), self.scratch[0..self.count]);
        return NodeSlice{ .start = ChildrenID.from(start), .end = ChildrenID.from(self.parser.indices.items.len) };
    }
};

// LOGGING [[[
threadlocal var debug_depth: usize = 0;

pub fn log(comptime fmt: []const u8, args: anytype) void {
    _ = args;
    _ = fmt;
    // var i: usize = 0;
    // while (i < debug_depth) : (i += 1) {
    //     std.debug.print("  ", .{});
    // }
    // std.debug.print(fmt ++ "\n", args);
}

pub fn enter(comptime name: []const u8) void {
    log("> {s}", .{name});
    debug_depth += 1;
}

pub fn exit() void {
    debug_depth -= 1;
}
// LOGGING ]]]

pub const Parser = struct {
    iter: GraphemeIterator,
    text: []const u8,
    nodes: std.ArrayList(Node),
    indices: std.ArrayList(NodeID),
    arena: std.heap.ArenaAllocator,

    pub fn new_node(self: *@This(), node: Node) !NodeID {
        try self.nodes.append(self.arena.allocator(), node);
        return NodeID.from(self.nodes.items.len - 1);
    }

    pub fn finish(self: *@This(), root: NodeID) Parsed {
        return Parsed{
            .root = root,
            .text = self.text,
            .nodes = self.nodes,
            .indices = self.indices,
            .arena = self.arena,
        };
    }

    pub fn pprint(self: *@This(), start_line: usize, num_lines: usize, node_id: NodeID) void {
        const node = self.nodes.items[node_id];

        // Find byte boundaries for the requested line range
        var line_num: usize = 0;
        var start_byte: usize = 0;
        var end_byte: usize = std.math.maxInt(usize);
        var in_range = false;

        for (self.text, 0..) |byte, pos| {
            if (line_num == start_line and !in_range) {
                in_range = true;
                start_byte = pos;
            }
            if (byte == '\n') {
                line_num += 1;
                if (in_range and line_num == start_line + num_lines) {
                    end_byte = pos;
                    break;
                }
            }
        }
        if (in_range and end_byte == std.math.maxInt(usize)) {
            end_byte = self.text.len - 1;
        }

        const text_slice = self.text[start_byte..end_byte];
        var children: []NodeID = undefined;
        switch (node.kind) {
            .para => {
                const ns = node.kind.para;
                children = self.indices.items[ns.start..ns.end];
            },
            .heading => {
                const ns = node.kind.heading.content;
                children = self.indices.items[ns.start..ns.end];
            },
            else => {
                children = &[_]NodeID{};
            },
        }

        std.debug.print("⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄⌄\n", .{});

        var byte_offset: usize = start_byte;
        var it = std.mem.splitScalar(u8, text_slice, '\n');
        while (it.next()) |line| {
            std.debug.print("> {s}\n", .{line});
            if (line.len == 0) {
                byte_offset += 1; // for newline
                continue;
            }
            var indicators: [120]u8 = undefined;
            @memset(&indicators, ' ');

            // for each immediate child
            for (children) |child_id| {
                const child = self.nodes.items[child_id];
                if (child.start >= byte_offset + line.len) break; // past this node

                const span_end = @min(child.start + child.len, byte_offset + line.len);
                if (child.start + child.len <= byte_offset) continue; // before this node
                if (span_end >= byte_offset) {
                    // overlaps
                    var name: []const u8 = "unknown";
                    switch (child.kind) {
                        .text => {
                            name = "text";
                        },
                        .para => {
                            name = "para";
                        },
                        .bold => {
                            name = "bold";
                        },
                        .italic => {
                            name = "italic";
                        },
                        .codeI => {
                            name = "code";
                        },
                        .heading => {
                            name = "heading";
                        },
                        else => {},
                    }
                    const rel_start = @max(child.start, byte_offset) - byte_offset;
                    const rel_end = @min((child.start + child.len - 1) - byte_offset, byte_offset + line.len - 1);
                    // std.debug.print("Child ID: {}, Kind: {}, Span: [{}..{}], Rel Span: [{}..{}]\n", .{child_id, child.kind, child.start, child.start + child.len, rel_start, rel_end});
                    @memcpy(indicators[rel_start + 1 .. rel_start + 1 + name.len], name);
                    indicators[rel_start] = '[';
                    indicators[rel_end] = ']';
                }
            }

            if (!std.mem.allEqual(u8, &indicators, ' ')) {
                std.debug.print("  {s}\n", .{indicators});
            }
            byte_offset += line.len + 1; // +1 for newline
        }
        std.debug.print("⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃⌃\n", .{});
    }
};

pub const Parsed = struct {
    root: NodeID,
    text: []const u8,
    nodes: std.ArrayList(Node),
    indices: std.ArrayList(NodeID),
    arena: std.heap.ArenaAllocator,

    pub fn getSlice(self: *const @This(), slice: NodeSlice) []const NodeID {
        return self.indices.items[slice.start.into()..slice.end.into()];
    }

    pub fn getNode(self: *const @This(), id: NodeID) Node {
        return self.nodes.items[id.into()];
    }
};
