using TerritoryTool.ServerSide.Domain.Enums;

namespace TerritoryTool.ServerSide.Controllers.Models.User
{
    public class RegisterModel
    {
        public string UserName { get; set; }
        public string Password { get; set; }
        public RoleType Role { get; set; }
    }
}
