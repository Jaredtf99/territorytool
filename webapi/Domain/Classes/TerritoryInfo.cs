using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace TerritoryTool.ServerSide.Domain.Classes
{
    public class TerritoryInfo
    {
        public int Id { get; set; }
        public string Code { get; set; }
        public string Name { get; set; }
        public string MapUrl { get; set; }
        public string? ImgUrl { get; set; }
        public string? PersonName { get; set; }
    }
}
