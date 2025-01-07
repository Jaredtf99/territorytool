using System.Collections.Generic;
using TerritoryTool.ServerSide.Controllers.Models.Person;
using TerritoryTool.ServerSide.Controllers.Models.Transactions;
using TerritoryTool.ServerSide.Persistence.Entities;

namespace TerritoryTool.ServerSide.Persistence.Repositories.Interfaces
{
    public interface ITransactionRepository
    {
        
        Task<Transaction?> GetTransactionWithIncludes(int id);
        Task<Transaction> UpdateTransaction(Transaction transaction);
        Task<Transaction> DeleteTransaction(int id);
        Task<Transaction?> GetTransaction(int id);
    }
}
