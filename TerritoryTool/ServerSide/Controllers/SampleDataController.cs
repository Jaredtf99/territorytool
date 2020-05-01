using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.WebSockets.Internal;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Domain.Helpers;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;

namespace TerritoryTool.ServerSide.Controllers
{
    [Route("api/[controller]")]
    public class SampleDataController : Controller
    {

        private readonly ILogger _logger;

        private readonly ITerritoryRepository _territoryRepository;
        private readonly IUserActionLogFacade _userActionLogFacade;

        public SampleDataController(ITerritoryRepository territoryRepository, ILogger<SampleDataController> logger, IUserActionLogFacade userActionLogFacade)
        {
            _territoryRepository = territoryRepository;
            _logger = logger;
            _userActionLogFacade = userActionLogFacade;
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
            var userId = SecurityHelper.GetLoggedUserId(User);
            _logger.LogInformation("Adding territory...");
            
            if (_territoryRepository.GetTerritoryByCode(code) != null)
                return BadRequest("Ya existe un territorio con el mismo código");

            if (_territoryRepository.GetTerritoryByName(name) != null)
                return BadRequest("Ya existe un territorio con el mismo nombre");

            if (_territoryRepository.GetTerritoryByMapUrl(mapUrl) != null)
                return BadRequest("Ya existe un territorio con la misma URL del mapa");

            _territoryRepository.AddNewTerritory(code, name, mapUrl);

            _userActionLogFacade.AddNewActionLog(ActionType.AddTerritory, string.Format("Added territory {0} {1}", code, name), userId, true);

            return Ok();
        }

        [HttpPost("[action]")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult EditTerritory(int id, string code, string name, string mapUrl)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);

            _logger.LogInformation("Editing territory...");

            if (string.IsNullOrWhiteSpace(code) || string.IsNullOrWhiteSpace(name) || string.IsNullOrWhiteSpace(mapUrl))
                return BadRequest("INVALID_PARAMETERS");

            Territory territory = _territoryRepository.GetTerritoryById(id);


            if (territory.Code != code &&_territoryRepository.GetTerritoryByCode(code) != null)
                return BadRequest("CODE_EXIST");

            if (territory.Name != name && _territoryRepository.GetTerritoryByName(name) != null)
                return BadRequest("NAME_EXIST");

            if (territory.MapUrl != mapUrl && _territoryRepository.GetTerritoryByMapUrl(mapUrl) != null)
                return BadRequest("MAPURL_EXIST");


            _territoryRepository.EditTerritory(id, code, name, mapUrl);

            _userActionLogFacade.AddNewActionLog(ActionType.EditTerritory, string.Format("Edited territory ID {0} to: Code ({1}) Name ({2}) MapURL ({3})", id, code, name, mapUrl), userId, true);

            return Ok();
        }

        [HttpPost("[action]")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult DeleteTerritory(int idToDelete)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);

            _logger.LogInformation("Delete territory...");

            _territoryRepository.DeleteTerritory(idToDelete);

            _userActionLogFacade.AddNewActionLog(ActionType.DeleteTerritory, string.Format("Deleted territory id {0}", idToDelete), userId, true);

            return Ok();
        }

        [HttpGet("[action]")]
        [Authorize(Roles = "SUPERADMIN")]
        public ActionResult GetAllActionLogs()
        {
            var actionLogs = _userActionLogFacade.GetAllActionLogs();

            return Content(JsonConvert.SerializeObject(actionLogs), ConfigurationHelper.JsonMime);
        }


    }
}
