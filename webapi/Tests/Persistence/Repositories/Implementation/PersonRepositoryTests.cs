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
                new Person { Id = 1, Name = "John Doe", Enabled = true },
                new Person { Id = 2, Name = "Jane Smith", Enabled = true },
                new Person { Id = 3, Name = "Joséphine Moreau", Enabled = true }, // Accents
                new Person { Id = 4, Name = "Søren Kierkegaard", Enabled = true }, // Special chars
                new Person { Id = 5, Name = "Janette Miller", Enabled = true }, // For fuzzy
                new Person { Id = 6, Name = "Disabled User", Enabled = false },
                new Person { Id = 7, Name = "Pedro Álvares Cabral", Enabled = true}, // Name contains full name
                new Person { Id = 8, Name = "Another John", Enabled = true },
                new Person { Id = 9, Name = "Jean-Luc Picard", Enabled = true },
                new Person { Id = 10, Name = "Helmut Jöhn", Enabled = true }, // For combined fuzzy & accent
                new Person { Id = 11, Name = "Ainhoa Iglesias", Enabled = true },
                new Person { Id = 12, Name = "Johnny Test", Enabled = true },
                new Person { Id = 13, Name = "Axxxxxxxxxxxxxx", Enabled = true }, // For prefix vs fuzzy test
                new Person { Id = 14, Name = "Zzz Top", Enabled = true } // For fuzzy not prefix test
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

            var specificResult1 = result1.Where(p => p.Name == "John Doe").ToList();
            Assert.Single(specificResult1);

            var result2 = repository.SearchPersonsByName("Jannette Miller").ToList(); // Janette Miller
            Assert.Contains(result2, p => p.Name == "Janette Miller");
        }
        
        [Fact]
        public void SearchPersonsByName_FuzzyMatching_ThresholdTest()
        {
            var persons = new List<Person> { new Person { Id = 1, Name = "Alexander", Enabled = true } };
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

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

            var result = repository.SearchPersonsByName("Jõnh").ToList(); // normalized "jonh"
            // "John Doe" (john doe) - Levenshtein dist 1 to "jonh"
            Assert.Contains(result, p => p.Name == "John Doe");
            // "Another John" (another john) - Levenshtein dist 1 (of "john" to "jonh")
            Assert.Contains(result, p => p.Name == "Another John");
            // "Helmut Jöhn" (helmut john) vs "jonh" - Levenshtein dist is high on whole string
            Assert.DoesNotContain(result, p => p.Name == "Helmut Jöhn");

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
            var persons = GetDefaultPersons(); 
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("Disabled User").ToList();
            Assert.Empty(result.Where(p => p.Name == "Disabled User"));
        }
        
        [Fact]
        public void SearchPersonsByName_EnabledFilterWorks_ReturnsOnlyEnabled()
        {
            var persons = new List<Person>
            {
                new Person { Id = 1, Name = "Enabled Person", Enabled = true },
                new Person { Id = 2, Name = "Disabled Person", Enabled = false }
            };
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("Person").ToList(); // "Person" is prefix of "Enabled Person"
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

            var resultJohn = repository.SearchPersonsByName("John Do").ToList(); // Levenshtein for "John Doe"
            Assert.Contains(resultJohn, p => p.Name == "John Doe");

            var resultPedro = repository.SearchPersonsByName("Pedro Alvares Cabra").ToList(); // Levenshtein for "Pedro Álvares Cabral"
            Assert.Contains(resultPedro, p => p.Name == "Pedro Álvares Cabral");
            
            var resultJosephine = repository.SearchPersonsByName("Josephine Morea").ToList(); // Levenshtein for "Joséphine Moreau"
            Assert.Contains(resultJosephine, p => p.Name == "Joséphine Moreau");
        }

        [Fact]
        public void SearchPersonsByName_NameFieldDifferentFromParts_MatchesNameField()
        {
            var persons = new List<Person> {
                new Person { Id = 1, Name = "TheLegend SpecialName", Enabled = true }
            };
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("TheLegen SpecialNam").ToList(); 
            Assert.Contains(result, p => p.Name == "TheLegend SpecialName");

            var resultNonMatch = repository.SearchPersonsByName("John Do").ToList();
            Assert.DoesNotContain(resultNonMatch, p => p.Name == "TheLegend SpecialName");
        }

        [Fact]
        public void SearchPersonsByName_PrefixMatch_Simple()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var resultAinh = repository.SearchPersonsByName("Ainh").ToList(); // Prefix of "Ainhoa Iglesias"
            Assert.Contains(resultAinh, p => p.Name == "Ainhoa Iglesias");

            var resultJo = repository.SearchPersonsByName("Jo").ToList();
            Assert.Contains(resultJo, p => p.Name == "John Doe"); // StartsWith "jo"
            Assert.Contains(resultJo, p => p.Name == "Johnny Test");  // StartsWith "jo"
            Assert.Contains(resultJo, p => p.Name == "Joséphine Moreau"); // Normalized "josephine moreau" StartsWith "jo"
            // "Helmut Jöhn" (helmut john) vs "Jo" (jo). Levenshtein("helmut john", "jo") is 7. Not StartsWith.
            Assert.DoesNotContain(resultJo, p => p.Name == "Helmut Jöhn");

            var resultJohn = repository.SearchPersonsByName("John").ToList();
            Assert.Contains(resultJohn, p => p.Name == "John Doe"); // StartsWith "john"
            Assert.Contains(resultJohn, p => p.Name == "Johnny Test"); // StartsWith "john"
             // "Another John" (another john) vs "John" (john). LevenshteinDistance=8. Not StartsWith.
            Assert.DoesNotContain(resultJohn, p => p.Name == "Another John");
            // "Helmut Jöhn" (helmut john) vs "John" (john). LevenshteinDistance=7. Not StartsWith.
            Assert.DoesNotContain(resultJohn, p => p.Name == "Helmut Jöhn");
        }

        [Fact]
        public void SearchPersonsByName_PrefixMatch_WithAccents()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var resultJos = repository.SearchPersonsByName("Jos").ToList(); // "Jos" is prefix of normalized "josephine moreau"
            Assert.Contains(resultJos, p => p.Name == "Joséphine Moreau");

            var resultAin = repository.SearchPersonsByName("Aïn").ToList(); // Normalized "ain" is prefix of normalized "ainhoa iglesias"
            Assert.Contains(resultAin, p => p.Name == "Ainhoa Iglesias");
        }

        [Fact]
        public void SearchPersonsByName_PrefixMatch_DifferentLengths()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var resultA = repository.SearchPersonsByName("A").ToList();
            Assert.Contains(resultA, p => p.Name == "Ainhoa Iglesias"); // StartsWith 'a'
            Assert.Contains(resultA, p => p.Name == "Another John");  // StartsWith 'a'
            Assert.Contains(resultA, p => p.Name == "Axxxxxxxxxxxxxx"); // StartsWith 'a'
            // "Pedro Álvares Cabral" (pedro alvares cabral) does not start with 'a'.
            Assert.DoesNotContain(resultA, p => p.Name == "Pedro Álvares Cabral");

            var resultAinho = repository.SearchPersonsByName("Ainho").ToList();
            Assert.Contains(resultAinho, p => p.Name == "Ainhoa Iglesias");
            Assert.Single(resultAinho.Where(p => p.Name == "Ainhoa Iglesias")); 
        }
        
        [Fact]
        public void SearchPersonsByName_PrefixMatch_OverridesHighLevenshteinDistance()
        {
            var persons = GetDefaultPersons(); 
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            // "A" is a prefix of "Axxxxxxxxxxxxxx" (normalized "axxxxxxxxxxxxxx")
            // Levenshtein distance between "a" and "axxxxxxxxxxxxxx" is 14, above threshold 2
            // Should match because of StartsWith
            var result = repository.SearchPersonsByName("A").ToList();
            Assert.Contains(result, p => p.Name == "Axxxxxxxxxxxxxx");
        }

        [Fact]
        public void SearchPersonsByName_FuzzyMatch_StillWorksWhenNotPrefix()
        {
            var persons = GetDefaultPersons(); 
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            // "Zz Top" is not a prefix of "Zzz Top", but Levenshtein distance is 1 (normalized "zz top" vs "zzz top")
            var resultZzz = repository.SearchPersonsByName("Zz Top").ToList();
            Assert.Contains(resultZzz, p => p.Name == "Zzz Top");

            // "Janette Miller" vs "Jannte Miller" (Levenshtein 2)
            var resultJanette = repository.SearchPersonsByName("Jannte Miller").ToList();
            Assert.Contains(resultJanette, p => p.Name == "Janette Miller");
            Assert.DoesNotContain(resultJanette, p => p.Name == "Jane Smith"); 
        }
        
        [Fact]
        public void SearchPersonsByName_PrefixMatch_CaseInsensitive()
        {
            var persons = GetDefaultPersons();
            var context = GetInMemoryDbContext(persons);
            var logger = NullLogger<PersonRepository>.Instance;
            var repository = new PersonRepository(context, logger);

            var result = repository.SearchPersonsByName("jo").ToList();
            Assert.Contains(result, p => p.Name == "John Doe");
            Assert.Contains(result, p => p.Name == "Johnny Test");
            Assert.Contains(result, p => p.Name == "Joséphine Moreau");
            // "Helmut Jöhn" (helmut john) vs "jo". Levenshtein is 7. Not StartsWith.
            Assert.DoesNotContain(result, p => p.Name == "Helmut Jöhn");
        }
    }
}
