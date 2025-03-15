CREATE TABLE application (
       id UUID PRIMARY KEY,
       name TEXT NOT NULL,
       tenant UUID NOT NULL,
       client_id TEXT NOT NULL,
       client_secret TEXT NOT NULL,
       UNIQUE(tenant, name),
       FOREIGN KEY(tenant) REFERENCES tenants(id) ON DELETE CASCADE
);     
