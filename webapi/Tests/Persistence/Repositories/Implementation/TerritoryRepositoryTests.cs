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
                new Territory { Id = 10, Name = "Südlicher Bereich", Code = "SBR10", PersonId = 5}, // Assigned, Accent name and code part
                
                // New territories for StartsWith tests
                new Territory { Id = 11, Name = "Alpha Centauri", Code = "AC011", PersonId = null }, 
                new Territory { Id = 12, Name = "Território Gamma Plus", Code = "TGP12", PersonId = 2 }, 
                new Territory { Id = 13, Name = "Sirius Sector", Code = "KÖD321", PersonId = null }, 
                new Territory { Id = 14, Name = "Orion Spur", Code = "OS014", PersonId = 6 }, 
                new Territory { Id = 15, Name = "Nebula Outpost X", Code = "NOX15", PersonId = null }, // For prefix vs fuzzy - Name
                new Territory { Id = 16, Name = "Kepler Station", Code = "KXXXX016", PersonId = 7 }, // For prefix vs fuzzy - Code
                new Territory { Id = 17, Name = "Vega Colony", Code = "VC017", PersonId = null }, // For fuzzy not prefix - Name
                new Territory { Id = 18, Name = "Polaris Base", Code = "PLBASE1", PersonId = 8 } // For fuzzy not prefix - Code
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

            var result = repository.SearchTerritories("Zta Place", false, false).ToList(); 
            Assert.Contains(result, t => t.Name == "Zeta Place");

            var result2 = repository.SearchTerritories("Central Distric", false, false).ToList(); 
            Assert.Contains(result2, t => t.Name == "Central District");
        }

        [Fact]
        public void SearchTerritories_FuzzyMatching_Code_ReturnsMatchingTerritories()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("TA1", false, false).ToList(); 
            Assert.Contains(result, t => t.Code == "TA01");
            
            var result2 = repository.SearchTerritories("NSR0", false, false).ToList(); 
            Assert.Contains(result2, t => t.Code == "NSR09");
        }
        
        [Fact]
        public void SearchTerritories_FuzzyMatching_ThresholdTest()
        {
            var territories = new List<Territory> { new Territory { Id = 1, Name = "Alexander", Code = "ALEX", PersonId = null } };
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            Assert.Single(repository.SearchTerritories("Alexandr", false, false)); 
            Assert.Single(repository.SearchTerritories("Alexande", false, false)); 
            Assert.Empty(repository.SearchTerritories("Alexand", false, false));   

            Assert.Single(repository.SearchTerritories("ALE", false, false)); 
            Assert.Single(repository.SearchTerritories("AL", false, false));  
            Assert.Empty(repository.SearchTerritories("A", false, false));    
        }

        [Fact]
        public void SearchTerritories_CombinationAccentAndFuzzy_Name_ReturnsMatchingTerritories()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);
            
            var result = repository.SearchTerritories("Sudlicer Berech", false, false).ToList(); 
            Assert.Contains(result, t => t.Name == "Südlicher Bereich");
        }

        [Fact]
        public void SearchTerritories_CombinationAccentAndFuzzy_Code_ReturnsMatchingTerritories()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("TDO", false, false).ToList(); 
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
            Assert.Contains(result, t => t.Name == "Território Gamma Plus"); // Also matches by prefix
            
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

            var result = repository.SearchTerritories("Territory", true, false).ToList(); 
            Assert.True(result.Any());
            Assert.True(result.All(t => t.PersonId == null));
            Assert.Contains(result, t => t.Name == "Território Beta"); 
            Assert.DoesNotContain(result, t => t.Name == "Territory Alpha"); 
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
            Assert.Contains(result, t => t.Name == "Territory Alpha"); 
            Assert.DoesNotContain(result, t => t.Name == "Território Beta");
        }
        
        [Fact]
        public void SearchTerritories_OnlyFreeAndOnlyGiven_True_ReturnsEmpty()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("Territory", true, true).ToList();
            Assert.Empty(result); 
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

            var result = repository.SearchTerritories("Território Beta", true, false).ToList();
            Assert.Single(result);
            Assert.Equal("Território Beta", result.First().Name);
            Assert.Null(result.First().PersonId);

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

            var result = repository.SearchTerritories("TB02", true, false).ToList();
            Assert.Single(result);
            Assert.Equal("TB02", result.First().Code);
            Assert.Null(result.First().PersonId);

            var result2 = repository.SearchTerritories("TA01", false, true).ToList();
            Assert.Single(result2);
            Assert.Equal("TA01", result2.First().Code);
            Assert.NotNull(result2.First().PersonId);
        }

        // --- New tests for StartsWith ---

        [Fact]
        public void SearchTerritories_PrefixMatch_Name_Simple()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("Alpha", false, false).ToList(); // For "Alpha Centauri"
            Assert.Contains(result, t => t.Name == "Alpha Centauri");
            Assert.DoesNotContain(result, t => t.Name == "Territory Alpha"); // "Territory Alpha" does not start with "Alpha"
        }

        [Fact]
        public void SearchTerritories_PrefixMatch_Name_WithAccents()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // Search "Territ" (normalized from "Territ") finds "Território Gamma Plus" (normalized to "territorio gamma plus")
            var result = repository.SearchTerritories("Territ", false, false).ToList();
            Assert.Contains(result, t => t.Name == "Território Gamma Plus");
            Assert.Contains(result, t => t.Name == "Territory Alpha"); // Also matches "Territory Alpha" etc.
        }

        [Fact]
        public void SearchTerritories_PrefixMatch_Code_Simple()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("AC", false, false).ToList(); // For "AC011"
            Assert.Contains(result, t => t.Code == "AC011");
        }

        [Fact]
        public void SearchTerritories_PrefixMatch_Code_WithAccents()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // Search "KÖD" (normalized to "kod") finds "KÖD321" (normalized to "kod321")
            var result = repository.SearchTerritories("KÖD", false, false).ToList();
            Assert.Contains(result, t => t.Code == "KÖD321");
        }

        [Fact]
        public void SearchTerritories_PrefixMatch_NameOrCode_FindsByName()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // "Alpha" is prefix of "Alpha Centauri" (Name), not its code "AC011"
            var result = repository.SearchTerritories("Alpha", false, false).ToList();
            Assert.Contains(result, t => t.Name == "Alpha Centauri");
        }

        [Fact]
        public void SearchTerritories_PrefixMatch_NameOrCode_FindsByCode()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);
            
            // "AC0" is prefix of "AC011" (Code) of "Alpha Centauri", not its name
            var result = repository.SearchTerritories("AC0", false, false).ToList();
            Assert.Contains(result, t => t.Code == "AC011");
        }

        [Fact]
        public void SearchTerritories_PrefixMatch_Name_WithOnlyFreeFilter()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // "Alpha Centauri" is free (PersonId = null)
            var result = repository.SearchTerritories("Alpha", true, false).ToList();
            Assert.Contains(result, t => t.Name == "Alpha Centauri" && t.PersonId == null);
            Assert.Single(result.Where(t => t.Name == "Alpha Centauri"));
        }

        [Fact]
        public void SearchTerritories_PrefixMatch_Code_WithOnlyGivenFilter()
        {
            var territories = GetDefaultTerritories(); // "Território Gamma Plus" (TGP12) is PersonId = 2
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("TGP", false, true).ToList();
            Assert.Contains(result, t => t.Code == "TGP12" && t.PersonId != null);
            Assert.Single(result.Where(t => t.Code == "TGP12"));
        }

        [Fact]
        public void SearchTerritories_PrefixMatch_OverridesHighLevenshtein_Name()
        {
            var territories = GetDefaultTerritories(); // Nebula Outpost X (NOX15)
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // "Neb" is prefix of "Nebula Outpost X". Levenshtein("nebula outpost x", "neb") is high.
            var result = repository.SearchTerritories("Neb", false, false).ToList();
            Assert.Contains(result, t => t.Name == "Nebula Outpost X");
        }

        [Fact]
        public void SearchTerritories_PrefixMatch_OverridesHighLevenshtein_Code()
        {
            var territories = GetDefaultTerritories(); // Kepler Station (KXXXX016)
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);
            
            // "K" is prefix of "KXXXX016". Levenshtein("kxxxx016", "k") is high.
            var result = repository.SearchTerritories("K", false, false).ToList();
            Assert.Contains(result, t => t.Code == "KXXXX016"); // Matches KÖD321 as well
            Assert.Contains(result, t => t.Code == "KÖD321");
        }

        [Fact]
        public void SearchTerritories_FuzzyMatch_StillWorksWhenNotPrefix_Name()
        {
            var territories = GetDefaultTerritories(); // Vega Colony (VC017)
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // "Vaga Colony" is Levenshtein 1 from "Vega Colony", not prefix
            var result = repository.SearchTerritories("Vaga Colony", false, false).ToList();
            Assert.Contains(result, t => t.Name == "Vega Colony");
        }

        [Fact]
        public void SearchTerritories_FuzzyMatch_StillWorksWhenNotPrefix_Code()
        {
            var territories = GetDefaultTerritories(); // Polaris Base (PLBASE1)
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            // "PLBAS1" is Levenshtein 1 from "PLBASE1", not prefix
            var result = repository.SearchTerritories("PLBAS1", false, false).ToList();
            Assert.Contains(result, t => t.Code == "PLBASE1");
        }

        [Fact]
        public void SearchTerritories_PrefixMatch_CaseInsensitive_Name()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);

            var result = repository.SearchTerritories("alpha", false, false).ToList(); // for "Alpha Centauri"
            Assert.Contains(result, t => t.Name == "Alpha Centauri");
        }

        [Fact]
        public void SearchTerritories_PrefixMatch_CaseInsensitive_Code()
        {
            var territories = GetDefaultTerritories();
            var context = GetInMemoryDbContext(territories);
            var logger = NullLogger<TerritoryRepository>.Instance;
            var repository = new TerritoryRepository(context, logger);
            
            var result = repository.SearchTerritories("ac", false, false).ToList(); // for "AC011"
            Assert.Contains(result, t => t.Code == "AC011");
        }
    }
}
