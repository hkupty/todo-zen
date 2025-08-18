const std = @import("std");
const walker = @import("walker.zig");

const variants = [_][]const u8{ "TODO", "HACK", "FIX", "FIXME" };

// TODO: Enable different comment prefixes for different file types
const extensions = [_][]const u8{
    "zig",
    "kt",
    "java",
    "go",
};

const stdout = std.io.getStdOut();

const help =
    \\todo-zen [options]
    \\
    \\Options:
    \\     -h --help            Shows this help text
    \\     -d --max-depth       Maximum traversal depth. Set to 0 to disable            [default: 8]
    \\     -D --max-src-depth   Maximum depth for a `src/` folder. Set to 0 to disable  [default: 3]
    \\     -m --markers         Comment markers to look for in the comments.            [default: TODO,HACK,FIX,FIXME]
    \\     -x --extensions      File extensions to be considered during search.         [default: zig,java,kt,go]
    \\
;

const Config = struct {
    markers: [][]const u8,
    maxDepth: usize,
    maxSrcDepth: usize,
    fileTypes: [][]const u8,

    pub fn deinit(self: *const Config, allocator: std.mem.Allocator) void {
        for (self.markers) |marker| {
            allocator.free(marker);
        }

        for (self.fileTypes) |ft| {
            allocator.free(ft);
        }
        allocator.free(self.markers);
        allocator.free(self.fileTypes);
    }
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
                self.lines = self.lines + std.mem.count(u8, items, "\n");
                const amt = try self.reader.readAll(&buffer);
                if (amt == 0) break;
                try self.commentBuffer.appendSlice(buffer[0..amt]);
            }
        }

        return null;
    }

    fn readTODOComments(self: *TodoIterator, config: Config) !?Match {
        while (try self.readCommentsDirect()) |comment| {
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

fn readTodos(allocator: std.mem.Allocator, identifier: []const u8, file: std.fs.File, config: Config) !void {
    var iterator = TodoIterator{
        .reader = file.reader(),
        .allocator = allocator,
        .commentBuffer = std.ArrayList(u8).init(allocator),
    };

    var lineBuilder = try std.ArrayList(u8).initCapacity(allocator, identifier.len + 100);

    lineBuilder.appendSliceAssumeCapacity(identifier);
    lineBuilder.appendAssumeCapacity(':');

    while (try iterator.readTODOComments(config)) |line| {
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

pub fn parseConfigFromArgs(allocator: std.mem.Allocator) !Config {
    var args = std.process.args();
    defer args.deinit();
    _ = args.skip();

    var cursor: ?[]const u8 = null;
    var markers: ?[][]const u8 = null;
    var filetypes: ?[][]const u8 = null;
    var maxDepth: ?usize = null;
    var maxSrcDepth: ?usize = null;
    while (args.next()) |arg| {
        if (cursor) |flag| {
            if (std.mem.eql(u8, "-m", flag) or std.mem.eql(u8, "--markers", flag)) {
                const max = std.mem.count(u8, arg, ",") + 1;
                markers = try allocator.alloc([]const u8, max);

                var splitIter = std.mem.splitScalar(u8, arg, ',');
                var ix: usize = 0;
                while (splitIter.next()) |nxt| : (ix += 1) {
                    const marker = allocator.dupe(u8, nxt) catch |err| {
                        std.log.err(
                            "Failed to allocate more memory. Will try to operate on best effort. {any}",
                            .{err},
                        );
                        break;
                    };
                    markers.?[ix] = marker;
                }
            } else if (std.mem.eql(u8, "-x", flag) or std.mem.eql(u8, "--extensions", flag)) {
                const max = std.mem.count(u8, arg, ",") + 1;
                filetypes = try allocator.alloc([]const u8, max);

                var splitIter = std.mem.splitScalar(u8, arg, ',');
                var ix: usize = 0;
                while (splitIter.next()) |nxt| : (ix += 1) {
                    const ft = allocator.dupe(u8, nxt) catch |err| {
                        std.log.err(
                            "Failed to allocate more memory. Will try to operate on best effort. {any}",
                            .{err},
                        );
                        break;
                    };
                    filetypes.?[ix] = ft;
                }
            } else if (std.mem.eql(u8, "-d", flag) or std.mem.eql(u8, "--max-depth", flag)) {
                maxDepth = try std.fmt.parseInt(usize, arg, 10);
            } else if (std.mem.eql(u8, "-D", flag) or std.mem.eql(u8, "--max-src-depth", flag)) {
                maxSrcDepth = try std.fmt.parseInt(usize, arg, 10);
            }
            cursor = null;
        } else {
            if (std.mem.eql(u8, "-h", arg) or std.mem.eql(u8, "--help", arg)) {
                _ = try stdout.writeAll(help);
                std.process.exit(0);
            }

            cursor = arg;
        }
    }

    if (markers == null) {
        markers = try allocator.alloc([]const u8, variants.len);
        for (variants, 0..) |marker, ix| {
            markers.?[ix] = try allocator.dupe(u8, marker);
        }
    }

    if (filetypes == null) {
        filetypes = try allocator.alloc([]const u8, extensions.len);
        for (extensions, 0..) |ft, ix| {
            filetypes.?[ix] = try allocator.dupe(u8, ft);
        }
    }

    return .{
        .markers = markers.?,
        .fileTypes = filetypes.?,
        .maxDepth = maxDepth orelse 8,
        .maxSrcDepth = maxSrcDepth orelse 3,
    };
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

    const config = try parseConfigFromArgs(allocator);
    defer config.deinit(allocator);

    // TODO: Ignore .gitignore files
    var dirWalker = try walker.walk(allocator, cwd);
    defer dirWalker.deinit();
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

                try readTodos(arenaAllocator, entry.path, file, config);
            },
            else => {},
        }
    }
}
