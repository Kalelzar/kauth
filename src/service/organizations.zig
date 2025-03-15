const std = @import("std");

const Repository = @import("../repos/organizations.zig");
const models = @import("../model/organizations.zig");

const OrganizationService = @This();
const ar = @import("../api_result.zig");

repo_factory: *Repository.FromPool,

pub fn init(repo: *Repository.FromPool) OrganizationService {
    return .{
        .repo_factory = repo,
    };
}

pub fn create(
    self: *const OrganizationService,
    allocator: std.mem.Allocator,
    req: models.CreateOrganizationRequest,
) !ar.ApiResult(models.CreateOrganizationResponse) {
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
            },
        },
    };
}
