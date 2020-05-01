using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Persistence;

namespace TerritoryTool.ServerSide.Domain.Helpers
{
    public static class SecurityHelper
    {
        public static string GetLoggedUserName(ClaimsPrincipal user)
        {
            return user.Claims.FirstOrDefault(x => x.Type == ConfigurationHelper.UserNameClaimKey)?.Value;
        }

        public static string GetLoggedUserId(ClaimsPrincipal user)
        {
            return user.Claims.FirstOrDefault(x => x.Type == ConfigurationHelper.UserIDClaimKey)?.Value;
        }

    }
}
