using Dapper;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Configuration;
using System.Collections.Generic;
using System.Data;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;

namespace TerritoryTool.ServerSide.Persistence.Repositories.Implementation
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

        public Territory GetTerritoryById(int id)
        {
            using (IDbConnection con = Connection)
            {
                string query = @"SELECT * FROM Territory WHERE Id = @id";
                con.Open();
                var result = con.QueryFirstOrDefault<Territory>(query, new { id });
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

        public void EditTerritory(int id, string code, string name, string mapUrl)
        {
            using (IDbConnection con = Connection)
            {
                string query = @"UPDATE Territory SET Name = @name, Code = @code, MapUrl = @mapUrl WHERE Id = @id; SELECT LAST_INSERT_ROWID()";
                con.Open();
                con.Query<long>(query, new { id, code, name, mapUrl });
            }
        }

        public void DeleteTerritory(int id)
        {
            using (IDbConnection con = Connection)
            {
                string query = @"DELETE FROM Territory WHERE Id = @id; SELECT LAST_INSERT_ROWID()";
                con.Open();
                con.Query<long>(query, new { id });
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
