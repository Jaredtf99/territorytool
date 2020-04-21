using Dapper;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.Persistence.Entities;
using TerritoryTool.Persistence.Repositories.Interfaces;

namespace TerritoryTool.Persistence.Repositories.Implementation
{
    public class TerritoryRepository : ITerritoryRepository
    {
        private readonly IConfiguration _config;

        private IDbConnection Connection
        {
            get
            {
                return new SqliteConnection(_config.GetConnectionString("SQLite"));
            }
        }

        public TerritoryRepository(IConfiguration config)
        {
            _config = config;
        }

        public IEnumerable<Territory> GetAllTerritories()
        {
            using (IDbConnection con = Connection)
            {
                string query = "SELECT * FROM Territory";
                con.Open();
                var result = con.Query<Territory>(query);
                return result;
            }
        }

        public Territory GetTerritoryByName(string name)
        {
            using (IDbConnection con = Connection)
            {
                string query = @"SELECT * FROM Territory WHERE Name = @name";
                con.Open();
                var result = con.QueryFirstOrDefault<Territory>(query, new { name });
                return result;
            }
        }

        public void AddNewTerritory(string code, string name, string mapUrl)
        {
            using (IDbConnection con = Connection)
            {
                string query = @"INSERT INTO Territory (Code, Name, MapUrl) VALUES (@code, @name, @mapUrl); SELECT LAST_INSERT_ROWID()";
                con.Open();
                con.Query<long>(query, new { code, name, mapUrl});
            }
        }

        public Territory GetTerritoryByCode(string code)
        {
            using (IDbConnection con = Connection)
            {
                string query = @"SELECT * FROM Territory WHERE Code = @code";
                con.Open();
                var result = con.QueryFirstOrDefault<Territory>(query, new { code });
                return result;
            }
        }

        public Territory GetTerritoryByMapUrl(string mapUrl)
        {
            using (IDbConnection con = Connection)
            {
                string query = @"SELECT * FROM Territory WHERE MapUrl = @mapUrl";
                con.Open();
                var result = con.QueryFirstOrDefault<Territory>(query, new { mapUrl });
                return result;
            }
        }
    }
}
