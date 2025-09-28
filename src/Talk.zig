const std = @import("std");

pub fn main() !void {
    std.debug.print("Started \n", .{});

    var buffer: [1024]u8 = undefined;
    var allocat = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = allocat.allocator();

    std.debug.print("Alocator done \n", .{});

    var argumentItterator = try std.process.argsWithAllocator(allocator);
    defer argumentItterator.deinit();

    var i: usize = 1;
    i = 1;
    while (argumentItterator.next()) |arg| : (i += 1) {
        if (std.mem.eql(u8, arg, "-help") | std.mem.eql(u8, arg, "-h")) {
            std.debug.print("help menue triggered, the program will self destruct in 10 seconds", .{});
        }
    }
}
