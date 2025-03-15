CREATE TABLE organizations (
       id UUID PRIMARY KEY,
       name TEXT NOT NULL,
       unique(name)
);

CREATE TABLE tenants (
       id UUID PRIMARY KEY,
       name TEXT NOT NULL,
       organization UUID NOT NULL,
       unique(organization, name),
       FOREIGN KEY(organization) REFERENCES organizations(id) ON DELETE CASCADE
);

CREATE TABLE connections (
       id UUID PRIMARY KEY,
       tenant UUID NOT NULL,
       name TEXT NOT NULL,
       UNIQUE(tenant, name),
       FOREIGN KEY(tenant) REFERENCES tenants(id) ON DELETE CASCADE
);

CREATE TABLE users (
       id UUID PRIMARY KEY,
       username TEXT NOT NULL,
       email TEXT NOT NULL,
       credential TEXT NOT NULL,
       connection UUID NOT NULL,
       UNIQUE(connection, email, username),
       FOREIGN KEY(connection) REFERENCES connections(id) ON DELETE CASCADE
);
