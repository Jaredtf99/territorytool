using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace TerritoryTool.ServerSide.Domain.Classes
{
    public class TerritorySuggestionInfo
    {
        public int Id { get; set; }
        public string Code { get; set; }
        public string Name { get; set; }
        public string MapUrl { get; set; }
        public string? ImgUrl { get; set; }
        public DateTime? LastPickedDate { get; set; }
    }
}
