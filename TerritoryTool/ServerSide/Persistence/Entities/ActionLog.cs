using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace TerritoryTool.ServerSide.Persistence.Entities
{
    public class ActionLog : Entity
    {
        public string UserId { get; set; }
        public DateTime DateTimeUTC { get; set; }
        public string Message { get; set; }
        public int ActionType { get; set; }
        public bool Successful { get; set; }
    }
}
