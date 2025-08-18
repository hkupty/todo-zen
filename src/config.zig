const std = @import("std");

const stdout = std.io.getStdOut();

const variants = [_][]const u8{ "TODO", "HACK", "FIX", "FIXME" };

// TODO: Enable different comment prefixes for different file types
const extensions = [_][]const u8{
    "zig",
    "kt",
    "java",
    "go",
};

const help =
    \\todo-zen [options]
    \\
    \\Options:
    \\     -h --help            Shows this help text
    \\     -d --max-depth       Maximum traversal depth.                                [default: 8]
    \\                          Set to 0 to disable.
    \\     -D --max-src-depth   Maximum depth for a `src/` folder.                      [default: 3]
    \\                          Set to 0 to disable.
    \\     -t --threshold       When set, exit with code 1 if there are more todos      [default: 0]
    \\                          then the value set in the threshold.
    \\     -m --markers         Comment markers to look for in the comments.            [default: TODO,HACK,FIX,FIXME]
    \\     -x --extensions      File extensions to be considered during search.         [default: zig,java,kt,go]
    \\
;

markers: [][]const u8,
maxDepth: usize,
maxSrcDepth: usize,
threshold: usize,
fileTypes: [][]const u8,

const Config = @This();

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

pub const ConfigError = error{
    Help,
};

pub fn parseConfigFromArgs(allocator: std.mem.Allocator) !Config {
    var args = std.process.args();
    defer args.deinit();
    _ = args.skip();

    var cursor: ?[]const u8 = null;
    var markers: ?[][]const u8 = null;
    var filetypes: ?[][]const u8 = null;
    var maxDepth: ?usize = null;
    var maxSrcDepth: ?usize = null;
    var threshold: ?usize = null;
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
            } else if (std.mem.eql(u8, "-t", flag) or std.mem.eql(u8, "--threshold", flag)) {
                threshold = try std.fmt.parseInt(usize, arg, 10);
            }
            cursor = null;
        } else {
            if (std.mem.eql(u8, "-h", arg) or std.mem.eql(u8, "--help", arg)) {
                _ = try stdout.writeAll(help);
                return ConfigError.Help;
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
        .threshold = threshold orelse 0,
    };
}
