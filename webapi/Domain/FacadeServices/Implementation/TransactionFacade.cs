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
        private readonly IUserActionLogFacade _actionLog;

        public TransactionFacade(ILogger<TransactionFacade> logger, ITransactionRepository transactionRepo, ITerritoryRepository territoryRepo, IUserActionLogFacade actionLog)
        {
            _logger = logger;
            _transactionRepo = transactionRepo;
            _territoryRepo = territoryRepo;
            _actionLog = actionLog;
        }

        public async Task DeleteTransaction(int id, string loggedUserId)
        {
            try
            {
                var transaction = await _transactionRepo.DeleteTransaction(id);

                if (transaction.PickedDateUtc == null)
                {
                    var territory = _territoryRepo.GetTerritoryById(transaction.TerritoryId);
                    if (territory != null) // Ensure territory exists before trying to update
                    {
                        territory.PersonId = null;
                        _territoryRepo.EditTerritory(territory);
                    }
                    else
                    {
                        // Log a warning or handle the case where the associated territory is not found,
                        // though DeleteTransaction should ideally succeed even if the territory link is broken.
                        _logger.LogWarning($"Territory with ID {transaction.TerritoryId} not found when trying to nullify PersonId after deleting transaction {id}.");
                    }
                }
                _actionLog.AddNewActionLog(ActionType.DeleteTransaction, $"Transaction {id} deleted successfully.", loggedUserId, true);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error deleting transaction {id}.");
                _actionLog.AddNewActionLog(ActionType.DeleteTransaction, $"Error deleting transaction {id}: {ex.Message}", loggedUserId, false);
                throw;
            }
        }

        public async Task<TransactionInfo> UpdateTransaction(int id, TransactionData transactionData, string currentUserId)
        {
            Transaction transaction = null;
            try
            {
                transaction = await _transactionRepo.GetTransaction(id) ?? throw new KeyNotFoundException($"Transaction with ID {id} not found.");

                var activeTransactionTerritory = await _transactionRepo.GetTerritoryActiveTransactionAsync(transaction.TerritoryId);

                if (transactionData.GivenDateUtc > transactionData.PickedDateUtc)
                {
                    throw new DomainException("INVALID_DATES");
                }

                if (activeTransactionTerritory != null && activeTransactionTerritory.Id != id && transactionData.PickedDateUtc == null)
                {
                    throw new DomainException("TERRITORY_ALREADY_IN_USE");
                }

                bool updateTerritoryPersonNeeded = transaction.PersonId != transactionData.PersonId && transaction.PickedDateUtc == null;
                // Also, if the transaction is being marked as 'not picked' (PickedDateUtc is null),
                // and it wasn't like that before, or the person changed, update the territory.
                bool becomesOrStaysActiveForPerson = transactionData.PickedDateUtc == null;
                bool oldPickedDateWasNull = transaction.PickedDateUtc == null;

                transaction.PersonId = transactionData.PersonId;
                transaction.GivenDateUtc = transactionData.GivenDateUtc;
                transaction.PickedDateUtc = transactionData.PickedDateUtc;

                await _transactionRepo.UpdateTransaction(transaction);

                if (becomesOrStaysActiveForPerson) // If transaction is now active (no picked date)
                {
                    var territory = _territoryRepo.GetTerritoryById(transaction.TerritoryId);
                    if (territory != null)
                    {
                        territory.PersonId = transactionData.PersonId; // Assign to new person
                        _territoryRepo.EditTerritory(territory);
                    }
                }
                else if (oldPickedDateWasNull && transactionData.PickedDateUtc != null) // If it was active and now is picked
                {
                     var territory = _territoryRepo.GetTerritoryById(transaction.TerritoryId);
                     if (territory != null && territory.PersonId == transaction.PersonId) // only nullify if current person is the one on transaction
                     {
                        territory.PersonId = null; // Unassign from person
                        _territoryRepo.EditTerritory(territory);
                     }
                }
                // If updateTerritoryPersonNeeded is true due to person change for an active transaction,
                // the first 'if (becomesOrStaysActiveForPerson)' block handles it.

                var updatedTransactionInfo = ConvertTransactionToTransactionInfo(await _transactionRepo.GetTransactionWithIncludes(id));
                _actionLog.AddNewActionLog(ActionType.EditTransaction, $"Transaction {id} updated successfully. Person: {updatedTransactionInfo.PersonName}, Given: {updatedTransactionInfo.GivenDateUtc}, Picked: {updatedTransactionInfo.PickedDateUtc}", currentUserId, true);
                return updatedTransactionInfo;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error updating transaction {id}.");
                string personInfo = transactionData?.PersonId.ToString() ?? "unknown person";
                string originalPersonInfo = transaction?.PersonId.ToString() ?? "unknown original person";
                _actionLog.AddNewActionLog(ActionType.EditTransaction, $"Error updating transaction {id} for person {personInfo} (original: {originalPersonInfo}): {ex.Message}", currentUserId, false);
                throw;
            }
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

