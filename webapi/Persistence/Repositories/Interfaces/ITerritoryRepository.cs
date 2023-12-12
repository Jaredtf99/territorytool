using System.Collections.Generic;
using TerritoryTool.ServerSide.Controllers.Models.Person;
using TerritoryTool.ServerSide.Persistence.Entities;

namespace TerritoryTool.ServerSide.Persistence.Repositories.Interfaces
{
    public interface ITerritoryRepository
    {
        Territory? GetTerritoryById(int id);
        Territory? GetTerritoryByName(string name);
        Territory? GetTerritoryByCode(string code);
        Territory? GetTerritoryByMapUrl(string mapUrl);
        IEnumerable<Territory> GetAllTerritories(string? term, bool? inUse, FilterTerritoriesOrderByEnum? orderBy, bool orderAscending);
        IEnumerable<Territory> SearchTerritories(string search, bool onlyFreeTerritories, bool onlyGivenTerritories);

        void AddNewTerritory(string code, string name, string mapUrl);

        void EditTerritory(Territory territory);

        void DeleteTerritory(Territory territory);

        void GiveTerritory(Transaction giveTransaction);
        void PickTerritory(int territoryId, string pickedBy, bool isAutomaticPickedDate, DateTime pickedDateUtc);
        IEnumerable<Transaction> GetAllTransactionsForReport(DateTime start, DateTime end);
    }
}
