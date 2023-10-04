using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;

namespace TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces
{
    public interface IPersonFacade
    {
        bool AddNewPerson(string name, string idLoggedUser);
        IEnumerable<PersonInfo> GetAllPersons();
        void DeletePerson(string name, string loggedUserId);
    }
}
