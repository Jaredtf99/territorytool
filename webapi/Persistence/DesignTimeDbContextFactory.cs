using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;
using System.IO;

namespace TerritoryTool.ServerSide.Persistence
{
    public class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<TerritoryToolDbContext>
    {
        public TerritoryToolDbContext CreateDbContext(string[] args)
        {
            string basePath = Directory.GetCurrentDirectory(); 
            
            IConfigurationRoot configuration = new ConfigurationBuilder()
                .SetBasePath(basePath)
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
                .AddEnvironmentVariables()
                .Build();

            var optionsBuilder = new DbContextOptionsBuilder<TerritoryToolDbContext>();
            
            var connectionString = configuration.GetConnectionString("SQLite"); 
            
            if (string.IsNullOrEmpty(connectionString))
            {
                throw new System.InvalidOperationException("Connection string 'SQLite' not found in appsettings.json.");
            }

            // Removed optionsBuilder.UseSqlite(connectionString, o => o.MigrationsAssembly("TerritoryTool.ServerSide"));
            // Let EF Core use the default assembly (webapi)
            optionsBuilder.UseSqlite(connectionString); 
            
            return new TerritoryToolDbContext(optionsBuilder.Options);
        }
    }
}
