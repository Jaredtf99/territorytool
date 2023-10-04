using System;
using System.Collections.Generic;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Persistence.Entities;

namespace TerritoryTool.ServerSide.Persistence.Repositories.Interfaces
{
    public interface IActionLogRepository
    {
        IEnumerable<ActionLog> GetActionLogs();
        void AddNewActionLog(ActionLog actionLog);

    }
}
