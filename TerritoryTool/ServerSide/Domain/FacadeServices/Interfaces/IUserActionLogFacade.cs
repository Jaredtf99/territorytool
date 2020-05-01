using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;

namespace TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces
{
    public interface IUserActionLogFacade
    {
        bool AddNewActionLog(ActionType actionType, string message, string loggedUserId, bool successful);
        IEnumerable<ActionLogInfo> GetAllActionLogs();
    }
}
