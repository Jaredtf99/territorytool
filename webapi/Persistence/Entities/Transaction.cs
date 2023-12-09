using System;
using System.Collections.Generic;

namespace TerritoryTool.ServerSide.Persistence.Entities
{
    public partial class Transaction : Entity
    {
        public int TerritoryId { get; set; }
        public int PersonId { get; set; }
        public DateTime GivenDateUtc { get; set; }
        public bool IsAutomaticGivenDate { get; set; }
        public string GivenBy { get; set; }
        public DateTime? PickedDateUtc { get; set; }
        public bool? IsAutomaticPickedDate { get; set; }
        public string? PickedBy { get; set; }

        public AspNetUsers GivenByNavigation { get; set; }
        public Person Person { get; set; }
        public AspNetUsers? PickedByNavigation { get; set; }
        public Territory Territory { get; set; }
    }
}
