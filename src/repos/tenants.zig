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

pub fn init(conn: *pg.Conn) Tenants {
    return .{
        .conn = conn,
    };
}

pub const FromPool = struct {
    conn: *pg.Conn,
    repo: Tenants,
    pub fn init(pool: *pg.Pool) !FromPool {
        const conn = try pool.acquire();
        return .{
            .conn = conn,
            .repo = Tenants.init(conn),
        };
    }

    pub fn yield(self: *FromPool) *Tenants {
        return &self.repo;
    }

    pub fn deinit(self: *FromPool) void {
        self.conn.release();
    }
};

pub fn deinit(self: *Tenants) void {
    self.conn.release();
}

pub fn create(
    self: *Tenants,
    req: models.CreateTenantRequest,
) !TenantRow {
    const query =
        \\ insert into tenants (id, organization, name)
        \\   values($1, $2, $3)
    ;
    const id = uuid.v7.new();
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
                log.err(
                    "[{s}] Encountered an error ({s}) while creating a tenant: \n{s}\n",
                    .{ pge.severity, pge.code, pge.message },
                );
            } else {
                log.err("Encountered an unknown error while creating a tenant.\n", .{});
            }
            return e;
        },
        else => return e,
    };

    return .{
        .id = &urn,
        .organization = req.orgId,
        .name = req.name,
    };
}
