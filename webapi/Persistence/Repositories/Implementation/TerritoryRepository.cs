using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Xml.Linq;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;

namespace TerritoryTool.ServerSide.Persistence.Repositories.Implementation
{
    public class TerritoryRepository : ITerritoryRepository
    {
        private readonly TerritoryToolDbContext _context;
        private readonly ILogger _logger;

        public TerritoryRepository(TerritoryToolDbContext context, ILogger<TerritoryRepository> logger)
        {
            _context = context;
            _logger = logger;
        }

        public IEnumerable<Territory> GetAllTerritories()
        {
            return _context.Territory.ToList();
        }

        public IEnumerable<Territory> SearchTerritories(string search, bool onlyFreeTerritories)
        {
            search = search.ToLower();
            //TODO: hacer una busqueda por proximidad, en vez de un contains
            return _context.Territory.Where(x => (x.Name.ToLower().Contains(search) || search.Contains(x.Name.ToLower()) || x.Code.ToLower().Contains(search)) &&
                                                 (onlyFreeTerritories ? x.Person == null : true));
        }


        public Territory? GetTerritoryById(int id)
        {
            return _context.Territory.Find(id);
        }

        public Territory? GetTerritoryByName(string name)
        {
            return _context.Territory.Where(x => x.Name.ToLower() == name.ToLower()).FirstOrDefault();
        }

        public void AddNewTerritory(string code, string name, string mapUrl)
        {
            Territory newTerritory = new Territory
            {
                Code = code,
                Name = name,
                MapUrl = mapUrl
            };

            _context.Territory.Add(newTerritory);
            _context.SaveChanges();

        }

        public void EditTerritory(Territory territory)
        {
            if (territory.Id != 0)
            {
                _context.Territory.Update(territory);
                _context.SaveChanges();
            }
            else
                _logger.LogError("Error updating territory entity. Entity to update dont have an ID");
        }

        public void DeleteTerritory(Territory territory)
        {
            if (territory.Id != 0)
            {
                _context.Territory.Remove(territory);
                _context.SaveChanges();
            }
            else
                _logger.LogError("Error deleting territory entity. Entity to update dont have an ID");
            
        }

        public Territory? GetTerritoryByCode(string code)
        {
            return _context.Territory.FirstOrDefault(x => x.Code.ToLower() == code.ToLower());
        }

        public Territory? GetTerritoryByMapUrl(string mapUrl)
        {
            return _context.Territory.FirstOrDefault(x => x.MapUrl.ToLower() == mapUrl.ToLower());
        }

        public void GiveTerritory(Transaction giveTransaction)
        {

            var test = _context.Transaction.Add(giveTransaction);

            test.Entity.Territory.IdPerson = giveTransaction.PersonId;

            _context.SaveChanges();

        }

    }
}
