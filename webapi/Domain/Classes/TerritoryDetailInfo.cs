using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace TerritoryTool.ServerSide.Domain.Classes
{
    public class TerritoryDetailInfo
    {
        public int Id { get; set; }
        public string Code { get; set; }
        public string Name { get; set; }
        public string MapUrl { get; set; }
        public string? ImgUrl { get; set; }
        public string? PersonName { get; set; }
        public DateTime? LastPickedDateUtc { get; set; }
        public DateTime? GivenDateUtc { get; set; }
        public int PickedCount { get; set; }
        public string? LastUser { get; set; }
        public List<TerritoryInfoTimeline> TimelineItems { get; set; }
    }
}
