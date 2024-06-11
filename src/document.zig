const std = @import("std");

// TODO: need more powerful type like slice of slices
pub const Document = struct {
    rows: std.ArrayList([]u8),
    file_path: []const u8,

    pub fn init(file_path: []const u8) !Document {
        const empty_row = "".*;
        var rows = std.ArrayList([]u8).init(std.heap.page_allocator);
        const file = std.fs.cwd().openFile(file_path, .{
            .mode = std.fs.File.OpenMode.read_only,
        }) catch {
            try rows.append(&empty_row);
            // TODO: error processing
            return Document{
                .file_path = file_path,
                .rows = rows,
            };
        };
        defer file.close();

        const size = try file.getEndPos();
        if (size == 0) {
            try rows.append(&empty_row);
            return Document{
                .file_path = file_path,
                .rows = rows,
            };
        }

        const file_stat = try file.stat();
        while (try file.reader().readUntilDelimiterOrEofAlloc(std.heap.page_allocator, '\n', file_stat.size + 1)) |line| {
            try rows.append(line);
        }

        return Document{
            .file_path = file_path,
            .rows = rows,
        };
    }

    pub fn deinit(self: *Document) void {
        self.rows.deinit();
    }

    pub fn save(self: *Document) !void {
        const file = try std.fs.cwd().createFile(self.file_path, .{});
        defer file.close();

        for (self.rows.items) |line| {
            _ = try file.writer().write(line);
            _ = try file.writer().writeByte('\n');
        }
    }

    pub fn len(self: *Document) usize {
        return self.rows.items.len;
    }

    pub fn get_row(self: *Document, row_num: usize) ?[]u8 {
        if (row_num >= self.rows.items.len) {
            return null;
        }
        return self.rows.items[row_num];
    }

    pub fn insert_row(self: *Document, position: usize, row: []u8) !void {
        try self.rows.insert(position, row);
    }

    pub fn remove_row(self: *Document, position: usize) void {
        _ = self.rows.orderedRemove(position);
    }

    pub fn replace_row(self: *Document, position: usize, row: []u8) !void {
        _ = self.rows.orderedRemove(position);
        try self.rows.insert(position, row);
    }
};
