const std = @import("std");
const terminal = @import("terminal");
const document = @import("document");

const BOTTOM_SCREEN_PADDING: u16 = 2;
const DEFAULT_X_POSITION: u8 = 0;
const DEFAULT_Y_POSITION: u8 = 0;
const SPACE_CHAR_BYTE: u8 = 32;
const NEW_LINE_CHARACTER: u8 = '\n';
const EXIT_CHARACTER: u8 = 'q';
const SAVE_CHARACTER: u8 = 's';

const Position = struct {
    x: u64,
    y: u64,
};

const Size = struct {
    width: u16,
    height: u16,
};

pub const Editor = struct {
    close: bool,
    terminal: terminal.Terminal,
    document: document.Document,
    cusrsor_position: Position,
    offset_position: Position,
    editor_size: Size,

    pub fn init(term: terminal.Terminal, doc: document.Document) Editor {
        const size = term.termina_size();
        return Editor{
            .terminal = term,
            .document = doc,
            .close = false,
            .cusrsor_position = Position{ .x = 0, .y = 0 },
            .offset_position = Position{ .x = 0, .y = 0 },
            .editor_size = Size{
                .height = size.ws_row - BOTTOM_SCREEN_PADDING,
                .width = size.ws_col,
            },
        };
    }

    pub fn run(self: *Editor) !void {
        while (!self.close) {
            self.change_offsets();
            try self.render();
            try self.process_next_key();
        }
    }

    pub fn resize(self: *Editor) !void {
        const size = self.terminal.termina_size();
        self.editor_size = Size{
            .height = size.ws_row - BOTTOM_SCREEN_PADDING,
            .width = size.ws_col,
        };
        self.change_offsets();
        try self.render();
    }

    fn render(self: *Editor) !void {
        try self.terminal.cursor_hide();
        try self.terminal.cursor_go_to(0, 0);

        try self.render_rows();
        try self.render_status_bar();

        try self.terminal.cursor_go_to(
            self.cusrsor_position.x - self.offset_position.x,
            self.cusrsor_position.y - self.offset_position.y,
        );

        try self.terminal.cursor_show();
        try self.terminal.flush();
    }

    fn render_rows(self: *Editor) !void {
        for (0..self.editor_size.height) |row_num| {
            try self.terminal.clear_current_line();
            const doc_row_index = self.offset_position.y + row_num;
            const row_data = self.document.get_row(doc_row_index);
            if (row_data != null) {
                try self.render_row(row_data.?);
            } else {
                try self.terminal.write("\r\n");
            }
        }
    }

    fn render_row(self: *Editor, row: []u8) !void {
        var start: u64 = self.offset_position.x;
        var end: u64 = start + self.editor_size.width;

        if (start > row.len) {
            start = row.len;
        }

        if (end > row.len) {
            end = row.len;
        }

        try self.terminal.formated_write("{s}\r\n", .{row[start..end]});
    }

    fn render_status_bar(self: *Editor) !void {
        try self.terminal.clear_current_line();

        var buffer: [256]u8 = undefined;
        const status_content = try std.fmt.bufPrint(&buffer, "cursor: ({d}|{d}) offset: ({d}|{d}) size: ({d}|{d})", .{
            self.cusrsor_position.x,
            self.cusrsor_position.y,
            self.offset_position.x,
            self.offset_position.y,
            self.editor_size.width,
            self.editor_size.height,
        });

        const editor_size = self.terminal.termina_size();
        var status_padding = try padding(0);
        if (@subWithOverflow(editor_size.ws_col, status_content.len)[1] == 0) {
            status_padding = try padding(editor_size.ws_col - status_content.len);
        }
        defer std.heap.page_allocator.free(status_padding);

        try self.terminal.background_color(231, 231, 231);
        try self.terminal.foreground_color(0, 0, 0);
        try self.terminal.formated_write("{s}{s}\n\r", .{ status_content, status_padding });
        try self.terminal.reset_background();
        try self.terminal.reset_foreground();

        try self.terminal.write("CTRL+Q: exist, CTRL+S: save\r");
    }

    fn process_next_key(self: *Editor) !void {
        const key = try terminal.KeyEvent.next(self.terminal.stdin);
        switch (key) {
            terminal.KeyEvent.CtrlChar => |c| {
                if (c == EXIT_CHARACTER) {
                    self.close = true;
                }

                if (c == SAVE_CHARACTER) {
                    try self.document.save();
                }
            },
            terminal.KeyEvent.Char => |c| {
                try self.add_char(c);
            },
            terminal.KeyEvent.Enter => {
                try self.add_char(NEW_LINE_CHARACTER);
            },
            terminal.KeyEvent.Backspace => {
                try self.remove_char();
            },
            terminal.KeyEvent.Up => {
                self.move_up();
            },
            terminal.KeyEvent.Down => {
                self.move_down();
            },
            terminal.KeyEvent.Left => {
                self.move_left();
            },
            terminal.KeyEvent.Right => {
                self.move_right();
            },
            else => {},
        }
    }

    fn add_char(self: *Editor, c: u21) !void {
        const row = self.document.get_row(self.cusrsor_position.y);
        if (row != null) {
            if (c == NEW_LINE_CHARACTER) {
                try self.document.insert_row(self.cusrsor_position.y + 1, row.?[self.cusrsor_position.x..]);
                try self.document.replace_row(self.cusrsor_position.y, row.?[0..self.cusrsor_position.x]);
            } else {
                var new_row = std.ArrayList(u8).init(std.heap.page_allocator);
                for (row.?) |row_c| {
                    try new_row.append(row_c);
                }
                try new_row.insert(self.cusrsor_position.x, @intCast(c));
                try self.document.replace_row(self.cusrsor_position.y, new_row.items);
            }
            self.move_right();
        }
    }

    fn remove_char(self: *Editor) !void {
        var new_row = std.ArrayList(u8).init(std.heap.page_allocator);
        if (self.cusrsor_position.x > DEFAULT_X_POSITION) {
            const current_row = self.document.get_row(self.cusrsor_position.y) orelse std.ArrayList(u8).init(std.heap.page_allocator).items;
            for (current_row) |row_c| {
                try new_row.append(row_c);
            }
            _ = new_row.orderedRemove(self.cusrsor_position.x - 1);
            try self.document.replace_row(self.cusrsor_position.y, new_row.items);
            self.move_left();
        } else if (self.cusrsor_position.y > DEFAULT_Y_POSITION) {
            const current_row = self.document.get_row(self.cusrsor_position.y) orelse std.ArrayList(u8).init(std.heap.page_allocator).items;
            const prev_row = self.document.get_row(self.cusrsor_position.y - 1) orelse std.ArrayList(u8).init(std.heap.page_allocator).items;

            self.move_left();

            for (prev_row) |row_c| {
                try new_row.append(row_c);
            }

            for (current_row) |row_c| {
                try new_row.append(row_c);
            }

            try self.document.replace_row(self.cusrsor_position.y, new_row.items);
            self.document.remove_row(self.cusrsor_position.y + 1);
        }
    }

    fn move_up(self: *Editor) void {
        if (self.cusrsor_position.y > 0) {
            self.cusrsor_position.y -= 1;
        }

        const row = self.document.get_row(self.cusrsor_position.y);
        if (row != null) {
            if (self.cusrsor_position.x > row.?.len) {
                self.cusrsor_position.x = row.?.len;
            }
        }
    }

    fn move_down(self: *Editor) void {
        if (self.cusrsor_position.y < self.document.len() - 1) {
            self.cusrsor_position.y += 1;
            const row = self.document.get_row(self.cusrsor_position.y);
            if (row != null) {
                if (self.cusrsor_position.x > row.?.len) {
                    self.cusrsor_position.x = row.?.len;
                }
            }
        }
    }

    fn move_left(self: *Editor) void {
        if (self.cusrsor_position.x == DEFAULT_X_POSITION and
            self.cusrsor_position.y != DEFAULT_Y_POSITION)
        {
            self.cusrsor_position.y -= 1;
            const row = self.document.get_row(self.cusrsor_position.y);
            if (row != null) {
                self.cusrsor_position.x = row.?.len;
            }
        } else if (self.cusrsor_position.x != DEFAULT_X_POSITION) {
            self.cusrsor_position.x -= 1;
        }
    }

    fn move_right(self: *Editor) void {
        const row = self.document.get_row(self.cusrsor_position.y);
        if (row != null) {
            if (self.cusrsor_position.x < row.?.len) {
                self.cusrsor_position.x += 1;
            } else if (self.cusrsor_position.y < self.document.len() - 1) {
                self.move_down();
                self.cusrsor_position.x = DEFAULT_X_POSITION;
            }
        }
    }

    fn change_offsets(self: *Editor) void {
        const height = self.editor_size.height;
        if (self.cusrsor_position.y < self.offset_position.y) {
            self.offset_position.y = self.cusrsor_position.y;
        } else if (self.cusrsor_position.y >= self.offset_position.y + height) {
            self.offset_position.y = self.cusrsor_position.y - height + 1;
        }

        const width = self.editor_size.width;
        if (self.cusrsor_position.x < self.offset_position.x) {
            self.offset_position.x = self.cusrsor_position.x;
        } else if (self.cusrsor_position.x >= self.offset_position.x + width) {
            self.offset_position.x = self.cusrsor_position.x - width + 1;
        }
    }
};

fn padding(length: usize) ![]u8 {
    var slice = try std.heap.page_allocator.alloc(u8, length);
    for (0..slice.len) |index| {
        slice[index] = SPACE_CHAR_BYTE;
    }

    return slice;
}
