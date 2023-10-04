using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;

namespace TerritoryTool.ServerSide.Persistence.Repositories.Implementation
{
    public class ActionLogRepository : IActionLogRepository
    {
        private readonly TerritoryToolDbContext _context;
        private readonly ILogger _logger;

        public ActionLogRepository(TerritoryToolDbContext context, ILogger<ActionLogRepository> logger)
        {
            _context = context;
            _logger = logger;
        }

        public IEnumerable<ActionLog> GetActionLogs()
        {
            //TODO: paginar
            return _context.ActionLog;
        }

        public void AddNewActionLog(ActionLog actionLog)
        {
            if (actionLog.Id == 0)
            {
                _context.ActionLog.Add(actionLog);
                _context.SaveChanges();
            }
            else
                _logger.LogError("Error adding new actionLog, id should be 0");

        }
    }
}
