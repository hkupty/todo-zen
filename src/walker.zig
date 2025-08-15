/// This is a fork of walker to enable skipping entire parts of the directory tree
const std = @import("std");
const fs = std.fs;
const Dir = fs.Dir;
const Allocator = std.mem.Allocator;

pub const Walker = struct {
    stack: std.ArrayListUnmanaged(StackItem),
    name_buffer: std.ArrayListUnmanaged(u8),
    allocator: Allocator,

    pub const Entry = struct {
        /// The containing directory. This can be used to operate directly on `basename`
        /// rather than `path`, avoiding `error.NameTooLong` for deeply nested paths.
        /// The directory remains open until `next` or `deinit` is called.
        dir: Dir,
        basename: [:0]const u8,
        path: [:0]const u8,
        kind: Dir.Entry.Kind,
    };

    const StackItem = struct {
        iter: Dir.Iterator,
        dirname_len: usize,
    };

    /// After each call to this function, and on deinit(), the memory returned
    /// from this function becomes invalid. A copy must be made in order to keep
    /// a reference to the path.
    pub fn next(self: *Walker) !?Walker.Entry {
        const gpa = self.allocator;
        while (self.stack.items.len != 0) {
            // `top` and `containing` become invalid after appending to `self.stack`
            var top = &self.stack.items[self.stack.items.len - 1];
            var containing = top;
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
            }) |base| {
                self.name_buffer.shrinkRetainingCapacity(dirname_len);
                if (self.name_buffer.items.len != 0) {
                    try self.name_buffer.append(gpa, fs.path.sep);
                    dirname_len += 1;
                }
                try self.name_buffer.ensureUnusedCapacity(gpa, base.name.len + 1);
                self.name_buffer.appendSliceAssumeCapacity(base.name);
                self.name_buffer.appendAssumeCapacity(0);
                if (base.kind == .directory) {
                    var new_dir = top.iter.dir.openDir(base.name, .{ .iterate = true }) catch |err| switch (err) {
                        error.NameTooLong => unreachable, // no path sep in base.name
                        else => |e| return e,
                    };
                    {
                        errdefer new_dir.close();
                        try self.stack.append(gpa, .{
                            .iter = new_dir.iterateAssumeFirstIteration(),
                            .dirname_len = self.name_buffer.items.len - 1,
                        });
                        top = &self.stack.items[self.stack.items.len - 1];
                        containing = &self.stack.items[self.stack.items.len - 2];
                    }
                }
                return .{
                    .dir = containing.iter.dir,
                    .basename = self.name_buffer.items[dirname_len .. self.name_buffer.items.len - 1 :0],
                    .path = self.name_buffer.items[0 .. self.name_buffer.items.len - 1 :0],
                    .kind = base.kind,
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

    pub fn deinit(self: *Walker) void {
        const gpa = self.allocator;
        // Close any remaining directories except the initial one (which is always at index 0)
        if (self.stack.items.len > 1) {
            for (self.stack.items[1..]) |*item| {
                item.iter.dir.close();
            }
        }
        self.stack.deinit(gpa);
        self.name_buffer.deinit(gpa);
    }

    /// Skips processing the remainder of the files in the current directory
    pub fn skip(self: *Walker) void {
        var item = self.stack.pop().?;
        if (self.stack.items.len != 0) {
            item.iter.dir.close();
        }
    }
};

pub fn walk(allocator: Allocator, dir: Dir) !Walker {
    var stack: std.ArrayListUnmanaged(Walker.StackItem) = .empty;

    try stack.append(allocator, .{
        .iter = dir.iterate(),
        .dirname_len = 0,
    });

    return .{
        .stack = stack,
        .name_buffer = .{},
        .allocator = allocator,
    };
}
