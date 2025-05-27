using System;
using System.Collections.Generic;

namespace TerritoryTool.ServerSide.Persistence.Entities
{
    public partial class Person : Entity
    {
        public Person()
        {
            TerritoriesInUse = new HashSet<Territory>();
            Transactions = new HashSet<Transaction>();
        }

        public string Name { get; set; }
        public bool Enabled { get; set; } = true;

        public ICollection<Territory> TerritoriesInUse { get; set; }
        public ICollection<Transaction> Transactions { get; set; }
    }
}
