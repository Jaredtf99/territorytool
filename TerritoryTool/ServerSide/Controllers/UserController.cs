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
using TerritoryTool.ServerSide.Controllers.Models;
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


        public UserController(UserManager<ApplicationUser> userManager, SignInManager<ApplicationUser> signInManager, IOptions<ApplicationSettings> appSettings, ILogger<SampleDataController> logger, IUserActionLogFacade userActionLogFacade)
        {
            _userManager = userManager;
            _appSettings = appSettings.Value;
            _logger = logger;
            _userActionLogFacade = userActionLogFacade;
        }

        [HttpPost]
        [Route("register")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult RegisterUser(RegisterModel model)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);

            var registerInfo = new ApplicationUser()
            {
                UserName = model.UserName,
                Email = "nothing@nothing.com"
            };
            try
            {
                var result = _userManager.CreateAsync(registerInfo, model.Password);
                result.Wait();

                var taskAddRole = _userManager.AddToRoleAsync(registerInfo, RoleType.User.ToString());
                taskAddRole.Wait();

                _userActionLogFacade.AddNewActionLog(ActionType.AddUser, string.Format("User {0} registered", model.UserName), userId);


                return Ok(result.Result);
            }
            catch (Exception)
            {

                throw;
            }
        }


        [HttpPost]
        [Route("login")]
        public async Task<IActionResult> Login(LoginModel model)
        {
            _logger.LogInformation("Login user");

            var user = await _userManager.FindByNameAsync(model.UserName);

            _logger.LogInformation("final user checked");


            if (user != null && await _userManager.CheckPasswordAsync(user, model.Password))
            {
                _logger.LogInformation("Password correct");
                var role = await _userManager.GetRolesAsync(user);
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
                var token = tokenHandler.WriteToken(securityToken);

                _logger.LogInformation("token writed... returning");

                return Ok(new { token });
            }
            else
            {
                _logger.LogInformation("Wrong user or password");
                return BadRequest(new { message = "Usuario o contraseña incorrecta" });
            }
        }
    
    }
}