using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System; // For StringComparison, Math.Min if they were used directly, though now in SearchUtils
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Xml.Linq;
using TerritoryTool.ServerSide.Controllers.Models.Person;
using TerritoryTool.ServerSide.Domain.Classes; // Added for SearchResultItem<T>
using TerritoryTool.ServerSide.Domain.Enums;   // Added for SearchMatchType
using TerritoryTool.ServerSide.Domain.Helpers; // For SearchUtils
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

        public IEnumerable<Territory> GetAllTerritories(   
            string? term, 
            bool? inUse, 
            FilterTerritoriesOrderByEnum? orderBy, 
            bool orderAscending, 
            DateTime? lastGivenDateFrom, 
            DateTime? lastGivenDateTo)
        {
            var query = _context.Territory.AsQueryable();

            if (term != null)
            {
                // This basic search is kept for GetAllTerritories, 
                // the advanced search is specific to SearchTerritories method
                string lowerTerm = term.ToLower();
                query = query.Where(x => (x.Name != null && x.Name.ToLower().Contains(lowerTerm)) || 
                                         (x.Code != null && x.Code.ToLower().Contains(lowerTerm)));
            }

            if (inUse != null)
            {
                if (inUse.Value)
                    query = query.Where(x => x.PersonId != null);
                else
                    query = query.Where(x => x.PersonId == null);
            }

            if (lastGivenDateFrom != null) 
            {
                query = query.Where(x => x.Transactions.Any() && x.Transactions.OrderByDescending(t => t.GivenDateUtc).First().GivenDateUtc > lastGivenDateFrom.Value);
            }

            if (lastGivenDateTo != null) 
            {
                query = query.Where(x => x.Transactions.Any() && lastGivenDateTo.Value > x.Transactions.OrderByDescending(t => t.GivenDateUtc).First().GivenDateUtc);
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
            return _context.Transaction.Where(tr => (tr.GivenDateUtc >= start && end >= tr.GivenDateUtc) || (tr.PickedDateUtc >= start && end >= tr.PickedDateUtc)).Include(tr => tr.Territory).Include(tr => tr.Person).ToList();
        }


        public IEnumerable<Transaction> GetTerritoryTransactions(int territoryId)
        {
            return _context.Transaction
                .Where(tr => tr.TerritoryId == territoryId)
                .Select(tr => new Transaction
                {
                    Id = tr.Id,
                    TerritoryId = tr.TerritoryId,
                    PersonId = tr.PersonId,
                    GivenBy = tr.GivenBy,
                    GivenDateUtc = tr.GivenDateUtc,
                    PickedBy = tr.PickedBy,
                    PickedDateUtc = tr.PickedDateUtc,
                    IsAutomaticGivenDate = tr.IsAutomaticGivenDate,
                    IsAutomaticPickedDate = tr.IsAutomaticPickedDate,
                    Territory = new Territory 
                    { 
                        Id = tr.Territory.Id,
                        Name = tr.Territory.Name 
                    },
                    Person = new Person 
                    { 
                        Id = tr.Person.Id,
                        Name = tr.Person.Name 
                    },
                    GivenByNavigation = new AspNetUsers 
                    { 
                        Id = tr.GivenByNavigation.Id,
                        UserName = tr.GivenByNavigation.UserName 
                    },
                    PickedByNavigation = tr.PickedBy != null ? new AspNetUsers 
                    { 
                        Id = tr.PickedByNavigation.Id,
                        UserName = tr.PickedByNavigation.UserName 
                    } : null
                })
                .ToList();
        }


        public IEnumerable<Territory> SearchTerritories(string search, bool onlyFreeTerritories, bool onlyGivenTerritories)
        {
            IQueryable<Territory> query = _context.Territory;

            // Apply initial filters
            if (onlyFreeTerritories)
            {
                query = query.Where(x => x.PersonId == null);
            }
            if (onlyGivenTerritories) // Note: if both are true, this will result in an empty set if they are mutually exclusive
            {
                query = query.Where(x => x.PersonId != null);
            }
            
            if (string.IsNullOrWhiteSpace(search))
            {
                return query.ToList(); 
            }

            var candidateTerritories = query.ToList(); // Fetch candidates after initial DB filtering
            var rankedResults = new List<SearchResultItem<Territory>>();

            foreach (var territory in candidateTerritories)
            {
                SearchUtils.MatchResult nameMatchResult = SearchUtils.CalculateMatchResult(search, territory.Name);
                SearchUtils.MatchResult codeMatchResult = SearchUtils.CalculateMatchResult(search, territory.Code);

                SearchUtils.MatchResult finalMatchResult;

                if (nameMatchResult.MatchType != SearchMatchType.None && codeMatchResult.MatchType != SearchMatchType.None)
                {
                    // Both Name and Code matched, determine which is better
                    if (nameMatchResult.MatchType < codeMatchResult.MatchType) // Lower enum value means higher priority
                    {
                        finalMatchResult = nameMatchResult;
                    }
                    else if (codeMatchResult.MatchType < nameMatchResult.MatchType)
                    {
                        finalMatchResult = codeMatchResult;
                    }
                    else // MatchTypes are the same, compare scores
                    {
                        finalMatchResult = nameMatchResult.Score >= codeMatchResult.Score ? nameMatchResult : codeMatchResult;
                    }
                }
                else if (nameMatchResult.MatchType != SearchMatchType.None)
                {
                    finalMatchResult = nameMatchResult;
                }
                else if (codeMatchResult.MatchType != SearchMatchType.None)
                {
                    finalMatchResult = codeMatchResult;
                }
                else
                {
                    finalMatchResult = new SearchUtils.MatchResult(SearchMatchType.None, 0); // No match
                }
                
                if (finalMatchResult.MatchType != SearchMatchType.None)
                {
                    rankedResults.Add(new SearchResultItem<Territory>(territory, finalMatchResult.Score, finalMatchResult.MatchType));
                }
            }
            
            return rankedResults
                .OrderBy(r => r.MatchType)      // Lower enum value (higher priority) first
                .ThenByDescending(r => r.Score) // Higher score first
                .ThenBy(r => r.Item.Name)       // Alphabetical by Name for tie-breaking
                .Select(r => r.Item)
                .ToList();
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
            var territory = await _context.Territory
                .AsNoTracking()
                .Where(t => t.Id == territoryId)
                .Select(t => new { t.Id, t.PersonId })
                .FirstOrDefaultAsync();

            if (territory == null)
                throw new KeyNotFoundException();

            var now = DateTime.UtcNow;

            var territoryUsages = await _context.Territory
                .Select(t => new { t.Id, Count = t.Transactions.Count })
                .OrderByDescending(t => t.Count)
                .ThenBy(t => t.Id)
                .ToListAsync();

            var currentTerritoryRank = territoryUsages
                .Select((t, index) => new { t.Id, Rank = index + 1 })
                .FirstOrDefault(t => t.Id == territoryId);

            var totalTerritories = await _context.Territory.CountAsync();
            var territoryIds = await _context.Territory
                .Select(t => t.Id)
                .ToListAsync();

            var stats = new TerritoryStatistics
            {
                TotalTerritories = totalTerritories
            };

            var allHistories = await _context.Transaction
                .OrderBy(tr => tr.GivenDateUtc)
                .ThenBy(tr => tr.Id)
                .Select(tr => new TerritoryStatisticsTransaction
                {
                    Id = tr.Id,
                    TerritoryId = tr.TerritoryId,
                    GivenDateUtc = tr.GivenDateUtc,
                    PickedDateUtc = tr.PickedDateUtc,
                    PersonId = tr.PersonId
                })
                .ToListAsync();

            var historiesByTerritory = allHistories
                .GroupBy(h => h.TerritoryId)
                .ToDictionary(g => g.Key, g => g.OrderBy(h => h.GivenDateUtc).ThenBy(h => h.Id).ToList());

            var globalStats = territoryIds
                .Select(id => CalculateTerritoryStatistics(
                    historiesByTerritory.TryGetValue(id, out var territoryHistories)
                        ? territoryHistories
                        : Enumerable.Empty<TerritoryStatisticsTransaction>(),
                    now,
                    isCurrentlyAssigned: false))
                .ToList();

            if (globalStats.Any())
            {
                var globalAssignedPercentages = globalStats
                    .Select(t => t.AssignedTimePercentage);
                if (globalAssignedPercentages.Any()) stats.GlobalAverageAssignedTimePercentage = globalAssignedPercentages.Average();

                var globalReassignmentPeriods = globalStats
                    .Select(t => t.AverageReassignmentTime);
                if (globalReassignmentPeriods.Any()) stats.GlobalAverageReassignmentTime = globalReassignmentPeriods.Average();

                var globalHoldingPeriods = globalStats
                    .Select(t => t.AverageHoldingTime);
                if (globalHoldingPeriods.Any()) stats.GlobalAverageHoldingTime = globalHoldingPeriods.Average();

                var globalUniqueUsers = globalStats
                    .Select(t => t.UniqueUsersCount);
                if (globalUniqueUsers.Any()) stats.GlobalAverageUniqueUsersCount = globalUniqueUsers.Average();
            }

            var histories = allHistories
                .Where(tr => tr.TerritoryId == territoryId)
                .OrderBy(tr => tr.GivenDateUtc)
                .ThenBy(tr => tr.Id)
                .ToList();

            if (histories.Any())
            {
                var territoryStats = CalculateTerritoryStatistics(histories, now, territory.PersonId != null);
                stats.AssignedTimePercentage = territoryStats.AssignedTimePercentage;
                stats.AverageReassignmentTime = territoryStats.AverageReassignmentTime;
                stats.AverageHoldingTime = territoryStats.AverageHoldingTime;
                stats.CurrentUnassignedTime = territoryStats.CurrentUnassignedTime;
                stats.UniqueUsersCount = territoryStats.UniqueUsersCount;
            }

            stats.UsageRank = currentTerritoryRank?.Rank ?? totalTerritories;
            if (totalTerritories > 0) // Avoid division by zero if there are no territories
            {
                stats.IsHighUsage = stats.UsageRank <= Math.Max(1, Math.Ceiling(totalTerritories * 0.25));
                stats.IsLowUsage = stats.UsageRank > Math.Ceiling(totalTerritories * 0.75);
            } else {
                stats.IsHighUsage = false;
                stats.IsLowUsage = false;
            }

            return stats;
        }

        private sealed class TerritoryStatisticsTransaction
        {
            public int Id { get; set; }
            public int TerritoryId { get; set; }
            public DateTime GivenDateUtc { get; set; }
            public DateTime? PickedDateUtc { get; set; }
            public int PersonId { get; set; }
        }

        private static TerritoryStatistics CalculateTerritoryStatistics(
            IEnumerable<TerritoryStatisticsTransaction> rawHistories,
            DateTime now,
            bool isCurrentlyAssigned)
        {
            var histories = rawHistories
                .OrderBy(h => h.GivenDateUtc)
                .ThenBy(h => h.Id)
                .ToList();

            var stats = new TerritoryStatistics();

            if (!histories.Any())
                return stats;

            var firstGivenDate = histories.First().GivenDateUtc;
            var totalDays = Math.Max((now - firstGivenDate).TotalDays, 0);
            if (totalDays > 0)
            {
                var assignedDays = histories.Sum(h =>
                    Math.Max(((h.PickedDateUtc ?? now) - h.GivenDateUtc).TotalDays, 0));
                stats.AssignedTimePercentage = (assignedDays / totalDays) * 100;
            }

            var reassignmentPeriods = new List<double>();
            for (int i = 0; i < histories.Count - 1; i++)
            {
                var current = histories[i];
                var next = histories[i + 1];

                if (current.PickedDateUtc.HasValue)
                    reassignmentPeriods.Add(Math.Max((next.GivenDateUtc - current.PickedDateUtc.Value).TotalDays, 0));
            }

            if (reassignmentPeriods.Any())
                stats.AverageReassignmentTime = reassignmentPeriods.Average();

            var holdingPeriods = histories
                .Where(h => h.PickedDateUtc.HasValue)
                .Select(h => Math.Max((h.PickedDateUtc!.Value - h.GivenDateUtc).TotalDays, 0));
            if (holdingPeriods.Any())
                stats.AverageHoldingTime = holdingPeriods.Average();

            var lastPickedDate = histories
                .Where(h => h.PickedDateUtc.HasValue)
                .Select(h => h.PickedDateUtc!.Value)
                .DefaultIfEmpty()
                .Max();
            if (!isCurrentlyAssigned && lastPickedDate != default)
                stats.CurrentUnassignedTime = Math.Max((now - lastPickedDate).TotalDays, 0);

            stats.UniqueUsersCount = histories
                .Select(h => h.PersonId)
                .Distinct()
                .Count();

            return stats;
        }

        public async Task<IEnumerable<TerritorySuggestionInfo>> GetTerritoriesSuggestions(int count, string requestScheme, string requestHost, string requestPathBase)
        {
            var territories = await _context.Territory
                .Where(t => t.PersonId == null)
                .Select(t => new
                {
                    Territory = t,
                    LastPickedDate = t.Transactions
                        .Where(tr => tr.PickedDateUtc != null)
                        .OrderByDescending(tr => tr.PickedDateUtc)
                        .Select(tr => (DateTime?)tr.PickedDateUtc) // Cast to nullable DateTime
                        .FirstOrDefault(),
                    GivenDate = t.Transactions
                        .Where(tr => tr.PickedDateUtc == null)
                        .OrderByDescending(tr => tr.GivenDateUtc)
                        .Select(tr => (DateTime?)tr.GivenDateUtc) // Cast to nullable DateTime
                        .FirstOrDefault()
                })
                .OrderBy(t => t.LastPickedDate) // Nulls will typically be first or last depending on DB, handle if needed
                .ThenBy(t => t.Territory.Transactions.Count)
                .Take(count)
                .ToListAsync();

            return territories.Select(x => new TerritorySuggestionInfo {
                Code = x.Territory.Code,
                Id = x.Territory.Id,
                LastPickedDate = x.LastPickedDate,
                GivenDate = x.GivenDate,
                MapUrl = x.Territory.MapUrl,
                Name = x.Territory.Name,
                ImgUrl = x.Territory.ImgUrl == null ? null : $"{requestScheme}://{requestHost}{requestPathBase}/{x.Territory.ImgUrl}"

            });
        }
    }
}
