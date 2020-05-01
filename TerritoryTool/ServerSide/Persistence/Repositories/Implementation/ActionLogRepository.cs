using Dapper;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics.Contracts;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;

namespace TerritoryTool.ServerSide.Persistence.Repositories.Implementation
{
    public class ActionLogRepository : IActionLogRepository
    {
        private readonly IConfiguration _config;

        private IDbConnection Connection
        {
            get
            {
                return new SqliteConnection(_config.GetConnectionString("SQLite"));
            }
        }

        public ActionLogRepository(IConfiguration config)
        {
            _config = config;
        }

        public IEnumerable<ActionLog> GetActionLogs()
        {
            using (IDbConnection con = Connection)
            {
                string query = "SELECT * FROM ActionLog";
                con.Open();
                var result = con.Query<ActionLog>(query);
                return result;
            }
        }

        public void AddNewActionLog(ActionLog actionLog)
        {
            Contract.Requires(actionLog != null);

            using (IDbConnection con = Connection)
            {
                string query = @"INSERT INTO ActionLog (UserId, DateTimeUTC, Message, ActionType, Successful) VALUES (@userId, @dateTimeUtc, @message, @actionType, @successful); SELECT LAST_INSERT_ROWID()";
                con.Open();
                con.Query<long>(query, new 
                { 
                    userId = actionLog.UserId, 
                    dateTimeUtc = actionLog.DateTimeUTC, 
                    message = actionLog.Message, 
                    actionType = actionLog.ActionType,
                    successful = actionLog.Successful
                });
            }

        }
    }
}
