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

        public IEnumerable<ActionLog> GetActionLogs(int page, int pageSize, string sortField, string sortOrder, out int total)
        {
            var query = _context.ActionLog.AsQueryable();

            Func<ActionLog, object> orderExpression = sortField switch
            {
                "ActionType" => x => x.ActionType,
                "DateUtc" => x => x.DateTimeUtc,
                "UserName" => x => x.User.UserName,
                "Message" => x => x.Message,
                "Successful" => x => x.Successful,
                _ => x => x.DateTimeUtc,
            };

            if (sortOrder?.ToLower() == "asc")
                query = query.OrderBy(orderExpression).AsQueryable();
            else
                query = query.OrderByDescending(orderExpression).AsQueryable();
            
            total = query.Count();
            return query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToList();
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
