using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace TerritoryTool.ServerSide.Domain.Classes
{
    public class PersonInfo
    {
        public string Name { get; set; }
        public int Id { get; set; }
        public List<PersonInfoTransaction> TerritoriesInUse { get; set; }
    }
}
