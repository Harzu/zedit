const std = @import("std");

pub const KeyEvent = union(enum) {
    Char: u21,
    AltChar: u21,
    CtrlChar: u21,
    Backspace,
    Left,
    Right,
    Up,
    Down,
    Home,
    End,
    BackTab,
    F: u21,
    Esc,
    Enter,
    Tab,
    Null,
    None,
    Unknown,

    pub fn next(stdin: std.fs.File) !KeyEvent {
        var buffer: [16]u8 = undefined;
        const receive_bytes_count = try stdin.reader().read(buffer[0..]);

        if (receive_bytes_count == 0) {
            return KeyEvent.None;
        }

        const chars = std.unicode.Utf8View{ .bytes = buffer[0..receive_bytes_count] };
        var chars_iter = chars.iterator();

        if (chars_iter.nextCodepoint()) |c0| {
            return switch (c0) {
                0x1B => {
                    if (chars_iter.nextCodepoint()) |c1| {
                        return switch (c1) {
                            0x4F => {
                                if (chars_iter.nextCodepoint()) |c2| {
                                    return switch (c2) {
                                        0x44 => KeyEvent.Left,
                                        0x43 => KeyEvent.Right,
                                        0x41 => KeyEvent.Up,
                                        0x42 => KeyEvent.Down,
                                        0x48 => KeyEvent.Home,
                                        0x46 => KeyEvent.End,
                                        // F1 - F4
                                        0x50...0x53 => KeyEvent{ .F = 1 + c2 - 0x50 },
                                        else => KeyEvent.Unknown,
                                    };
                                }

                                return KeyEvent.Unknown;
                            },
                            0x5B => KeyEvent.parse_csi(&chars_iter),
                            else => KeyEvent.Unknown,
                        };
                    }

                    return KeyEvent.Unknown;
                },
                // ctrl+key (excluding enter and tab)
                0x01...0x08, 0x0A...0x0C, 0x0E...0x1A => |char| KeyEvent{ .CtrlChar = char - 0x1 + 0x61 },
                // ctrl+key
                0x1C...0x1F => |char| KeyEvent{ .CtrlChar = char - 0x1C + 0x34 },
                0x0D => KeyEvent.Enter,
                0x09 => KeyEvent.Tab,
                else => KeyEvent{ .Char = c0 },
            };
        }

        return KeyEvent.Unknown;
    }

    // TODO: not full
    fn parse_csi(chars_iter: *std.unicode.Utf8Iterator) KeyEvent {
        if (chars_iter.nextCodepoint()) |c2| {
            return switch (c2) {
                0x44 => KeyEvent.Left,
                0x43 => KeyEvent.Right,
                0x41 => KeyEvent.Up,
                0x42 => KeyEvent.Down,
                0x48 => KeyEvent.Home,
                0x46 => KeyEvent.End,
                0x5A => KeyEvent.BackTab,
                else => KeyEvent.Unknown,
            };
        }
        return KeyEvent.Unknown;
    }
};

pub const WinSize = packed struct {
    ws_row: u16,
    ws_col: u16,
    ws_xpixel: u16,
    ws_ypixel: u16,
};

pub const Terminal = struct {
    stdout: std.fs.File,
    stdin: std.fs.File,
    original_termios: ?std.posix.termios,
    raw_termios: ?std.posix.termios,

    pub fn init() Terminal {
        const stdout = std.io.getStdOut();
        const stdin = std.io.getStdIn();
        return Terminal{ .stdout = stdout, .stdin = stdin, .original_termios = null, .raw_termios = null };
    }

    pub fn into_raw_mode(self: *Terminal) !void {
        const original_termios = try std.posix.tcgetattr(self.stdout.handle);
        self.original_termios = original_termios;
        var raw = original_termios;

        // TODO: comment what are flags mean
        raw.iflag.ICRNL = false;
        raw.iflag.IXON = false;
        raw.iflag.BRKINT = false;
        raw.iflag.INPCK = false;
        raw.iflag.ISTRIP = false;

        raw.oflag.OPOST = false;

        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.ISIG = false;
        raw.lflag.IEXTEN = false;

        raw.cflag.CSIZE = std.posix.CSIZE.CS8;

        const VMIN = 5;
        const VTIME = 6;
        raw.cc[VMIN] = 1;
        raw.cc[VTIME] = 0;

        try std.posix.tcsetattr(self.stdout.handle, std.posix.TCSA.FLUSH, raw);
        self.raw_termios = raw;
    }

    pub fn return_to_normal_mode(self: *Terminal) !void {
        if (self.original_termios != null) {
            try std.posix.tcsetattr(self.stdout.handle, .FLUSH, self.original_termios.?);
        }
    }

    pub fn write(self: *Terminal, bytes: []const u8) !void {
        _ = try self.stdout.writeAll(bytes);
    }

    pub fn formated_write(self: *Terminal, comptime format: []const u8, args: anytype) !void {
        try self.stdout.writer().print(format, args);
    }

    pub fn termina_size(self: Terminal) WinSize {
        var size: WinSize = undefined;
        // TODO: need to handle error
        _ = std.posix.system.ioctl(self.stdout.handle, std.posix.system.T.IOCGWINSZ, @intFromPtr(&size));
        return size;
    }

    pub fn alternate_screen(self: *Terminal) !void {
        try self.stdout.writeAll("\x1B[?1049h");
    }

    pub fn main_screen(self: *Terminal) !void {
        try self.stdout.writeAll("\x1b[?1049l");
    }

    pub fn clear_current_line(self: *Terminal) !void {
        try self.write("\x1B[2K");
    }

    pub fn cursor_go_to(self: *Terminal, x: u16, y: u16) !void {
        try self.stdout.writer().print("\x1B[{d};{d}H", .{ y + 1, x + 1 });
    }

    pub fn background_color(self: *Terminal, r: u16, g: u16, b: u16) !void {
        try self.stdout.writer().print("\x1B[48;2;{d};{d};{d}m", .{ r, g, b });
    }

    pub fn reset_background(self: *Terminal) !void {
        try self.stdout.writer().writeAll("\x1B[49m");
    }

    pub fn foreground_color(self: *Terminal, r: u16, g: u16, b: u16) !void {
        try self.stdout.writer().print("\x1B[38;2;{d};{d};{d}m", .{ r, g, b });
    }

    pub fn reset_foreground(self: *Terminal) !void {
        try self.stdout.writer().writeAll("\x1B[39m");
    }

    pub fn flush(self: *Terminal) !void {
        // TODO: need make raw_termios unoptional
        try std.posix.tcsetattr(self.stdout.handle, .FLUSH, self.raw_termios.?);
    }
};
