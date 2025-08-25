const std = @import("std");
const walker = @import("walker.zig");
const Config = @import("config.zig");

const stdout_buffer_size: usize = 2 * 1024;
const file_buffer_size: usize = 4 * 1024;
const content_buffer_size: usize = 6 * 1024;

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
                    try stdout.print(":{d}:{d}:", .{ lineno, mpos });
                    reader.toss(mpos);
                    _ = try reader.streamDelimiter(stdout, '\n');
                    try stdout.writeByte('\n');
                    reader.toss(1);
                    continue :lines;
                }
            }
        }
        reader.toss(line.len);
        _ = reader.peekByte() catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        reader.toss(1);
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
