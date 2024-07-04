using Microsoft.AspNetCore.Mvc;
using TerritoryTool.ServerSide.Domain.Helpers;

namespace webapi.Controllers.Helpers
{
    public class WebApiUrlHelper : IWebApiUrlHelper
    {
        public static WebApiUrlHelper AsInstance(HttpRequest req) 
        {
            return new WebApiUrlHelper { Scheme = req.Scheme, Host = req.Host.Value, PathBase = req.PathBase };
        }

        private string Scheme { get; set; }
        private string Host { get; set; }
        private string PathBase { get; set; }

        public string GetCurrentUrl()
        {
            return $"{Scheme}://{Host}{PathBase}";
        }
    }
}
