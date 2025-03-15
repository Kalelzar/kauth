pub const Config = struct {
    postgre: struct {
        pool_size: u8 = 5,
        port: u16 = 5432,
        host: []const u8 = "127.0.0.1",
        auth: struct {
            username: []const u8,
            password: []const u8,
            database: []const u8 = "kauth",
            timeout: u16 = 10000,
        },
    },
    server: struct {
        hostname: []const u8 = "0.0.0.0",
        port: u16 = 4269,
    } = .{},
};
