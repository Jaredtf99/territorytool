using System.Collections.Generic;
using TerritoryTool.ServerSide.Persistence.Entities;

namespace TerritoryTool.ServerSide.Persistence.Repositories.Interfaces
{
    public interface ITerritoryRepository
    {
        Territory GetTerritoryById(int id);
        Territory GetTerritoryByName(string name);
        Territory GetTerritoryByCode(string code);
        Territory GetTerritoryByMapUrl(string mapUrl);
        IEnumerable<Territory> GetAllTerritories();

        void AddNewTerritory(string code, string name, string mapUrl);

        void EditTerritory(int idToEdit, string code, string name, string mapUrl);

        void DeleteTerritory(int id);
    }
}
