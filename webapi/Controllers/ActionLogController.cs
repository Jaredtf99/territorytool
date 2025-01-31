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
    [Route("api/v1/actionlogs")]
    [ApiController]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class ActionLogController : ControllerBase
    {

        private readonly ILogger _logger;

        private readonly IUserActionLogFacade _userActionLogFacade;

        public ActionLogController(ILogger<ActionLogController> logger, IUserActionLogFacade userActionLogFacade)
        {
            _logger = logger;
            _userActionLogFacade = userActionLogFacade;
        }

        [HttpGet]
        [Authorize(Roles = "SUPERADMIN")]
        public ActionResult GetActionLogsPaged(int pageNumber = 1, int pageSize = 20, string sortField = "DateUtc", string sortOrder = "desc")
        {
            var result = _userActionLogFacade.GetActionLogsPaged(pageNumber, pageSize, sortField, sortOrder);
            return Content(JsonConvert.SerializeObject(result), ConfigurationHelper.JsonMime);
        }

    }
}
