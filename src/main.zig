const std = @import("std");
const terminal = @import("terminal");
const editor = @import("editor");

pub fn main() !void {
    var term = terminal.Terminal.init();
    try term.into_raw_mode();
    defer {
        term.main_screen() catch |err| {
            std.debug.print("{any}", .{err});
        };
        term.return_to_normal_mode() catch |err| {
            std.debug.print("{any}", .{err});
        };
    }
    try term.alternate_screen();

    var editor_instance = editor.Editor.init(term);
    try editor_instance.run();
}
