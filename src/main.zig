const std = @import("std");
const terminal = @import("terminal");
const editor = @import("editor");
const document = @import("document");

var editor_instance: editor.Editor = undefined;

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const file_path = args.next() orelse "";
    var doc = try document.Document.init(file_path);
    defer doc.deinit();

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

    editor_instance = editor.Editor.init(term, doc);
    try std.posix.sigaction(std.posix.SIG.WINCH, &std.posix.Sigaction{
        .handler = .{ .handler = handleSigWinch },
        .mask = std.posix.empty_sigset,
        .flags = 0,
    }, null);

    try editor_instance.run();
}

fn handleSigWinch(_: c_int) callconv(.C) void {
    editor_instance.resize() catch |err| {
        // TODO: normal error processing
        std.debug.print("{any}\n", .{err});
    };
}
