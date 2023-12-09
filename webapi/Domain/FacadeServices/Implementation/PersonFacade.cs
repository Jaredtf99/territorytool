using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics.Contracts;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Persistence;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;

namespace TerritoryTool.ServerSide.Domain.FacadeServices.Implementation
{
    public class PersonFacade : IPersonFacade
    {

        private readonly ILogger _logger;

        private readonly IPersonRepository _personRepo;
        private readonly IUserActionLogFacade _actionLog;

        public PersonFacade(ILogger<UserActionLogFacade> logger, IPersonRepository personRepo, IUserActionLogFacade actionLog)
        {
            _logger = logger;

            _personRepo = personRepo;
            _actionLog = actionLog;
        }

        public bool AddNewPerson(string name, string idLoggedUser)
        {
            Contract.Requires(!string.IsNullOrWhiteSpace(name));

            Person person = new Person { Name = name };

            _logger.LogInformation(string.Format("Adding {0} to persons", name));

            _personRepo.AddNewPerson(person);

            _actionLog.AddNewActionLog(ActionType.AddPerson, string.Format("Person {0} added", name), idLoggedUser, true);

            return true;
        }

        public IEnumerable<PersonInfo> GetAllPersons()
        {
            IEnumerable<PersonInfo> personsInfo = new List<PersonInfo>();

            var persons = _personRepo.GetAllPersons();

            var retval = ConvertPersonToPersonInfoList(persons);

            return retval;
        }

        public IEnumerable<PersonInfo> SearchPersonsByName(string name)
        {
            IEnumerable<PersonInfo> personsInfo = new List<PersonInfo>();

            var persons = _personRepo.SearchPersonsByName(name);

            var retval = ConvertPersonToPersonInfoList(persons);

            return retval;
        }


        public void DeletePerson(string name, string loggedUserId)
        {
            var personToDelete = _personRepo.GetPersonByName(name);

            if (personToDelete == null)
                _logger.LogError($"Cannot found person to delete. Name: {name}");
            else
                _personRepo.DeletePerson(personToDelete);

            _actionLog.AddNewActionLog(ActionType.DeletePerson, $"Deleting person {name}", loggedUserId, personToDelete != null);
        }

        public PersonInfo? GetPersonByName(string name)
        {
            var person = _personRepo.GetPersonByName(name);

            return ConvertPersonToPersonInfo(person);
        }


        private IEnumerable<PersonInfo> ConvertPersonToPersonInfoList(IEnumerable<Person> persons)
        {
            List<PersonInfo> retval = new List<PersonInfo>();

            foreach (Person person in persons)
            {
                PersonInfo personInfo = ConvertPersonToPersonInfo(person)!;

                retval.Add(personInfo);
            }

            return retval;
        }

        private PersonInfo? ConvertPersonToPersonInfo(Person? person) {

            if (person == null) return null;

            PersonInfo personInfo = new PersonInfo();

            personInfo.Name = person.Name;
            //TODO: Revisar esto, estaba mal planteado. Podemos sacar una lista de territorios activos, y ver como mostrarlo por pantalla.
            //personInfo.TerritoryCode = person.Te?.Code;
            //personInfo.TerritoryName = person.Territory?.Name;

            return personInfo;

        }


    }
}
