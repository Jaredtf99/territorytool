using System;

namespace TerritoryTool.ServerSide.Controllers.Models.Transactions
{
    public class TransactionData
    {
        public int PersonId { get; set; }
        public DateTime GivenDateUtc { get; set; }
        public DateTime? PickedDateUtc { get; set; }
    }
}
