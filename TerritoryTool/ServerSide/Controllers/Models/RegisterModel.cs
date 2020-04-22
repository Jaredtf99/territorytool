using TerritoryTool.Domain.Enums;

namespace TerritoryTool.Controllers.Models
{
    public class RegisterModel
    {
        public string UserName { get; set; }
        public string Password { get; set; }
        public RoleType Role { get; set; }
    }
}
