const std = @import("std");
const terminal = @import("terminal");

const BOTTOM_SCREEN_PADDING: u16 = 2;

const Position = struct {
    x: u16,
    y: u16,
};

const Size = struct {
    width: u16,
    height: u16,
};

pub const Editor = struct {
    close: bool,
    terminal: terminal.Terminal,
    cusrsor_position: Position,
    editor_size: Size,

    pub fn init(term: terminal.Terminal) Editor {
        const size = term.termina_size();
        return Editor{
            .terminal = term,
            .close = false,
            .cusrsor_position = Position{ .x = 0, .y = 0 },
            .editor_size = Size{
                .height = size.ws_row - BOTTOM_SCREEN_PADDING,
                .width = size.ws_col,
            },
        };
    }

    pub fn run(self: *Editor) !void {
        while (!self.close) {
            try self.render();
            try self.process_next_key();
        }
    }

    fn render(self: *Editor) !void {
        try self.terminal.cursor_go_to(0, 0);

        try self.render_rows();
        try self.render_status_bar();

        try self.terminal.cursor_go_to(
            self.cusrsor_position.x,
            self.cusrsor_position.y,
        );

        try self.terminal.flush();
    }

    fn render_rows(self: *Editor) !void {
        const editor_height = self.editor_size.height;
        const editor_width = self.editor_size.width;
        for (0..editor_height) |row_num| {
            try self.terminal.clear_current_line();

            if (row_num == 0) {
                try self.terminal.write("~ ZEDIT\n\r");
            } else if (row_num == editor_height / 2) {
                const message = "Hello from zedit";
                const message_padding = try padding((editor_width / 2 + 1) - (message.len / 2));
                try self.terminal.formated_write("~{s}{s}\n\r", .{ message_padding, message });
            } else {
                try self.terminal.write("~\n\r");
            }
        }
    }

    fn render_status_bar(self: *Editor) !void {
        try self.terminal.clear_current_line();

        var buffer: [256]u8 = undefined;
        const status_content = try std.fmt.bufPrint(&buffer, "cursor: ({d}|{d}) size: ({d}|{d})", .{
            self.cusrsor_position.x,
            self.cusrsor_position.y,
            self.editor_size.width,
            self.editor_size.height,
        });

        const editor_size = self.terminal.termina_size();
        const status_padding = try padding(editor_size.ws_col - status_content.len);

        try self.terminal.background_color(231, 231, 231);
        try self.terminal.foreground_color(0, 0, 0);
        try self.terminal.formated_write("{s}{s}\n\r", .{ status_content, status_padding });
        try self.terminal.reset_background();
        try self.terminal.reset_foreground();

        try self.terminal.write("CTRL+Q: exist\r");
    }

    fn process_next_key(self: *Editor) !void {
        const key = try terminal.KeyEvent.next(self.terminal.stdin);
        switch (key) {
            terminal.KeyEvent.CtrlChar => |c| {
                if (c == 'q') {
                    self.close = true;
                }
            },
            terminal.KeyEvent.Up => {
                if (self.cusrsor_position.y > 0) {
                    self.cusrsor_position.y -= 1;
                }
            },
            terminal.KeyEvent.Down => {
                if (self.cusrsor_position.y < self.editor_size.height - 1) {
                    self.cusrsor_position.y += 1;
                }
            },
            terminal.KeyEvent.Left => {
                if (self.cusrsor_position.x > 0) {
                    self.cusrsor_position.x -= 1;
                }
            },
            terminal.KeyEvent.Right => {
                if (self.cusrsor_position.x < self.editor_size.width - 1) {
                    self.cusrsor_position.x += 1;
                }
            },
            else => {},
        }
    }
};

fn padding(length: usize) ![]u8 {
    const allocator = std.heap.page_allocator;
    var slice = try allocator.alloc(u8, length);
    for (0..slice.len) |index| {
        slice[index] = 32; // Add space char's byte
    }

    return slice;
}
