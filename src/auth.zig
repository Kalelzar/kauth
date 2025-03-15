const std = @import("std");

pub fn get(allocator: std.mem.Allocator, password: []const u8, buf: []u8) ![]const u8 {
    return try std.crypto.pwhash.argon2.strHash(
        password,
        .{
            .params = .{ .t = 2, .m = 20801, .p = 1 },
            .allocator = allocator,
            .mode = .argon2id,
            .encoding = .phc,
        },
        buf,
    );
}

pub fn verify(allocator: std.mem.Allocator, password: []const u8, cred: []const u8) !void {
    return std.crypto.pwhash.argon2.strVerify(
        cred,
        password,
        .{ .allocator = allocator },
    );
}
