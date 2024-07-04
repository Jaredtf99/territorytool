using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Persistence;

namespace TerritoryTool.ServerSide.Domain.Helpers
{
    public interface IWebApiUrlHelper
    {
        string GetCurrentUrl();

    }
}
