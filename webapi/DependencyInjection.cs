using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using TerritoryTool.ServerSide.Domain.FacadeServices.Implementation;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Persistence;
using TerritoryTool.ServerSide.Persistence.Repositories.Implementation;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;
using Quartz;
using TerritoryTool.ServerSide.Domain.Jobs;

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
    }

    public static IServiceCollection AddWebApiServices(this IServiceCollection services)
    {
        services.AddQuartz(q =>
        {
            var jobKey = new JobKey("UpdateTerritoryImagesJob");
            q.AddJob<UpdateTerritoryImagesJob>(opts => opts.WithIdentity(jobKey));

            q.AddTrigger(opts => opts
                .ForJob(jobKey)
                .WithIdentity("UpdateTerritoryImagesJob-startup-trigger")
                .StartNow()); // Se ejecuta inmediatamente al iniciar la aplicación
        });

        services.AddQuartzHostedService(q => q.WaitForJobsToComplete = true);

        return services;
    }
}