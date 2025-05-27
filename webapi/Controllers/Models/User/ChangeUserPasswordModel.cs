using System.ComponentModel.DataAnnotations;

namespace webapi.Controllers.Models.User
{
    public class ChangeUserPasswordModel
    {
        [Required]
        public string NewPassword { get; set; }
    }
}
