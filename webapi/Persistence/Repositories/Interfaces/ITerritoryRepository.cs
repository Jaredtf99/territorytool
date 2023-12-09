using System.Collections.Generic;
using TerritoryTool.ServerSide.Persistence.Entities;

namespace TerritoryTool.ServerSide.Persistence.Repositories.Interfaces
{
    public interface ITerritoryRepository
    {
        Territory? GetTerritoryById(int id);
        Territory? GetTerritoryByName(string name);
        Territory? GetTerritoryByCode(string code);
        Territory? GetTerritoryByMapUrl(string mapUrl);
        IEnumerable<Territory> GetAllTerritories();
        IEnumerable<Territory> SearchTerritories(string search, bool onlyFreeTerritories);

        void AddNewTerritory(string code, string name, string mapUrl);

        void EditTerritory(Territory territory);

        void DeleteTerritory(Territory territory);

        void GiveTerritory(Transaction giveTransaction);
    }
}
