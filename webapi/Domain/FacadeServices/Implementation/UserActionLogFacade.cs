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
    public class UserActionLogFacade : IUserActionLogFacade
    {

        private readonly ILogger _logger;

        private readonly IActionLogRepository _actionLog;
        private UserManager<ApplicationUser> _userManager;


        public UserActionLogFacade(ILogger<UserActionLogFacade> logger, IActionLogRepository actionLog, UserManager<ApplicationUser> userManager)
        {
            _logger = logger;

            _actionLog = actionLog;
            _userManager = userManager;
        }

        public bool AddNewActionLog(ActionType actionType, string message, string loggedUserId, bool successful)
        {
            Contract.Requires(actionType != ActionType.Unknown, "actionType cannot be unknown");
            Contract.Requires(!string.IsNullOrWhiteSpace(message), "message cannot be null or whitespace");

            ActionLog actionLog = new ActionLog
            {
                ActionType = (int)actionType,
                DateTimeUtc = DateTime.UtcNow,
                Message = message,
                UserId = loggedUserId,
                Successful = successful
            };

            _logger.LogInformation("Adding new actionLog. Type: {0}", actionType.ToString());

            _actionLog.AddNewActionLog(actionLog);

            return true;
        }


        public PagedResult<ActionLogInfo> GetActionLogsPaged(int pageNumber, int pageSize, string sortField, string sortOrder)
        {
            var items = _actionLog.GetActionLogs(pageNumber, pageSize, sortField, sortOrder, out int total);
            
            return new PagedResult<ActionLogInfo> {
                data = ConvertActionLogsToActionLogInfo(items),
                TotalCount = total,
                PageNumber = pageNumber,
                PageSize = pageSize
            };
        }

        private IEnumerable<ActionLogInfo> ConvertActionLogsToActionLogInfo(IEnumerable<ActionLog> actions)
        { 
            _logger.LogInformation("Converting action logs to action logs info");

            Dictionary<string, string> userIdsAndName = new Dictionary<string, string>();

            foreach(var id in actions.Select(x => x.UserId).Distinct())
            {
                string userName = _userManager.FindByIdAsync(id.ToString()).Result?.UserName;
                if (string.IsNullOrWhiteSpace(userName))
                {
                    _logger.LogError("UserID {0} not finded on BBDD...", id);
                }
                else
                    userIdsAndName.Add(id, userName);
            };

            List<ActionLogInfo> retval = new List<ActionLogInfo>();

            foreach (var action in actions)
            {
                if (userIdsAndName.TryGetValue(action.UserId, out string userNameFinded))
                {
                    ActionLogInfo actionInfo = new ActionLogInfo
                    {
                        ActionType = (ActionType)action.ActionType,
                        DateUtc = action.DateTimeUtc,
                        Message = action.Message,
                        UserName = userNameFinded,
                        Successful = action.Successful
                    };

                    retval.Add(actionInfo);
                }
            }

            return retval;
        }


    }
}
