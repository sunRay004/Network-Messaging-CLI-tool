const std = @import("std");

pub fn main() !void {
    std.debug.print("Started \n", .{});

    var buffer: [1024]u8 = undefined;
    var allocat = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = allocat.allocator();

    std.debug.print("Alocator done \n", .{});

    var argumentItterator = try std.process.argsWithAllocator(allocator);

    var i: usize = 1;
    i = 1;
    while (argumentItterator.next()) |arg| : (i += 1) std.debug.print("arg# {}: {s}\n", .{ i, arg });
}
