using System;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using TerritoryTool.Controllers.Models;
using TerritoryTool.Domain;
using TerritoryTool.Domain.Enums;
using TerritoryTool.Persistence;

namespace TerritoryTool.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class UserController : ControllerBase
    {
        private readonly ILogger _logger;

        private UserManager<ApplicationUser> _userManager;
        private SignInManager<ApplicationUser> _signInManager;
        private readonly ApplicationSettings _appSettings;

        public UserController(UserManager<ApplicationUser> userManager, SignInManager<ApplicationUser> signInManager, IOptions<ApplicationSettings> appSettings, ILogger<SampleDataController> logger)
        {
            _userManager = userManager;
            _signInManager = signInManager;
            _appSettings = appSettings.Value;
            _logger = logger;
        }

        [HttpPost]
        [Route("register")]
        //TODO: AUTHORIZAR ESTO SOLO A ADMIN!!!
        //ROL POR DEFECTO DEBE SER USER, SALVO QUE EL USUARIO LOGUEADO SEA SUPERADMIN, QUE ENTONCES PODRIA REGISTRAR ADMINS
        public ActionResult RegisterUser(RegisterModel model)
        {
            var registerInfo = new ApplicationUser()
            {
                UserName = model.UserName,
                Email = "nothing@nothing.com"
            };

            try
            {
                var result = _userManager.CreateAsync(registerInfo, model.Password);
                result.Wait();

                var taskAddRole = _userManager.AddToRoleAsync(registerInfo, RoleType.SuperAdmin.ToString()); //BORRAR ESTO!!!! SOLO TESTING
                taskAddRole.Wait();

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
                        new Claim("UserID", user.Id.ToString()),
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