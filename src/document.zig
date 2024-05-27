const std = @import("std");

pub const Document = struct {
    rows: std.ArrayList([]u8),
    file_path: []const u8,

    pub fn init(file_path: []const u8) !Document {
        const file = std.fs.cwd().openFile(file_path, .{
            .mode = std.fs.File.OpenMode.read_write,
        }) catch {
            // TODO: error processing
            return Document{
                .file_path = file_path,
                .rows = std.ArrayList([]u8).init(std.heap.page_allocator),
            };
        };
        defer file.close();

        const size = try file.getEndPos();
        if (size == 0) {
            return Document{
                .file_path = file_path,
                .rows = std.ArrayList([]u8).init(std.heap.page_allocator),
            };
        }

        var rows = std.ArrayList([]u8).init(std.heap.page_allocator);
        // TODO: need the better way of allocate buffer
        var buffer: [1024]u8 = undefined;
        while (try file.reader().readUntilDelimiterOrEof(&buffer, '\n')) |line| {
            try rows.append(line);
        }

        return Document{
            .file_path = file_path,
            .rows = rows,
        };
    }

    pub fn destroy(self: *Document) void {
        self.rows.deinit();
    }

    pub fn get_row(self: *Document, row_num: usize) ?[]u8 {
        if (row_num >= self.rows.items.len) {
            return null;
        }
        return self.rows.items[row_num];
    }
};
