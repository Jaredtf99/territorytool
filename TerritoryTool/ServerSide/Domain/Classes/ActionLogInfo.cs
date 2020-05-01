using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Domain.Enums;

namespace TerritoryTool.ServerSide.Domain.Classes
{
    public class ActionLogInfo
    {
        [JsonConverter(typeof(StringEnumConverter))]
        public ActionType ActionType { get; set; }
        public DateTime DateUtc { get; set; }
        public string Message { get; set; }
        public string UserName { get; set; }
    }
}
