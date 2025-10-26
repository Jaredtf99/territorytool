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
        /// <summary>
        /// Obtiene la transacción activa de un territorio (sin fecha de recogida)
        /// </summary>
        /// <param name="territoryId">ID del territorio</param>
        /// <returns>La transacción activa o null si no existe</returns>
        Task<Transaction?> GetTerritoryActiveTransactionAsync(int territoryId);

        /// <summary>
        /// Obtiene la última transacción completada de un territorio
        /// </summary>
        /// <param name="territoryId">ID del territorio</param>
        /// <returns>La última transacción completada o null si no existe</returns>
        Task<Transaction?> GetTerritoryLastCompletedTransactionAsync(int territoryId);
        Task<IEnumerable<Transaction>> GetRecentTransactionsAsync();
    }
}
