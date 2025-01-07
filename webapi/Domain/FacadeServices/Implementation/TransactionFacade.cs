using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics.Contracts;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Transactions;
using System.Xml.Linq;
using TerritoryTool.ServerSide.Controllers.Models.Person;
using TerritoryTool.ServerSide.Controllers.Models.Transactions;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.Exceptions;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Domain.Helpers;
using TerritoryTool.ServerSide.Persistence;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Implementation;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;
using static Microsoft.EntityFrameworkCore.DbLoggerCategory.Database;
using Transaction = TerritoryTool.ServerSide.Persistence.Entities.Transaction;

namespace TerritoryTool.ServerSide.Domain.FacadeServices.Implementation
{
    public class TransactionFacade : ITransactionFacade
    {

        private readonly ILogger _logger;

        private readonly ITransactionRepository _transactionRepo;
        private readonly ITerritoryRepository _territoryRepo;

        public TransactionFacade(ILogger<TransactionFacade> logger, ITransactionRepository transactionRepo, ITerritoryRepository territoryRepo)
        {
            _logger = logger;

            _transactionRepo = transactionRepo;
            _territoryRepo = territoryRepo;
        }

        public async Task<TransactionInfo> UpdateTransaction(int id, TransactionData transactionData)
        {
             var transaction = await _transactionRepo.GetTransaction(id) ?? throw new KeyNotFoundException();

            transaction.PersonId = transactionData.PersonId;
            transaction.GivenDateUtc = transactionData.GivenDateUtc;
            transaction.PickedDateUtc = transactionData.PickedDateUtc;

            await _transactionRepo.UpdateTransaction(transaction);

            return ConvertTransactionToTransactionInfo(await _transactionRepo.GetTransactionWithIncludes(id));
        }

        public async Task<IEnumerable<TransactionInfo>> GetTerritoryTransactions(int territoryId)
        {
            var transactions = _territoryRepo.GetTerritoryTransactions(territoryId);
            return transactions.Select(t => ConvertTransactionToTransactionInfo(t));
        }

        public async Task<TransactionInfo> GetTransaction(int transactionId)
        {
            var transaction = await _transactionRepo.GetTransactionWithIncludes(transactionId);
            return ConvertTransactionToTransactionInfo(transaction);
        }


        private TransactionInfo ConvertTransactionToTransactionInfo(Transaction transaction)
        {
            if (transaction == null) return null;

            TransactionInfo transactionInfo = new TransactionInfo
            {
                TransactionId = transaction.Id,
                PersonId = transaction.PersonId,
                GivenDateUtc = transaction.GivenDateUtc,
                PickedDateUtc = transaction.PickedDateUtc,  
                GivenBy = transaction.GivenByNavigation.UserName,
                PickedBy = transaction.PickedByNavigation?.UserName,
                TerritoryName = transaction.Territory.Name,
                PersonName = transaction.Person.Name
            };

            return transactionInfo;
        }

    }
}

