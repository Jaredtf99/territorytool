using System.Collections.Generic;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;

namespace TerritoryTool.ServerSide.Controllers
{
    [Route("api/[controller]")]
    public class SampleDataController : Controller
    {

        private readonly ILogger _logger;

        private readonly ITerritoryRepository _territoryRepository;

        public SampleDataController(ITerritoryRepository territoryRepository, ILogger<SampleDataController> logger)
        {
            _territoryRepository = territoryRepository;
            _logger = logger;
        }

        [HttpGet("[action]")]
        [Authorize]
        public IEnumerable<Territory> AllTerritories()
        {
            _logger.LogInformation("Returning all territories...");

            return _territoryRepository.GetAllTerritories();
        }

        [HttpPost("[action]")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult AddTerritory(string code, string name, string mapUrl)
        {
            _logger.LogInformation("Adding territory...");

            if (_territoryRepository.GetTerritoryByCode(code) != null)
                return BadRequest("Ya existe un territorio con el mismo código");

            if (_territoryRepository.GetTerritoryByName(name) != null)
                return BadRequest("Ya existe un territorio con el mismo nombre");

            if (_territoryRepository.GetTerritoryByMapUrl(mapUrl) != null)
                return BadRequest("Ya existe un territorio con la misma URL del mapa");

            _territoryRepository.AddNewTerritory(code, name, mapUrl);

            return Ok();
        }

    }
}
