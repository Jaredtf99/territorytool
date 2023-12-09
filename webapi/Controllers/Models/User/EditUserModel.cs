using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Domain.Enums;

namespace TerritoryTool.ServerSide.Controllers.Models.User
{
    public class EditUserModel
    {
        public string UserName { get; set; }
        public RoleType Role { get; set; }
    }
}
