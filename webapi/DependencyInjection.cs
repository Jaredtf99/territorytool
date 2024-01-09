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

public static class DependencyInjection
{
    public static void RegisterRepositories(this IServiceCollection services)
    {
        services.AddScoped<IActionLogRepository, ActionLogRepository>();
        services.AddScoped<IPersonRepository, PersonRepository>();
        services.AddScoped<ITerritoryRepository, TerritoryRepository>();
    }

    public static void RegisterFacadeServices(this IServiceCollection services)
    {
        services.AddScoped<IPersonFacade, PersonFacade>();
        services.AddScoped<IUserActionLogFacade, UserActionLogFacade>();
        services.AddScoped<IUserConfigurationFacade, UserConfigurationFacade>();
        services.AddScoped<ITerritoryFacade, TerritoryFacade>();
    }

}