using System.ComponentModel.DataAnnotations;

namespace TerritoryTool.ServerSide.Controllers.Models.User
{
    public class ChangeUserPasswordModel
    {
        [Required]
        public string NewPassword { get; set; }
    }
}
