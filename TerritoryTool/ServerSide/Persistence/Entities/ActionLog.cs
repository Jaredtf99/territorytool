using System;
using System.Collections.Generic;

namespace TerritoryTool.ServerSide.Persistence.Entities
{
    public partial class ActionLog : Entity
    {
        public string UserId { get; set; }
        public DateTime DateTimeUtc { get; set; }
        public string Message { get; set; }
        public int ActionType { get; set; }
        public bool Successful { get; set; }

        public AspNetUsers User { get; set; }
    }
}
