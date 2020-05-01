using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using System;
using System.Collections.Generic;
using System.Diagnostics.Contracts;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Domain.Helpers;
using TerritoryTool.ServerSide.Persistence;

namespace TerritoryTool.ServerSide.Domain.FacadeServices.Implementation
{
    public class UserConfigurationFacade : IUserConfigurationFacade
    {
        private readonly ILogger _logger;

        private UserManager<ApplicationUser> _userManager;
        private readonly ApplicationSettings _appSettings;
        private readonly IUserActionLogFacade _userActionLogFacade;

        public UserConfigurationFacade(ILogger<UserConfigurationFacade> logger, UserManager<ApplicationUser> userManager, IOptions<ApplicationSettings> appSettings, IUserActionLogFacade userActionLogFacade)
        {
            _logger = logger;
            _userManager = userManager;
            _appSettings = appSettings.Value;
            _userActionLogFacade = userActionLogFacade;
        }

        public IdentityResult ChangePassword(string userId, string currentPassword, string newPassword)
        {
            IdentityResult retval = null;

            var user = _userManager.FindByIdAsync(userId).Result;

            _logger.LogError("Changing password for user: {0}", user?.UserName ?? userId);

            if (user == null)
                _logger.LogError("Null user finded for change password. UserId: {0}", userId);
            else
                retval = _userManager.ChangePasswordAsync(user, currentPassword, newPassword).Result;

            _userActionLogFacade.AddNewActionLog(ActionType.ChangeUserPassword, string.Format("Changued password for user {0}", user.UserName), userId, user != null && retval.Succeeded);

            return retval;
        }

        public string Login(string userName, string password)
        {
            string token = null;

            ApplicationUser user = _userManager.FindByNameAsync(userName).Result;


            if (user != null && _userManager.CheckPasswordAsync(user, password).Result)
            {
                _logger.LogInformation("Password correct");
                var role = _userManager.GetRolesAsync(user).Result;
                _logger.LogInformation("Roles matched");

                IdentityOptions _options = new IdentityOptions();

                var tokenDescriptor = new SecurityTokenDescriptor
                {
                    Subject = new ClaimsIdentity(new Claim[] {
                        new Claim(ConfigurationHelper.UserIDClaimKey, user.Id.ToString()),
                        new Claim(ConfigurationHelper.UserNameClaimKey, user.UserName),
                        new Claim(_options.ClaimsIdentity.RoleClaimType, role.FirstOrDefault())
                    }),
                    Expires = DateTime.UtcNow.AddMonths(2),
                    SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_appSettings.JWT_Secret)), SecurityAlgorithms.HmacSha256Signature)
                };

                _logger.LogInformation("tokendescriptor created");

                var tokenHandler = new JwtSecurityTokenHandler();
                var securityToken = tokenHandler.CreateToken(tokenDescriptor);
                token = tokenHandler.WriteToken(securityToken);

                _logger.LogInformation("token writed... returning");
            }
            else
                _logger.LogInformation("Wrong user or password requested");

            return token;
        }

        public IdentityResult RegisterUser(string userName, string password, RoleType role, string userIdRegisteredBy)
        {
            _logger.LogInformation("Registering user...");

            IdentityResult result = null;

            var registerInfo = new ApplicationUser()
            {
                UserName = userName,
                Email = "nothing@nothing.com"
            };

            result = _userManager.CreateAsync(registerInfo, password).Result;

            IdentityResult roleResult = _userManager.AddToRoleAsync(registerInfo, role.ToString()).Result;

            if (!roleResult.Succeeded)
                _logger.LogError("Error adding role to new user {0}. Errors: {1}", userName, string.Join(", ", roleResult.Errors.Select(x => x.Code)));

            _userActionLogFacade.AddNewActionLog(ActionType.AddUser, string.Format("User {0} registered", userName), userIdRegisteredBy, roleResult.Succeeded);


            return result;
        }
    }
}
