const std = @import("std");
const klib = @import("klib");
const tk = @import("tokamak");
const zmpl = @import("zmpl");
const pg = @import("pg");
const Config = @import("config.zig").Config;
const template = @import("template.zig");
const metrics = @import("metrics.zig");
const builtin = @import("builtin");

const migration = @import("migration.zig");

fn notFound(context: *tk.Context, data: *zmpl.Data) !template.Template {
    const object = try data.object();
    context.res.status = 404;
    try object.put("error", "Not found");
    try object.put("status", 404);
    return template.Template.init("not_found");
}

const App = struct {
    server: *tk.Server,
    routes: []const tk.Route = &.{
        tk.logger(.{}, &.{
            metrics.track(&.{
                .get("/", tk.static.file("static/index.html")),
                .get("/metrics", metrics.route()),
                .get("/openapi.json", tk.swagger.json(.{ .info = .{ .title = "Kauth" } })),
                .get("/swagger-ui", tk.swagger.ui(.{ .url = "openapi.json" })),
                template.templates(&.{
                    .get("/*", notFound),
                }),
            }),
        }),
    },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();
    {
        const allocator = gpa.allocator();

        var instr_allocator = metrics.instrumentAllocator(allocator);
        const alloc = instr_allocator.allocator();
        try metrics.initialize(alloc, .{});
        defer metrics.deinitialize();

        var instr_page_allocator = metrics.instrumentAllocator(std.heap.page_allocator);
        const page_allocator = instr_page_allocator.allocator();
        var arena = std.heap.ArenaAllocator.init(page_allocator);
        defer arena.deinit();

        const config = try klib.config.findConfigFile(
            Config,
            arena.allocator(),
            "kauth",
            "config",
        ) orelse {
            std.log.err("Could not find configuration file... Aborting...", .{});
            return;
        };

        const ptr = try pg.Pool.init(alloc, .{
            .size = config.postgre.pool_size,
            .connect = .{
                .port = config.postgre.port,
                .host = config.postgre.host,
            },
            .auth = .{
                .username = config.postgre.auth.username,
                .password = config.postgre.auth.password,
                .database = config.postgre.auth.database,
                .timeout = config.postgre.auth.timeout,
            },
        });
        defer ptr.deinit();
        try migration.configure(ptr);
        try migration.applyPendingMigrations(allocator, ptr);

        const root = tk.Injector.init(&.{
            &alloc,
            &tk.ServerOptions{
                .listen = .{
                    .hostname = config.server.hostname,
                    .port = config.server.port,
                },
            },
            ptr,
        }, null);

        var app: App = undefined;
        const injector = try tk.Module(App).init(&app, &root);
        defer tk.Module(App).deinit(injector);

        if (comptime builtin.os.tag == .linux) {
            // call our shutdown function (below) when
            // SIGINT or SIGTERM are received
            std.posix.sigaction(std.posix.SIG.INT, &.{
                .handler = .{ .handler = shutdown },
                .mask = std.posix.empty_sigset,
                .flags = 0,
            }, null);
            std.posix.sigaction(std.posix.SIG.TERM, &.{
                .handler = .{ .handler = shutdown },
                .mask = std.posix.empty_sigset,
                .flags = 0,
            }, null);
        }

        if (injector.find(*tk.Server)) |server| {
            server.injector = injector;
            server_instance = server;
            //            try server.start();
        }
    }
    _ = gpa.detectLeaks();
}

var server_instance: ?*tk.Server = null;

fn shutdown(_: c_int) callconv(.C) void {
    if (server_instance) |server| {
        server_instance = null;
        server.stop();
    }
}
