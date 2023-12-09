using System.Collections.Generic;
using TerritoryTool.ServerSide.Persistence.Entities;

namespace TerritoryTool.ServerSide.Persistence.Repositories.Interfaces
{
    public interface IPersonRepository
    {
        Person? GetPersonById(int id);
        Person? GetPersonByName(string name);
        IEnumerable<Person> SearchPersonsByName(string name);
        Person? GetPersonWithTerritory(int idTerritory);
        IEnumerable<Person> GetAllPersons();
        void AddNewPerson(Person person);
        void EditPerson(Person person);
        void DeletePerson(Person person);

    }
}
