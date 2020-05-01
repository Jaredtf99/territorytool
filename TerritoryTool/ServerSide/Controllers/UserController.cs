using System;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using TerritoryTool.ServerSide.Controllers.Models.User;
using TerritoryTool.ServerSide.Domain;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Domain.Helpers;
using TerritoryTool.ServerSide.Persistence;

namespace TerritoryTool.ServerSide.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class UserController : ControllerBase
    {
        private readonly ILogger _logger;

        private UserManager<ApplicationUser> _userManager;
        private readonly ApplicationSettings _appSettings;
        private readonly IUserActionLogFacade _userActionLogFacade;
        private readonly IUserConfigurationFacade _userConfigurationFacade;

        public UserController(UserManager<ApplicationUser> userManager, IOptions<ApplicationSettings> appSettings, ILogger<SampleDataController> logger, IUserActionLogFacade userActionLogFacade, IUserConfigurationFacade userConfigurationFacade)
        {
            _userManager = userManager;
            _appSettings = appSettings.Value;
            _logger = logger;
            _userActionLogFacade = userActionLogFacade;
            _userConfigurationFacade = userConfigurationFacade;
        }

        [HttpPost]
        [Route("register")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult RegisterUser(RegisterModel model)
        {
            var userId  = SecurityHelper.GetLoggedUserId(User);

            IdentityResult result = _userConfigurationFacade.RegisterUser(model?.UserName, model?.Password, RoleType.User, userId); 

            if (result == null)
                return BadRequest();
            else
                return Ok(result);

        }


        [HttpPost]
        [Route("login")]
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
        [Authorize]
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

    }
}