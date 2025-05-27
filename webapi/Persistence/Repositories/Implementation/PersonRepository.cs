using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using TerritoryTool.ServerSide.Domain.Classes; // Added for SearchResultItem<T>
using TerritoryTool.ServerSide.Domain.Enums;   // Added for SearchMatchType
using TerritoryTool.ServerSide.Domain.Helpers; // For SearchUtils
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
            // This method likely needs to be updated or reviewed in context of new search logic
            // For now, keeping its original simple equality check.
            return _context.Person.FirstOrDefault(x => x.Name == name);
        }

        public IEnumerable<Person> SearchPersonsByName(string name)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                return _context.Person.Where(p => p.Enabled).ToList();
            }

            var allEnabledPersons = _context.Person.Where(p => p.Enabled).ToList();
            var rankedResults = new List<SearchResultItem<Person>>();

            foreach (var person in allEnabledPersons)
            {
                if (person.Name == null) continue; // Skip persons with null names

                var matchResult = SearchUtils.CalculateMatchResult(name, person.Name);

                if (matchResult.MatchType != SearchMatchType.None)
                {
                    rankedResults.Add(new SearchResultItem<Person>(person, matchResult.Score, matchResult.MatchType));
                }
            }

            // Sort by MatchType (lower enum value = higher priority), then by Score (higher score = better), then by Name for stability
            return rankedResults
                .OrderBy(r => r.MatchType)  // Lower enum value is better match type
                .ThenByDescending(r => r.Score) // Higher score is better
                .ThenBy(r => r.Item.Name)   // Alphabetical for tie-breaking
                .Select(r => r.Item)
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
