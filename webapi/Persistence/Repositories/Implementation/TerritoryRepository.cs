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

        public Territory? GetTerritoryForDetailById(int id)
        {
            return _context.Territory.Where(x => x.Id == id)
                .Include(x => x.Transactions).ThenInclude(t => t.Person)
                .Include(x => x.Transactions).ThenInclude(t => t.GivenByNavigation)
                .Include(x => x.Transactions).ThenInclude(t => t.PickedByNavigation)
                .FirstOrDefault();
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

        public async Task<TerritoryStatistics> GetTerritoryStatistics(int territoryId)
        {
            // Obtener solo los conteos de transacciones de todos los territorios
            var territoryUsages = await _context.Territory
                .Select(t => t.Transactions.Count)
                .OrderByDescending(count => count)
                .ToListAsync();

            var territory = await _context.Territory
                .Include(t => t.Transactions)
                .FirstOrDefaultAsync(t => t.Id == territoryId);

            if (territory == null)
                throw new KeyNotFoundException("Territory not found");

            var totalTerritories = territoryUsages.Count;
            var stats = new TerritoryStatistics
            {
                TotalTerritories = totalTerritories
            };

            // Calcular estadísticas de uso
            var usageCount = territory.Transactions.Count;

            // Encontrar todos los territorios con más usos que el actual
            var territoriesWithMoreUsage = territoryUsages.Count(x => x > usageCount);
            // El ranking es el número de territorios con más usos + 1
            stats.UsageRank = territoriesWithMoreUsage + 1;

            stats.IsHighUsage = stats.UsageRank <= (totalTerritories * 0.25);
            stats.IsLowUsage = stats.UsageRank > (totalTerritories * 0.75);

            // Calcular tiempos promedio
            var histories = territory.Transactions.OrderBy(h => h.GivenDateUtc).ToList();
            if (histories.Any())
            {
                // Calcular porcentaje de tiempo asignado
                var firstTransaction = histories.First();
                var totalDays = (DateTime.UtcNow - firstTransaction.GivenDateUtc).TotalDays;
                var assignedDays = 0.0;
                
                for (int i = 0; i < histories.Count; i++)
                {
                    var current = histories[i];
                    var startDate = current.GivenDateUtc;
                    var endDate = current.PickedDateUtc ?? DateTime.UtcNow;
                    assignedDays += (endDate - startDate).TotalDays;
                }
                
                stats.AssignedTimePercentage = (assignedDays / totalDays) * 100;

                // Calcular tiempo promedio de reasignación
                var reassignmentPeriods = new List<double>();
                for (int i = 0; i < histories.Count - 1; i++)
                {
                    var current = histories[i];
                    var next = histories[i + 1];

                    if (current.PickedDateUtc.HasValue)
                        reassignmentPeriods.Add((next.GivenDateUtc - current.PickedDateUtc.Value).TotalDays);
                }

                stats.AverageReassignmentTime = reassignmentPeriods.Any() ? reassignmentPeriods.Average() : 0;

                // Calcular tiempo promedio que cada persona mantiene el territorio
                var holdingPeriods = histories
                    .Where(h => h.PickedDateUtc.HasValue)
                    .Select(h => (h.PickedDateUtc!.Value - h.GivenDateUtc).TotalDays);
                stats.AverageHoldingTime = holdingPeriods.Any() ? holdingPeriods.Average() : 0;

                // Calcular tiempo actual sin asignar
                if (territory.PersonId == null)
                {
                    var lastPickup = histories.FirstOrDefault(h => h.PickedDateUtc.HasValue)?.PickedDateUtc;
                    if (lastPickup.HasValue)
                        stats.CurrentUnassignedTime = (DateTime.UtcNow - lastPickup.Value).TotalDays;
                }

                // Calcular frecuencia de uso
                stats.TotalTimesUsed = histories.Count;
                stats.UsageFrequencyDays = totalDays / stats.TotalTimesUsed;

                // Calcular tiempo desde último uso
                var lastUsage = histories.LastOrDefault();
                if (lastUsage != null)
                {
                    var lastDate = lastUsage.PickedDateUtc ?? DateTime.UtcNow;
                    var daysAgo = (DateTime.UtcNow - lastDate).TotalDays;
                    
                    if (daysAgo < 30)
                        stats.LastUsedAgo = $"hace {(int)daysAgo} días";
                    else if (daysAgo < 365)
                        stats.LastUsedAgo = $"hace {(int)(daysAgo / 30)} meses";
                    else
                        stats.LastUsedAgo = $"hace {(int)(daysAgo / 365)} años";
                }

                // Obtener medias globales de todos los territorios
                var globalStats = await _context.Territory
                    .Select(t => new
                    {
                        HoldingTimes = t.Transactions
                            .Where(tr => tr.PickedDateUtc.HasValue)
                            .Select(tr => (tr.PickedDateUtc!.Value - tr.GivenDateUtc).TotalDays),
                        Transactions = t.Transactions
                            .OrderBy(tr => tr.GivenDateUtc)
                            .Select(tr => new { tr.GivenDateUtc, tr.PickedDateUtc })
                    })
                    .ToListAsync();

                var globalAvgHolding = globalStats
                    .SelectMany(s => s.HoldingTimes)
                    .DefaultIfEmpty()
                    .Average();

                // Calcular tiempo promedio de reasignación global
                var globalReassignmentTimes = new List<double>();
                foreach (var territoryStats in globalStats)
                {
                    var transactions = territoryStats.Transactions.ToList();
                    for (int i = 0; i < transactions.Count - 1; i++)
                    {
                        var current = transactions[i];
                        var next = transactions[i + 1];
                        if (current.PickedDateUtc.HasValue)
                        {
                            globalReassignmentTimes.Add(
                                (next.GivenDateUtc - current.PickedDateUtc.Value).TotalDays);
                        }
                    }
                }
                var globalAvgReassignment = globalReassignmentTimes.Any() ? 
                    globalReassignmentTimes.Average() : 0;

                // Calcular comparativas con la media global
                stats.AverageHoldingTimeVsGlobal = ((stats.AverageHoldingTime / globalAvgHolding) - 1) * 100;
                stats.ReassignmentTimeVsGlobal = ((stats.AverageReassignmentTime / globalAvgReassignment) - 1) * 100;
                stats.IsQuicklyReassigned = stats.AverageReassignmentTime < globalAvgReassignment;
                stats.IsLongHeld = stats.AverageHoldingTime > globalAvgHolding;
            }

            return stats;
        }

    }
}
