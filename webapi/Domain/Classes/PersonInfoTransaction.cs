using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace TerritoryTool.ServerSide.Domain.Classes
{
    public class PersonInfoTransaction
    {
        public string TerritoryName { get; set; }
        public string TerritoryCode { get; set; }
        public DateTime GivenDate { get; set; }
    }
}
