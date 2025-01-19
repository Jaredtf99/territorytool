using System.Collections.Generic;
using System.Linq;
using System.Net.Mime;
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using TerritoryTool.ServerSide.Controllers.Models.Person;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.Exceptions;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Domain.Helpers;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Implementation;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;

namespace TerritoryTool.ServerSide.Controllers
{
    [Route("api/v1/persons")]
    [ApiController]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class PersonController : Controller
    {
        private readonly ILogger _logger;

        private readonly IPersonFacade _personFacade;

        public PersonController(ILogger<ActionLogController> logger, IPersonFacade personFacade)
        {
            _personFacade = personFacade;
            _logger = logger;
        }

        [HttpPost]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult AddPerson(AddPersonModel personInfo)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);
            _logger.LogInformation("Adding person...");

            try
            {
                _personFacade.AddNewPerson(personInfo.Name, userId);
            }
            catch (DomainException ex)
            {
                return BadRequest(ex.Message);
            }

            return Ok();
        }

        [HttpGet]
        public ActionResult GetAllPersons()
        {
            IEnumerable<PersonInfo> persons = _personFacade.GetAllPersons();

            return Content(JsonConvert.SerializeObject(persons), ConfigurationHelper.JsonMime);
        }

        [HttpDelete("{name}")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult DeletePerson(string name)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);

            _personFacade.DeletePerson(name, userId);

            return Ok();
        }

        /// <summary>
        /// Devuelve una lista de personas en base al filtro de busqueda por texto
        /// </summary>
        /// <param name="search"></param>
        /// <returns></returns>
        [HttpGet("{search}")]
        public IEnumerable<PersonInfo> SearchPersons(string search)
        {
            _logger.LogInformation("Searching persons");

            return _personFacade.SearchPersonsByName(search);
        }

    }
}
