const std = @import("std");
const tk = @import("tokamak");
const zmpl = @import("zmpl");
const metrics = @import("../metrics.zig");

const TenantService = @import("../service/tenants.zig");
const model = @import("../model/tenants.zig");
const template = @import("../template.zig");

pub fn @"POST /"(data: *zmpl.Data, tenant_service: *TenantService, req: model.CreateTenantRequest) !template.Template {
    const response = try tenant_service.create(req);
    const root = try data.object();
    try root.put("name", response.name);
    try root.put("orgId", response.orgId);
    try root.put("id", response.id);
    return template.Template.init("not_found");
}
