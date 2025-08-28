const std = @import("std");
const fs = std.fs;
const Dir = fs.Dir;
const Allocator = std.mem.Allocator;

pub const DirWalker = struct {
    stack: std.ArrayListUnmanaged(StackItem),
    name_buffer: std.ArrayListUnmanaged(u8),

    pub const empty: DirWalker = .{
        .stack = .{},
        .name_buffer = .{},
    };

    const StackItem = struct {
        iter: Dir.Iterator,
        dirname_len: usize,
        hit: bool,
    };

    pub const Entry = struct {
        /// The containing directory. This can be used to operate directly on `basename`
        /// rather than `path`, avoiding `error.NameTooLong` for deeply nested paths.
        /// The directory remains open until `next` or `deinit` is called.
        dir: Dir,
        basename: [:0]const u8,
        path: [:0]const u8,
        kind: Dir.Entry.Kind,
        hit: bool,
    };

    pub fn init(allocator: Allocator, dir: Dir) !DirWalker {
        var stack: std.ArrayListUnmanaged(DirWalker.StackItem) = .empty;

        try stack.append(allocator, .{
            .iter = dir.iterate(),
            .dirname_len = 0,
            .hit = false,
        });

        return .{
            .stack = stack,
            .name_buffer = .{},
        };
    }

    pub fn next(self: *DirWalker, allocator: Allocator) !?Entry {
        while (self.stack.items.len > 0) {
            const top = &self.stack.items[self.stack.items.len - 1];
            var dirname_len = top.dirname_len;
            if (top.iter.next() catch |err| {
                // If we get an error, then we want the user to be able to continue
                // walking if they want, which means that we need to pop the directory
                // that errored from the stack. Otherwise, all future `next` calls would
                // likely just fail with the same error.
                var item = self.stack.pop().?;
                if (self.stack.items.len != 0) {
                    item.iter.dir.close();
                }
                return err;
            }) |entry| {
                self.name_buffer.shrinkRetainingCapacity(dirname_len);
                if (self.name_buffer.items.len != 0) {
                    try self.name_buffer.append(allocator, fs.path.sep);
                    dirname_len += 1;
                }
                try self.name_buffer.ensureUnusedCapacity(allocator, entry.name.len + 1);
                self.name_buffer.appendSliceAssumeCapacity(entry.name);
                self.name_buffer.appendAssumeCapacity(0);
                return .{
                    .dir = top.iter.dir,
                    .basename = self.name_buffer.items[dirname_len .. self.name_buffer.items.len - 1 :0],
                    .path = self.name_buffer.items[0 .. self.name_buffer.items.len - 1 :0],
                    .kind = entry.kind,
                    .hit = top.hit,
                };
            } else {
                var item = self.stack.pop().?;
                if (self.stack.items.len != 0) {
                    item.iter.dir.close();
                }
            }
        }
        return null;
    }

    pub inline fn hit(self: *DirWalker) void {
        var top = &self.stack.items[self.stack.items.len - 1];
        top.hit = true;
    }

    pub fn accept(self: *DirWalker, allocator: Allocator, entry: DirWalker.Entry) !void {
        if (entry.kind != .directory) {
            @branchHint(.cold);
            return;
        }

        var new_dir = entry.dir.openDir(entry.basename, .{ .iterate = true }) catch |err| {
            switch (err) {
                error.NameTooLong => unreachable, // no path sep in base.name
                else => |e| return e,
            }
        };

        errdefer new_dir.close();
        const top = &self.stack.items[self.stack.items.len - 1];

        try self.stack.append(allocator, .{
            .iter = new_dir.iterateAssumeFirstIteration(),
            .dirname_len = self.name_buffer.items.len - 1,
            .hit = top.hit,
        });
    }

    pub fn deinit(self: *DirWalker, allocator: Allocator) void {
        self.name_buffer.deinit(allocator);
        self.stack.deinit(allocator);
    }

    pub fn depth(self: *DirWalker) usize {
        return self.stack.items.len;
    }

    /// Skips processing the remainder of the files in the current directory
    pub fn skip(self: *DirWalker) void {
        var item = self.stack.pop().?;
        if (self.stack.items.len != 0) {
            @branchHint(.likely);
            item.iter.dir.close();
        }
    }
};
