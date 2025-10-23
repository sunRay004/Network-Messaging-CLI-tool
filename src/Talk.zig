const std = @import("std");
var printMutex = std.Thread.Mutex{};
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

    var clientMode: bool = false;
    var serverMode: bool = false;

    var portNum: ?[:0]const u8 = null;
    var selectedHostArg: [:0]const u8 = undefined;
    var selectedPort: [:0]const u8 = undefined;

    while (argumentItterator.next()) |arg| : (i += 1) {
        //HELP
        if (std.mem.eql(u8, arg, "-help")) {
            std.debug.print("help menue triggered, the program will self destruct in 10 seconds", .{});
        }
        //CLIENT
        if (std.mem.eql(u8, arg, "-h")) {
            // -h means we are running client mode
            const hostArg = argumentItterator.next();
            if (hostArg == null) {
                std.debug.print("ERROR: \nno Hostname or IpAddress \ndo -h [hostname | IPaddress] instead", .{});
                std.process.exit(1);
            }

            std.debug.print("Client Mode, conecting to: {?s}", .{hostArg});
            // TODO identify if [hostname | IPaddress]

            clientMode = true;
            selectedHostArg = hostArg.?;
        }

        //SERVER
        if (std.mem.eql(u8, arg, "-s")) {
            // raise a isServer flag
            std.debug.print("Server mode", .{});

            serverMode = true;
        }

        //PORT
        if (std.mem.eql(u8, arg, "-p")) {
            portNum = argumentItterator.next();
            if (portNum == null) {
                std.debug.print("ERROR: \nno Portnumber \ndo [-p portnumber] instead", .{});
                std.process.exit(1);
            }

            std.debug.print("Port set to: {?s}", .{portNum});
            selectedPort = portNum.?;
        }
    }

    // decide if we run client or server
    if (clientMode) {
        client(selectedHostArg, selectedPort) catch {};
    } else if (serverMode) {
        server(selectedPort) catch {};
    }

    // needed for input reading
    // var stdinBuffer: [1024]u8 = undefined;
    // var stdinReader = std.fs.File.stdin().reader(&stdinBuffer);

    // var alloc = std.heap.DebugAllocator(.{}).init;
    // defer _ = alloc.deinit();
    // const debugAloc = alloc.allocator();
    // var lineWriter = std.Io.Writer.Allocating.init(debugAloc);
    // defer lineWriter.deinit();

    // while (stdinReader.interface.streamDelimiter(&lineWriter.writer, '\n')) |_| {
    //     const line = lineWriter.written();
    //     std.debug.print("{s}\n", .{line});
    //     lineWriter.clearRetainingCapacity();
    //     stdinReader.interface.toss(1);
    // } else |_| {
    //     std.debug.print("{s}\n", .{"dying now"});
    // } // else |err| if (err != error.EndOfStream) return err;

    // Read 1 line
    // _ = try stdinReader.interface.streamDelimiter(&lineWriter.writer, '\n');
    // const line = lineWriter.written();
    // std.debug.print("{s}\n", .{line});
    // lineWriter.clearRetainingCapacity();
    // stdinReader.interface.toss(1);
}

pub fn client(hostArgs: [:0]const u8, port: [:0]const u8) !void {
    //const adress = tru std.net.Address.parseIp(name: []const u8, port: u16)
    std.debug.print(" client got {s}\n", .{hostArgs});
    std.debug.print(" client got {s}\n", .{port});
    const newport = try std.fmt.parseInt(u16, port, 10);
    // const adress = try std.net.Address.parseIp(hostArgs, newport);

    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const hostAddr: std.net.Address = blk: {
        if (!std.net.isValidHostName(hostArgs)) {
            //exit
        }
        if (std.net.Address.parseIp4(hostArgs, newport)) |addr| {
            break :blk addr;
        } else |_| {
            const addrList = try std.net.getAddressList(allocator, hostArgs, newport);
            std.debug.print(" client also got address {any}\n", .{addrList.addrs[0]});
            break :blk addrList.addrs[0];
        }
    };
    std.debug.print("client conecting to host \n", .{});
    const stream = try std.net.tcpConnectToAddress(hostAddr);

    const rthread = try std.Thread.spawn(.{}, threadedReader.beginReading, .{stream});
    defer rthread.join();
    const wthread = try std.Thread.spawn(.{}, threadedWriter.beginWriting, .{stream});
    defer wthread.join();

    std.debug.print("Client is fine \n", .{});
}

pub fn server(port: [:0]const u8) !void {
    std.debug.print(" server got {s}\n", .{port});

    const newport = try std.fmt.parseInt(u16, port, 10);
    const adress = try std.net.Address.parseIp("127.0.0.1", newport);
    var lisseningServer = try adress.listen(.{ .reuse_address = true, .force_nonblocking = false });
    defer lisseningServer.deinit();

    std.debug.print("prepared to accept now \n", .{});
    const clientConnection: std.net.Server.Connection = try lisseningServer.accept();
    std.debug.print("accepted connection from {f} \n", .{clientConnection.address});

    const rthread = try std.Thread.spawn(.{}, threadedReader.beginReading, .{clientConnection.stream});
    defer rthread.join();
    const wthread = try std.Thread.spawn(.{}, threadedWriter.beginWriting, .{clientConnection.stream});
    defer wthread.join();
}

// take stream, read message from stream and save as message
const threadedReader = struct {
    pub fn beginReading(stream: std.net.Stream) void {
        var buff: [1024]u8 = undefined;
        var writer = stream.reader(&buff);
        while (true) {
            const msg = writer.interface_state.takeDelimiterExclusive('\n') catch |err| {
                if (err == error.EndOfStream) {
                    std.debug.print("Conection Terminated", .{});
                    break;
                }
                std.debug.print("{any}\n", .{err});
                break;
            };

            printMutex.lock();
            std.debug.print("[ got:] {s}\n", .{msg});
            printMutex.unlock();
        }
    }
};

// take stream, read user input and write it to message, also write to the stream
const threadedWriter = struct {
    pub fn beginWriting(stream: std.net.Stream) void {
        var buff: [1024]u8 = undefined;
        var writer = stream.writer(&buff);

        var stdinBuffer: [1024]u8 = undefined;
        var stdinReader = std.fs.File.stdin().reader(&stdinBuffer);

        while (true) {
            const msg = stdinReader.interface.takeDelimiterInclusive('\n') catch |err| {
                if (err == error.EndOfStream) {
                    std.debug.print("Conection Terminated", .{});
                    break;
                }
                std.debug.print("{any}\n", .{err});
                break;
            };

            printMutex.lock();

            writer.interface.writeAll(msg) catch {
                std.debug.print("threadedWriter Failed to write \n", .{});
            };
            writer.interface.flush() catch {
                std.debug.print("threadedWriter Failed to flush \n", .{});
            };
            std.debug.print("[sent:] {s}", .{msg});

            printMutex.unlock();

            // lineWriter.clearRetainingCapacity();
            // stdinReader.interface.toss(1);
        }
    }
};

// / function client
// / while true
// /     while (something in stdin)
// /     try send it
// /     catch {}
// / ...
// /     while (something in socket)
// /
// /
// pub fn client() null{
//     while (true) {
//         while (stdinReader.interface.takeDelimiterExclusive('\n')) {

//         }
//         while () {

//         }
//     }
// }
