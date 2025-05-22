using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Google.Apis.Auth.OAuth2;
using Google.Apis.Drive.v3;
using Google.Apis.Services;
using Microsoft.Extensions.Logging;
using webapi.Domain.FacadeServices.Interfaces;

namespace webapi.Domain.FacadeServices.Implementation
{
    public class GoogleDriveService : IGoogleDriveService
    {
        private readonly ILogger<GoogleDriveService> _logger;
        private const string ApplicationName = "TerritoryToolBackup";

        public GoogleDriveService(ILogger<GoogleDriveService> logger)
        {
            _logger = logger;
        }

        public async Task UploadFileAsync(string filePath, string fileName, string credentialsPath, string folderId)
        {
            try
            {
                _logger.LogInformation($"Starting Google Drive upload for file: {fileName} to folder: {folderId}");

                if (!File.Exists(credentialsPath))
                {
                    _logger.LogError($"Google Drive credentials file not found at: {credentialsPath}");
                    return;
                }

                if (!File.Exists(filePath))
                {
                    _logger.LogError($"File to upload not found at: {filePath}");
                    return;
                }

                GoogleCredential credential;
                await using (var stream = new FileStream(credentialsPath, FileMode.Open, FileAccess.Read))
                {
                    credential = GoogleCredential.FromStream(stream)
                        .CreateScoped(DriveService.ScopeConstants.DriveFile);
                }
                _logger.LogInformation("Google Drive credentials loaded successfully.");

                var service = new DriveService(new BaseClientService.Initializer()
                {
                    HttpClientInitializer = credential,
                    ApplicationName = ApplicationName,
                });
                _logger.LogInformation("Google Drive service created successfully.");

                var fileMetadata = new Google.Apis.Drive.v3.Data.File()
                {
                    Name = fileName,
                    Parents = new List<string> { folderId }
                };

                FilesResource.CreateMediaUpload request;
                await using (var uploadStream = new FileStream(filePath, FileMode.Open, FileAccess.Read))
                {
                    request = service.Files.Create(fileMetadata, uploadStream, "application/octet-stream");
                    request.Fields = "id, name";
                    request.UploadSessionDataTransferProgress += progress =>
                        _logger.LogInformation($"Upload progress: {progress.Status} - {progress.BytesSent} bytes");
                    
                    var uploadResponse = await request.UploadAsync();

                    if (uploadResponse.Status == Google.Apis.Upload.UploadStatus.Completed)
                    {
                        var uploadedFile = request.ResponseBody;
                        _logger.LogInformation($"File '{uploadedFile.Name}' (ID: {uploadedFile.Id}) uploaded successfully to Google Drive folder {folderId}.");
                    }
                    else
                    {
                        _logger.LogError($"Google Drive upload failed for file: {fileName}. Status: {uploadResponse.Status}. Exception: {uploadResponse.Exception?.Message}");
                        if (uploadResponse.Exception != null)
                        {
                             _logger.LogError(uploadResponse.Exception, "Google Drive upload exception details:");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"An error occurred during Google Drive upload for file: {fileName}");
            }
        }
    }
}
