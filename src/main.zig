const std = @import("std");
const terminal = @import("terminal");
const editor = @import("editor");
const document = @import("document");

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const file_path = args.next() orelse "";
    var doc = try document.Document.init(file_path);
    defer doc.destroy();

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

    var editor_instance = editor.Editor.init(term, doc);
    try editor_instance.run();
}
