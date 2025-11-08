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
            var territoryUsages = await _context.Territory
                .Select(t => new { t.Id, Count = t.Transactions.Count })
                .OrderByDescending(t => t.Count)
                .ToListAsync();

            var currentTerritoryRank = territoryUsages
                .Select((t, index) => new { t.Id, Rank = index + 1 })
                .FirstOrDefault(t => t.Id == territoryId);

            var totalTerritories = await _context.Territory.CountAsync();

            var stats = new TerritoryStatistics
            {
                TotalTerritories = totalTerritories
            };

            var globalStats = await _context.Territory
                .Where(t => t.Transactions.Any())
                .Select(t => new
                {
                    FirstGivenDate = t.Transactions.Min(tr => tr.GivenDateUtc),
                    Transactions = t.Transactions
                        .Select(tr => new { 
                            tr.GivenDateUtc, 
                            tr.PickedDateUtc,
                            tr.PersonId
                        })
                        .ToList()
                })
                .ToListAsync();

            if (globalStats.Any())
            {
                var globalAssignedPercentages = globalStats
                    .Where(t => t.FirstGivenDate != null)
                    .Select(t =>
                    {
                        var territoryDays = (DateTime.UtcNow - t.FirstGivenDate).TotalDays; // Ensure Value is used for Nullable DateTime
                        if (territoryDays == 0) return 0; // Avoid division by zero
                        var territoryAssignedDays = t.Transactions
                            .Sum(tr => ((tr.PickedDateUtc ?? DateTime.UtcNow) - tr.GivenDateUtc).TotalDays);
                        return (territoryAssignedDays / territoryDays) * 100;
                    });
                if (globalAssignedPercentages.Any()) stats.GlobalAverageAssignedTimePercentage = globalAssignedPercentages.Average();


                var globalReassignmentPeriods = globalStats
                    .SelectMany(t => t.Transactions
                        .Select((tr, i) => new { Transaction = tr, Index = i }) // Keep track of index for next transaction
                        .Where(x => x.Transaction.PickedDateUtc.HasValue)
                        .Select(x => 
                            x.Index < t.Transactions.Count - 1 
                            ? (t.Transactions[x.Index + 1].GivenDateUtc - x.Transaction.PickedDateUtc!.Value).TotalDays
                            : (DateTime.UtcNow - x.Transaction.PickedDateUtc!.Value).TotalDays
                        ));
                 if (globalReassignmentPeriods.Any()) stats.GlobalAverageReassignmentTime = globalReassignmentPeriods.Average();


                var globalHoldingPeriods = globalStats
                    .SelectMany(t => t.Transactions
                        .Where(tr => tr.PickedDateUtc.HasValue)
                        .Select(tr => (tr.PickedDateUtc!.Value - tr.GivenDateUtc).TotalDays));
                if (globalHoldingPeriods.Any()) stats.GlobalAverageHoldingTime = globalHoldingPeriods.Average();

                var globalUniqueUsers = globalStats
                    .Select(t => t.Transactions
                        .Select(tr => tr.PersonId)
                        .Distinct()
                        .Count());
                if (globalUniqueUsers.Any()) stats.GlobalAverageUniqueUsersCount = globalUniqueUsers.Average();
            }

            var histories = await _context.Transaction
                .Where(tr => tr.TerritoryId == territoryId)
                .OrderBy(tr => tr.GivenDateUtc)
                .Select(tr => new { tr.GivenDateUtc, tr.PickedDateUtc, tr.PersonId })
                .ToListAsync();

            if (histories.Any())
            {
                var firstTransaction = histories.First();
                var totalDays = (DateTime.UtcNow - firstTransaction.GivenDateUtc).TotalDays;
                if (totalDays > 0) // Avoid division by zero
                {
                    var assignedDays = histories.Sum(h => 
                        ((h.PickedDateUtc ?? DateTime.UtcNow) - h.GivenDateUtc).TotalDays);
                    stats.AssignedTimePercentage = (assignedDays / totalDays) * 100;
                }


                var reassignmentPeriods = new List<double>();
                for (int i = 0; i < histories.Count; i++)
                {
                    var current = histories[i];
                    if (current.PickedDateUtc.HasValue)
                    {
                        double reassignmentTime;
                        if (i < histories.Count - 1)
                        {
                            var next = histories[i + 1];
                            reassignmentTime = (next.GivenDateUtc - current.PickedDateUtc.Value).TotalDays;
                        }
                        else if (current.PersonId == null) // No longer assigned to anyone
                        {
                            reassignmentTime = (DateTime.UtcNow - current.PickedDateUtc.Value).TotalDays;
                        }
                        else continue; // Still assigned or last transaction

                        reassignmentPeriods.Add(reassignmentTime);
                    }
                }
                if (reassignmentPeriods.Any()) stats.AverageReassignmentTime = reassignmentPeriods.Average();


                var holdingPeriods = histories
                    .Where(h => h.PickedDateUtc.HasValue)
                    .Select(h => (h.PickedDateUtc!.Value - h.GivenDateUtc).TotalDays);
                if (holdingPeriods.Any()) stats.AverageHoldingTime = holdingPeriods.Average();

                var lastTransaction = histories.LastOrDefault();
                if (lastTransaction != null && lastTransaction.PersonId == null && lastTransaction.PickedDateUtc.HasValue) // Check if currently unassigned
                {
                     stats.CurrentUnassignedTime = (DateTime.UtcNow - lastTransaction.PickedDateUtc.Value).TotalDays;
                } else if (lastTransaction != null && lastTransaction.PersonId != null && !lastTransaction.PickedDateUtc.HasValue) { // Currently assigned
                    stats.CurrentUnassignedTime = 0; 
                } else if (!histories.Any()) { // Never assigned
                    // This case might need specific handling if totalDays from first transaction is not applicable
                }


                stats.UniqueUsersCount = histories
                    .Select(h => h.PersonId)
                    .Distinct()
                    .Count();
            }

            stats.UsageRank = currentTerritoryRank?.Rank ?? totalTerritories;
            if (totalTerritories > 0) // Avoid division by zero if there are no territories
            {
                stats.IsHighUsage = stats.UsageRank <= (totalTerritories * 0.25);
                stats.IsLowUsage = stats.UsageRank > (totalTerritories * 0.75);
            } else {
                stats.IsHighUsage = false;
                stats.IsLowUsage = false;
            }
            

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
