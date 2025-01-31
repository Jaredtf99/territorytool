using System;
using System.Collections.Generic;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Persistence.Entities;

namespace TerritoryTool.ServerSide.Persistence.Repositories.Interfaces
{
    public interface IActionLogRepository
    {
        IEnumerable<ActionLog> GetActionLogs(int page, int pageSize, string sortField, string sortOrder, out int total);
        void AddNewActionLog(ActionLog actionLog);

    }
}
