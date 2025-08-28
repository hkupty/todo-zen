const std = @import("std");
const Config = @import("config.zig");
const walker = @import("walker.zig");

// TODO: Allow multi-threaded
// TODO: trie-based file blocking (to enable .gitignore)

const stdout_buffer_size: usize = 64 * 1024;
const file_buffer_size: usize = 4 * 1024;

var stdout_buffer: [stdout_buffer_size]u8 = undefined;
var reader_buffer: [file_buffer_size]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout = &stdout_writer.interface;

fn readTodos(identifier: []const u8, reader: *std.Io.Reader, config: Config) !usize {
    var count: usize = 0;
    var lineno: usize = 1;

    lines: while (true) : (lineno += 1) {
        const line = reader.peekDelimiterInclusive('\n') catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };

        const prefixIndex: ?usize = sz: switch (config.prefix.len) {
            1 => break :sz std.mem.indexOfScalar(u8, line, config.prefix[0]),
            2 => {
                @branchHint(.likely);
                if (std.mem.indexOfScalar(u8, line, config.prefix[0])) |index| {
                    break :sz if (line[index + 1] == config.prefix[1]) index else null;
                } else {
                    break :sz null;
                }
            },

            else => break :sz std.mem.indexOf(u8, line, config.prefix),
        };

        if (prefixIndex) |prefix| {
            @branchHint(.unlikely);
            for (config.markers) |marker| {
                if (std.mem.indexOfScalarPos(u8, line, prefix, marker[0])) |mpos| {
                    const match = line[mpos..];
                    if (match.len >= marker.len and std.mem.eql(u8, match[0..marker.len], marker)) {
                        @branchHint(.unlikely);
                        count += 1;
                        _ = try stdout.write(identifier);
                        _ = try stdout.writeByte(':');
                        _ = try stdout.printInt(lineno, 10, .lower, .{});
                        _ = try stdout.writeByte(':');
                        _ = try stdout.printInt(mpos, 10, .lower, .{});
                        _ = try stdout.writeByte(':');

                        reader.toss(mpos);
                        _ = try reader.streamDelimiter(stdout, '\n');
                        try stdout.writeByte('\n');
                        continue :lines;
                    }
                }
            }
        }
        reader.toss(line.len);
    }

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

    var dirWalker = try walker.DirWalker.init(allocator, cwd);
    defer dirWalker.deinit(allocator);
    var count: usize = 0;
    while (try dirWalker.next(allocator)) |entry| next: {
        switch (entry.kind) {
            .directory => {
                @branchHint(.unlikely);
                // Ignore hidden folders
                if (entry.basename[0] == '.') break :next;
                const cur_depth = dirWalker.depth() + 1;

                // Ignore deep paths without src
                if (config.maxSrcDepth > 0 and cur_depth > config.maxSrcDepth and std.mem.indexOf(u8, entry.path, "src") == null) break :next;
                // Ignore too deep paths
                if (config.maxDepth > 0 and cur_depth > config.maxDepth) break :next;

                try dirWalker.accept(allocator, entry);
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
                var file_reader = file.reader(&reader_buffer);

                count += try readTodos(entry.path, &file_reader.interface, config);
            },
            else => {},
        }
    }

    try stdout.flush();

    if (config.threshold > 0 and count > config.threshold) {
        return 1;
    }

    return 0;
}
