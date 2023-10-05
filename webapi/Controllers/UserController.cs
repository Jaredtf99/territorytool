using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Newtonsoft.Json;
using TerritoryTool.ServerSide.Controllers.Models.User;
using TerritoryTool.ServerSide.Domain;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Domain.Helpers;
using TerritoryTool.ServerSide.Persistence;

namespace TerritoryTool.ServerSide.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class UserController : ControllerBase
    {
        private readonly ILogger _logger;

        private readonly IUserConfigurationFacade _userConfigurationFacade;

        public UserController(ILogger<SampleDataController> logger, IUserConfigurationFacade userConfigurationFacade)
        {
            _logger = logger;
            _userConfigurationFacade = userConfigurationFacade;
        }

        [HttpPost]
        [Route("register")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult RegisterUser(RegisterModel model)
        {
            var userId  = SecurityHelper.GetLoggedUserId(User);

            IdentityResult result = _userConfigurationFacade.RegisterUser(model?.UserName, model?.Password, RoleType.USER, userId); 

            if (result == null)
                return BadRequest();
            else
                return Ok(result);

        }


        [HttpPost]
        [Route("login")]
        [AllowAnonymous]
        public ActionResult Login(LoginModel model)
        {
            _logger.LogInformation("Loging user...");

            string token = _userConfigurationFacade.Login(model?.UserName, model?.Password);

            if (string.IsNullOrWhiteSpace(token))
                return BadRequest("WRONG_USERNAME_PASSWORD");
            else
                return Ok(new { token });

        }


        [HttpPost]
        [Route("change-password")]
        public ActionResult ChangePassword(ChangePasswordModel model)
        {
            var userId  = SecurityHelper.GetLoggedUserId(User);

            IdentityResult result = _userConfigurationFacade.ChangePassword(userId, model?.OldPassword, model?.NewPassword);

            if (result == null)
                return BadRequest();
            else if (result.Succeeded)
                return Ok();
            else
            {
                string codesJoined = string.Join(",", result.Errors.Select(x => x.Code));
                _logger.LogInformation("Errors on changing password for userId {0}. Errors: {1}", userId, codesJoined);
                return BadRequest(codesJoined);
            }

        }


        [HttpGet]
        [Route("get-users")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult GetUsers()
        {
            IEnumerable<UserInfo> users = _userConfigurationFacade.GetUsersInformation();

            return Content(JsonConvert.SerializeObject(users), ConfigurationHelper.JsonMime);
        }

        [HttpPost]
        [Route("edit-user")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult EditUser(EditUserModel model)
        {
            if (string.IsNullOrWhiteSpace(model.UserID) || string.IsNullOrWhiteSpace(model.UserName) || model.Role == RoleType.Unknown || model.Role == RoleType.SUPERADMIN)
                return BadRequest("INVALID_PARAMETERS");

            if (model.Role == RoleType.ADMIN && !User.IsInRole(RoleType.SUPERADMIN.ToString()))
                return Forbid();

            var loggedUserId = SecurityHelper.GetLoggedUserId(User);

            bool successful = _userConfigurationFacade.EditUser(model.UserID, model.UserName, model.Role, loggedUserId, out string errorMsg);

            if (successful)
                return Ok();
            else
                return BadRequest(errorMsg);

        }

        [HttpGet]
        [Route("delete-user")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult DeleteUser(string idToDelete)
        {
            if (string.IsNullOrWhiteSpace(idToDelete))
                return BadRequest("INVALID_PARAMETERS");

            var loggedUserId = SecurityHelper.GetLoggedUserId(User);

            _userConfigurationFacade.DeleteUser(idToDelete, loggedUserId);

            return Ok();

        }


    }
}