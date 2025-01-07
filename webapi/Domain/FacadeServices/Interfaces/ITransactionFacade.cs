using Microsoft.AspNetCore.Mvc;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Controllers.Models.Transactions;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.Helpers;

namespace TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces
{
    public interface ITransactionFacade
    {
        Task<TransactionInfo> UpdateTransaction(int id, TransactionData transactionData);
        Task<IEnumerable<TransactionInfo>> GetTerritoryTransactions(int territoryId);
        Task<TransactionInfo> GetTransaction(int transactionId);
    }
}
