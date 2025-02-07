const std = @import("std");

fn computeBracketMap(comptime instructions: []const u8) []const usize {
    var opening_to_closing: [instructions.len]usize = undefined;
    var stack: [instructions.len]usize = undefined;
    var stack_size: usize = 0;

    for (instructions, 0..) |c, i| {
        switch (c) {
            '[' => {
                stack[stack_size] = i;
                stack_size += 1;
            },
            ']' => {
                if (stack_size == 0) @compileError("unmatched closing bracket");
                stack_size -= 1;
                opening_to_closing[stack[stack_size]] = i;
            },
            else => {},
        }
    }
    if (stack_size != 0) @compileError("unmatched opening bracket");

    return &opening_to_closing;
}

inline fn compileBrainfuckImpl(
    comptime instructions: []const u8,
    comptime inst_pointer_start: comptime_int,
    comptime bracket_map: []const usize,
    data_ptr: *usize,
    cells: []u8,
    writer: anytype,
    reader: anytype,
) !void {
    comptime var inst_pointer = inst_pointer_start;
    inline while (inst_pointer < instructions.len) : (inst_pointer += 1) {
        switch (instructions[inst_pointer]) {
            '>' => data_ptr.* += 1,
            '<' => data_ptr.* -= 1,
            '+' => cells[data_ptr.*] +%= 1,
            '-' => cells[data_ptr.*] -%= 1,
            '.' => try writer.writeByte(cells[data_ptr.*]),
            ',' => cells[data_ptr.*] = reader.readByte() catch |err| switch (err) {
                error.EndOfStream => 0,
                else => |err_| return err_,
            },
            '[' => {
                while (cells[data_ptr.*] != 0)
                    try compileBrainfuckImpl(instructions, inst_pointer + 1, bracket_map, data_ptr, cells, writer, reader);
                inst_pointer = bracket_map[inst_pointer];
            },
            ']' => return,
            else => {},
        }
    }
}

pub fn compileBrainfuck(
    comptime instructions: []const u8,
    cells: []u8,
    writer: anytype,
    reader: anytype,
) !void {
    @setEvalBranchQuota(1000000);
    const bracket_map = comptime computeBracketMap(instructions);
    var data_ptr: usize = 0;
    try compileBrainfuckImpl(instructions, 0, bracket_map, &data_ptr, cells, writer, reader);
}

pub fn main() !void {
    var timer = try std.time.Timer.start();
    const std_out = std.io.getStdOut();
    var buff = [_]u8{0} ** 1024;

    const source_code: []const u8 = @embedFile("./program.bf");

    var input = std.io.fixedBufferStream("hello word");
    try compileBrainfuck(source_code, &buff, std_out.writer(), input.reader());
    const time = timer.read();
    std.debug.print("{} ns\n", .{time});
    std.debug.print("{d:.3} ms\n", .{@as(f64, @floatFromInt(time)) / 1e6});
}
