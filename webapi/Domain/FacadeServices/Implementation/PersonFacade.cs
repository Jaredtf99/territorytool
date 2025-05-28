using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics.Contracts;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.Exceptions;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Persistence;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;
using static System.Collections.Specialized.BitVector32;

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

            var existingPerson = _personRepo.GetPersonByName(name);

            if (existingPerson != null)
            {
                throw new DomainException("PERSON_ALREADY_EXISTS");
            }

            Person person = new Person { Name = name };

            _logger.LogInformation(string.Format("Adding {0} to persons", name));

            try
            {
                _personRepo.AddNewPerson(person);
                _actionLog.AddNewActionLog(ActionType.AddPerson, string.Format("Person {0} added", name), idLoggedUser, true);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error adding person {name}");
                _actionLog.AddNewActionLog(ActionType.AddPerson, string.Format("Error adding person {0}: {1}", name, ex.Message), idLoggedUser, false);
                throw;
            }
        }

        public IEnumerable<PersonInfo> GetAllPersons()
        {
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
            Person? personToDelete = null;
            try
            {
                personToDelete = _personRepo.GetPersonByName(name);

                if (personToDelete == null)
                {
                    _logger.LogError($"Cannot find person to delete. Name: {name}");
                    _actionLog.AddNewActionLog(ActionType.DeletePerson, $"Person {name} not found for deletion.", loggedUserId, false);
                    // Optionally, throw an exception here if desired, e.g., new DomainException("PERSON_NOT_FOUND");
                    // For now, just logging and exiting as per original logic's implication.
                    return; 
                }
                
                _personRepo.DeletePerson(personToDelete);
                _actionLog.AddNewActionLog(ActionType.DeletePerson, $"Person {name} deleted successfully.", loggedUserId, true);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error deleting person {name}");
                // Check personToDelete again because it might be null if GetPersonByName failed,
                // though less likely if GetPersonByName itself doesn't throw and just returns null.
                string message = $"Error deleting person {name}: {ex.Message}";
                if (personToDelete == null) { // If person was not found and an error still occurred (e.g. DB connection)
                    message = $"Error trying to delete non-existent person {name}: {ex.Message}";
                }
                _actionLog.AddNewActionLog(ActionType.DeletePerson, message, loggedUserId, false);
                throw;
            }
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
            personInfo.Id = person.Id;
            personInfo.Enabled = person.Enabled;

            if (person.Transactions != null)
                personInfo.TerritoriesInUse = ConvertTransactionToPersonInfoTransactionList(person.Transactions.Where(x => x.PickedDateUtc == null));

            return personInfo;

        }

        public void UpdatePerson(int id, string name, bool enabled, string currentUserId)
        {
            var person = _personRepo.GetPersonById(id);
            if (person == null)
            {
                throw new DomainException("Persona no encontrada");
            }

            string originalName = person.Name;
            bool originalEnabled = person.Enabled;

            if (originalName != name)
            {
                var existingPersonWithNewName = _personRepo.GetPersonByName(name);
                if (existingPersonWithNewName != null && existingPersonWithNewName.Id != id)
                {
                    throw new DomainException($"Ya existe un hermano con el nombre {name}");
                }
            }

            person.Name = name;
            person.Enabled = enabled;

            try
            {
                _personRepo.EditPerson(person);
                string logMessage = $"Se actualizó el hermano. Id: {person.Id}. Nombre Anterior: {originalName}, Nuevo Nombre: {person.Name}. Habilitado Anterior: {originalEnabled}, Nuevo Habilitado: {person.Enabled}";
                _actionLog.AddNewActionLog(ActionType.EditPerson, logMessage, currentUserId, true);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error updating person with Id: {id}");
                string logMessage = $"Error actualizando el hermano con Id: {id}. Nombre Anterior: {originalName}, Habilitado Anterior: {originalEnabled}. Error: {ex.Message}";
                _actionLog.AddNewActionLog(ActionType.EditPerson, logMessage, currentUserId, false);
                throw;
            }
        }

        private List<PersonInfoTransaction> ConvertTransactionToPersonInfoTransactionList(IEnumerable<Transaction> transactions)
        {
            List<PersonInfoTransaction> retval = new List<PersonInfoTransaction>();

            foreach (Transaction t in transactions)
            {
                PersonInfoTransaction personInfoTransaction = ConvertTransactionToPersonInfoTransaction(t)!;

                retval.Add(personInfoTransaction);
            }

            return retval;
        }

        private PersonInfoTransaction ConvertTransactionToPersonInfoTransaction(Transaction transaction)
        {
            if (transaction == null) return null;

            PersonInfoTransaction personInfoTransaction = new PersonInfoTransaction();

            personInfoTransaction.GivenDate = transaction.GivenDateUtc;
            personInfoTransaction.TerritoryName = transaction.Territory.Name;
            personInfoTransaction.TerritoryCode = transaction.Territory.Code;
            return personInfoTransaction;
        }


    }
}
