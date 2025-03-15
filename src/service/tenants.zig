const std = @import("std");

const Repository = @import("../repos/tenants.zig");
const models = @import("../model/tenants.zig");

const TenantService = @This();

repo: *Repository,

pub fn init(repo: *Repository.FromPool) TenantService {
    return .{
        .repo = repo.yield(),
    };
}

pub fn create(
    self: *const TenantService,
    req: models.CreateTenantRequest,
) !models.CreateTenantResponse {
    const row = try self.repo.create(req);
    return .{
        .name = row.name,
        .id = row.id,
        .orgId = row.organization,
    };
}
