using System.ComponentModel.DataAnnotations;

namespace TerritoryTool.ServerSide.Controllers.Models.Person
{
    public class UpdatePersonModel
    {
        [Required]
        public string Name { get; set; }

        [Required]
        public bool Enabled { get; set; }
    }
}
