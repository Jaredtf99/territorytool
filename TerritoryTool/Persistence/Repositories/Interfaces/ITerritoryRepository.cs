using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.Persistence.Entities;

namespace TerritoryTool.Persistence.Repositories.Interfaces
{
    public interface ITerritoryRepository
    {
        Territory GetTerritoryByName(string name);
        Territory GetTerritoryByCode(string code);
        Territory GetTerritoryByMapUrl(string mapUrl);
        IEnumerable<Territory> GetAllTerritories();

        void AddNewTerritory(string code, string name, string mapUrl);
    }
}
