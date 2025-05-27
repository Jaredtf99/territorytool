using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;

namespace TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces
{
    public interface IUserConfigurationFacade
    {
        string Login(string userName, string password);
        IdentityResult RegisterUser(string userName, string password, RoleType role, string userIdRegisteredBy);
        IdentityResult ChangePassword(string userId, string currentPassword, string newPassword);
        bool EditUser(string userID, string userName, RoleType newRole, string loggedUserId, out string errorMsg);

        void DeleteUser(string userID, string loggedUserId);

        IEnumerable<UserInfo> GetUsersInformation();

        Task<IdentityResult> ChangeUserPasswordAsync(string targetUserId, string newPassword, string loggedInUserId);
    }
}
