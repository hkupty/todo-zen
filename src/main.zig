const std = @import("std");
const walker = @import("walker.zig");

// TODO: Make it configurable
const variants = [_][]const u8{ "TODO", "HACK", "NOTE", "PERF", "FIX", "FIXME" };

// TODO: Make it configurable
const extensions = [_][]const u8{
    ".zig",
    ".kt",
    ".java",
    ".go",
};

const Match = struct {
    text: []u8,
    linenumber: usize,
    column: usize,
};

const TodoIterator = struct {
    reader: std.fs.File.Reader,
    allocator: std.mem.Allocator,
    commentBuffer: std.ArrayList(u8),
    start: usize = 0,
    lines: usize = 0,

    fn readCommentsDirect(self: *TodoIterator) !?Match {
        var buffer: [4 * 1024]u8 = undefined;

        while (true) {
            const items = self.commentBuffer.items;
            if (std.mem.indexOfPos(u8, items, self.start, "//")) |commentStart| {
                if (std.mem.indexOfScalarPos(u8, items, commentStart, '\n')) |linebreakIndex| {
                    const columnOffset = std.mem.lastIndexOfScalar(u8, items[0..commentStart], '\n') orelse 0;
                    const lineOffset = std.mem.count(u8, items[0..commentStart], "\n") + 1;
                    self.start = linebreakIndex + 1;
                    return .{
                        .text = items[commentStart..linebreakIndex],
                        .linenumber = self.lines + lineOffset,
                        .column = commentStart - columnOffset,
                    };
                } else {
                    const amt = try self.reader.readAll(&buffer);
                    if (amt == 0) break;
                    try self.commentBuffer.appendSlice(&buffer);
                    continue;
                }
            } else {
                self.commentBuffer.clearRetainingCapacity();
                self.start = 0;
                self.lines = std.mem.count(u8, items, "\n");
                const amt = try self.reader.readAll(&buffer);
                if (amt == 0) break;
                try self.commentBuffer.appendSlice(&buffer);
            }
        }

        self.commentBuffer.clearAndFree();

        return null;
    }

    fn readTODOComments(self: *TodoIterator) !?Match {
        while (try self.readCommentsDirect()) |comment| {
            for (variants) |prefix| {
                if (std.mem.indexOf(u8, comment.text, prefix)) |index| {
                    return .{
                        .text = comment.text[index..],
                        .linenumber = comment.linenumber,
                        .column = comment.column,
                    };
                }
            }
        }
        return null;
    }
};

fn readTodos(allocator: std.mem.Allocator, identifier: []const u8, file: std.fs.File) !void {
    var iterator = TodoIterator{
        .reader = file.reader(),
        .allocator = allocator,
        .commentBuffer = std.ArrayList(u8).init(allocator),
    };
    const stdout = std.io.getStdOut();
    var lineBuilder = try std.ArrayList(u8).initCapacity(allocator, identifier.len + 100);

    lineBuilder.appendSliceAssumeCapacity(identifier);
    lineBuilder.appendAssumeCapacity(':');

    while (try iterator.readTODOComments()) |line| {
        lineBuilder.shrinkRetainingCapacity(identifier.len + 1);
        const linenumber = try std.fmt.allocPrint(allocator, "{d}", .{line.linenumber});
        const column = try std.fmt.allocPrint(allocator, "{d}", .{line.column});
        try lineBuilder.ensureUnusedCapacity(linenumber.len + column.len + line.text.len + 3);
        lineBuilder.appendSliceAssumeCapacity(linenumber);
        lineBuilder.appendAssumeCapacity(':');
        lineBuilder.appendSliceAssumeCapacity(column);
        lineBuilder.appendAssumeCapacity(':');
        lineBuilder.appendSliceAssumeCapacity(line.text);
        lineBuilder.appendAssumeCapacity('\n');

        _ = try stdout.write(lineBuilder.items);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var arena = std.heap.ArenaAllocator.init(allocator);
    const arenaAllocator = arena.allocator();
    defer arena.deinit();

    var cwd = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer cwd.close();

    // TODO Make it configurable
    const maxDepth = 3;

    var dirWalker = try walker.walk(allocator, cwd);
    defer dirWalker.deinit();
    while (try dirWalker.next()) |entry| next: {
        // TODO: Ignore .gitignore files
        // NOTE: Revisit blocking all the hidden files
        if (entry.kind == .directory and std.mem.startsWith(u8, entry.basename, ".")) {
            dirWalker.skip();
            continue;
        }

        if (entry.kind == .directory and dirWalker.depth() > maxDepth and std.mem.indexOf(u8, entry.path, "src") == null) {
            dirWalker.skip();
            continue;
        }

        if (entry.kind == .file) {
            const extension = std.fs.path.extension(entry.basename);

            check: {
                for (extensions) |ext| {
                    if (std.mem.eql(u8, ext, extension)) {
                        break :check;
                    }
                }
                break :next;
            }

            defer _ = arena.reset(.retain_capacity);
            const file = try entry.dir.openFile(entry.basename, .{ .mode = .read_only });
            defer file.close();

            try readTodos(arenaAllocator, entry.path, file);
        }
    }
}
