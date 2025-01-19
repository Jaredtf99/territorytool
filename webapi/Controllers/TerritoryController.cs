using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Web;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Newtonsoft.Json;
using OfficeOpenXml;
using OfficeOpenXml.Style;
using TerritoryTool.ServerSide.Controllers.Models.Person;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.Exceptions;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Domain.Helpers;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;
using webapi.Controllers.Helpers;

namespace TerritoryTool.ServerSide.Controllers
{
    [Route("api/v1/territories")]
    [ApiController]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class TerritoryController : ControllerBase
    {
        private readonly ILogger _logger;

        private readonly ITerritoryRepository _territoryRepository;
        private readonly ITerritoryFacade _territoryFacade;
        private readonly ITransactionRepository _transactionRepository;
        private readonly IPersonRepository _personRepository;
        private readonly IUserActionLogFacade _userActionLogFacade;
        private readonly ITransactionFacade _transactionFacade;

        public TerritoryController(ITerritoryRepository territoryRepository, 
        ITerritoryFacade territoryFacade, 
        ILogger<ActionLogController> logger, 
        IUserActionLogFacade userActionLogFacade,
        IPersonRepository personRepository,
        ITransactionRepository transactionRepository,
        ITransactionFacade transactionFacade)
        {
            _territoryRepository = territoryRepository;
            _territoryFacade = territoryFacade;
            _logger = logger;
            _userActionLogFacade = userActionLogFacade;
            _personRepository = personRepository;
            _transactionFacade = transactionFacade; 
            _transactionRepository = transactionRepository;
        }

        [HttpGet("all")]
        public IEnumerable<TerritoryInfo> AllTerritories([FromQuery] FilterTerritoriesModel filter)
        {
            _logger.LogInformation("Returning all territories...");

            var territories = _territoryRepository.GetAllTerritories(filter.Term, filter.InUse, filter.OrderBy, filter.OrderByAscending);

            return ConvertTerritoryToTerritoryInfoList(territories);
        }

        [HttpGet("{idTerritory}")]
        public async Task<ActionResult> GetTerritory(int idTerritory)
        {
            var territory = _territoryRepository.GetTerritoryById(idTerritory);

            if (territory == null)
                return NotFound();

            await LoadLastAndActiveTransactions(territory);

            return Ok(ConvertTerritoryToTerritoryInfo(territory));
        }


        [HttpGet("{idTerritory}/detail")]
        public ActionResult GetTerritoryDetailInfo(int idTerritory)
        {
            var territory = _territoryFacade.GetTerritoryDetailInfo(idTerritory, WebApiUrlHelper.AsInstance(Request));

            if (territory == null) 
            {
                return NotFound();
            }

            return Ok(territory);
        }


        /// <summary>
        /// Devuelve una lista de territorios en base al filtro de busqueda por texto
        /// </summary>
        /// <param name="search">Termino de busqueda</param>
        /// <param name="onlyFreeTerritories">Flag para obtener solo los territorios libres</param>
        /// <returns></returns>
        [HttpGet]
        public IEnumerable<TerritoryInfo> SearchTerritories(string search, bool onlyFreeTerritories = false, bool onlyGivenTerritories = false)
        {
            _logger.LogInformation("Searching territories");

            var territories = _territoryRepository.SearchTerritories(search, onlyFreeTerritories, onlyGivenTerritories);

            return ConvertTerritoryToTerritoryInfoList(territories);
        }


        /// <summary>
        /// Devuelve un territorio por el mapUrl
        /// </summary>
        /// <param name="mapUrl">MapUrl del territorio</param>
        /// <returns></returns>
        [HttpGet("map")]
        public async Task<ActionResult> GetTerritoryByMap(string mapUrl)
        {
            mapUrl = HttpUtility.UrlDecode(mapUrl);

            var territory = _territoryRepository.GetTerritoryByMapUrl(mapUrl);

            if (territory == null)
                return NotFound();

            await LoadLastAndActiveTransactions(territory);

            return Ok(ConvertTerritoryToTerritoryInfo(territory));
        }

        

        /// <summary>
        /// Devuelve un territorio por el codigo
        /// </summary>
        /// <param name="code">Codigo del territorio</param>
        /// <returns></returns>
        [HttpGet("code")]
        public async Task<ActionResult> GetTerritoryByCode(string code)
        {
            var territory = _territoryRepository.GetTerritoryByCode(code);

            if (territory == null)
                return NotFound();

            await LoadLastAndActiveTransactions(territory);

            return Ok(ConvertTerritoryToTerritoryInfo(territory));
        }

        [HttpPost]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult AddTerritory(AddTerritoryModel territoryInfo)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);
            _logger.LogInformation("Adding territory...");

            try
            {
                _territoryFacade.AddTerritory(territoryInfo.Code, territoryInfo.Name, territoryInfo.MapUrl, userId);
            }
            catch (DomainException ex)
            {
                return BadRequest(ex.Message);
            }

            return Ok();
        }

        [HttpPost("{idTerritory}")] //TODO: cambiar a patch
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult EditTerritory([FromRoute] int idTerritory, EditTerritoryModel info)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);

            _logger.LogInformation("Editing territory...");

            if (string.IsNullOrWhiteSpace(info.Code) || string.IsNullOrWhiteSpace(info.Name) || string.IsNullOrWhiteSpace(info.MapUrl))
                return BadRequest("INVALID_PARAMETERS");

            try
            {
                _territoryFacade.EditTerritory(idTerritory, info.Code, info.Name, info.MapUrl, userId);
            }
            catch (DomainException ex)
            {
                return BadRequest(ex.Message);
            }

            return Ok();
        }

        [HttpDelete("{idTerritory}")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult DeleteTerritory(int idTerritory)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);

            _logger.LogInformation("Deleting territory...");

            string errorMessage = null;

            Territory territoryToDelete = _territoryRepository.GetTerritoryById(idTerritory);

            if (territoryToDelete != null)
                _territoryRepository.DeleteTerritory(territoryToDelete);
            else
                errorMessage = "TERRITORY_NOT_FOUND";

            _userActionLogFacade.AddNewActionLog(ActionType.DeleteTerritory, string.Format("Deleted territory id {0}", idTerritory), userId, string.IsNullOrWhiteSpace(errorMessage));

            if (string.IsNullOrWhiteSpace(errorMessage))
                return Ok();
            else
                return BadRequest(errorMessage);

        }


        [HttpPost("give-territory")]
        public ActionResult GiveTerritory(GiveTerritoryModel info)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);
            _logger.LogInformation("Giving territory...");

            if (info.IsCustomDate && info.CustomDate == null)
                return BadRequest("Fecha invalida");

            Territory? territoryToGive = _territoryRepository.GetTerritoryByCode(info.TerritoryCode);

            if (territoryToGive == null)
                return BadRequest("No existe el territorio a entregar");

            Person? personToGive = _personRepository.GetPersonByName(info.PersonName);

            if (personToGive == null)
                return BadRequest("No existe la persona a la que entregar el territorio");

            // Validar que la fecha de entrega no sea anterior a la última fecha de recogida
            var lastTransaction = _territoryRepository.GetTerritoryTransactions(territoryToGive.Id)
                .OrderByDescending(t => t.PickedDateUtc)
                .FirstOrDefault();

            if (lastTransaction != null && lastTransaction.PickedDateUtc.HasValue)
            {
                var givenDate = info.IsCustomDate ? info.CustomDate!.Value : DateTime.UtcNow;
                if (givenDate < lastTransaction.PickedDateUtc.Value)
                {
                    return BadRequest("La fecha de entrega no puede ser anterior a la última fecha de recogida");
                }
            }

            Transaction giveTransaction = new Transaction
            {
                GivenBy = userId,
                GivenDateUtc = info.IsCustomDate ? info.CustomDate!.Value : DateTime.UtcNow,
                IsAutomaticGivenDate = !info.IsCustomDate,
                PersonId = personToGive.Id,
                TerritoryId = territoryToGive.Id
            };

            _territoryRepository.GiveTerritory(giveTransaction);

            _userActionLogFacade.AddNewActionLog(ActionType.GiveTerritory, $"Given territory ({territoryToGive.Code}) {territoryToGive.Name} to {personToGive.Name}. IsCustomDate: {info.IsCustomDate}", userId, true);

            return Ok();
        }

        [HttpPost("pick-territory")]
        public ActionResult PickTerritory(PickTerritoryModel info)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);
            _logger.LogInformation("Picking territory...");

            if (info.IsCustomDate && info.CustomDate == null)
                return BadRequest("Fecha invalida");

            Territory? territoryToPick = _territoryRepository.GetTerritoryByCode(info.TerritoryCode);

            if (territoryToPick == null)
                return BadRequest("No existe el territorio a recoger");

            if (territoryToPick.PersonId == null)
                return BadRequest("El territorio no esta asignado a nadie");

            DateTime pickedDate = info.IsCustomDate ? info.CustomDate!.Value : DateTime.UtcNow;

            // Validar que la fecha de recogida no sea posterior a la fecha de entrega
            var currentTransaction = _territoryRepository.GetTerritoryTransactions(territoryToPick.Id)
                .OrderByDescending(t => t.GivenDateUtc)
                .FirstOrDefault();

            if (currentTransaction != null)
            {
                if (pickedDate > DateTime.UtcNow)
                {
                    return BadRequest("La fecha de recogida no puede ser posterior a la fecha actual");
                }

                if (pickedDate < currentTransaction.GivenDateUtc)
                {
                    return BadRequest("La fecha de recogida no puede ser anterior a la fecha de entrega");
                }
            }

            _territoryRepository.PickTerritory(territoryToPick.Id, userId, !info.IsCustomDate, pickedDate);

            _userActionLogFacade.AddNewActionLog(ActionType.GiveTerritory, $"Picked territory ({territoryToPick.Code}) {territoryToPick.Name}. IsCustomDate: {info.IsCustomDate}", userId, true);

            return Ok();
        }

        [HttpPost("generate-excel")]
        public IActionResult GenerateExcel(GenerateTerritoryModel info)
        {
            var transactions = _territoryRepository.GetAllTransactionsForReport(info.Start, info.End);

            var transactionsGroupedByTerritory = transactions.GroupBy(x => new { x.Territory.Name, x.Territory.Code });

            using (var package = new ExcelPackage())
            {
                var worksheet = package.Workbook.Worksheets.Add("TerritoryTransactions");
               
                var firstColumnTerritory = 1;

                foreach (var territoryTransactions in transactionsGroupedByTerritory)
                {
                    var row = 1;

                    worksheet.Cells[row, firstColumnTerritory].Value = territoryTransactions.Key.Name;
                    worksheet.Cells[row, firstColumnTerritory + 1].Value = territoryTransactions.Key.Code;

                    foreach (var transaction in territoryTransactions)
                    {
                        row++;
                        worksheet.Cells[row, firstColumnTerritory].Value = transaction.GivenDateUtc;
                        worksheet.Cells[row, firstColumnTerritory + 1].Value = transaction.PickedDateUtc;
                        
                        // Formatear las celdas de fecha
                        worksheet.Cells[row, firstColumnTerritory].Style.Numberformat.Format = "yyyy-MM-dd";
                        worksheet.Cells[row, firstColumnTerritory + 1].Style.Numberformat.Format = "yyyy-MM-dd";

                        row++;

                        worksheet.Cells[row, firstColumnTerritory, row, firstColumnTerritory + 1].Merge = true;
                        worksheet.Cells[row, firstColumnTerritory].Value = transaction.Person?.Name;
                    }
                    firstColumnTerritory += 2;

                }

                if (worksheet.Dimension != null)
                {
                    worksheet.Cells[worksheet.Dimension.Address].AutoFitColumns();
                    worksheet.Cells[worksheet.Dimension.Address].Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;
                }

                var stream = new MemoryStream();
                package.SaveAs(stream);

                var fileName = $"TerritoryTransactions_{DateTime.Now.ToString("yyyyMMddHHmmss")}.xlsx";
                var contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

                return File(stream.ToArray(), contentType, fileName);
            }
        }

        [HttpPost("{idTerritory}/refresh-image")]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult RefreshImage([FromRoute] int idTerritory)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);

            _logger.LogInformation("Refreshing territory...");

            try
            {
                _territoryFacade.RefreshImageTerritory(idTerritory, userId);
            }
            catch (DomainException ex)
            {
                return NotFound(ex.Message);
            }

            return Ok();
        }

        [HttpGet("{id}/statistics")]
        public async Task<ActionResult<TerritoryStatistics>> GetTerritoryStatistics(int id)
        {
            try
            {
                var stats = await _territoryRepository.GetTerritoryStatistics(id);
                return Ok(stats);
            }
            catch (KeyNotFoundException)
            {
                return NotFound();
            }
        }

        [HttpGet("{territoryId}/transactions")]
        public async Task<IActionResult> GetTerritoryTransactions(int territoryId)
        {
            try
            {
                var transactions = await _transactionFacade.GetTerritoryTransactions(territoryId);
                return Ok(transactions);
            }
            catch (KeyNotFoundException)
            {
                return NotFound();
            }
        }

        [HttpGet("give-suggestions")]
        public async Task<IActionResult> GetGiveSuggestions()
        {
            _logger.LogInformation("Searching territory suggestions...");

            var territories = await _territoryRepository.GetTerritoriesSuggestions(3);

            return Ok(territories);
        }

        private async Task LoadLastAndActiveTransactions(Territory territory)
        {
            var activeTransaction = await _transactionRepository.GetTerritoryActiveTransactionAsync(territory.Id);
            var lastTransaction = await _transactionRepository.GetTerritoryLastCompletedTransactionAsync(territory.Id);

            territory.Transactions = new List<Transaction>();
            if (activeTransaction != null)
                territory.Transactions.Add(activeTransaction);
            if (lastTransaction != null)
                territory.Transactions.Add(lastTransaction);
        }

        private IEnumerable<TerritoryInfo> ConvertTerritoryToTerritoryInfoList(IEnumerable<Territory> territories)
        {
            List<TerritoryInfo> retval = new List<TerritoryInfo>();

            foreach (Territory territory in territories)
            {
                TerritoryInfo territoryInfo = ConvertTerritoryToTerritoryInfo(territory)!;

                retval.Add(territoryInfo);
            }

            return retval;

        }

        private TerritoryInfo? ConvertTerritoryToTerritoryInfo(Territory? territory)
        {

            if (territory == null) return null;

            TerritoryInfo territoryInfo = new TerritoryInfo();

            territoryInfo.MapUrl = territory.MapUrl;
            territoryInfo.PersonName = territory.Person?.Name;
            territoryInfo.Code = territory.Code;
            territoryInfo.Name = territory.Name;
            territoryInfo.Id = territory.Id;
            territoryInfo.GivenDateUtc = territory.Transactions?.FirstOrDefault(x => x.PickedDateUtc == null)?.GivenDateUtc;
            territoryInfo.LastPickedDateUtc = territory.Transactions?.OrderByDescending(x => x.PickedDateUtc)?.FirstOrDefault()?.PickedDateUtc;


            if (territory.ImgUrl != null)
                territoryInfo.ImgUrl = $"{Request.Scheme}://{Request.Host}{Request.PathBase}/{territory.ImgUrl}";

            return territoryInfo;

        }

    }
}
