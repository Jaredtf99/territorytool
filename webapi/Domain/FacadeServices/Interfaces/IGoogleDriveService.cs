using System.Threading.Tasks;

namespace webapi.Domain.FacadeServices.Interfaces
{
    public interface IGoogleDriveService
    {
        Task UploadFileAsync(string filePath, string fileName, string credentialsPath, string folderId);
    }
}
