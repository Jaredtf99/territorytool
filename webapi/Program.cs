using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;
using OfficeOpenXml;
using System.Text;
using TerritoryTool.ServerSide.Domain;
using TerritoryTool.ServerSide.Persistence;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Configuration.AddUserSecrets("TerritoryTool").Build();

builder.Services.ConfigureDatabaseServices(builder.Configuration.GetConnectionString("SQLite"));
builder.Services.ConfigureIdentityServices();
builder.Services.ConfigureJwtAuthentication(builder.Configuration);

builder.Services.RegisterRepositories();
builder.Services.RegisterFacadeServices();
builder.Services.AddWebApiServices();

builder.Services.Configure<ApplicationSecrets>(builder.Configuration);

builder.Logging.AddFile(builder.Configuration["Logging:LogFilePath"].ToString());

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowSpecificOrigin",
        builder => builder.AllowAnyOrigin()
                          .AllowAnyHeader()
                          .AllowAnyMethod());
});

ExcelPackage.LicenseContext = LicenseContext.NonCommercial;

var app = builder.Build();

app.UseExceptionHandler(errorApp =>
{
    errorApp.Run(async context =>
    {
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        context.Response.ContentType = "application/json";

        var exceptionHandlerPathFeature = context.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerPathFeature>();

        if (exceptionHandlerPathFeature?.Error != null)
        {
            var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
            logger.LogError(exceptionHandlerPathFeature.Error, "Unhandled exception occurred.");
        }

        await context.Response.WriteAsync("{\"message\": \"Error interno del servidor\"}");
    });
});

app.UseCors("AllowSpecificOrigin");

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}


app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});
app.UseHttpsRedirection();

app.UseAuthorization();
app.UseAuthentication();
app.UseStaticFiles();
app.UseStaticFiles(new StaticFileOptions()
{
    FileProvider = new PhysicalFileProvider(Path.Combine(Directory.GetCurrentDirectory(), @"Resources\Images")),
    RequestPath = new PathString("/Resources/Images")
});
app.MapControllers();

// Aplicar migraciones
app.ApplyMigrations();

app.Run();
