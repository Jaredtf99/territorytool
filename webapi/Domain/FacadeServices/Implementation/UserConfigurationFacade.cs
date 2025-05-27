using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using System;
using System.Collections.Generic;
using System.Diagnostics.Contracts;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Domain.Classes;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.Exceptions;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Domain.Helpers;
using TerritoryTool.ServerSide.Persistence;

namespace TerritoryTool.ServerSide.Domain.FacadeServices.Implementation
{
    public class UserConfigurationFacade : IUserConfigurationFacade
    {
        private readonly ILogger _logger;

        private UserManager<ApplicationUser> _userManager;
        private readonly ApplicationSecrets _appSettings;
        private readonly IUserActionLogFacade _userActionLogFacade;

        public UserConfigurationFacade(ILogger<UserConfigurationFacade> logger, UserManager<ApplicationUser> userManager, IOptions<ApplicationSecrets> appSettings, IUserActionLogFacade userActionLogFacade)
        {
            _logger = logger;
            _userManager = userManager;
            _appSettings = appSettings.Value;
            _userActionLogFacade = userActionLogFacade;
        }

        public IdentityResult ChangePassword(string userId, string currentPassword, string newPassword)
        {
            IdentityResult retval = null;

            var user = _userManager.FindByIdAsync(userId).Result;

            _logger.LogInformation("Changing password for user: {0}", user?.UserName ?? userId);

            if (user == null)
                _logger.LogError("Null user finded for change password. UserId: {0}", userId);
            else
                retval = _userManager.ChangePasswordAsync(user, currentPassword, newPassword).Result;

            _userActionLogFacade.AddNewActionLog(ActionType.ChangeUserPassword, string.Format("Changed password for user {0}", user.UserName), userId, user != null && retval.Succeeded);

            return retval;
        }

        public string Login(string userName, string password)
        {
            string token = null;

            ApplicationUser user = _userManager.FindByNameAsync(userName).Result;


            if (user != null && _userManager.CheckPasswordAsync(user, password).Result)
            {
                _logger.LogInformation("Password correct");
                var role = _userManager.GetRolesAsync(user).Result;
                _logger.LogInformation("Roles matched");

                IdentityOptions _options = new IdentityOptions();

                var tokenDescriptor = new SecurityTokenDescriptor
                {
                    Subject = new ClaimsIdentity(new Claim[] {
                        new Claim(ConfigurationHelper.UserIDClaimKey, user.Id.ToString()),
                        new Claim(ConfigurationHelper.UserNameClaimKey, user.UserName),
                        new Claim(_options.ClaimsIdentity.RoleClaimType, role.FirstOrDefault())
                    }),
                    Expires = DateTime.UtcNow.AddMonths(2),
                    SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_appSettings.JWT_Secret)), SecurityAlgorithms.HmacSha256Signature)
                };

                _logger.LogInformation("tokendescriptor created");

                var tokenHandler = new JwtSecurityTokenHandler();
                var securityToken = tokenHandler.CreateToken(tokenDescriptor);
                token = tokenHandler.WriteToken(securityToken);

                _logger.LogInformation("token writed... returning");
            }
            else
                _logger.LogInformation("Wrong user or password requested");

            return token;
        }

        public IdentityResult RegisterUser(string userName, string password, RoleType role, string userIdRegisteredBy)
        {
            _logger.LogInformation("Registering user...");

            IdentityResult result = null;
            
            var registerInfo = new ApplicationUser()
            {
                UserName = userName,
                Email = "nothing@nothing.com"
            };

            result = _userManager.CreateAsync(registerInfo, password).Result;

            IdentityResult roleResult = _userManager.AddToRoleAsync(registerInfo, role.ToString()).Result;

            if (!roleResult.Succeeded)
                _logger.LogError("Error adding role to new user {0}. Errors: {1}", userName, string.Join(", ", roleResult.Errors.Select(x => x.Code)));

            _userActionLogFacade.AddNewActionLog(ActionType.AddUser, string.Format("User {0} registered", userName), userIdRegisteredBy, roleResult.Succeeded);


            return result;
        }

        public IEnumerable<UserInfo> GetUsersInformation() 
        {
            _logger.LogInformation("Retrieving all users info...");

            var users = _userManager.Users.ToList();

            return ConvertApplicationUserToUserInfo(users, _userManager);
        }

        public bool EditUser(string userID, string userName, RoleType newRole, string loggedUserId, out string errorMsg)
        {
            errorMsg = null;

            ApplicationUser user = _userManager.Users.Where(x => x.Id == userID).FirstOrDefault();

            if (user == null)
            {
                errorMsg = "USER_NOT_EXISTS";
                return false;
            }

            ApplicationUser userWithSameUserName = _userManager.Users.Where(x => x.Id != userID && x.UserName.ToLower() == userName.ToLower()).FirstOrDefault();

            if (userWithSameUserName != null)
            {
                errorMsg = "USERNAME_IN_USE";
                return false;
            }

            string actualRole = _userManager.GetRolesAsync(user).Result.FirstOrDefault();

            if (string.IsNullOrWhiteSpace(actualRole))
            {
                _logger.LogError("Role not found for edit user with ID {0}", userID);
                throw new DomainException("Role not found for user");
            }

            if (userName != user.UserName)
                _userManager.SetUserNameAsync(user, userName);

            if (actualRole != newRole.ToString())
            {
                _userManager.RemoveFromRoleAsync(user, actualRole);
                _userManager.AddToRoleAsync(user, newRole.ToString());
            }

            _logger.LogInformation("User with ID {0} edited. Name: {1}. Role: {2}", userID, userName, newRole.ToString());

            _userActionLogFacade.AddNewActionLog(ActionType.EditUser, string.Format("User with ID {0} edited. Name: {1}. Role: {2}", userID, userName, newRole.ToString()), loggedUserId, true);

            return true;
        }

        public void DeleteUser(string userID, string loggedUserId)
        {
            ApplicationUser userToDelete = _userManager.Users.FirstOrDefault(x => x.Id == userID);

            bool deleted = false;

            if (userToDelete != null)
            {
                ApplicationUser loggedUser = _userManager.Users.FirstOrDefault(x => x.Id == loggedUserId);

                string loggedRole = _userManager.GetRolesAsync(loggedUser).Result.FirstOrDefault();
                string userToDeleteRole = _userManager.GetRolesAsync(userToDelete).Result.FirstOrDefault();

                if (loggedRole == RoleType.SUPERADMIN.ToString() || (loggedRole == RoleType.ADMIN.ToString() && userToDeleteRole == RoleType.USER.ToString()))
                {
                    var result = _userManager.DeleteAsync(userToDelete).Result;

                    deleted = result.Succeeded;

                    if (deleted)
                        _logger.LogInformation("User with ID {0} deleted.", userID);
                    else
                        _logger.LogError("Error deleting user with id {0}. Errors: {1}", userID, string.Join(", ", result.Errors.Select(x => x.Description)));
                }
                else
                    _logger.LogWarning("Unauthorized user delete action. LoggedUserID: {0}. UserToDelete: {1}", loggedUserId, userID);
            }

            _userActionLogFacade.AddNewActionLog(ActionType.DeleteUser, string.Format("User with ID {0} deleted.", userID), loggedUserId, deleted);
        }

        private IEnumerable<UserInfo> ConvertApplicationUserToUserInfo(IEnumerable<ApplicationUser> users, UserManager<ApplicationUser> userManager)
        {
            foreach (var user in users)
            {
                RoleType role = Enum.Parse<RoleType>(userManager.GetRolesAsync(user).Result?.FirstOrDefault() ?? RoleType.Unknown.ToString());
                UserInfo us = new UserInfo
                {
                    Role = role,
                    UserID = user.Id,
                    UserName = user.UserName
                };

                yield return us;
            }
        }

        public async Task<IdentityResult> ChangeUserPasswordAsync(string targetUserId, string newPassword, string loggedInUserId)
        {
            _logger.LogInformation("Attempting to change password for target user {TargetUserId} by logged-in user {LoggedInUserId}", targetUserId, loggedInUserId);

            var targetUser = await _userManager.FindByIdAsync(targetUserId);
            if (targetUser == null)
            {
                _logger.LogWarning("Target user with ID {TargetUserId} not found.", targetUserId);
                _userActionLogFacade.AddNewActionLog(ActionType.ChangeUserPassword, $"Attempt to change password for non-existent target user ID {targetUserId}", loggedInUserId, false);
                return IdentityResult.Failed(new IdentityError { Code = "USER_NOT_FOUND", Description = "Target user not found." });
            }

            var loggedInUser = await _userManager.FindByIdAsync(loggedInUserId);
            if (loggedInUser == null)
            {
                // This case should ideally not be reached if JWT authentication is working correctly
                _logger.LogError("Logged-in user with ID {LoggedInUserId} not found. This indicates a potential issue.", loggedInUserId);
                // Not logging to userActionLogFacade as loggedInUserId might be compromised or invalid.
                return IdentityResult.Failed(new IdentityError { Code = "REQUESTER_NOT_FOUND", Description = "Logged-in user not found." });
            }

            var loggedInUserRoles = await _userManager.GetRolesAsync(loggedInUser);
            var targetUserRoles = await _userManager.GetRolesAsync(targetUser);

            RoleType loggedInUserRole = RoleType.Unknown;
            Enum.TryParse(loggedInUserRoles.FirstOrDefault(), out loggedInUserRole);

            RoleType targetUserRole = RoleType.Unknown;
            Enum.TryParse(targetUserRoles.FirstOrDefault(), out targetUserRole);

            _logger.LogInformation("Logged-in user {LoggedInUserName} (Role: {LoggedInUserRole}) is attempting to change password for target user {TargetUserName} (Role: {TargetUserRole})",
                loggedInUser.UserName, loggedInUserRole, targetUser.UserName, targetUserRole);

            if (loggedInUserRole == RoleType.SUPERADMIN)
            {
                if (targetUserRole == RoleType.SUPERADMIN)
                {
                    _logger.LogWarning("SUPERADMIN {LoggedInUserName} permission denied to change password for SUPERADMIN {TargetUserName}.", loggedInUser.UserName, targetUser.UserName);
                    _userActionLogFacade.AddNewActionLog(ActionType.ChangeUserPassword, $"Attempt by SUPERADMIN {loggedInUser.UserName} to change password for SUPERADMIN {targetUser.UserName} - DENIED", loggedInUserId, false);
                    return IdentityResult.Failed(new IdentityError { Code = "PERMISSION_DENIED", Description = "SuperAdmins cannot change other SuperAdmins' passwords." });
                }
                // SUPERADMIN can change ADMIN or USER passwords
            }
            else if (loggedInUserRole == RoleType.ADMIN)
            {
                if (targetUserRole == RoleType.ADMIN || targetUserRole == RoleType.SUPERADMIN)
                {
                    _logger.LogWarning("ADMIN {LoggedInUserName} permission denied to change password for {TargetUserRole} {TargetUserName}.", loggedInUser.UserName, targetUserRole, targetUser.UserName);
                    _userActionLogFacade.AddNewActionLog(ActionType.ChangeUserPassword, $"Attempt by ADMIN {loggedInUser.UserName} to change password for {targetUserRole} {targetUser.UserName} - DENIED", loggedInUserId, false);
                    return IdentityResult.Failed(new IdentityError { Code = "PERMISSION_DENIED", Description = "Admins can only change User passwords." });
                }
                // ADMIN can change USER passwords
            }
            else // USER or Unknown role
            {
                _logger.LogWarning("User {LoggedInUserName} (Role: {LoggedInUserRole}) has insufficient permissions to change passwords.", loggedInUser.UserName, loggedInUserRole);
                _userActionLogFacade.AddNewActionLog(ActionType.ChangeUserPassword, $"Attempt by user {loggedInUser.UserName} (Role: {loggedInUserRole}) to change password for {targetUser.UserName} - DENIED (Insufficient Permission)", loggedInUserId, false);
                return IdentityResult.Failed(new IdentityError { Code = "PERMISSION_DENIED", Description = "Insufficient permissions." });
            }

            // If permissions are valid, proceed to change password
            _logger.LogInformation("Permissions validated for {LoggedInUserName} to change password for {TargetUserName}. Proceeding with password change.", loggedInUser.UserName, targetUser.UserName);
            
            // Remove existing password. If the user has no password, this step might return errors, but AddPasswordAsync should still work.
            // It's safer to remove first to ensure the user doesn't end up with multiple password hashes if that's possible by the provider.
            var removePasswordResult = await _userManager.RemovePasswordAsync(targetUser);
            if (!removePasswordResult.Succeeded)
            {
                // Log if removal failed, but still attempt to add. Some providers might not require removal or handle it.
                _logger.LogWarning("Could not remove existing password for user {TargetUserName}. Errors: {Errors}. Proceeding to add new password.", 
                    targetUser.UserName, string.Join(", ", removePasswordResult.Errors.Select(e => e.Description)));
            }

            IdentityResult result = await _userManager.AddPasswordAsync(targetUser, newPassword);

            if (result.Succeeded)
            {
                _logger.LogInformation("Password successfully changed for user {TargetUserName} by {LoggedInUserName}.", targetUser.UserName, loggedInUser.UserName);
            }
            else
            {
                _logger.LogError("Failed to change password for user {TargetUserName} by {LoggedInUserName}. Errors: {Errors}", 
                    targetUser.UserName, loggedInUser.UserName, string.Join(", ", result.Errors.Select(e => e.Description)));
            }
            
            _userActionLogFacade.AddNewActionLog(ActionType.ChangeUserPassword, $"Attempt to change password for user {targetUser.UserName} by user {loggedInUser.UserName}. Success: {result.Succeeded}", loggedInUserId, result.Succeeded);

            return result;
        }
    }
}
