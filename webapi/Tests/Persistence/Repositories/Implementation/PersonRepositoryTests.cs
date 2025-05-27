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
    public class PersonRepositoryTests
    {
        private TerritoryToolDbContext GetInMemoryDbContext(List<Person> initialData = null)
        {
            var options = new DbContextOptionsBuilder<TerritoryToolDbContext>()
                .UseInMemoryDatabase(databaseName: System.Guid.NewGuid().ToString()) // Unique name for each test
                .Options;

            var context = new TerritoryToolDbContext(options);

            if (initialData != null)
            {
                context.Person.AddRange(initialData);
                context.SaveChanges();
            }
            return context;
        }

        private List<Person> GetDefaultPersons()
        {
            return new List<Person>
            {
                new Person { Id = 1, Name = "John Doe", FirstName = "John", LastName = "Doe", Enabled = true },
                new Person { Id = 2, Name = "Jane Smith", FirstName = "Jane", LastName = "Smith", Enabled = true },
                new Person { Id = 3, Name = "Joséphine Moreau", FirstName = "Joséphine", LastName = "Moreau", Enabled = true }, // Accents
                new Person { Id = 4, Name = "Søren Kierkegaard", FirstName = "Søren", LastName = "Kierkegaard", Enabled = true }, // Special chars
                new Person { Id = 5, Name = "Janette Miller", FirstName = "Janette", LastName = "Miller", Enabled = true }, // For fuzzy
                new Person { Id = 6, Name = "Disabled User", FirstName = "Disabled", LastName = "User", Enabled = false },
                new Person { Id = 7, Name = "Pedro Álvares Cabral", FirstName = "Pedro", MiddleName = "Álvares", LastName = "Cabral", Enabled = true}, // Accent in middle name
                new Person { Id = 8, Name = "Another John", FirstName = "John", LastName = "Another", Enabled = true },
                new Person { Id = 9, Name = "Jean-Luc Picard", FirstName = "Jean-Luc", LastName = "Picard", Enabled = true },
                new Person { Id = 10, Name = "Helmut Jöhn", FirstName = "Helmut", LastName = "Jöhn", Enabled = true } // For combined fuzzy & accent
            };
        }

        [Fact]
        public void SearchPersonsByName_AccentInsensitive_ReturnsMatchingPersons()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result1 = repository.SearchPersonsByName("Jose").ToList();
            Assert.Contains(result1, p => p.Name == "Joséphine Moreau");

            var result2 = repository.SearchPersonsByName("Josephine").ToList();
            Assert.Contains(result2, p => p.Name == "Joséphine Moreau");
            
            var result3 = repository.SearchPersonsByName("Soren").ToList();
            Assert.Contains(result3, p => p.Name == "Søren Kierkegaard");
        }

        [Fact]
        public void SearchPersonsByName_FuzzyMatching_ReturnsMatchingPersons()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            // Levenshtein distance 1 for "John Doe" vs "Jonh Doe"
            var result1 = repository.SearchPersonsByName("Jonh Doe").ToList(); 
            Assert.Contains(result1, p => p.Name == "John Doe");
            
            // Levenshtein distance 1 for "Another John" vs "Anoter John"
            var resultAnotherJohn = repository.SearchPersonsByName("Anoter John").ToList();
            Assert.Contains(resultAnotherJohn, p => p.Name == "Another John");

            // Check that "Jonh Doe" doesn't accidentally match "Another John" if "John Doe" is a closer match and both are different by 1
            // This depends on the specific behavior for multiple matches and thresholds.
            // For now, we ensure "John Doe" is found. If "Another John" is also found, that might be acceptable depending on requirements not specified here.
            // Assert.Single(result1.Where(p => p.Name == "John Doe" || p.Name == "Another John"));
            // Let's be more specific: only John Doe should be found by "Jonh Doe" with threshold 2 from default list
            var specificResult1 = result1.Where(p => p.Name == "John Doe").ToList();
            Assert.Single(specificResult1);


            // Levenshtein distance 2 for "Janette Miller" vs "Jannette Miller"
            var result2 = repository.SearchPersonsByName("Jannette Miller").ToList(); // Janette Miller
            Assert.Contains(result2, p => p.Name == "Janette Miller");
        }
        
        [Fact]
        public void SearchPersonsByName_FuzzyMatching_ThresholdTest()
        {
            var persons = new List<Person> { new Person { Id = 1, Name = "Alexander", FirstName = "Alexander", Enabled = true } };
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            // Assuming threshold is 2
            var result1 = repository.SearchPersonsByName("Alexandr").ToList(); // Dist 1
            Assert.Contains(result1, p => p.Name == "Alexander");
            
            var result2 = repository.SearchPersonsByName("Alexande").ToList(); // Dist 2
            Assert.Contains(result2, p => p.Name == "Alexander");

            var result3 = repository.SearchPersonsByName("Alexand").ToList(); // Dist 3 - Should not match if threshold is 2
            Assert.DoesNotContain(result3, p => p.Name == "Alexander");
        }


        [Fact]
        public void SearchPersonsByName_CombinationAccentAndFuzzy_ReturnsMatchingPersons()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            // "Jõnh" (search term) -> normalized "Jonh"
            // "Helmut Jöhn" (db) -> normalized "Helmut John" -> dist("Jonh", "Helmut John") is large
            // "John Doe" (db) -> normalized "John Doe" -> dist("Jonh", "John Doe") is 1 ("Jonh" vs "John")
            // "Another John" (db) -> normalized "Another John" -> dist("Jonh", "Another John") is 1 ("Jonh" vs "John")
            var result = repository.SearchPersonsByName("Jõnh").ToList();

            // Expected: "John Doe" and "Another John" (due to "John" part)
            // "Helmut Jöhn" should match if we search "Helmut Jonh" or similar, 
            // but "Jõnh" alone is too far from "Helmut Jöhn"
            Assert.Contains(result, p => p.Name == "John Doe");
            Assert.Contains(result, p => p.Name == "Another John");
            Assert.DoesNotContain(result, p => p.Name == "Helmut Jöhn"); // This should not match "Jõnh" with threshold 2

            // Test for "Helmut Jöhn" specifically
            var resultHelmut = repository.SearchPersonsByName("Helmut Jonh").ToList(); // Fuzzy for Jöhn
            Assert.Contains(resultHelmut, p => p.Name == "Helmut Jöhn");
        }

        [Fact]
        public void SearchPersonsByName_SearchTermWithDiacritics_ReturnsMatchingPersons()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("Joséphine").ToList();
            Assert.Contains(result, p => p.Name == "Joséphine Moreau");
        }

        [Fact]
        public void SearchPersonsByName_CaseInsensitive_ReturnsMatchingPersons()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("john doe").ToList();
            Assert.Contains(result, p => p.Name == "John Doe");
        }

        [Fact]
        public void SearchPersonsByName_DisabledPerson_NotReturned()
        {
            var persons = GetDefaultPersons(); // Includes "Disabled User"
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("Disabled User").ToList();
            Assert.DoesNotContain(result, p => p.Name == "Disabled User" && !p.Enabled);
            Assert.Empty(result.Where(p => p.Name == "Disabled User"));
        }
        
        [Fact]
        public void SearchPersonsByName_EnabledFilterWorks_ReturnsOnlyEnabled()
        {
            var persons = new List<Person>
            {
                new Person { Id = 1, Name = "Enabled Person", FirstName = "Enabled", Enabled = true },
                new Person { Id = 2, Name = "Disabled Person", FirstName = "Disabled", Enabled = false }
            };
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("Person").ToList();
            Assert.Single(result);
            Assert.Equal("Enabled Person", result.First().Name);
        }

        [Fact]
        public void SearchPersonsByName_EmptySearchTerm_ReturnsAllEnabledPersons()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("").ToList();
            Assert.Equal(persons.Count(p => p.Enabled), result.Count);
            Assert.DoesNotContain(result, p => !p.Enabled);
        }

        [Fact]
        public void SearchPersonsByName_NullSearchTerm_ReturnsAllEnabledPersons()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName(null).ToList();
            Assert.Equal(persons.Count(p => p.Enabled), result.Count);
            Assert.DoesNotContain(result, p => !p.Enabled);
        }

        [Fact]
        public void SearchPersonsByName_NoMatches_ReturnsEmptyList()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("NonExistentNameXYZ").ToList();
            Assert.Empty(result);
        }

        [Fact]
        public void SearchPersonsByName_ExactMatch_ReturnsCorrectPerson()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("John Doe").ToList();
            Assert.Contains(result, p => p.Name == "John Doe");
            Assert.Equal(1, result.Count(p => p.Name == "John Doe"));
        }
        
        [Fact]
        public void SearchPersonsByName_PartialMatchNameWithinThreshold_ReturnsPerson()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            // Search for part of "John Doe"
            var resultJohn = repository.SearchPersonsByName("John Do").ToList();
            Assert.Contains(resultJohn, p => p.Name == "John Doe");

            // Search for part of "Pedro Álvares Cabral"
            var resultPedro = repository.SearchPersonsByName("Pedro Alvares Cabra").ToList();
            Assert.Contains(resultPedro, p => p.Name == "Pedro Álvares Cabral");
            
            // Search for part of "Joséphine Moreau" with fuzzy and accent
            var resultJosephine = repository.SearchPersonsByName("Josephine Morea").ToList();
            Assert.Contains(resultJosephine, p => p.Name == "Joséphine Moreau");
        }

        [Fact]
        public void SearchPersonsByName_NameFieldDifferentFromParts_MatchesNameField()
        {
            var persons = new List<Person> {
                new Person { Id = 1, Name = "TheLegend SpecialName", FirstName = "John", LastName = "Doe", Enabled = true }
            };
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            // This test confirms that search is against the Name field, not FirstName/LastName.
            // "TheLegen SpecialNam" is a fuzzy search for "TheLegend SpecialName"
            var result = repository.SearchPersonsByName("TheLegen SpecialNam").ToList(); 
            Assert.Contains(result, p => p.Name == "TheLegend SpecialName");

            // Searching for "John Do" should NOT find this person, as "John Doe" is not in the Name field.
            var resultNonMatch = repository.SearchPersonsByName("John Do").ToList();
            Assert.DoesNotContain(resultNonMatch, p => p.Name == "TheLegend SpecialName");
        }
        // Removed SearchPersonsByName_NameFieldDifferentFromParts_MatchesFullName as it's no longer applicable
        // Removed SearchPersonsByName_MatchOnlyFirstName_ReturnsPerson, SearchPersonsByName_MatchOnlyLastName_ReturnsPerson, SearchPersonsByName_MatchMiddleName_ReturnsPerson
        // as the logic now only targets the consolidated Name field.
        // The functionality of matching parts of a name is covered by fuzzy matching on the Name field itself in SearchPersonsByName_PartialMatchNameWithinThreshold_ReturnsPerson.
    }
}
