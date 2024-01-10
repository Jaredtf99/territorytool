using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Xml.Linq;
using TerritoryTool.ServerSide.Controllers.Models.Person;
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

        public IEnumerable<Territory> GetAllTerritories(string? term, bool? inUse, FilterTerritoriesOrderByEnum? orderBy, bool orderAscending)
        {
            var query = _context.Territory.AsQueryable();

            if (term != null)
            {
                term = term.ToLower();
                query = query.Where(x => x.Name.ToLower().Contains(term) || term.Contains(x.Name.ToLower()) || x.Code.ToLower().Contains(term));
            }

            if (inUse != null)
            {
                if (inUse.Value)
                    query = query.Where(x => x.PersonId != null);
                else
                    query = query.Where(x => x.PersonId == null);
            }

            if (orderBy != null)
            {
                switch (orderBy)
                {
                    case FilterTerritoriesOrderByEnum.Name:
                        query = orderAscending ? query.OrderBy(x => x.Name) : query.OrderByDescending(x => x.Name);
                        break;
                    case FilterTerritoriesOrderByEnum.Code:
                        query = orderAscending ? query.OrderBy(x => x.Code) : query.OrderByDescending(x => x.Code);
                        break;
                    case FilterTerritoriesOrderByEnum.GivenDate:
                        query = orderAscending ? query.OrderBy(t => t.Transactions.Max(tr => (DateTime?)tr.GivenDateUtc) ?? DateTime.MinValue) : query.OrderByDescending(t => t.Transactions.Max(tr => (DateTime?)tr.GivenDateUtc) ?? DateTime.MinValue);
                        break;
                    default:
                        _logger.LogError("FilterTerritoriesOrderByEnum type not supported for filter territories");
                        break;
                }
            }

            return query.Include(x => x.Person).Include(x => x.Transactions.Where(t => t.PickedDateUtc == null)).ToList();
        }

        public IEnumerable<Transaction> GetAllTransactionsForReport(DateTime start, DateTime end)
        {
            return _context.Transaction.Where(tr => tr.GivenDateUtc >= start && end >= tr.GivenDateUtc).Include(tr => tr.Territory).Include(tr => tr.Person).ToList();
        }



        public IEnumerable<Territory> SearchTerritories(string search, bool onlyFreeTerritories, bool onlyGivenTerritories)
        {
            search = search.ToLower();
            //TODO: hacer una busqueda por proximidad, en vez de un contains
            return _context.Territory.Where(x => (x.Name.ToLower().Contains(search) || search.Contains(x.Name.ToLower()) || x.Code.ToLower().Contains(search)) &&
                                                 (onlyFreeTerritories ? x.PersonId == null : true) &&
                                                 (onlyGivenTerritories ? x.PersonId != null : true));
        }


        public Territory? GetTerritoryById(int id)
        {
            return _context.Territory.Find(id);
        }

        public Territory? GetTerritoryByName(string name)
        {
            return _context.Territory.Where(x => x.Name.ToLower() == name.ToLower()).FirstOrDefault();
        }

        public Territory AddNewTerritory(string code, string name, string mapUrl)
        {
            Territory newTerritory = new Territory
            {
                Code = code,
                Name = name,
                MapUrl = mapUrl
            };

            var territory = _context.Territory.Add(newTerritory);
            _context.SaveChanges();


            return territory.Entity;
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

            var transactionTracking = _context.Transaction.Add(giveTransaction);

            transactionTracking.Entity.Territory.PersonId = giveTransaction.PersonId;

            _context.SaveChanges();

        }

        public void PickTerritory(int territoryId, string pickedBy, bool isAutomaticPickedDate, DateTime pickedDateUtc)
        {
            Transaction transactionToPick = _context.Transaction.Single(x => x.TerritoryId == territoryId && x.PickedBy == null);

            transactionToPick.PickedBy = pickedBy;
            transactionToPick.IsAutomaticPickedDate = isAutomaticPickedDate;
            transactionToPick.PickedDateUtc = pickedDateUtc;

            var transactionTracking = _context.Transaction.Update(transactionToPick);

            transactionTracking.Entity.Territory.PersonId = null;

            _context.SaveChanges();

        }


    }
}
