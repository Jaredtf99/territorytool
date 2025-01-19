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
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.Exceptions;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Domain.Helpers;
using TerritoryTool.ServerSide.Persistence;
using TerritoryTool.ServerSide.Persistence.Entities;
using TerritoryTool.ServerSide.Persistence.Repositories.Implementation;
using TerritoryTool.ServerSide.Persistence.Repositories.Interfaces;
using Transaction = TerritoryTool.ServerSide.Persistence.Entities.Transaction;

namespace TerritoryTool.ServerSide.Domain.FacadeServices.Implementation
{
    public class TerritoryFacade : ITerritoryFacade
    {

        private readonly ILogger _logger;
        private readonly ApplicationSecrets _appSettings;

        private readonly ITerritoryRepository _territoryRepo;
        private readonly IUserActionLogFacade _actionLog;

        public TerritoryFacade(ILogger<TerritoryFacade> logger, ITerritoryRepository territoryRepo, IUserActionLogFacade actionLog, IOptions<ApplicationSecrets> appSettings)
        {
            _logger = logger;
            _appSettings = appSettings.Value;

            _territoryRepo = territoryRepo;
            _actionLog = actionLog;
        }


        public void AddTerritory(string code, string name, string mapUrl, string createdById)
        {

            if (_territoryRepo.GetTerritoryByCode(code) != null)
                throw new DomainException("CODE_EXIST");

            if (_territoryRepo.GetTerritoryByName(name) != null)
                throw new DomainException("NAME_EXIST");

            if (_territoryRepo.GetTerritoryByMapUrl(mapUrl) != null)
                throw new DomainException("MAPURL_EXIST");

            Territory territoryAdded = _territoryRepo.AddNewTerritory(code, name, mapUrl);

            _actionLog.AddNewActionLog(ActionType.AddTerritory, string.Format("Added territory {0} {1}", code, name), createdById, true);

            //TODO: hacer que no haya que esperar por esto
            string rutaImagen = DownloadTerritoryMapImageAsync(territoryAdded).Result;

            territoryAdded.ImgUrl = rutaImagen;
            _territoryRepo.EditTerritory(territoryAdded);
        }

        public void EditTerritory(int id, string code, string name, string mapUrl, string editedById)
        {
            Territory? territory = _territoryRepo.GetTerritoryById(id);

            if (territory == null)
                throw new DomainException("TERRITORY_NOT_FOUND");

            if (territory.Code != code && _territoryRepo.GetTerritoryByCode(code) != null)
                throw new DomainException("CODE_EXIST");

            if (territory.Name != name && _territoryRepo.GetTerritoryByName(name) != null)
                throw new DomainException("NAME_EXIST");

            if (territory.MapUrl != mapUrl && _territoryRepo.GetTerritoryByMapUrl(mapUrl) != null)
                throw new DomainException("MAPURL_EXIST");

            if (mapUrl != territory.MapUrl)
            {
                //TODO: hacer que no haya que esperar por esto
                string rutaImagen = DownloadTerritoryMapImageAsync(territory).Result;
                territory.ImgUrl = rutaImagen;
            }


            territory.Code = code;
            territory.Name = name;
            territory.MapUrl = mapUrl;

            _territoryRepo.EditTerritory(territory);

            _actionLog.AddNewActionLog(ActionType.EditTerritory, string.Format("Edited territory ID {0} to: Code ({1}) Name ({2}) MapURL ({3})", id, code, name, mapUrl), editedById, true);

        }

        public void RefreshImageTerritory(int territoryId, string? refreshedById = null)
        {
            Territory? territory = _territoryRepo.GetTerritoryById(territoryId);

            if (territory == null)
                throw new DomainException("TERRITORY_NOT_FOUND");

            string rutaImagen = DownloadTerritoryMapImageAsync(territory).Result;
            territory.ImgUrl = rutaImagen;

            _territoryRepo.EditTerritory(territory);

            if (!string.IsNullOrEmpty(refreshedById))
            {
                _actionLog.AddNewActionLog(
                    ActionType.RefreshTerritoryImage, 
                    string.Format("Refreshed image territory ID {0}", territoryId), 
                    refreshedById, 
                    true);
            }
        }


        public TerritoryDetailInfo? GetTerritoryDetailInfo(int id, IWebApiUrlHelper urlHelper)
        {
            var territory = _territoryRepo.GetTerritoryForDetailById(id);

            return ConvertTerritoryToTerritoryDetailInfo(territory, urlHelper.GetCurrentUrl());
        }

        private async Task<string> DownloadTerritoryMapImageAsync(Territory territory)
        {
            string rutaImagen = null;

            //TODO: sacar apiImage a un externalService
            //TODO: Lanzar excepciones si no va bien

            const string MapApiImage = "https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/{0},{1},16.31,0,25/300x200@2x?access_token={2}&attribution=false&logo=false";
            _logger.LogInformation($"Buscando coordenadas de la url del mapa del territorio {territory.Name} ({territory.Code})");

            Coordinate? coordinate = await GetCoordsFromMapUrl(territory.MapUrl);

            if (coordinate != null)
            {
                byte[] imageBytes = null;

                using (HttpClient httpClient = new HttpClient())
                {
                    string url = string.Format(MapApiImage, coordinate.Longitude.ToString().Replace(",", "."), coordinate.Latitude.ToString().Replace(",", "."), _appSettings.MapBoxApiKey);

                    HttpResponseMessage response = await httpClient.GetAsync(url);

                    if (response.IsSuccessStatusCode)
                    {
                        imageBytes = await response.Content.ReadAsByteArrayAsync();
                    }
                    else
                    {
                        _logger.LogError($"Error en la solicitud al generador de imagenes de mapas. Código de estado: {response.StatusCode}");
                    }
                }

                if (imageBytes != null)
                {
                    var directorioImagenes = Path.Combine("Resources", "Images");

                    if (!Directory.Exists(directorioImagenes))
                    {
                        Directory.CreateDirectory(directorioImagenes);
                    }

                    rutaImagen = Path.Combine(directorioImagenes, $"{Guid.NewGuid()}.png");
                    File.WriteAllBytes(rutaImagen, imageBytes);

                    _logger.LogInformation($"Imagen guardada en {rutaImagen}");

                }
            }

            return rutaImagen;
        }

        private async Task<Coordinate?> GetCoordsFromMapUrl(string mapUrl)
        {
            Coordinate coordinate = null;

            using (HttpClient httpClient = new HttpClient())
            {
                HttpResponseMessage response = await httpClient.GetAsync(mapUrl);

                if (response.IsSuccessStatusCode)
                {
                    string content = await response.Content.ReadAsStringAsync();

                    //Regex para sacar las coordenadas del html de google
                    string pattern = @"\[(-?\d+(\.\d+)?),(-?\d+(\.\d+)?)\]";
                    Regex regex = new Regex(pattern);

                    Match? match = regex.Matches(content).FirstOrDefault(x => x.Length > 5);

                    if (match != null)
                    {
                        string coordenadasString = match.Value;
                        coordenadasString = coordenadasString.Replace("[", "").Replace("]", "");

                        var coordenadas = coordenadasString.Split(',');

                        decimal lat = decimal.Parse(coordenadas[0], NumberStyles.AllowDecimalPoint | NumberStyles.AllowLeadingSign, NumberFormatInfo.InvariantInfo);
                        decimal lon = decimal.Parse(coordenadas[1], NumberStyles.AllowDecimalPoint | NumberStyles.AllowLeadingSign, NumberFormatInfo.InvariantInfo);

                        coordinate = new Coordinate(lat, lon);
                    }
                    else
                    {
                        _logger.LogError($"No se han podido encontrar las coordenadas");
                    }

                }
                else
                {
                    _logger.LogError($"Error en la solicitud a google para obtener coordenadas del mapa. Código de estado: {response.StatusCode}");
                }
            }

            return coordinate;
        }

        private TerritoryInfo? ConvertTerritoryToTerritoryInfo(Territory? territory, string resourceUrl = "")
        {

            if (territory == null) return null;

            TerritoryInfo territoryInfo = new TerritoryInfo();

            territoryInfo.MapUrl = territory.MapUrl;
            territoryInfo.PersonName = territory.Person?.Name;
            territoryInfo.Code = territory.Code;
            territoryInfo.Name = territory.Name;
            territoryInfo.Id = territory.Id;
            territoryInfo.GivenDateUtc = territory.Transactions?.FirstOrDefault(x => x.PickedDateUtc == null)?.GivenDateUtc;

            if (territory.ImgUrl != null)
                territoryInfo.ImgUrl = $"{resourceUrl}/{territory.ImgUrl}";

            return territoryInfo;

        }

        private TerritoryDetailInfo? ConvertTerritoryToTerritoryDetailInfo(Territory? territory, string resourceUrl = "")
        {

            if (territory == null) return null;

            TerritoryDetailInfo territoryDetailInfo = new TerritoryDetailInfo();


            Transaction? lastTransaction = territory.Transactions?.OrderBy(x => x.Id).FirstOrDefault();

            territoryDetailInfo.MapUrl = territory.MapUrl;
            territoryDetailInfo.PersonName = territory.Person?.Name;
            territoryDetailInfo.Code = territory.Code;
            territoryDetailInfo.Name = territory.Name;
            territoryDetailInfo.Id = territory.Id;
            territoryDetailInfo.GivenDateUtc = lastTransaction?.GivenDateUtc;
            territoryDetailInfo.LastPickedDateUtc = lastTransaction?.PickedDateUtc;
            territoryDetailInfo.PickedCount = territory.Transactions?.Count() ?? 0;
            territoryDetailInfo.LastUser = lastTransaction?.PickedByNavigation?.UserName ?? lastTransaction?.GivenByNavigation.UserName;


            if (territory.ImgUrl != null)
                territoryDetailInfo.ImgUrl = $"{resourceUrl}/{territory.ImgUrl}";

            territoryDetailInfo.TimelineItems = new List<TerritoryInfoTimeline>();

            foreach (var transaction in territory.Transactions)
            {
                TerritoryInfoTimeline t = new TerritoryInfoTimeline();
                t.Id = transaction.Id;
                t.Date = transaction.GivenDateUtc;
                t.Description = $"Entregado a {transaction.Person.Name}";
                t.Type = TerritoryInfoTimelineType.Gave;
                territoryDetailInfo.TimelineItems.Add(t);

                if (transaction.PickedDateUtc != null)
                {
                    TerritoryInfoTimeline tr = new TerritoryInfoTimeline();
                    tr.Id = transaction.Id;
                    tr.Date = transaction.PickedDateUtc.Value;
                    tr.Description = $"Devuelto";
                    tr.Type = TerritoryInfoTimelineType.Picked;
                    territoryDetailInfo.TimelineItems.Add(tr);
                }

            }

            return territoryDetailInfo;

        }

    }
}
