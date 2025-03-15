pub const CreateTenantRequest = struct {
    name: []const u8,
    orgId: []const u8,
};

pub const CreateTenantResponse = struct {
    id: []const u8,
    name: []const u8,
    orgId: []const u8,
};
