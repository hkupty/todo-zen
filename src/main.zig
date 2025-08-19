const std = @import("std");
const walker = @import("walker.zig");
const Config = @import("config.zig");

const stdout = std.io.getStdOut();

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

    fn readCommentsDirect(self: *TodoIterator, prefix: []const u8) !?Match {
        var buffer: [4 * 1024]u8 = undefined;

        while (true) {
            const items = self.commentBuffer.items;
            if (std.mem.indexOfPos(u8, items, self.start, prefix)) |commentStart| {
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
                self.lines = self.lines + std.mem.count(u8, items, "\n");
                const amt = try self.reader.readAll(&buffer);
                if (amt == 0) break;
                try self.commentBuffer.appendSlice(buffer[0..amt]);
            }
        }

        return null;
    }

    fn readTODOComments(self: *TodoIterator, config: Config) !?Match {
        while (try self.readCommentsDirect(config.prefix)) |comment| {
            for (config.markers) |prefix| {
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

fn readTodos(allocator: std.mem.Allocator, identifier: []const u8, file: std.fs.File, config: Config) !usize {
    var iterator = TodoIterator{
        .reader = file.reader(),
        .allocator = allocator,
        .commentBuffer = std.ArrayList(u8).init(allocator),
    };

    var lineBuilder = try std.ArrayList(u8).initCapacity(allocator, identifier.len + 100);

    lineBuilder.appendSliceAssumeCapacity(identifier);
    lineBuilder.appendAssumeCapacity(':');
    var count: usize = 0;

    while (try iterator.readTODOComments(config)) |line| : (count += 1) {
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

    return count;
}

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var arena = std.heap.ArenaAllocator.init(allocator);
    const arenaAllocator = arena.allocator();
    defer arena.deinit();

    var cwd = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer cwd.close();

    const config = Config.parseConfigFromArgs(allocator) catch |err| {
        switch (err) {
            Config.ConfigError.Help => return 0,
            else => return err,
        }
    };
    defer config.deinit(allocator);

    // TODO: Ignore .gitignore files
    var dirWalker = try walker.walk(allocator, cwd);
    defer dirWalker.deinit();
    var count: usize = 0;
    while (try dirWalker.next()) |entry| next: {
        switch (entry.kind) {
            .directory => {
                if (std.mem.startsWith(u8, entry.basename, ".")) {
                    // NOTE: Revisit blocking all the hidden files
                    @branchHint(.unlikely);
                    dirWalker.skip();
                    continue;
                } else if (config.maxSrcDepth > 0 and dirWalker.depth() > config.maxSrcDepth and std.mem.indexOf(u8, entry.path, "src") == null) {
                    // PERF: This check avoids unnecessary traversals on non-code paths in the directory structure
                    dirWalker.skip();
                    continue;
                } else if (config.maxDepth > 0 and dirWalker.depth() > config.maxDepth) {
                    // PERF: This check avoids unnecessary traversals on too nested paths in the directory structure
                    dirWalker.skip();
                    continue;
                }
            },
            .file => {
                @branchHint(.likely);
                const extension = std.fs.path.extension(entry.basename);
                // NOTE: when the file is either `.gitignore` or `something.`, the size will be smaller than 2 ("" or "." respectively)
                if (extension.len < 2) break :next;

                // PERF: Avoid checking files that are not actual source files, based on extensions
                check: {
                    for (config.fileTypes) |ext| {
                        if (std.mem.eql(u8, ext, extension[1..])) {
                            break :check;
                        }
                    }
                    break :next;
                }

                defer _ = arena.reset(.retain_capacity);

                const file = try entry.dir.openFile(entry.basename, .{ .mode = .read_only });
                defer file.close();

                count += try readTodos(arenaAllocator, entry.path, file, config);
            },
            else => {},
        }
    }

    if (config.threshold > 0 and count > config.threshold) {
        return 1;
    }

    return 0;
}
