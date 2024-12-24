using Microsoft.AspNetCore.Mvc;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.Helpers;

namespace TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces
{
    public interface ITerritoryFacade
    {
        void AddTerritory(string code, string name, string mapUrl, string createdById);
        void EditTerritory(int id, string code, string name, string mapUrl, string editedById);

        TerritoryDetailInfo? GetTerritoryDetailInfo(int id, IWebApiUrlHelper urlHelper);

        void RefreshImageTerritory(int id, string refreshedById);
    }
}
