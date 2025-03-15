const std = @import("std");
const log = std.log.scoped(.tenants_repo);
const pg = @import("pg");
const uuid = @import("uuid");

const models = @import("../model/tenants.zig");

const Tenants = @This();

conn: *pg.Conn,

pub const TenantRow = struct {
    id: []const u8, // UUID
    organization: []const u8, // UUID FK(organizations)
    name: []const u8, // TEXT
};

pub fn init(pool: *pg.Pool) !Tenants {
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

    pub fn yield(self: *FromPool) !Tenants {
        return try .init(self.pool);
    }
};

pub fn deinit(self: *Tenants) void {
    self.conn.release();
}

pub fn create(
    self: *Tenants,
    allocator: std.mem.Allocator,
    req: models.CreateTenantRequest,
) !TenantRow {
    const query =
        \\ insert into tenants (id, organization, name)
        \\   values($1, $2, $3)
    ;
    const id = uuid.v4.new();
    const urn = uuid.urn.serialize(id);
    _ = self.conn.exec(
        query,
        .{
            &urn,
            req.orgId,
            req.name,
        },
    ) catch |e| switch (e) {
        error.PG => {
            if (self.conn.err) |pge| {
                if (std.mem.eql(u8, pge.code, "23505") and std.mem.eql(u8, pge.constraint.?, "tenants_organization_name_key")) {
                    return error.Conflict;
                }
                log.err(
                    "[{s}] Encountered an error ({s}) while creating a tenant: \n{s}\n",
                    .{ pge.severity, pge.code, pge.message },
                );
            } else {
                log.err("Encountered an unknown error while creating a tenant.\n", .{});
            }
            return e;
        },
        else => {
            log.err("Encountered an unknown error while creating a tenant.\n", .{});
            return e;
        },
    };

    return .{
        .id = try allocator.dupe(u8, &urn),
        .organization = req.orgId,
        .name = req.name,
    };
}
