using System.Threading.Tasks;

namespace TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces
{
    public interface IGoogleDriveService
    {
        Task UploadFileAsync(string filePath, string fileName, string credentialsPath, string folderId);
    }
}
