const std = @import("std");

const Repository = @import("../repos/tenants.zig");
const models = @import("../model/tenants.zig");

const TenantService = @This();
const ar = @import("../api_result.zig");

repo_factory: *Repository.FromPool,

pub fn init(repo: *Repository.FromPool) TenantService {
    return .{
        .repo_factory = repo,
    };
}

pub fn create(
    self: *const TenantService,
    allocator: std.mem.Allocator,
    req: models.CreateTenantRequest,
) !ar.ApiResult(models.CreateTenantResponse) {
    var repo = try self.repo_factory.yield();
    defer repo.deinit();
    const row = try ar.handleAny(repo.create(allocator, req));
    return switch (row) {
        .err => |e| return .{
            .err = .{
                .code = e.code,
                .message = e.message,
            },
        },
        .result => |r| return .{
            .result = .{
                .name = r.name,
                .id = r.id,
                .orgId = r.organization,
            },
        },
    };
}
