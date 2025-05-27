using Microsoft.EntityFrameworkCore;
using System.Data;
using System.Linq;
using System.Text;
using System.Globalization;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;

namespace TerritoryTool.ServerSide.Persistence.Repositories.Implementation
{
    public class PersonRepository : IPersonRepository
    {
        private readonly TerritoryToolDbContext _context;
        private readonly ILogger _logger;

        public PersonRepository(TerritoryToolDbContext context, ILogger<PersonRepository> logger)
        {
            _context = context;
            _logger = logger;
        }

        public Person? GetPersonById(int id)
        {
            return _context.Person.Find(id);
        }

        public Person? GetPersonByName(string name)
        {
            name = name;

            return _context.Person.FirstOrDefault(x => x.Name == name);
        }

        public IEnumerable<Person> SearchPersonsByName(string name)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                return _context.Person.Where(p => p.Enabled).ToList();
            }

            var normalizedSearchTerm = RemoveDiacritics(name.ToLower());
            const int levenshteinThreshold = 2; // Or a percentage of normalizedSearchTerm.Length

            return _context.Person
                .Where(p => p.Enabled)
                .ToList() // Bring entities into memory to perform complex string operations
                .Where(p =>
                {
                    var normalizedDbName = RemoveDiacritics(p.Name?.ToLower() ?? string.Empty);
                    
                    // Construct full name from parts, ensuring null safety
                    var parts = new[] { p.FirstName, p.MiddleName, p.LastName };
                    var fullName = string.Join(" ", parts.Where(part => !string.IsNullOrEmpty(part)));
                    var normalizedDbFullName = RemoveDiacritics(fullName.ToLower());

                    // Check Levenshtein distance against the main Name property
                    if (!string.IsNullOrEmpty(normalizedDbName) && LevenshteinDistance(normalizedDbName, normalizedSearchTerm) <= levenshteinThreshold)
                    {
                        return true;
                    }

                    // Check Levenshtein distance against the constructed full name
                    if (!string.IsNullOrEmpty(normalizedDbFullName) && LevenshteinDistance(normalizedDbFullName, normalizedSearchTerm) <= levenshteinThreshold)
                    {
                        return true;
                    }
                    
                    // Fallback or alternative: check if the normalized search term is contained in any part,
                    // This can be useful if fuzzy matching is too restrictive or for partial matches.
                    // However, the requirement is to replace Contains with Levenshtein.
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

        public IEnumerable<Person> GetAllPersons()
        {
            return _context.Person
                .Include(p => p.Transactions.Where(t => t.PickedDateUtc == null))
                    .ThenInclude(t => t.Territory)
                .ToList();
        }
        public Person? GetPersonWithTerritory(int idTerritory)
        {
            return _context.Territory.Find(idTerritory)?.Person;
        }

        public void AddNewPerson(Person person)
        {
            if (person.Id == 0)
            {
                _context.Person.Add(person);
                _context.SaveChanges();
            }
            else
                _logger.LogError("Error add person entity. Entity to add shouldnt have an ID");
        }

        public void EditPerson(Person person)
        {
            if (person.Id != 0)
            {
                _context.Person.Update(person);
                _context.SaveChanges();
            }
            else
                _logger.LogError("Error updating person entity. Entity to update should have an ID");
           
        }

        public void DeletePerson(Person person)
        {
            _context.Person.Remove(person);
            _context.SaveChanges();
        }

    }
}
