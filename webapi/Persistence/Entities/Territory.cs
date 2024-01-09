using System;
using System.Collections.Generic;

namespace TerritoryTool.ServerSide.Persistence.Entities
{
    public partial class Territory : Entity
    {
        public Territory()
        {
            Transactions = new HashSet<Transaction>();
        }

        public string Code { get; set; }
        public string Name { get; set; }
        public string MapUrl { get; set; }
        public string? ImgUrl { get; set; }
        public int? PersonId { get; set; }

        public Person? Person { get; set; }
        public ICollection<Transaction> Transactions { get; set; }
    }
}
