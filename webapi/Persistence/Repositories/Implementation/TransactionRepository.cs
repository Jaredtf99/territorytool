using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Xml.Linq;
using TerritoryTool.ServerSide.Controllers.Models.Person;
using TerritoryTool.ServerSide.Controllers.Models.Transactions;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;

namespace TerritoryTool.ServerSide.Persistence.Repositories.Implementation
{
    public class TransactionRepository : ITransactionRepository
    {
        private readonly TerritoryToolDbContext _context;
        private readonly ILogger _logger;

        public TransactionRepository(TerritoryToolDbContext context, ILogger<TransactionRepository> logger)
        {
            _context = context;
            _logger = logger;
        }
        public async Task<Transaction?> GetTransactionWithIncludes(int id)
        {
            return await _context.Transaction
                               .Select(tr => new Transaction
                               {
                                   Id = tr.Id,
                                   TerritoryId = tr.TerritoryId,
                                   PersonId = tr.PersonId,
                                   GivenBy = tr.GivenBy,
                                   GivenDateUtc = tr.GivenDateUtc,
                                   PickedBy = tr.PickedBy,
                                   PickedDateUtc = tr.PickedDateUtc,
                                   IsAutomaticGivenDate = tr.IsAutomaticGivenDate,
                                   IsAutomaticPickedDate = tr.IsAutomaticPickedDate,
                                   Territory = new Territory
                                   {
                                       Id = tr.Territory.Id,
                                       Name = tr.Territory.Name
                                   },
                                   Person = new Person
                                   {
                                       Id = tr.Person.Id,
                                       Name = tr.Person.Name
                                   },
                                   GivenByNavigation = new AspNetUsers
                                   {
                                       Id = tr.GivenByNavigation.Id,
                                       UserName = tr.GivenByNavigation.UserName
                                   },
                                   PickedByNavigation = tr.PickedBy != null ? new AspNetUsers
                                   {
                                       Id = tr.PickedByNavigation.Id,
                                       UserName = tr.PickedByNavigation.UserName
                                   } : null
                               })

                .FirstOrDefaultAsync(t => t.Id == id);
        }

        public async Task<Transaction?> GetTransaction(int id)
        {
            return await _context.Transaction.FirstOrDefaultAsync(t => t.Id == id);
        }

        public async Task<Transaction> UpdateTransaction(Transaction transaction)
        {
            var transactionUpdated = _context.Transaction.Update(transaction);

            await _context.SaveChangesAsync();

            return transactionUpdated.Entity;
        }

        public async Task<Transaction> DeleteTransaction(int id)
        {
            var transaction = await _context.Transaction.FindAsync(id) ?? throw new KeyNotFoundException();

            _context.Transaction.Remove(transaction);
            await _context.SaveChangesAsync();

            return transaction;
        }

        public async Task<Transaction?> GetTerritoryActiveTransactionAsync(int territoryId)
        {
            return await _context.Transaction
                .Where(t => t.TerritoryId == territoryId && t.PickedDateUtc == null)
                .Include(t => t.Person)
                .FirstOrDefaultAsync();
        }

        public async Task<Transaction?> GetTerritoryLastCompletedTransactionAsync(int territoryId)
        {
            return await _context.Transaction
                .Where(t => t.TerritoryId == territoryId && t.PickedDateUtc != null)
                .OrderByDescending(t => t.PickedDateUtc)
                .Include(t => t.Person)
                .FirstOrDefaultAsync();
        }

        public async Task<IEnumerable<Transaction>> GetRecentTransactionsAsync()
        {
            var threeDaysAgo = DateTime.UtcNow.AddDays(-3);

            return await _context.Transaction
                .Where(t => t.GivenDateUtc >= threeDaysAgo)
                .Include(t => t.Territory)
                .Include(t => t.Person)
                .Include(t => t.GivenByNavigation)
                .Include(t => t.PickedByNavigation)
                .OrderByDescending(t => t.GivenDateUtc)
                .ToListAsync();
        }
    }
}
