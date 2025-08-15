const std = @import("std");
const walker = @import("walker.zig");

const variants = [_][]const u8{ "TODO", "HACK", "NOTE", "PERF", "FIX", "FIXME" };

const TodoIterator = struct {
    reader: std.fs.File.Reader,
    allocator: std.mem.Allocator,
    remaining: [256]u8 = undefined,
    startIx: usize = 0,
    endIx: usize = 0,

    /// Returns all lines from a file
    fn readLines(self: *TodoIterator) !?[]u8 {
        var buffer: [256]u8 = undefined;
        var lineBuffer = try std.ArrayList(u8).initCapacity(self.allocator, 256);
        defer lineBuffer.deinit();

        if (self.startIx != self.endIx) {
            if (std.mem.indexOf(u8, self.remaining[self.startIx..self.endIx], "\n")) |linebreakOffset| {
                const linebreakIndex = self.startIx + linebreakOffset;
                std.debug.assert(linebreakIndex <= self.endIx);
                const oldStart = self.startIx;
                self.startIx = linebreakIndex + 1;
                return try self.allocator.dupe(u8, self.remaining[oldStart..linebreakIndex]);
            }

            lineBuffer.appendSliceAssumeCapacity(self.remaining[self.startIx..self.endIx]);
        }

        while (true) {
            const amt = try self.reader.readAll(&buffer);
            if (amt == 0) break;

            if (std.mem.indexOf(u8, &buffer, "\n")) |linebreakIndex| {
                try lineBuffer.appendSlice(buffer[0..linebreakIndex]);
                @memcpy(&self.remaining, &buffer);
                self.startIx = linebreakIndex + 1;
                self.endIx = amt;
                return try lineBuffer.toOwnedSlice();
            } else {
                try lineBuffer.appendSlice(&buffer);
            }
        }

        if (lineBuffer.items.len > 0) {
            self.startIx = 0;
            self.endIx = 0;
            return try lineBuffer.toOwnedSlice();
        }

        return null;
    }

    /// Return only the comments, filtering them out from regular lines
    fn readComments(self: *TodoIterator) !?[]u8 {
        while (try self.readLines()) |line| {
            if (std.mem.indexOf(u8, line, "//")) |index| {
                if (index == 0 or std.ascii.isWhitespace(line[index - 1])) {
                    return try self.allocator.dupe(u8, line[index..]);
                }
            }
        }
        return null;
    }

    fn readTODOComments(self: *TodoIterator) !?[]u8 {
        while (try self.readComments()) |comment| {
            for (variants) |prefix| {
                if (std.mem.indexOf(u8, comment, prefix)) |index| {
                    return try self.allocator.dupe(u8, comment[index..]);
                }
            }
        }
        return null;
    }
};

fn readTodos(allocator: std.mem.Allocator, identifier: []const u8, fpath: []const u8) !void {
    const file = try std.fs.openFileAbsolute(fpath, .{ .mode = .read_only });
    defer file.close();
    var iterator = TodoIterator{
        .reader = file.reader(),
        .allocator = allocator,
    };
    const stdout = std.io.getStdOut();

    var hasPrint = false;

    while (try iterator.readTODOComments()) |line| {
        if (!hasPrint) {
            _ = try stdout.write("\n → ");
            _ = try stdout.write(identifier);
            _ = try stdout.write("\n\n");
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

    const path = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(path);
    var cwd = try std.fs.openDirAbsolute(path, .{ .iterate = true });
    defer cwd.close();

    var dirWalker = try walker.walk(allocator, cwd);
    defer dirWalker.deinit();
    while (try dirWalker.next()) |entry| {
        // NOTE: Revisit blocking all the hidden files
        if (entry.kind == .directory and std.mem.startsWith(u8, entry.path, ".")) {
            dirWalker.skip();
            continue;
        }

        if (entry.kind == .file) {
            const fullPath = try cwd.realpathAlloc(arenaAllocator, entry.path);
            defer _ = arena.reset(.retain_capacity);

            try readTodos(arenaAllocator, entry.path, fullPath);
        }
    }
}
