const std = @import("std");
const log = std.log.scoped(.tenants_repo);
const pg = @import("pg");
const uuid = @import("uuid");

const models = @import("../model/organizations.zig");

const Organizations = @This();

conn: *pg.Conn,

pub const OrganizationRow = struct {
    id: []const u8, // UUID
    name: []const u8, // TEXT
};

pub fn init(pool: *pg.Pool) !Organizations {
    return .{
        .conn = try pool.acquire(),
    };
}

pub const FromPool = struct {
    pool: *pg.Pool,
    pub fn init(pool: *pg.Pool) FromPool {
        return .{
            .pool = pool,
        };
    }

    pub fn yield(self: *FromPool) !Organizations {
        return try Organizations.init(self.pool);
    }
};

pub fn deinit(self: *Organizations) void {
    self.conn.release();
}

pub fn create(
    self: *Organizations,
    allocator: std.mem.Allocator,
    req: models.CreateOrganizationRequest,
) !OrganizationRow {
    const query =
        \\ insert into organizations (id, name)
        \\   values($1, $2)
    ;
    const id = uuid.v4.new();
    const urn = uuid.urn.serialize(id);
    _ = self.conn.exec(
        query,
        .{
            &urn,
            req.name,
        },
    ) catch |e| switch (e) {
        error.PG => {
            if (self.conn.err) |pge| {
                if (std.mem.eql(u8, pge.code, "23505") and std.mem.eql(u8, pge.constraint.?, "organizations_name_key")) {
                    return error.Conflict;
                }
                log.err(
                    "[{s}] Encountered an error ({s}) while creating a organization: \n{s}\n",
                    .{ pge.severity, pge.code, pge.message },
                );
            } else {
                log.err("Encountered an unknown error while creating an organization.\n", .{});
            }
            return e;
        },
        else => {
            log.err("Encountered an unknown error while creating an organization.\n", .{});
            return e;
        },
    };

    return .{
        .id = try allocator.dupe(u8, &urn),
        .name = req.name,
    };
}
