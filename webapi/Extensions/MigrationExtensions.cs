using Microsoft.EntityFrameworkCore;
using TerritoryTool.ServerSide.Persistence;

public static class MigrationExtensions
{
    public static void ApplyMigrations(this IApplicationBuilder app)
    {
        using (var scope = app.ApplicationServices.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<TerritoryToolDbContext>();
            db.Database.Migrate();
        }
    }
} 