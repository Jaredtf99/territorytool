using Quartz;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;
using Microsoft.Extensions.Logging;

namespace TerritoryTool.ServerSide.Domain.Jobs;

public class UpdateTerritoryImagesJob : IJob
{
    private readonly ITerritoryRepository _territoryRepository;
    private readonly ITerritoryFacade _territoryFacade;
    private readonly ILogger<UpdateTerritoryImagesJob> _logger;

    public UpdateTerritoryImagesJob(
        ITerritoryRepository territoryRepository,
        ITerritoryFacade territoryFacade,
        ILogger<UpdateTerritoryImagesJob> logger)
    {
        _territoryRepository = territoryRepository;
        _territoryFacade = territoryFacade;
        _logger = logger;
    }

    public async Task Execute(IJobExecutionContext context)
    {
        try
        {
            _logger.LogInformation("Iniciando actualización de imágenes de territorios");
            var territories = _territoryRepository.GetAllTerritories(null, null, null, true, null, null);
            
            foreach (var territory in territories)
            {
                _territoryFacade.RefreshImageTerritory(territory.Id);
            }
            
            _logger.LogInformation("Actualización de imágenes de territorios completada");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error durante la actualización de imágenes de territorios");
            throw;
        }
    }
} 