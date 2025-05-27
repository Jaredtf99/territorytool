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

            // Levenshtein distance 1
            var result1 = repository.SearchPersonsByName("Jonh Doe").ToList(); // John Doe
            Assert.Contains(result1, p => p.Name == "John Doe");
            Assert.Equal(1, result1.Count(p => p.Name == "John Doe" || p.Name == "Another John")); // Should ideally only find "John Doe" if threshold is tight

            // Levenshtein distance 2 for "Janette" vs "Jannette"
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

            // "Jõnh" vs "John" (Jöhn) -> remove diacritic "Jonh", then fuzzy to "John"
            var result = repository.SearchPersonsByName("Jõnh").ToList();
            Assert.Contains(result, p => p.Name == "Helmut Jöhn" || p.Name == "John Doe" || p.Name == "Another John");
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
        public void SearchPersonsByName_PartialMatchFullNameWithinThreshold_ReturnsPerson()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            // Search by "First Last"
            var result = repository.SearchPersonsByName("John Do").ToList(); // John Doe
            Assert.Contains(result, p => p.FirstName == "John" && p.LastName == "Doe");

            // Search by "First Middle Last"
            var resultPedro = repository.SearchPersonsByName("Pedro Alvares Cabra").ToList(); // Pedro Álvares Cabral
            Assert.Contains(resultPedro, p => p.Name == "Pedro Álvares Cabral");
        }
        
        [Fact]
        public void SearchPersonsByName_MatchOnlyFirstName_ReturnsPerson()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("Joséph").ToList(); // Joséphine
            Assert.Contains(result, p => p.FirstName == "Joséphine");
        }

        [Fact]
        public void SearchPersonsByName_MatchOnlyLastName_ReturnsPerson()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("Morea").ToList(); // Moreau (fuzzy for Joséphine Moreau)
            Assert.Contains(result, p => p.LastName == "Moreau");
        }
        
        [Fact]
        public void SearchPersonsByName_MatchMiddleName_ReturnsPerson()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            // Pedro Álvares Cabral
            var result = repository.SearchPersonsByName("Alvare").ToList(); // Álvares (fuzzy + accent)
            Assert.Contains(result, p => p.MiddleName == "Álvares");
        }

        [Fact]
        public void SearchPersonsByName_NameFieldDifferentFromParts_MatchesNameField()
        {
            var persons = new List<Person> { 
                new Person { Id = 1, Name = "TheLegend", FirstName = "John", LastName = "Doe", Enabled = true } 
            };
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("TheLegen").ToList(); // Fuzzy for TheLegend
            Assert.Contains(result, p => p.Name == "TheLegend");
        }

        [Fact]
        public void SearchPersonsByName_NameFieldDifferentFromParts_MatchesFullName()
        {
             var persons = new List<Person> { 
                new Person { Id = 1, Name = "TheLegend", FirstName = "John", LastName = "Doe", Enabled = true } 
            };
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("John Do").ToList(); // Fuzzy for John Doe
            Assert.Contains(result, p => p.FirstName == "John" && p.LastName == "Doe");
        }
    }
}
