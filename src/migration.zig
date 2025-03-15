const std = @import("std");
const pg = @import("pg");
const embedded_migrations = @import("migrations");
const builtin = @import("builtin");

const E: std.StaticStringMap([]const u8) = .initComptime(kvs: {
    var res: [embedded_migrations.files.len]struct { []const u8, []const u8 } = undefined;
    for (embedded_migrations.files, embedded_migrations.contents, 0..) |f, c, i| res[i] = .{ f, c };
    break :kvs &res;
});

pub fn configure(pool: *pg.Pool) !void {
    const stmt =
        \\ create table if not exists _db_migrations (
        \\     version VARCHAR(255) PRIMARY KEY,
        \\     applied_at TIMESTAMP NOT NULL DEFAULT NOW()
        \\);
    ;

    _ = try pool.exec(stmt, .{});
}

pub fn applyPendingMigrations(allocator: std.mem.Allocator, pool: *pg.Pool) !void {
    std.log.info("Begin migration process.", .{});
    const migrations = try collectMigrations(allocator);
    defer allocator.free(migrations);

    const query =
        \\ select version from _db_migrations;
    ;

    const rows = try pool.query(query, .{});
    defer rows.deinit();

    var ids = std.BufSet.init(allocator);
    defer ids.deinit();

    while (try rows.next()) |row| {
        try ids.insert(row.get([]const u8, 0));
    }
    _ = try pool.exec("BEGIN;", .{});
    for (migrations) |migration_path| {
        var path_split_iter = std.mem.splitScalar(
            u8,
            migration_path,
            '/',
        );
        _ = path_split_iter.next().?;
        const migration = path_split_iter.next().?;
        var split_iter = std.mem.splitScalar(
            u8,
            migration,
            '.',
        );
        const id = split_iter.next().?;
        const name = split_iter.next().?;
        std.log.info("\tFound migration {s}/{s}", .{ id, name });
        if (ids.contains(id)) {
            std.log.info("\tMigration {s}/{s} is already applied.", .{ id, name });
            continue;
        }
        const sql = E.get(migration_path) orelse unreachable;
        _ = try pool.exec(sql, .{});

        _ = try pool.exec("INSERT INTO _db_migrations (version) VALUES ($1)", .{id});
        std.log.info("\tApplied migration {s}/{s}", .{ id, name });
    }
    _ = try pool.exec("COMMIT;", .{});
    std.log.info("End migration process.", .{});
}

const MigrationIterator = struct {
    length: u32,
    needle: u32,

    pub fn init() MigrationIterator {
        std.log.info("\t\tInitializing migration iterator: {} embeds", .{E.kvs.len});
        return .{
            .length = E.kvs.len,
            .needle = 0,
        };
    }

    pub fn next(self: *MigrationIterator) ?[]const u8 {
        while (self.needle < self.length) {
            const key = E.keys()[self.needle];
            self.needle += 1;
            if (std.mem.endsWith(u8, key, ".up.sql")) {
                return key;
            }
        }

        return null;
    }
};

fn collectMigrations(allocator: std.mem.Allocator) ![]const []const u8 {
    std.log.info("\tCollecting migrations...", .{});
    var migrations = std.ArrayListUnmanaged([]const u8){};
    defer migrations.deinit(allocator);
    var iter = MigrationIterator.init();
    while (iter.next()) |m| {
        try migrations.append(allocator, m);
    }

    std.sort.heap([]const u8, migrations.items, {}, compareStrings);

    return allocator.dupe([]const u8, migrations.items);
}

fn compareStrings(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.order(u8, lhs, rhs).compare(std.math.CompareOperator.lt);
}
