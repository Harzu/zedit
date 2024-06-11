const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zedit",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const terminal_module = b.addModule("terminal", .{
        .root_source_file = b.path("src/terminal.zig"),
        .target = target,
        .optimize = optimize,
    });

    const editor_module = b.addModule("editor", .{
        .root_source_file = b.path("src/editor.zig"),
        .target = target,
        .optimize = optimize,
    });

    const document_module = b.addModule("document", .{
        .root_source_file = b.path("src/document.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("terminal", terminal_module);
    exe.root_module.addImport("editor", editor_module);
    exe.root_module.addImport("document", document_module);
    editor_module.addImport("terminal", terminal_module);
    editor_module.addImport("document", document_module);

    // Libc
    exe.linkLibC();

    // BUILD
    b.installArtifact(exe);

    // RUN
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
