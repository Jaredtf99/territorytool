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
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Domain.Helpers;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;

namespace TerritoryTool.ServerSide.Controllers
{
    [Route("api/v1/territories")]
    [ApiController]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class TerritoryController : ControllerBase
    {
        private readonly ILogger _logger;

        private readonly ITerritoryRepository _territoryRepository;
        private readonly IPersonRepository _personRepository;
        private readonly IUserActionLogFacade _userActionLogFacade;

        public TerritoryController(ITerritoryRepository territoryRepository, ILogger<ActionLogController> logger, IUserActionLogFacade userActionLogFacade, IPersonRepository personRepository)
        {
            _territoryRepository = territoryRepository;
            _logger = logger;
            _userActionLogFacade = userActionLogFacade;
            _personRepository = personRepository;
        }

        [HttpGet("all")]
        public IEnumerable<TerritoryInfo> AllTerritories([FromQuery] FilterTerritoriesModel filter)
        {
            _logger.LogInformation("Returning all territories...");

            var territories = _territoryRepository.GetAllTerritories(filter.Term, filter.InUse, filter.OrderBy, filter.OrderByAscending);

            return ConvertTerritoryToTerritoryInfoList(territories);
        }

        /// <summary>
        /// Devuelve una lista de territorios en base al filtro de busqueda por texto
        /// </summary>
        /// <param name="search">Termino de búsqueda</param>
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
        [HttpGet("map")]
        public ActionResult GetTerritoryByMap(string mapUrl)
        {
            mapUrl = HttpUtility.UrlDecode(mapUrl);

            var territory = _territoryRepository.GetTerritoryByMapUrl(mapUrl);

            if (territory == null)
                return NotFound();

            return Ok(ConvertTerritoryToTerritoryInfo(territory));
        }


        [HttpPost]
        [Authorize(Roles = "SUPERADMIN,ADMIN")]
        public ActionResult AddTerritory(AddTerritoryModel territoryInfo)
        {
            var userId = SecurityHelper.GetLoggedUserId(User);
            _logger.LogInformation("Adding territory...");
            
            if (_territoryRepository.GetTerritoryByCode(territoryInfo.Code) != null)
                return BadRequest("Ya existe un territorio con el mismo código");

            if (_territoryRepository.GetTerritoryByName(territoryInfo.Name) != null)
                return BadRequest("Ya existe un territorio con el mismo nombre");

            if (_territoryRepository.GetTerritoryByMapUrl(territoryInfo.MapUrl) != null)
                return BadRequest("Ya existe un territorio con la misma URL del mapa");

            _territoryRepository.AddNewTerritory(territoryInfo.Code, territoryInfo.Name, territoryInfo.MapUrl);

            _userActionLogFacade.AddNewActionLog(ActionType.AddTerritory, string.Format("Added territory {0} {1}", territoryInfo.Code, territoryInfo.Name), userId, true);

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

            Territory? territory = _territoryRepository.GetTerritoryById(idTerritory);

            if (territory == null) 
                return BadRequest("TERRITORY_NOT_FOUND");

            if (territory.Code != info.Code && _territoryRepository.GetTerritoryByCode(info.Code) != null)
                return BadRequest("CODE_EXIST");

            if (territory.Name != info.Name && _territoryRepository.GetTerritoryByName(info.Name) != null)
                return BadRequest("NAME_EXIST");

            if (territory.MapUrl != info.MapUrl && _territoryRepository.GetTerritoryByMapUrl(info.MapUrl) != null)
                return BadRequest("MAPURL_EXIST");

            territory.Code = info.Code;
            territory.Name = info.Name;
            territory.MapUrl = info.MapUrl;

            _territoryRepository.EditTerritory(territory);

            _userActionLogFacade.AddNewActionLog(ActionType.EditTerritory, string.Format("Edited territory ID {0} to: Code ({1}) Name ({2}) MapURL ({3})", idTerritory, info.Code, info.Name, info.MapUrl), userId, true);

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

            Transaction giveTransaction = new Transaction
            {
                GivenBy = userId,
                GivenDateUtc = info.IsCustomDate ? info.CustomDate!.Value : DateTime.UtcNow,
                IsAutomaticGivenDate = !info.IsCustomDate,
                PersonId = personToGive.Id,
                TerritoryId = territoryToGive.Id
            };

            //TODO: validaciones. No se puede dar un territorio para una fecha en la que ya estaba asignado a alguien 
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
            //TODO: validaciones. No se puede recoger un territorio con una fecha ANTERIOR a la de entrega 
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

            return territoryInfo;

        }

    }
}
