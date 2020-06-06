using System;
using System.Collections.Generic;

namespace TerritoryTool.ServerSide.Persistence.Entities
{
    public partial class Transaction : Entity
    {
        public int TerritoryId { get; set; }
        public int PersonId { get; set; }
        public string GivenDateUtc { get; set; }
        public string IsAutomaticGivenDate { get; set; }
        public string GivenBy { get; set; }
        public string PickedDateUtc { get; set; }
        public string IsAutomaticPickedDate { get; set; }
        public string PickedBy { get; set; }

        public AspNetUsers GivenByNavigation { get; set; }
        public Person Person { get; set; }
        public AspNetUsers PickedByNavigation { get; set; }
        public Territory Territory { get; set; }
    }
}
