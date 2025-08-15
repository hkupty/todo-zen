const std = @import("std");
const walker = @import("walker.zig");

// TODO: Make it configurable
const variants = [_][]const u8{ "TODO", "HACK", "NOTE", "PERF", "FIX", "FIXME" };

// TODO: Make it configurable
const extensions = [_][]const u8{
    ".zig",
    ".md",
    ".kt",
    ".java",
    ".go",
};

const TodoIterator = struct {
    reader: std.fs.File.Reader,
    allocator: std.mem.Allocator,
    commentBuffer: std.ArrayList(u8),
    start: usize = 0,

    fn readCommentsDirect(self: *TodoIterator) !?[]u8 {
        var buffer: [4 * 1024]u8 = undefined;

        while (true) {
            const items = self.commentBuffer.items;
            if (std.mem.indexOfPos(u8, items, self.start, "//")) |commentStart| {
                if (std.mem.indexOfScalarPos(u8, items, commentStart, '\n')) |linebreakIndex| {
                    self.start = linebreakIndex + 1;
                    return items[commentStart..linebreakIndex];
                } else {
                    const amt = try self.reader.readAll(&buffer);
                    if (amt == 0) break;
                    try self.commentBuffer.appendSlice(&buffer);
                    continue;
                }
            } else {
                self.commentBuffer.clearRetainingCapacity();
                self.start = 0;
                const amt = try self.reader.readAll(&buffer);
                if (amt == 0) break;
                try self.commentBuffer.appendSlice(&buffer);
            }
        }

        self.commentBuffer.clearAndFree();

        return null;
    }

    fn readTODOComments(self: *TodoIterator) !?[]u8 {
        while (try self.readCommentsDirect()) |comment| {
            for (variants) |prefix| {
                if (std.mem.indexOf(u8, comment, prefix)) |index| {
                    return try self.allocator.dupe(u8, comment[index..]);
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

    var hasPrint = false;

    while (try iterator.readTODOComments()) |line| {
        if (!hasPrint) {
            _ = try stdout.write("\n → ");
            _ = try stdout.write(identifier);
            _ = try stdout.write("\n");
            hasPrint = true;
        }
        _ = try stdout.write(line);
        _ = try stdout.write("\n");
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

    var dirWalker = try walker.walk(allocator, cwd);
    defer dirWalker.deinit();
    while (try dirWalker.next()) |entry| next: {
        // TODO: Ignore .gitignore files
        // NOTE: Revisit blocking all the hidden files
        if (entry.kind == .directory and std.mem.startsWith(u8, entry.basename, ".")) {
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
