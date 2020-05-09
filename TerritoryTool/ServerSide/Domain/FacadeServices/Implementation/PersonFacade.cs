using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
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

            _personRepo.AddNewPerson(person);

            _actionLog.AddNewActionLog(ActionType.AddPerson, string.Format("Person {0} added", name), idLoggedUser, true);

            return true;
        }
    }
}
