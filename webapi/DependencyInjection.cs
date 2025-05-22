using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Quartz;
using System.Text;
using TerritoryTool.ServerSide.Domain.FacadeServices.Implementation;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Domain.Jobs;
using TerritoryTool.ServerSide.Persistence;
using TerritoryTool.ServerSide.Persistence.Repositories.Implementation;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;
using webapi.Domain.Jobs;

public static class DependencyInjection
{
    public static void RegisterRepositories(this IServiceCollection services)
    {
        services.AddScoped<IActionLogRepository, ActionLogRepository>();
        services.AddScoped<IPersonRepository, PersonRepository>();
        services.AddScoped<ITerritoryRepository, TerritoryRepository>();
        services.AddScoped<ITransactionRepository, TransactionRepository>();
    }

    public static void RegisterFacadeServices(this IServiceCollection services)
    {
        services.AddScoped<IPersonFacade, PersonFacade>();
        services.AddScoped<IUserActionLogFacade, UserActionLogFacade>();
        services.AddScoped<IUserConfigurationFacade, UserConfigurationFacade>();
        services.AddScoped<ITerritoryFacade, TerritoryFacade>();
        services.AddScoped<ITransactionFacade, TransactionFacade>();
        services.AddScoped<IGoogleDriveService, GoogleDriveService>();
    }

    public static IServiceCollection AddWebApiServices(this IServiceCollection services)
    {
        services.AddQuartz(q =>
        {
            var jobKeyUpdateTerritoryImages = new JobKey("UpdateTerritoryImagesJob");
            //q.AddJob<UpdateTerritoryImagesJob>(opts => opts.WithIdentity(jobKeyUpdateTerritoryImages));

            var jobKeyDriveBackupUploader = new JobKey("BackupDatabaseDrive");
            q.AddJob<BackupDatabaseJob>(opts => opts.WithIdentity(jobKeyDriveBackupUploader));

            q.AddTrigger(opts => opts
                .ForJob(jobKeyDriveBackupUploader)
                .WithIdentity("BackupDatabaseDrive-startup-trigger")
                .StartNow());

            //q.AddTrigger(opts => opts
            //    .ForJob(jobKey)
            //    .WithIdentity("UpdateTerritoryImagesJob-startup-trigger")
            //    .StartNow()); // Se ejecuta inmediatamente al iniciar la aplicación

        });

        services.AddQuartzHostedService(q => q.WaitForJobsToComplete = true);

        return services;
    }
}