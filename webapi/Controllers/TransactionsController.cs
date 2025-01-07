using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Newtonsoft.Json;
using TerritoryTool.ServerSide.Controllers.Models.Transactions;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Domain.Helpers;
using TerritoryTool.ServerSide.Persistence;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;

namespace TerritoryTool.ServerSide.Controllers
{
    [Route("api/v1/transactions")]
    [ApiController]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class TransactionsController : ControllerBase
    {
        private readonly ILogger _logger;

        private readonly ITransactionRepository _transactionRepository;
        private readonly IUserActionLogFacade _userActionLogFacade;
        private readonly ITransactionFacade _transactionFacade;

        public TransactionsController(ITransactionRepository transactionRepository, ILogger<TransactionsController> logger, IUserActionLogFacade userActionLogFacade, ITransactionFacade transactionFacade)
        {
            _transactionRepository = transactionRepository;
            _logger = logger;
            _userActionLogFacade = userActionLogFacade;
            _transactionFacade = transactionFacade;
        }

        

        [HttpGet("{id}")]
        public async Task<ActionResult<TransactionInfo>> GetTransaction(int id)
        {
            var transaction = await _transactionFacade.GetTransaction(id);

            if (transaction == null)
            {
                return NotFound();
            }

            return Ok(transaction);
        }


        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateTransaction(int id, TransactionData transactionData)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);
            try
            {   
                var transaction = await _transactionFacade.UpdateTransaction(id, transactionData);

                _userActionLogFacade.AddNewActionLog(ActionType.EditTransaction, $"Transaction {id} updated with data: {JsonConvert.SerializeObject(transactionData)}", userId, true);

                return Ok(transaction);
            }
            catch (KeyNotFoundException)
            {
                _userActionLogFacade.AddNewActionLog(ActionType.EditTransaction, $"Transaction {id} updated with data: {JsonConvert.SerializeObject(transactionData)}", userId, false);
                return NotFound();
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteTransaction(int id)
        {            
            var userId = SecurityHelper.GetLoggedUserId(User);
            try
            {   
                var transaction = await _transactionRepository.DeleteTransaction(id);
                _userActionLogFacade.AddNewActionLog(ActionType.DeleteTransaction, $"Transaction {id} deleted", userId, true);

                return NoContent();
            }
            catch (KeyNotFoundException)
            {
                _userActionLogFacade.AddNewActionLog(ActionType.DeleteTransaction, $"Transaction {id} deleted", userId, false);
                return NotFound();
            }
        }

    }
} 