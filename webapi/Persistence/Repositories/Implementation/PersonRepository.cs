using Microsoft.EntityFrameworkCore;
using System.Data;
using System.Linq;
using System.Data;
using System.Linq;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;
using TerritoryTool.ServerSide.Domain.Helpers; // Added for SearchUtils

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

            var normalizedSearchTerm = SearchUtils.RemoveDiacritics(name.ToLower());
            const int levenshteinThreshold = 2; // Or a percentage of normalizedSearchTerm.Length

            return _context.Person
                .Where(p => p.Enabled)
                .ToList() // Bring entities into memory to perform complex string operations
                .Where(p =>
                {
                    var normalizedDbName = SearchUtils.RemoveDiacritics(p.Name?.ToLower() ?? string.Empty);
                    
                    // Check Levenshtein distance against the Name property OR if the name starts with the search term
                    if (!string.IsNullOrEmpty(normalizedDbName))
                    {
                        if (SearchUtils.LevenshteinDistance(normalizedDbName, normalizedSearchTerm) <= levenshteinThreshold)
                        {
                            return true;
                        }

                        if (normalizedDbName.StartsWith(normalizedSearchTerm, StringComparison.Ordinal))
                        {
                            return true;
                        }
                    }
                    
                    return false;
                })
                .ToList();
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
