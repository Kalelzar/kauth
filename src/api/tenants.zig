const std = @import("std");
const tk = @import("tokamak");
const zmpl = @import("zmpl");
const metrics = @import("../metrics.zig");

const TenantService = @import("../service/tenants.zig");
const model = @import("../model/tenants.zig");
const template = @import("../template.zig");

pub fn @"POST /"(
    res: *tk.Response,
    data: *zmpl.Data,
    tenant_service: *TenantService,
    req: model.CreateTenantRequest,
) !template.Template {
    var instr = metrics.instrumentAllocator(res.arena);
    const alloc = instr.allocator();
    const response = try tenant_service.create(alloc, req);
    const root = try data.object();
    switch (response) {
        .result => |r| {
            try root.put("name", r.name);
            try root.put("orgId", r.orgId);
            try root.put("id", r.id);
        },
        .err => |e| {
            try root.put("message", e.message);
            try root.put("code", e.code);
            res.status = @intFromEnum(e.code);
        },
    }
    return template.Template.init("not_found");
}
