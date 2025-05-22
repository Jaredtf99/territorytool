using System;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Quartz;
using webapi.Domain.FacadeServices.Interfaces;

namespace webapi.Domain.Jobs
{
    [DisallowConcurrentExecution]
    public class BackupDatabaseJob : IJob
    {
        private readonly ILogger<BackupDatabaseJob> _logger;
        private readonly IConfiguration _configuration;
        // private readonly IGoogleDriveService _googleDriveService; // Will be added later

        public BackupDatabaseJob(
            ILogger<BackupDatabaseJob> logger,
            IConfiguration configuration)
            // IGoogleDriveService googleDriveService) // Will be added later
        {
            _logger = logger;
            _configuration = configuration;
            // _googleDriveService = googleDriveService; // Will be added later
        }

        public async Task Execute(IJobExecutionContext context)
        {
            _logger.LogInformation("BackupDatabaseJob started.");

            try
            {
                var databasePath = _configuration["DatabasePath"];
                var googleDriveCredentialsPath = _configuration["GoogleDriveCredentialsPath"];

                if (string.IsNullOrEmpty(databasePath))
                {
                    _logger.LogError("DatabasePath is not configured.");
                    return;
                }

                if (string.IsNullOrEmpty(googleDriveCredentialsPath))
                {
                    _logger.LogError("GoogleDriveCredentialsPath is not configured.");
                    return;
                }

                _logger.LogInformation($"Database path: {databasePath}");
                _logger.LogInformation("Database backup process would happen here.");

                // Placeholder for actual backup and upload logic
                // var fileName = $"TerritoryTool_Backup_{DateTime.UtcNow:yyyyMMddHHmmss}.db";
                // var backupFilePath = Path.Combine(Path.GetTempPath(), fileName);

                // File.Copy(databasePath, backupFilePath, true);
                // _logger.LogInformation($"Database copied to: {backupFilePath}");

                // await _googleDriveService.UploadFileAsync(backupFilePath, fileName, googleDriveCredentialsPath, "YOUR_GOOGLE_DRIVE_FOLDER_ID");
                // _logger.LogInformation($"Backup file {fileName} uploaded to Google Drive.");

                // File.Delete(backupFilePath);
                // _logger.LogInformation($"Temporary backup file {backupFilePath} deleted.");

                _logger.LogInformation("BackupDatabaseJob completed.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "An error occurred during BackupDatabaseJob execution.");
            }
        }
    }
}
