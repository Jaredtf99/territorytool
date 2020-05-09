using Dapper;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Configuration;
using Microsoft.VisualStudio.Web.CodeGenerators.Mvc.Identity;
using System.Collections.Generic;
using System.Data;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;

namespace TerritoryTool.ServerSide.Persistence.Repositories.Implementation
{
    public class PersonRepository : IPersonRepository
    {
        private readonly IConfiguration _config;

        private IDbConnection Connection
        {
            get
            {
                return new SqliteConnection(_config.GetConnectionString("SQLite"));
            }
        }

        public PersonRepository(IConfiguration config)
        {
            _config = config;
        }

        public Person GetPersonById(int id)
        {
            using (IDbConnection con = Connection)
            {
                string query = @"SELECT * FROM Person WHERE Id = @id";
                con.Open();
                var result = con.QueryFirstOrDefault<Person>(query, new { id });
                return result;
            }
        }

        public IEnumerable<Person> SearchPersonsByName(string name)
        {
            using (IDbConnection con = Connection)
            {
                string query = "SELECT * FROM Person WHERE Name LIKE '%@name%'";
                con.Open();
                var result = con.Query<Person>(query, new { name });
                return result;
            }

        }

        public Person GetPersonWithTerritory(int idTerritory)
        {
            using (IDbConnection con = Connection)
            {
                string query = @"SELECT * FROM Person WHERE idTerritory = @idTerritory";
                con.Open();
                var result = con.QueryFirstOrDefault<Person>(query, new { idTerritory });
                return result;
            }

        }

        public void AddNewPerson(Person person)
        {
            using (IDbConnection con = Connection)
            {
                string query = @"INSERT INTO Person (Name, IdTerritory) VALUES (@name, @idTerritory); SELECT LAST_INSERT_ROWID()";
                con.Open();
                con.Query<long>(query, new { name = person.Name, idTerritory = person.IdTerritory });
            }
        }

        public void EditPerson(Person person)
        {
            using (IDbConnection con = Connection)
            {
                string query = @"UPDATE Person SET Name = @name, IdTerritory = @idTerritory WHERE Id = @id; SELECT LAST_INSERT_ROWID()";
                con.Open();
                con.Query<long>(query, new { id = person.Id, name = person.Name, idTerritory = person.IdTerritory});
            }

        }

        public void DeletePerson(int idPerson)
        {
            using (IDbConnection con = Connection)
            {
                string query = @"DELETE FROM Person WHERE Id = @idPerson; SELECT LAST_INSERT_ROWID()";
                con.Open();
                con.Query<long>(query, new { idPerson });
            }

        }
    }
}
