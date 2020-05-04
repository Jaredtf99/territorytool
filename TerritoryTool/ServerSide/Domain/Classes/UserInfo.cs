using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Domain.Enums;

namespace TerritoryTool.ServerSide.Domain.Classes
{
    public class UserInfo
    {
        public string UserID { get; set; }
        public string UserName { get; set; }

        [JsonConverter(typeof(StringEnumConverter))]
        public RoleType Role { get; set; }
    }
}
