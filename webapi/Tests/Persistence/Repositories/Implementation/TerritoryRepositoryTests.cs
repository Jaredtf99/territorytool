using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using System.Collections.Generic;
using System.Linq;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Implementation;
using TerritoryTool.ServerSide.Persistence; // For TerritoryToolDbContext
using Xunit; // Assuming XUnit for testing framework

namespace TerritoryTool.ServerSide.Tests.Persistence.Repositories.Implementation
{
    public class TerritoryRepositoryTests
    {
        private TerritoryToolDbContext GetInMemoryDbContext(List<Territory> initialData = null)
        {
            var options = new DbContextOptionsBuilder<TerritoryToolDbContext>()
                .UseInMemoryDatabase(databaseName: System.Guid.NewGuid().ToString()) // Unique name
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
                new Territory { Id = 1, Name = "Territory Alpha", Code = "TA01", PersonId = 1 }, // Assigned
                new Territory { Id = 2, Name = "Território Beta", Code = "TB02", PersonId = null }, // Free, Accent name
                new Territory { Id = 3, Name = "Territory Gamma", Code = "TG03", PersonId = 2 }, // Assigned
                new Territory { Id = 4, Name = "Territory Delta", Code = "TDÖ4", PersonId = null }, // Free, Accent code
                new Territory { Id = 5, Name = "Territory Epsilon", Code = "TE05", PersonId = 3 }, // Assigned
                new Territory { Id = 6, Name = "Old Territory", Code = "OT06", PersonId = null }, // Free
                new Territory { Id = 7, Name = "Zeta Place", Code = "ZP07", PersonId = null }, // Free, for fuzzy
                new Territory { Id = 8, Name = "Central District", Code = "CDIST", PersonId = 4 }, // Assigned
                new Territory { Id = 9, Name = "North Sector (Residential)", Code = "NSR09", PersonId = null}, // Free
                new Territory { Id = 10, Name = "Südlicher Bereich", Code = "SBR10", PersonId = 5} // Assigned, Accent name and code part
            };
        }

        [Fact]
        public void SearchTerritories_AccentInsensitive_Name_ReturnsMatchingTerritories()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("Territorio Beta", false, false).ToList();
            Assert.Contains(result, t => t.Name == "Território Beta");
        }

        [Fact]
        public void SearchTerritories_AccentInsensitive_Code_ReturnsMatchingTerritories()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("TDO4", false, false).ToList(); // TDÖ4
            Assert.Contains(result, t => t.Code == "TDÖ4");
        }

        [Fact]
        public void SearchTerritories_FuzzyMatching_Name_ReturnsMatchingTerritories()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("Zta Place", false, false).ToList(); // Zeta Place (dist 1)
            Assert.Contains(result, t => t.Name == "Zeta Place");

            var result2 = repository.SearchTerritories("Central Distric", false, false).ToList(); // Central District (dist 1)
            Assert.Contains(result2, t => t.Name == "Central District");
        }

        [Fact]
        public void SearchTerritories_FuzzyMatching_Code_ReturnsMatchingTerritories()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("TA1", false, false).ToList(); // TA01 (dist 1)
            Assert.Contains(result, t => t.Code == "TA01");
            
            var result2 = repository.SearchTerritories("NSR0", false, false).ToList(); // NSR09 (dist 1)
            Assert.Contains(result2, t => t.Code == "NSR09");
        }
        
        [Fact]
        public void SearchTerritories_FuzzyMatching_ThresholdTest()
        {
            var territories = new List<Territory> { new Territory { Id = 1, Name = "Alexander", Code = "ALEX", PersonId = null } };
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // Name
            Assert.Single(repository.SearchTerritories("Alexandr", false, false)); // Dist 1
            Assert.Single(repository.SearchTerritories("Alexande", false, false)); // Dist 2
            Assert.Empty(repository.SearchTerritories("Alexand", false, false));   // Dist 3

            // Code
            Assert.Single(repository.SearchTerritories("ALE", false, false)); // Dist 1
            Assert.Single(repository.SearchTerritories("AL", false, false));  // Dist 2
            Assert.Empty(repository.SearchTerritories("A", false, false));    // Dist 3
        }

        [Fact]
        public void SearchTerritories_CombinationAccentAndFuzzy_Name_ReturnsMatchingTerritories()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);
            
            // Search "Sudlicher Bereich" for "Südlicher Bereich"
            var result = repository.SearchTerritories("Sudlicer Berech", false, false).ToList(); // Fuzzy (i for ü, c for h)
            Assert.Contains(result, t => t.Name == "Südlicher Bereich");
        }

        [Fact]
        public void SearchTerritories_CombinationAccentAndFuzzy_Code_ReturnsMatchingTerritories()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // Search "SBR1" for "SBR10" (SBR10 is part of Südlicher Bereich)
            // Search "TDO" for "TDÖ4"
            var result = repository.SearchTerritories("TDO", false, false).ToList(); // TDÖ4 (fuzzy + accent)
            Assert.Contains(result, t => t.Code == "TDÖ4");
        }
        
        [Fact]
        public void SearchTerritories_SearchTermWithDiacritics_ReturnsMatchingTerritories()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("Território", false, false).ToList();
            Assert.Contains(result, t => t.Name == "Território Beta");
            
            var resultCode = repository.SearchTerritories("TDÖ4", false, false).ToList();
            Assert.Contains(resultCode, t => t.Code == "TDÖ4");
        }
        
        [Fact]
        public void SearchTerritories_CaseInsensitive_ReturnsMatchingTerritories()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var resultName = repository.SearchTerritories("territory alpha", false, false).ToList();
            Assert.Contains(resultName, t => t.Name == "Territory Alpha");
            
            var resultCode = repository.SearchTerritories("ta01", false, false).ToList();
            Assert.Contains(resultCode, t => t.Code == "TA01");
        }

        [Fact]
        public void SearchTerritories_OnlyFreeTerritories_True_ReturnsOnlyFree()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // Search term that matches both a free and an assigned territory name/code part
            var result = repository.SearchTerritories("Territory", true, false).ToList(); // "Territory Alpha" (assigned), "Território Beta" (free), etc.
            Assert.True(result.Any());
            Assert.True(result.All(t => t.PersonId == null));
            Assert.Contains(result, t => t.Name == "Território Beta"); // Free
            Assert.DoesNotContain(result, t => t.Name == "Territory Alpha"); // Assigned
        }

        [Fact]
        public void SearchTerritories_OnlyGivenTerritories_True_ReturnsOnlyGiven()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("Territory", false, true).ToList();
            Assert.True(result.Any());
            Assert.True(result.All(t => t.PersonId != null));
            Assert.Contains(result, t => t.Name == "Territory Alpha"); // Assigned
            Assert.DoesNotContain(result, t => t.Name == "Território Beta"); // Free
        }
        
        [Fact]
        public void SearchTerritories_OnlyFreeAndOnlyGiven_True_ReturnsEmpty()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("Territory", true, true).ToList();
            Assert.Empty(result); // Cannot be both free and given
        }

        [Fact]
        public void SearchTerritories_SearchName_And_OnlyFree_ReturnsCorrectTerritories()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("Território Beta", true, false).ToList();
            Assert.Single(result);
            Assert.Equal("Território Beta", result.First().Name);
            Assert.Null(result.First().PersonId);
        }

        [Fact]
        public void SearchTerritories_SearchCode_And_OnlyGiven_ReturnsCorrectTerritories()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("TA01", false, true).ToList();
            Assert.Single(result);
            Assert.Equal("TA01", result.First().Code);
            Assert.NotNull(result.First().PersonId);
        }

        [Fact]
        public void SearchTerritories_EmptySearchTerm_And_OnlyFree_ReturnsAllFree()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("", true, false).ToList();
            var expectedFree = territories.Count(t => t.PersonId == null);
            Assert.Equal(expectedFree, result.Count);
            Assert.True(result.All(t => t.PersonId == null));
        }

        [Fact]
        public void SearchTerritories_NullSearchTerm_And_OnlyGiven_ReturnsAllGiven()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories(null, false, true).ToList();
            var expectedGiven = territories.Count(t => t.PersonId != null);
            Assert.Equal(expectedGiven, result.Count);
            Assert.True(result.All(t => t.PersonId != null));
        }

        [Fact]
        public void SearchTerritories_EmptySearchTerm_NoFilters_ReturnsAll()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("", false, false).ToList();
            Assert.Equal(territories.Count, result.Count);
        }
        
        [Fact]
        public void SearchTerritories_NullSearchTerm_NoFilters_ReturnsAll()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories(null, false, false).ToList();
            Assert.Equal(territories.Count, result.Count);
        }

        [Fact]
        public void SearchTerritories_NoMatches_WithFilters_ReturnsEmptyList()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("NonExistentXYZ", true, false).ToList();
            Assert.Empty(result);
        }

        [Fact]
        public void SearchTerritories_ExactMatch_Name_WithFilters_ReturnsCorrectTerritory()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // Search for "Território Beta" which is free
            var result = repository.SearchTerritories("Território Beta", true, false).ToList();
            Assert.Single(result);
            Assert.Equal("Território Beta", result.First().Name);
            Assert.Null(result.First().PersonId);

            // Search for "Territory Alpha" which is assigned
            var result2 = repository.SearchTerritories("Territory Alpha", false, true).ToList();
            Assert.Single(result2);
            Assert.Equal("Territory Alpha", result2.First().Name);
            Assert.NotNull(result2.First().PersonId);
        }

        [Fact]
        public void SearchTerritories_ExactMatch_Code_WithFilters_ReturnsCorrectTerritory()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // Search for "TB02" (Território Beta) which is free
            var result = repository.SearchTerritories("TB02", true, false).ToList();
            Assert.Single(result);
            Assert.Equal("TB02", result.First().Code);
            Assert.Null(result.First().PersonId);

            // Search for "TA01" (Territory Alpha) which is assigned
            var result2 = repository.SearchTerritories("TA01", false, true).ToList();
            Assert.Single(result2);
            Assert.Equal("TA01", result2.First().Code);
            Assert.NotNull(result2.First().PersonId);
        }
    }
}
