using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Globalization;
using System.Xml.Linq;
using TerritoryTool.ServerSide.Controllers.Models.Person;
using TerritoryTool.ServerSide.Domain.Classes;
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

            if (lastGivenDateFrom != null) 
            {
                query = query.Where(x => x.Transactions.OrderByDescending(t => t.GivenDateUtc).FirstOrDefault()!.GivenDateUtc > lastGivenDateFrom.Value);
            }

            if (lastGivenDateTo != null) 
            {
                query = query.Where(x => lastGivenDateTo.Value > x.Transactions.OrderByDescending(t => t.GivenDateUtc).FirstOrDefault()!.GivenDateUtc);
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

            if (onlyFreeTerritories)
            {
                query = query.Where(x => x.PersonId == null);
            }

            if (onlyGivenTerritories)
            {
                query = query.Where(x => x.PersonId != null);
            }

            if (string.IsNullOrWhiteSpace(search))
            {
                return query.ToList();
            }

            var normalizedSearchTerm = RemoveDiacritics(search.ToLower());
            const int levenshteinThreshold = 2;

            // Bring the initially filtered entities into memory to perform complex string operations
            var territoriesList = query.ToList();

            return territoriesList.Where(t =>
                {
                    var normalizedDbName = RemoveDiacritics(t.Name?.ToLower() ?? string.Empty);
                    var normalizedDbCode = RemoveDiacritics(t.Code?.ToLower() ?? string.Empty);

                    if (!string.IsNullOrEmpty(normalizedDbName) && LevenshteinDistance(normalizedDbName, normalizedSearchTerm) <= levenshteinThreshold)
                    {
                        return true;
                    }

                    if (!string.IsNullOrEmpty(normalizedDbCode) && LevenshteinDistance(normalizedDbCode, normalizedSearchTerm) <= levenshteinThreshold)
                    {
                        return true;
                    }

                    return false;
                })
                .ToList();
        }

        private static string RemoveDiacritics(string text)
        {
            if (string.IsNullOrWhiteSpace(text))
                return string.Empty;

            var normalizedString = text.Normalize(NormalizationForm.FormD);
            var stringBuilder = new StringBuilder();

            foreach (var c in normalizedString)
            {
                var unicodeCategory = CharUnicodeInfo.GetUnicodeCategory(c);
                if (unicodeCategory != UnicodeCategory.NonSpacingMark)
                {
                    stringBuilder.Append(c);
                }
            }

            return stringBuilder.ToString().Normalize(NormalizationForm.FormC);
        }

        private static int LevenshteinDistance(string s, string t)
        {
            if (string.IsNullOrEmpty(s))
            {
                return string.IsNullOrEmpty(t) ? 0 : t.Length;
            }

            if (string.IsNullOrEmpty(t))
            {
                return s.Length;
            }

            int n = s.Length;
            int m = t.Length;
            int[,] d = new int[n + 1, m + 1];

            for (int i = 0; i <= n; d[i, 0] = i++) { }
            for (int j = 0; j <= m; d[0, j] = j++) { }

            for (int i = 1; i <= n; i++)
            {
                for (int j = 1; j <= m; j++)
                {
                    int cost = (t[j - 1] == s[i - 1]) ? 0 : 1;
                    d[i, j] = Math.Min(
                        Math.Min(d[i - 1, j] + 1, d[i, j - 1] + 1),
                        d[i - 1, j - 1] + cost);
                }
            }
            return d[n, m];
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
            // Calcular el ranking directamente en la base de datos
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

            // Obtener estadísticas globales de manera eficiente
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

            // Inicializar medias globales incluso si el territorio no tiene historial
            if (globalStats.Any())
            {
                var globalAssignedPercentages = globalStats
                    .Where(t => t.FirstGivenDate != null)
                    .Select(t =>
                    {
                        var territoryDays = (DateTime.UtcNow - t.FirstGivenDate).TotalDays;
                        var territoryAssignedDays = t.Transactions
                            .Sum(tr => ((tr.PickedDateUtc ?? DateTime.UtcNow) - tr.GivenDateUtc).TotalDays);
                        return (territoryAssignedDays / territoryDays) * 100;
                    });
                stats.GlobalAverageAssignedTimePercentage = globalAssignedPercentages.Average();

                var globalReassignmentPeriods = globalStats
                    .SelectMany(t => t.Transactions
                        .Where((tr, i) => tr.PickedDateUtc.HasValue)
                        .Select((tr, i) => 
                            i < t.Transactions.Count - 1 
                            ? (t.Transactions[i + 1].GivenDateUtc - tr.PickedDateUtc!.Value).TotalDays
                            : (DateTime.UtcNow - tr.PickedDateUtc!.Value).TotalDays
                        ));
                stats.GlobalAverageReassignmentTime = globalReassignmentPeriods.Any() ? globalReassignmentPeriods.Average() : 0;

                var globalHoldingPeriods = globalStats
                    .SelectMany(t => t.Transactions
                        .Where(tr => tr.PickedDateUtc.HasValue)
                        .Select(tr => (tr.PickedDateUtc!.Value - tr.GivenDateUtc).TotalDays));
                stats.GlobalAverageHoldingTime = globalHoldingPeriods.Any() ? globalHoldingPeriods.Average() : 0;

                var globalUniqueUsers = globalStats
                    .Select(t => t.Transactions
                        .Select(tr => tr.PersonId)
                        .Distinct()
                        .Count());
                stats.GlobalAverageUniqueUsersCount = globalUniqueUsers.Average();
            }

            // Calcular tiempos promedio
            var histories = await _context.Transaction
                .Where(tr => tr.TerritoryId == territoryId)
                .OrderBy(tr => tr.GivenDateUtc)
                .Select(tr => new { tr.GivenDateUtc, tr.PickedDateUtc, tr.PersonId })
                .ToListAsync();

            if (histories.Any())
            {
                var firstTransaction = histories.First();
                var totalDays = (DateTime.UtcNow - firstTransaction.GivenDateUtc).TotalDays;

                // Calcular porcentaje de tiempo asignado del territorio actual
                var assignedDays = histories.Sum(h => 
                    ((h.PickedDateUtc ?? DateTime.UtcNow) - h.GivenDateUtc).TotalDays);
                stats.AssignedTimePercentage = (assignedDays / totalDays) * 100;

                // Calcular tiempo promedio de reasignación del territorio actual
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
                        else if (current.PersonId == null)
                        {
                            reassignmentTime = (DateTime.UtcNow - current.PickedDateUtc.Value).TotalDays;
                        }
                        else continue;

                        reassignmentPeriods.Add(reassignmentTime);
                    }
                }
                stats.AverageReassignmentTime = reassignmentPeriods.Any() ? reassignmentPeriods.Average() : 0;

                // Calcular tiempo promedio de uso por persona del territorio actual
                var holdingPeriods = histories
                    .Where(h => h.PickedDateUtc.HasValue)
                    .Select(h => (h.PickedDateUtc!.Value - h.GivenDateUtc).TotalDays);
                stats.AverageHoldingTime = holdingPeriods.Any() ? holdingPeriods.Average() : 0;

                // Calcular tiempo actual sin asignar
                var lastTransaction = histories.LastOrDefault();
                if (lastTransaction?.PersonId == null)
                {
                    var lastPickup = histories.LastOrDefault(h => h.PickedDateUtc.HasValue)?.PickedDateUtc;
                    if (lastPickup.HasValue)
                        stats.CurrentUnassignedTime = (DateTime.UtcNow - lastPickup.Value).TotalDays;
                }

                // Calcular tasa de rotación (usuarios únicos)
                stats.UniqueUsersCount = histories
                    .Select(h => h.PersonId)
                    .Distinct()
                    .Count();
            }

            // Calcular estadísticas de uso
            stats.UsageRank = currentTerritoryRank?.Rank ?? totalTerritories;
            stats.IsHighUsage = stats.UsageRank <= (totalTerritories * 0.25);
            stats.IsLowUsage = stats.UsageRank > (totalTerritories * 0.75);

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
                        .Select(tr => tr.PickedDateUtc)
                        .FirstOrDefault(),
                    GivenDate = t.Transactions
                        .Where(tr => tr.PickedDateUtc == null)
                        .OrderByDescending(tr => tr.GivenDateUtc)
                        .Select(tr => tr.GivenDateUtc)
                        .FirstOrDefault()
                })
                .OrderBy(t => t.LastPickedDate)
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
