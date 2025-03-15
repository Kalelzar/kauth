pub const CreateOrganizationRequest = struct {
    name: []const u8,
};

pub const CreateOrganizationResponse = struct {
    id: []const u8,
    name: []const u8,
};
