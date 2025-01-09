using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace TerritoryTool.ServerSide.Domain.Classes
{
    public class TerritoryInfoTimeline
    {
        public int Id { get; set; }
        public string Description { get; set; }
        public TerritoryInfoTimelineType Type { get; set; }
        public DateTime Date { get; set; }
    }

    public enum TerritoryInfoTimelineType 
    {
        Picked = 1,
        Gave = 2,
        Edited = 3,
        Added = 4,
    }
}
