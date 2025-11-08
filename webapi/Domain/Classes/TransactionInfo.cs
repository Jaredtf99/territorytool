using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace TerritoryTool.ServerSide.Domain.Classes
{
    public class TransactionInfo
    {
        public int TransactionId { get; set; }
        public int PersonId { get; set; }
        public DateTime GivenDateUtc { get; set; }
        public DateTime? PickedDateUtc { get; set; }
        public string GivenBy { get; set; }
        public string? PickedBy { get; set; }
        public int TerritoryId { get; set; }
        public string TerritoryName { get; set; }
        public string PersonName { get; set; }

    }
}
