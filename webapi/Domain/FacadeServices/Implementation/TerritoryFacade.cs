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
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;

namespace TerritoryTool.ServerSide.Domain.FacadeServices.Implementation
{
    public class TerritoryFacade : ITerritoryFacade
    {
        private const string GeoApifyStyle = "maptiler-3d";
        private const string GeoApifyScaleFactor = "2";
        private const string GeoApifyWidth = "420";
        private const string GeoApifyHeight = "280";
        private const string GeoApifyPitch = "40";
        private const string GeoApifyStyleCustomizationBackground = "background:%23f9f1e6";
        private const string GeoApifyStyleCustomizationLandcoverGrass = "landcover_grass:%23aee77e";
        private const string GeoApifyStyleCustomizationWater = "water:%238cd6f6";
        private const string GeoApifyStyleCustomizationRoadMinor = "road_minor:%239a9ea1";
        private const string GeoApifyStyleCustomizationRoadTrunkPrimary = "road_trunk_primary:%239a9ea1";
        private const string GeoApifyStyleCustomizationRoadSecondaryTertiary = "road_secondary_tertiary:%239a9ea1";
        private const string GeoApifyStyleCustomizationRoadMajorMotorway = "road_major_motorway:%239a9ea1";
        private const string GeoApifyStyleCustomizationBridgeMajor = "bridge_major:%239a9ea1";
        private const string GeoApifyStyleCustomizationBuilding3d = "building-3d:%23e8ebe1";

        private static readonly string GeoApifyStyleCustomizationString = string.Join("|",
            GeoApifyStyleCustomizationBackground,
            GeoApifyStyleCustomizationLandcoverGrass,
            GeoApifyStyleCustomizationWater,
            GeoApifyStyleCustomizationRoadMinor,
            GeoApifyStyleCustomizationRoadTrunkPrimary,
            GeoApifyStyleCustomizationRoadSecondaryTertiary,
            GeoApifyStyleCustomizationRoadMajorMotorway,
            GeoApifyStyleCustomizationBridgeMajor,
            GeoApifyStyleCustomizationBuilding3d);

        private readonly ILogger _logger;
        private readonly ApplicationSecrets _appSettings;

        private readonly ITerritoryRepository _territoryRepo;
        private readonly IUserActionLogFacade _actionLog;
        private readonly IConfiguration _configuration;

        public TerritoryFacade(ILogger<TerritoryFacade> logger, ITerritoryRepository territoryRepo, IUserActionLogFacade actionLog, IOptions<ApplicationSecrets> appSettings, IConfiguration configuration)
        {
            _logger = logger;
            _appSettings = appSettings.Value;
            _configuration = configuration;

            _territoryRepo = territoryRepo;
            _actionLog = actionLog;
        }

        public static string BuildGeoApifyStaticMapUrl(
            (Coordinate Southwest, Coordinate Northeast) boundingBox,
            string apiKey,
            string style,
            string scaleFactor,
            string width,
            string height,
            string pitch,
            string styleCustomization)
        {
            const string MapApiUrlFormatString = "https://maps.geoapify.com/v1/staticmap?style={0}&scaleFactor={1}&width={2}&height={3}&pitch={4}&area=rect:{5},{6},{7},{8}&apiKey={9}&styleCustomization={10}";
            
            return string.Format(MapApiUrlFormatString,
                style,
                scaleFactor,
                width,
                height,
                pitch,
                boundingBox.Southwest.Longitude.ToString().Replace(",", "."),
                boundingBox.Southwest.Latitude.ToString().Replace(",", "."),
                boundingBox.Northeast.Longitude.ToString().Replace(",", "."),
                boundingBox.Northeast.Latitude.ToString().Replace(",", "."),
                apiKey,
                styleCustomization);
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

            _logger.LogInformation($"Buscando coordenadas de la url del mapa del territorio {territory.Name} ({territory.Code})");

            var boundingBox = await GetBoundingBoxFromMapUrl(territory.MapUrl);

            if (boundingBox != null)
            {
                byte[] imageBytes = null;

                using (HttpClient httpClient = new HttpClient())
                {
                    string url = BuildGeoApifyStaticMapUrl(
                        boundingBox.Value,
                        _appSettings.MapBoxApiKey,
                        GeoApifyStyle,
                        GeoApifyScaleFactor,
                        GeoApifyWidth,
                        GeoApifyHeight,
                        GeoApifyPitch,
                        GeoApifyStyleCustomizationString);

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
                    using (var ms = new MemoryStream(imageBytes))
                    using (var image = System.Drawing.Image.FromStream(ms))
                    {
                        int newHeight = image.Height - 80;
                        if (newHeight > 0)
                        {
                            var croppedImage = new Bitmap(image.Width, newHeight);
                            
                            using (var graphics = Graphics.FromImage(croppedImage))
                            {
                                graphics.DrawImage(image,
                                    new Rectangle(0, 0, croppedImage.Width, croppedImage.Height),
                                    new Rectangle(0, 0, image.Width, newHeight),
                                    GraphicsUnit.Pixel);
                            }

                            var directorioFisicoImagenes = _configuration["Storage:PhysicalImagesPath"];
                            var directorioImagenes = _configuration["Storage:ImagesPath"];
                            Directory.CreateDirectory(directorioFisicoImagenes);

                            string nombreFichero = $"{Guid.NewGuid()}.png";


                            string rutaFisicaImagen = Path.Combine(directorioFisicoImagenes, nombreFichero);
                            croppedImage.Save(rutaFisicaImagen, System.Drawing.Imaging.ImageFormat.Png);

                            rutaImagen = Path.Combine(directorioImagenes, nombreFichero);
                            
                            _logger.LogInformation($"Imagen recortada guardada en {rutaFisicaImagen}");
                        }
                        else
                        {
                            _logger.LogWarning("La imagen es demasiado pequeña para recortar (Altura: {height}px)", image.Height);
                            return null;
                        }
                    }
                }
            }

            return rutaImagen;
        }

        protected virtual async Task<(Coordinate Southwest, Coordinate Northeast)?> GetBoundingBoxFromMapUrl(string mapUrl)
        {
            using (HttpClient httpClient = new HttpClient())
            {
                HttpResponseMessage response = await httpClient.GetAsync(mapUrl);

                if (response.IsSuccessStatusCode)
                {
                    string content = await response.Content.ReadAsStringAsync();

                    var perimeter = GetMapPerimeterCoordinates(content);

                    if (perimeter == null)
                    {
                        _logger.LogError($"No se han podido encontrar las coordenadas");
                        return null;
                    }
                    else
                    {
                        return GetBoundingBox(perimeter);
                    }

                }
                else
                {
                    _logger.LogError($"Error en la solicitud a google para obtener coordenadas del mapa. Código de estado: {response.StatusCode}");
                    return null;
                }
            }

        }

        public static List<Coordinate> GetMapPerimeterCoordinates(string htmlContent)
        {
            var coordinates = new List<Coordinate>();

            // Regex mejorada para capturar coordenadas con formato decimal
            var regex = new Regex(@"\[(\d+\.\d+),(-?\d+\.\d+)\]");
            var matches = regex.Matches(htmlContent);

            foreach (Match match in matches)
            {
                if (match.Groups.Count != 3) continue;

                try
                {
                    var latitude = decimal.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture);
                    var longitude = decimal.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture);
                    coordinates.Add(new Coordinate(latitude, longitude));
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error parsing coordinates: {ex.Message}");
                }
            }

            return coordinates;
        }

        public static (Coordinate Southwest, Coordinate Northeast) GetBoundingBox(List<Coordinate> coordinates)
        {
            if (coordinates == null || coordinates.Count == 0)
                throw new ArgumentException("La lista de coordenadas no puede estar vacía");

            decimal minLat = coordinates[0].Latitude;
            decimal maxLat = coordinates[0].Latitude;
            decimal minLon = coordinates[0].Longitude;
            decimal maxLon = coordinates[0].Longitude;

            foreach (var coord in coordinates)
            {
                minLat = Math.Min(minLat, coord.Latitude);
                maxLat = Math.Max(maxLat, coord.Latitude);
                minLon = Math.Min(minLon, coord.Longitude);
                maxLon = Math.Max(maxLon, coord.Longitude);
            }

            return (
                new Coordinate(minLat, minLon),  // Esquina suroeste
                new Coordinate(maxLat, maxLon)   // Esquina noreste
            );
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

            territoryDetailInfo.MapUrl = territory.MapUrl;
            territoryDetailInfo.PersonName = territory.Person?.Name;
            territoryDetailInfo.Code = territory.Code;
            territoryDetailInfo.Name = territory.Name;
            territoryDetailInfo.Id = territory.Id;

            // Calculate GivenDateUtc: Get the GivenDateUtc of the latest transaction (ordered by GivenDateUtc descending) where PickedDateUtc is null.
            // If no such transaction exists (e.g., the territory is not currently assigned), GivenDateUtc should be null.
            territoryDetailInfo.GivenDateUtc = territory.Transactions?
                .Where(t => t.PickedDateUtc == null)
                .OrderByDescending(t => t.GivenDateUtc)
                .FirstOrDefault()?.GivenDateUtc;

            // Calculate LastPickedDateUtc: Get the PickedDateUtc of the latest transaction (ordered by PickedDateUtc descending) that has a PickedDateUtc.
            // If no such transaction exists (e.g., the territory has always been assigned or is newly created), LastPickedDateUtc should be null.
            territoryDetailInfo.LastPickedDateUtc = territory.Transactions?
                .Where(t => t.PickedDateUtc != null)
                .OrderByDescending(t => t.PickedDateUtc)
                .FirstOrDefault()?.PickedDateUtc;
            
            territoryDetailInfo.PickedCount = territory.Transactions?.Count() ?? 0;

            // Determine LastUser based on the most recent transaction overall (either given or picked)
            // This part of the logic might need further refinement based on exact requirements for LastUser, 
            // but for now, we'll keep a simplified version based on the latest transaction available.
            // A more robust approach would be to find the absolute latest event (given or picked) and use that user.
            var lastOverallTransaction = territory.Transactions?
                .OrderByDescending(t => t.PickedDateUtc ?? t.GivenDateUtc)
                .FirstOrDefault();
            
            territoryDetailInfo.LastUser = lastOverallTransaction?.PickedByNavigation?.UserName ?? lastOverallTransaction?.GivenByNavigation?.UserName;


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
