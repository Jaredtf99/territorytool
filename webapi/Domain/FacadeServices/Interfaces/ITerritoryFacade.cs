using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;

namespace TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces
{
    public interface ITerritoryFacade
    {
        void AddTerritory(string code, string name, string mapUrl, string createdById);
        void EditTerritory(int id, string code, string name, string mapUrl, string editedById);

    }
}
