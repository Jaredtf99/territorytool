using System;
using System.Collections.Generic;

namespace TerritoryTool.ServerSide.Persistence.Entities
{
    public partial class AspNetRoleClaims : Entity
    {
        public string RoleId { get; set; }
        public string ClaimType { get; set; }
        public string ClaimValue { get; set; }

        public AspNetRoles Role { get; set; }
    }
}
