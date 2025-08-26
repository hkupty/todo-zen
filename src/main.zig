const std = @import("std");
const Config = @import("config.zig");
const Walker = std.fs.Dir.Walker;

const stdout_buffer_size: usize = 4 * 1024;
const file_buffer_size: usize = 4 * 1024;

var stdout_buffer: [stdout_buffer_size]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout = &stdout_writer.interface;

fn readTodos(identifier: []const u8, file: std.fs.File, config: Config) !usize {
    var reader_buffer: [file_buffer_size]u8 = undefined;
    var file_reader = file.reader(&reader_buffer);
    var reader = &file_reader.interface;
    var count: usize = 0;
    var lineno: usize = 1;

    lines: while (!file_reader.atEnd()) : (lineno += 1) {
        const line = reader.peekDelimiterExclusive('\n') catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };

        if (std.mem.indexOf(u8, line, config.prefix)) |prefix| {
            for (config.markers) |marker| {
                if (std.mem.indexOfPos(u8, line, prefix, marker)) |mpos| {
                    count += 1;
                    _ = try stdout.write(identifier);
                    _ = try stdout.writeByte(':');
                    _ = try stdout.printInt(lineno, 10, .lower, .{});
                    _ = try stdout.writeByte(':');
                    _ = try stdout.printInt(mpos, 10, .lower, .{});

                    reader.toss(mpos);
                    _ = try reader.streamDelimiter(stdout, '\n');
                    try stdout.writeByte('\n');
                    reader.toss(1);
                    continue :lines;
                }
            }
        }
        reader.toss(line.len + 1);
    }

    try stdout.flush();

    return count;
}

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

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
    var dirWalker = try cwd.walk(allocator);
    defer dirWalker.deinit();
    var count: usize = 0;
    while (try dirWalker.next()) |entry| next: {
        switch (entry.kind) {
            .directory => {
                @branchHint(.unlikely);
                if (std.mem.startsWith(u8, entry.basename, ".")) {
                    // NOTE: Revisit blocking all the hidden files
                    @branchHint(.cold);
                    skip(&dirWalker);
                    continue;
                } else if (config.maxSrcDepth > 0 and depth(&dirWalker) > config.maxSrcDepth and std.mem.indexOf(u8, entry.path, "src") == null) {
                    // PERF: This check avoids unnecessary traversals on non-code paths in the directory structure
                    skip(&dirWalker);
                    continue;
                } else if (config.maxDepth > 0 and depth(&dirWalker) > config.maxDepth) {
                    // PERF: This check avoids unnecessary traversals on too nested paths in the directory structure
                    skip(&dirWalker);
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

                const file = try entry.dir.openFile(entry.basename, .{ .mode = .read_only });
                defer file.close();

                count += try readTodos(entry.path, file, config);
            },
            else => {},
        }
    }

    if (config.threshold > 0 and count > config.threshold) {
        return 1;
    }

    return 0;
}

pub fn depth(self: *Walker) usize {
    return self.stack.items.len;
}

/// Skips processing the remainder of the files in the current directory
pub fn skip(self: *Walker) void {
    var item = self.stack.pop().?;
    if (self.stack.items.len != 0) {
        item.iter.dir.close();
    }
}
