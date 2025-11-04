//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub const GraphemeIterator = struct {
    text: []const u8,
    pos: u32 = 0,

    pub fn init(text: []const u8) GraphemeIterator {
        return GraphemeIterator{
            .text = text,
            .pos = 0,
        };
    }

    pub fn next(self: *GraphemeIterator) ?[]const u8 {
        if (self.pos >= self.text.len) return null;

        const start = self.pos;

        // Get the first code point
        const len = std.unicode.utf8ByteSequenceLength(self.text[self.pos]) catch return null;
        self.pos += len;

        // Keep consuming while we should continue
        while (self.pos < self.text.len) {
            const check_pos = self.pos;
            const check_len = std.unicode.utf8ByteSequenceLength(self.text[check_pos]) catch break;
            const codepoint = std.unicode.utf8Decode(self.text[check_pos..][0..check_len]) catch break;

            // Debug output
            // std.debug.print("    Checking at pos {}: U+{X:0>4} ", .{check_pos, codepoint});

            if (codepoint == 0x200D) {
                // std.debug.print("(ZWJ) - continuing\n", .{});
                self.pos += check_len;

                // After ZWJ, consume everything until we hit another ZWJ or end
                if (self.pos < self.text.len) {
                    const next_len = std.unicode.utf8ByteSequenceLength(self.text[self.pos]) catch break;
                    // const next_cp = std.unicode.utf8Decode(self.text[self.pos..][0..next_len]) catch break;
                    // std.debug.print("    After ZWJ, found U+{X:0>4} - consuming\n", .{next_cp});
                    self.pos += next_len;

                    // Now check for combining marks on this new base
                    while (self.pos < self.text.len) {
                        const mark_len = std.unicode.utf8ByteSequenceLength(self.text[self.pos]) catch break;
                        const mark_cp = std.unicode.utf8Decode(self.text[self.pos..][0..mark_len]) catch break;

                        if (self.isCombiningMark(mark_cp) or self.isVariationSelector(mark_cp)) {
                            // std.debug.print("    Found combining/VS U+{X:0>4} - consuming\n", .{mark_cp});
                            self.pos += mark_len;
                        } else if (mark_cp == 0x200D) {
                            // Another ZWJ! Keep going
                            // std.debug.print("    Found another ZWJ - looping\n", .{});
                            break; // Break inner loop to continue outer loop
                        } else {
                            // std.debug.print("    Found U+{X:0>4} - not continuing\n", .{mark_cp});
                            return self.text[start..self.pos];
                        }
                    }
                }
            } else if (self.isCombiningMark(codepoint)) {
                // std.debug.print("(combining) - continuing\n", .{});
                self.pos += check_len;
            } else if (self.isVariationSelector(codepoint)) {
                // std.debug.print("(VS) - continuing\n", .{});
                self.pos += check_len;
            } else {
                // std.debug.print("(other) - stopping\n", .{});
                break;
            }
        }

        return self.text[start..self.pos];
    }

    /// Peek at multiple graphemes and return them all
    /// Returns a slice of grapheme slices, up to n or until end of text
    pub fn peekMany(self: *const GraphemeIterator, allocator: std.mem.Allocator, n: usize) ![][]const u8 {
        if (n == 0) return &[_][]const u8{};

        var temp_iter = GraphemeIterator{
            .text = self.text,
            .pos = self.pos,
        };

        var graphemes = try allocator.alloc([]const u8, n);
        var count: usize = 0;

        while (count < n) {
            if (temp_iter.next()) |grapheme| {
                graphemes[count] = grapheme;
                count += 1;
            } else {
                break;
            }
        }
        
        // Resize to actual count if we hit the end
        if (count < n) {
            graphemes = try allocator.realloc(graphemes, count);
        }

        return graphemes;
    }

    /// Check if there are at least n more graphemes available
    pub fn hasNext(self: *const GraphemeIterator, n: usize) bool {
        var temp_iter = GraphemeIterator{
            .text = self.text,
            .pos = self.pos,
        };

        var i: usize = 0;
        while (i < n) : (i += 1) {
            if (temp_iter.next() == null) return false;
        }

        return true;
    }

    fn isCombiningMark(self: *const GraphemeIterator, codepoint: u21) bool {
        _ = self;
        return (codepoint >= 0x0300 and codepoint <= 0x036F) or
               (codepoint >= 0x1AB0 and codepoint <= 0x1AFF) or
               (codepoint >= 0x1DC0 and codepoint <= 0x1DFF) or
               (codepoint >= 0x20D0 and codepoint <= 0x20FF) or
               (codepoint >= 0xFE20 and codepoint <= 0xFE2F);
    }

    pub fn startsWith(self: *const GraphemeIterator, target: []const u8) bool {
        var target_iter = GraphemeIterator.init(target);

        var cloned = GraphemeIterator{
            .text = self.text,
            .pos = self.pos,
        };

        while (target_iter.next()) |expected| {
            const actual = cloned.next() orelse return false;
            if (!std.mem.eql(u8, actual, expected))
                return false;
        }
        return true;
    }

    fn isVariationSelector(self: *const GraphemeIterator, codepoint: u21) bool {
        _ = self;
        return (codepoint >= 0xFE00 and codepoint <= 0xFE0F) or
               (codepoint >= 0xE0100 and codepoint <= 0xE01EF);
    }
};

// fn test() !void {
//     const allocator = std.heap.page_allocator;
//     _ = allocator;

//     // Test with various Unicode combinations
//     const test_strings = [_][]const u8{
//         "Hello 👨‍👩‍👧‍👦 world",  // Family emoji with ZWJ
//         "café",                    // é as single character
//         "cafe\u{0301}",           // é as e + combining acute
//         "🏳️‍🌈",                    // Rainbow flag (flag + VS16 + ZWJ + rainbow)
//         "Ẓ̌á̲l͔g̖o",                // Zalgo text with many combiners
//         "A\u{0300}\u{0301}",      // A with multiple accents
//     };

//     for (test_strings) |text| {
//         std.debug.print("\nProcessing: \"{s}\"\n", .{text});
//         std.debug.print("Bytes: {d}\n", .{text.len});

//         var iter = GraphemeIterator{ .text = text };
//         var count: usize = 0;

//         while (iter.next()) |grapheme| {
//             count += 1;
//             std.debug.print("  Grapheme {d}: \"{s}\" ({d} bytes)\n", .{ count, grapheme, grapheme.len });
//         }

//         std.debug.print("Total graphemes: {d}\n", .{count});
//     }
// }
