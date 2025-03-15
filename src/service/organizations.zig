const std = @import("std");

const Repository = @import("../repos/organizations.zig");
const models = @import("../model/organizations.zig");

const OrganizationService = @This();
const ar = @import("../api_result.zig");

repo: *Repository,

pub fn init(repo: *Repository.FromPool) OrganizationService {
    return .{
        .repo = repo.yield(),
    };
}

pub fn create(
    self: *const OrganizationService,
    req: models.CreateOrganizationRequest,
) !ar.ApiResult(models.CreateOrganizationResponse) {
    const row = try ar.handleAny(self.repo.create(req));
    return switch (row) {
        .err => |e| return .{
            .err = .{
                .code = e.code,
                .message = e.message,
            },
        },
        .result => |r| return .{ .result = .{
            .name = r.name,
            .id = r.id,
        } },
    };
}
