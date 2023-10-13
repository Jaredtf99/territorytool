using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using TerritoryTool.ServerSide.Controllers.Models.Person;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Domain.Helpers;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;

namespace TerritoryTool.ServerSide.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class SampleDataController : ControllerBase
    {

        private readonly ILogger _logger;

        private readonly ITerritoryRepository _territoryRepository;
        private readonly IUserActionLogFacade _userActionLogFacade;
        private readonly IPersonFacade _personFacade;

        public SampleDataController(ITerritoryRepository territoryRepository, ILogger<SampleDataController> logger, IUserActionLogFacade userActionLogFacade, IPersonFacade personFacade)
        {
            _territoryRepository = territoryRepository;
            _logger = logger;
            _userActionLogFacade = userActionLogFacade;
            _personFacade = personFacade;
        }

        [HttpGet("[action]")]
        public IEnumerable<Territory> AllTerritories()
        {
            _logger.LogInformation("Returning all territories...");

            return _territoryRepository.GetAllTerritories();
        }

        [HttpPost("[action]")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult AddTerritory(AddTerritoryModel territoryInfo)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);
            _logger.LogInformation("Adding territory...");
            
            if (_territoryRepository.GetTerritoryByCode(territoryInfo.Code) != null)
                return BadRequest("Ya existe un territorio con el mismo código");

            if (_territoryRepository.GetTerritoryByName(territoryInfo.Name) != null)
                return BadRequest("Ya existe un territorio con el mismo nombre");

            if (_territoryRepository.GetTerritoryByMapUrl(territoryInfo.MapUrl) != null)
                return BadRequest("Ya existe un territorio con la misma URL del mapa");

            _territoryRepository.AddNewTerritory(territoryInfo.Code, territoryInfo.Name, territoryInfo.MapUrl);

            _userActionLogFacade.AddNewActionLog(ActionType.AddTerritory, string.Format("Added territory {0} {1}", territoryInfo.Code, territoryInfo.Name), userId, true);

            return Ok();
        }

        [HttpPost("[action]")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult EditTerritory(EditTerritoryModel info)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);

            _logger.LogInformation("Editing territory...");

            if (string.IsNullOrWhiteSpace(info.Code) || string.IsNullOrWhiteSpace(info.Name) || string.IsNullOrWhiteSpace(info.MapUrl))
                return BadRequest("INVALID_PARAMETERS");

            Territory territory = _territoryRepository.GetTerritoryById(info.Id);


            if (territory.Code != info.Code && _territoryRepository.GetTerritoryByCode(info.Code) != null)
                return BadRequest("CODE_EXIST");

            if (territory.Name != info.Name && _territoryRepository.GetTerritoryByName(info.Name) != null)
                return BadRequest("NAME_EXIST");

            if (territory.MapUrl != info.MapUrl && _territoryRepository.GetTerritoryByMapUrl(info.MapUrl) != null)
                return BadRequest("MAPURL_EXIST");

            territory.Code = info.Code;
            territory.Name = info.Name;
            territory.MapUrl = info.MapUrl;

            _territoryRepository.EditTerritory(territory);

            _userActionLogFacade.AddNewActionLog(ActionType.EditTerritory, string.Format("Edited territory ID {0} to: Code ({1}) Name ({2}) MapURL ({3})", info.Id, info.Code, info.Name, info.MapUrl), userId, true);

            return Ok();
        }

        [HttpDelete("[action]")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult DeleteTerritory(int id)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);

            _logger.LogInformation("Deleting territory...");

            string errorMessage = null;

            Territory territoryToDelete = _territoryRepository.GetTerritoryById(id);

            if (territoryToDelete != null)
                _territoryRepository.DeleteTerritory(territoryToDelete);
            else
                errorMessage = "TERRITORY_NOT_FOUND";

            _userActionLogFacade.AddNewActionLog(ActionType.DeleteTerritory, string.Format("Deleted territory id {0}", id), userId, string.IsNullOrWhiteSpace(errorMessage));

            if (string.IsNullOrWhiteSpace(errorMessage))
                return Ok();
            else
                return BadRequest(errorMessage);

        }

        [HttpGet("[action]")]
        [Authorize(Roles = "SUPERADMIN")]
        public ActionResult GetAllActionLogs()
        {
            IEnumerable<ActionLogInfo> actionLogs = _userActionLogFacade.GetAllActionLogs();

            return Content(JsonConvert.SerializeObject(actionLogs), ConfigurationHelper.JsonMime);
        }

        [HttpPost("[action]")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult AddPerson(AddPersonModel personInfo)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);
            _logger.LogInformation("Adding person...");

            _personFacade.AddNewPerson(personInfo.Name, userId);

            return Ok();
        }

        [HttpGet("[action]")]
        public ActionResult GetAllPersons()
        {
            IEnumerable<PersonInfo> persons = _personFacade.GetAllPersons();

            return Content(JsonConvert.SerializeObject(persons), ConfigurationHelper.JsonMime);
        }

        [HttpDelete("[action]")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult DeletePerson(string name)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);

            _personFacade.DeletePerson(name, userId);

            return Ok();
        }


    }
}
