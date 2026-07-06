using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Implementation;
using TerritoryTool.ServerSide.Persistence; 
using Xunit;

namespace TerritoryTool.ServerSide.Tests.Persistence.Repositories.Implementation
{
    public class TerritoryRepositoryTests
    {
        private TerritoryToolDbContext GetInMemoryDbContext(List<Territory> initialData = null)
        {
            var options = new DbContextOptionsBuilder<TerritoryToolDbContext>()
                .UseInMemoryDatabase(databaseName: System.Guid.NewGuid().ToString()) 
                .Options;

            var context = new TerritoryToolDbContext(options);

            if (initialData != null)
            {
                context.Territory.AddRange(initialData);
                context.SaveChanges();
            }
            return context;
        }

        private List<Territory> GetDefaultTerritories()
        {
            return new List<Territory>
            {
                new Territory { Id = 1, Name = "Territory Alpha", Code = "TA01", PersonId = 1 }, 
                new Territory { Id = 2, Name = "Território Beta", Code = "TB02", PersonId = null }, 
                new Territory { Id = 3, Name = "Territory Gamma", Code = "TG03", PersonId = 2 }, 
                new Territory { Id = 4, Name = "Territory Delta", Code = "TDÖ4", PersonId = null }, 
                new Territory { Id = 5, Name = "Territory Epsilon", Code = "TE05", PersonId = 3 }, 
                new Territory { Id = 6, Name = "Old Territory", Code = "OT06", PersonId = null }, 
                new Territory { Id = 7, Name = "Zeta Place", Code = "ZP07", PersonId = null }, 
                new Territory { Id = 8, Name = "Central District", Code = "CDIST", PersonId = 4 }, 
                new Territory { Id = 9, Name = "North Sector (Residential)", Code = "NSR09", PersonId = null}, 
                new Territory { Id = 10, Name = "Südlicher Bereich", Code = "SBR10", PersonId = 5}, 
                new Territory { Id = 11, Name = "Alpha Centauri", Code = "AC011", PersonId = null }, 
                new Territory { Id = 12, Name = "Território Gamma Plus", Code = "TGP12", PersonId = 2 }, 
                new Territory { Id = 13, Name = "Sirius Sector", Code = "KÖD321", PersonId = null }, 
                new Territory { Id = 14, Name = "Orion Spur", Code = "OS014", PersonId = 6 }, 
                new Territory { Id = 15, Name = "Nebula Outpost X", Code = "NOX15", PersonId = null }, 
                new Territory { Id = 16, Name = "Kepler Station", Code = "KXXXX016", PersonId = 7 }, 
                new Territory { Id = 17, Name = "Vega Colony", Code = "VC017", PersonId = null }, 
                new Territory { Id = 18, Name = "Polaris Base", Code = "PLBASE1", PersonId = 8 },

                // New for word matching and ordering
                new Territory { Id = 19, Name = "Alpha Station Gamma", Code = "ASG19", PersonId = null },
                new Territory { Id = 20, Name = "Beta Outpost Zeta", Code = "BOZ20", PersonId = 1 },
                new Territory { Id = 21, Name = "Sector 7G", Code = "S7G21", PersonId = null }, // Single letter word "G"
                new Territory { Id = 22, Name = "Main Hub Control", Code = "MHC22", PersonId = 2 },
                new Territory { Id = 23, Name = "Central Gamma Hub", Code = "CGH23", PersonId = null },
                new Territory { Id = 24, Name = "Delta Station Alpha", Code = "DSA24", PersonId = 3 }, // "Station" and "Alpha"
                new Territory { Id = 25, Name = "The Alpha Base", Code = "TAB25", PersonId = null }, 
                new Territory { Id = 26, Name = "Auxiliary Base", Code = "AUXALPHA", PersonId = 4 } 
            };
        }

        [Fact]
        public void SearchTerritories_ExactMatch_Name_IsTopResult()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("Territory Alpha", false, false).ToList();
            Assert.NotEmpty(result);
            Assert.Equal("Territory Alpha", result.First().Name); // ExactContains on Name
        }
        
        [Fact]
        public void SearchTerritories_ExactMatch_Code_IsTopResult()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("TA01", false, false).ToList();
            Assert.NotEmpty(result);
            Assert.Equal("TA01", result.First().Code); // ExactContains on Code
        }


        [Fact]
        public void SearchTerritories_AccentInsensitive_Name_ReturnsMatchingTerritories()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("Territorio Beta", false, false).ToList();
            Assert.Contains(result, t => t.Name == "Território Beta"); // FuzzyFull or PrefixFull
        }

        [Fact]
        public void SearchTerritories_Name_WordMatch_Exact_SecondWord()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // Search "Station" -> "Alpha Station Gamma", "Delta Station Alpha", "Kepler Station"
            // All are ExactContains on a word. Order by name.
            var results = repository.SearchTerritories("Station", false, false).ToList();
            Assert.Contains(results, t => t.Name == "Alpha Station Gamma");
            Assert.Contains(results, t => t.Name == "Delta Station Alpha");
            Assert.Contains(results, t => t.Name == "Kepler Station");
            Assert.Equal(3, results.Count);
            Assert.Equal("Alpha Station Gamma", results[0].Name); // Alpha comes before Delta, Kepler
        }

        [Fact]
        public void SearchTerritories_Name_WordMatch_Prefix_SecondWord()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);
            
            // Search "Gam" -> "Alpha Station Gamma", "Territory Gamma", "Território Gamma Plus", "Central Gamma Hub"
            // All are PrefixWord on "Gamma" or "Gamma Plus". Order by name.
            var results = repository.SearchTerritories("Gam", false, false).ToList();
            Assert.Contains(results, t => t.Name == "Alpha Station Gamma");      // PrefixWord
            Assert.Contains(results, t => t.Name == "Central Gamma Hub");        // PrefixWord
            Assert.Contains(results, t => t.Name == "Território Gamma Plus");    // PrefixWord
            Assert.Contains(results, t => t.Name == "Territory Gamma");          // PrefixWord
        }

        [Fact]
        public void SearchTerritories_Name_WordMatch_Fuzzy_SecondWord()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);
            
            // Search "Outpst" (fuzzy for Outpost) -> "Beta Outpost Zeta", "Nebula Outpost X"
            // Both FuzzyWord. Order by name.
            var results = repository.SearchTerritories("Outpst", false, false).ToList();
            Assert.Contains(results, t => t.Name == "Beta Outpost Zeta");
            Assert.Contains(results, t => t.Name == "Nebula Outpost X");
            Assert.Equal("Beta Outpost Zeta", results[0].Name);
        }

        [Fact]
        public void SearchTerritories_Name_WordMatch_Accent_SecondWord()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // Search "Südlich" -> "Südlicher Bereich" (PrefixWord after normalization)
            var result = repository.SearchTerritories("Südlich", false, false).ToList();
            Assert.Contains(result, t => t.Name == "Südlicher Bereich");
            Assert.Equal("Südlicher Bereich", result.First().Name);
        }
        
        [Fact]
        public void SearchTerritories_Ordering_NameMatchWinsOverCodeMatch()
        {
            // Name: "The Alpha Base" (PrefixFull for "Alpha") vs Code: "TAB25" (FuzzyFull for "Alpha")
            // Search "Alpha"
            // "The Alpha Base": Name is PrefixWord "Alpha". Score 70.
            // "Territory Alpha": Name is PrefixWord "Alpha". Score 70.
            // "Alpha Centauri": Name is PrefixFull "Alpha Centauri". Score 90.
            // "Auxiliary Base" Code "AUXALPHA": Code is ExactContains "alpha". Score 100.
            // "Delta Station Alpha": Name is ExactContains on word "Alpha". Score 100.
            var context = GetInMemoryDbContext(GetDefaultTerritories());
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var results = repository.SearchTerritories("Alpha", false, false).ToList();
            
            Assert.Collection(results,
                item => Assert.Equal("Delta Station Alpha", item.Name), // Name ExactContains Word (100)
                item => Assert.Equal("Auxiliary Base", item.Name),      // Code ExactContains (100) - AUXALPHA vs alpha
                item => Assert.Equal("Alpha Centauri", item.Name),      // Name PrefixFull (90)
                item => Assert.Equal("Territory Alpha", item.Name),     // Name PrefixWord (70)
                item => Assert.Equal("The Alpha Base", item.Name)       // Name PrefixWord (70)
            );
        }

        [Fact]
        public void SearchTerritories_Ordering_CodeMatchWinsOverNameMatch()
        {
            // Territory A: Name "LowPrio Name", Code "EXACTCODE"
            // Territory B: Name "Exact Name Match", Code "LPCODE"
            // Search "Exact"
            // A: Code "EXACTCODE" -> ExactContains. Score 100.
            // B: Name "Exact Name Match" -> ExactContains. Score 100.
            // B should come before A due to Name sort.
            var territories = new List<Territory> {
                new Territory { Id = 1, Name = "LowPrio Name", Code = "EXACTCODE", PersonId = null },
                new Territory { Id = 2, Name = "Exact Name Match", Code = "LPCODE", PersonId = null }
            };
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var results = repository.SearchTerritories("Exact", false, false).ToList();
            Assert.Collection(results,
                item => Assert.Equal("Exact Name Match", item.Name), // ExactContains on Name
                item => Assert.Equal("LowPrio Name", item.Name)      // ExactContains on Code
            );
        }
        
        [Fact]
        public void SearchTerritories_Ordering_PriorityOfMatchTypes_ComplexScenario()
        {
            // Search "Territory"
            // 1. Territory Alpha (Name: ExactContains - 100)
            // 2. Territory Delta (Name: ExactContains - 100)
            // 3. Territory Epsilon (Name: ExactContains - 100)
            // 4. Territory Gamma (Name: ExactContains - 100)
            // 5. Território Beta (Name: PrefixFull - 90, after normalization "territorio beta" starts with "territory")
            // 6. Território Gamma Plus (Name: PrefixFull - 90)
            // 7. Old Territory (Name: FuzzyFull - "old territory" vs "territory" is dist 2) -> No, dist is 4. This should not fuzzy match.
            //    "Old Territory" (Name: PrefixWord "Territory")
            var context = GetInMemoryDbContext(GetDefaultTerritories());
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);
            var results = repository.SearchTerritories("Territory", false, false).ToList();

            Assert.Collection(results,
                item => Assert.Equal("Territory Alpha", item.Name),   // ExactContains
                item => Assert.Equal("Territory Delta", item.Name),   // ExactContains
                item => Assert.Equal("Territory Epsilon", item.Name), // ExactContains
                item => Assert.Equal("Territory Gamma", item.Name),   // ExactContains
                item => Assert.Equal("Território Beta", item.Name),  // PrefixFull
                item => Assert.Equal("Território Gamma Plus", item.Name), // PrefixFull
                item => Assert.Equal("Old Territory", item.Name)      // PrefixWord
            );
        }
        
        [Fact]
        public void SearchTerritories_Ordering_ByName_WhenSameMatchTypeAndScore()
        {
            var territories = new List<Territory> {
                new Territory { Id = 1, Name = "Zulu Territory", Code = "ZT01", PersonId = null },
                new Territory { Id = 2, Name = "Yankee Territory", Code = "YT02", PersonId = null }
            }; // Both ExactContains for "Territory"
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var results = repository.SearchTerritories("Territory", false, false).ToList();
            Assert.Collection(results,
                item => Assert.Equal("Yankee Territory", item.Name), // Y before Z
                item => Assert.Equal("Zulu Territory", item.Name)
            );
        }

        [Fact]
        public void SearchTerritories_Name_WordMatch_WithOnlyFreeFilter()
        {
            var context = GetInMemoryDbContext(GetDefaultTerritories());
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // "Alpha Station Gamma" (ASG19) is free. "Delta Station Alpha" (DSA24) is assigned.
            // "Kepler Station" (KXXXX016) is assigned.
            var results = repository.SearchTerritories("Station", true, false).ToList(); // onlyFree = true
            Assert.Single(results);
            Assert.Equal("Alpha Station Gamma", results.First().Name);
        }
        
        [Fact]
        public void SearchTerritories_EmptySearchTerm_StillReturnsAllFiltered()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("", true, false).ToList(); // onlyFree
            Assert.Equal(territories.Count(t => t.PersonId == null), result.Count);

            var resultGiven = repository.SearchTerritories(null, false, true).ToList(); // onlyGiven
            Assert.Equal(territories.Count(t => t.PersonId != null), resultGiven.Count);
        }

        [Fact]
        public async Task GetTerritoryStatistics_ReturnsCompleteUsageMetrics()
        {
            var now = DateTime.UtcNow;
            var territories = new List<Territory>
            {
                new Territory { Id = 1, Name = "North", Code = "N01", MapUrl = "https://maps.example/north", PersonId = null },
                new Territory { Id = 2, Name = "South", Code = "S01", MapUrl = "https://maps.example/south", PersonId = 3 },
                new Territory { Id = 3, Name = "Empty", Code = "E01", MapUrl = "https://maps.example/empty", PersonId = null }
            };

            var context = GetInMemoryDbContext(territories);
            context.Transaction.AddRange(
                new Transaction
                {
                    Id = 1,
                    TerritoryId = 1,
                    PersonId = 1,
                    GivenBy = "user",
                    GivenDateUtc = now.AddDays(-100),
                    PickedBy = "user",
                    PickedDateUtc = now.AddDays(-90),
                    IsAutomaticGivenDate = true,
                    IsAutomaticPickedDate = true
                },
                new Transaction
                {
                    Id = 2,
                    TerritoryId = 1,
                    PersonId = 2,
                    GivenBy = "user",
                    GivenDateUtc = now.AddDays(-70),
                    PickedBy = "user",
                    PickedDateUtc = now.AddDays(-50),
                    IsAutomaticGivenDate = true,
                    IsAutomaticPickedDate = true
                },
                new Transaction
                {
                    Id = 3,
                    TerritoryId = 2,
                    PersonId = 3,
                    GivenBy = "user",
                    GivenDateUtc = now.AddDays(-10),
                    IsAutomaticGivenDate = true
                }
            );
            context.SaveChanges();

            var repository = new TerritoryRepository(context, NullLogger<TerritoryRepository>.Instance);

            var stats = await repository.GetTerritoryStatistics(1);

            Assert.Equal(3, stats.TotalTerritories);
            Assert.Equal(1, stats.UsageRank);
            Assert.True(stats.IsHighUsage);
            Assert.False(stats.IsLowUsage);
            Assert.InRange(stats.AssignedTimePercentage, 29.9, 30.1);
            Assert.InRange(stats.GlobalAverageAssignedTimePercentage, 43.2, 43.5);
            Assert.InRange(stats.AverageReassignmentTime, 19.9, 20.1);
            Assert.InRange(stats.GlobalAverageReassignmentTime, 6.6, 6.8);
            Assert.InRange(stats.AverageHoldingTime, 14.9, 15.1);
            Assert.InRange(stats.GlobalAverageHoldingTime, 4.9, 5.1);
            Assert.InRange(stats.CurrentUnassignedTime, 49.9, 50.1);
            Assert.Equal(2, stats.UniqueUsersCount);
            Assert.InRange(stats.GlobalAverageUniqueUsersCount, 0.9, 1.1);
        }
    }
}
