using Xunit;
using Moq;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Domain.Enums;
using TerritoryTool.ServerSide.Domain.FacadeServices.Implementation;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using TerritoryTool.ServerSide.Persistence;
using TerritoryTool.ServerSide.Domain;

namespace webapi.Tests.Domain.FacadeServices
{
    public class UserConfigurationFacadeTests
    {
        private readonly Mock<UserManager<ApplicationUser>> _mockUserManager;
        private readonly Mock<ILogger<UserConfigurationFacade>> _mockLogger;
        private readonly Mock<IOptions<ApplicationSecrets>> _mockAppSettings;
        private readonly Mock<IUserActionLogFacade> _mockUserActionLogFacade;
        private readonly UserConfigurationFacade _facade;

        // Helper to create UserManager mock
        public static Mock<UserManager<TUser>> MockUserManager<TUser>() where TUser : class
        {
            var store = new Mock<IUserStore<TUser>>();
            // Add more mock setup for IUserPasswordStore, IUserRoleStore etc. if needed for other UserManager methods.
            // For ChangeUserPasswordAsync, we primarily need FindByIdAsync, GetRolesAsync, RemovePasswordAsync, AddPasswordAsync.

            var options = new Mock<IOptions<IdentityOptions>>();
            var idOptions = new IdentityOptions();
            idOptions.Lockout.AllowedForNewUsers = false;
            options.Setup(o => o.Value).Returns(idOptions);

            var userValidators = new List<IUserValidator<TUser>>();
            var pwdValidators = new List<IPasswordValidator<TUser>>();
            
            // Ensure UserValidator is generic for TUser
            userValidators.Add(new UserValidator<TUser>());
            // Ensure PasswordValidator is generic for TUser
            pwdValidators.Add(new PasswordValidator<TUser>());


            return new Mock<UserManager<TUser>>(store.Object, options.Object, new Mock<IPasswordHasher<TUser>>().Object,
                userValidators, pwdValidators, new Mock<ILookupNormalizer>().Object,
                new Mock<IdentityErrorDescriber>().Object, new Mock<IServiceProvider>().Object,
                new Mock<ILogger<UserManager<TUser>>>().Object);
        }


        public UserConfigurationFacadeTests()
        {
            _mockUserManager = MockUserManager<ApplicationUser>();
            _mockLogger = new Mock<ILogger<UserConfigurationFacade>>();
            _mockAppSettings = new Mock<IOptions<ApplicationSecrets>>();
            _mockAppSettings.Setup(x => x.Value).Returns(new ApplicationSecrets()); // Provide a default if needed
            _mockUserActionLogFacade = new Mock<IUserActionLogFacade>();

            _facade = new UserConfigurationFacade(
                _mockLogger.Object,
                _mockUserManager.Object,
                _mockAppSettings.Object,
                _mockUserActionLogFacade.Object
            );
        }

        private ApplicationUser CreateUser(string id, string userName) => new ApplicationUser { Id = id, UserName = userName };

        private void SetupUser(Mock<UserManager<ApplicationUser>> userManagerMock, ApplicationUser user, string role, string userIdToFind)
        {
            if (user != null && user.Id == userIdToFind)
            {
                userManagerMock.Setup(um => um.FindByIdAsync(userIdToFind)).ReturnsAsync(user);
                userManagerMock.Setup(um => um.GetRolesAsync(It.Is<ApplicationUser>(u => u.Id == userIdToFind))).ReturnsAsync(new List<string> { role });
            }
            else if (user == null && userIdToFind != null) // For user not found scenarios
            {
                 userManagerMock.Setup(um => um.FindByIdAsync(userIdToFind)).ReturnsAsync((ApplicationUser)null);
            }
        }


        [Theory]
        [InlineData(RoleType.SUPERADMIN, RoleType.ADMIN, true)] // SuperAdmin changes Admin
        [InlineData(RoleType.SUPERADMIN, RoleType.USER, true)]  // SuperAdmin changes User
        [InlineData(RoleType.ADMIN, RoleType.USER, true)]       // Admin changes User
        public async Task ChangeUserPasswordAsync_AllowedRoleChanges_Succeeds(RoleType loggedInRole, RoleType targetRole, bool shouldSucceed)
        {
            // Arrange
            var loggedInUser = CreateUser("loggedInUserId", "logger");
            var targetUser = CreateUser("targetUserId", "target");
            
            SetupUser(_mockUserManager, loggedInUser, loggedInRole.ToString(), "loggedInUserId");
            SetupUser(_mockUserManager, targetUser, targetRole.ToString(), "targetUserId");

            _mockUserManager.Setup(um => um.RemovePasswordAsync(targetUser)).ReturnsAsync(IdentityResult.Success);
            _mockUserManager.Setup(um => um.AddPasswordAsync(targetUser, "newPassword")).ReturnsAsync(IdentityResult.Success);

            // Act
            var result = await _facade.ChangeUserPasswordAsync("targetUserId", "newPassword", "loggedInUserId");

            // Assert
            Assert.Equal(shouldSucceed, result.Succeeded);
            if (shouldSucceed)
            {
                _mockUserManager.Verify(um => um.RemovePasswordAsync(targetUser), Times.Once);
                _mockUserManager.Verify(um => um.AddPasswordAsync(targetUser, "newPassword"), Times.Once);
                _mockUserActionLogFacade.Verify(log => log.AddNewActionLog(ActionType.ChangeUserPassword, It.IsAny<string>(), "loggedInUserId", true), Times.Once);
            }
        }

        [Theory]
        [InlineData(RoleType.SUPERADMIN, RoleType.SUPERADMIN, false)] // SuperAdmin cannot change SuperAdmin
        [InlineData(RoleType.ADMIN, RoleType.ADMIN, false)]          // Admin cannot change Admin
        [InlineData(RoleType.ADMIN, RoleType.SUPERADMIN, false)]     // Admin cannot change SuperAdmin
        [InlineData(RoleType.USER, RoleType.USER, false)]            // User cannot change User
        [InlineData(RoleType.USER, RoleType.ADMIN, false)]           // User cannot change Admin
        public async Task ChangeUserPasswordAsync_DisallowedRoleChanges_FailsWithPermissionDenied(RoleType loggedInRole, RoleType targetRole, bool shouldSucceed)
        {
            // Arrange
            var loggedInUser = CreateUser("loggedInUserId", "logger");
            var targetUser = CreateUser("targetUserId", "target");

            SetupUser(_mockUserManager, loggedInUser, loggedInRole.ToString(), "loggedInUserId");
            SetupUser(_mockUserManager, targetUser, targetRole.ToString(), "targetUserId");
            
            // Act
            var result = await _facade.ChangeUserPasswordAsync("targetUserId", "newPassword", "loggedInUserId");

            // Assert
            Assert.False(result.Succeeded);
            Assert.Contains(result.Errors, e => e.Code == "PERMISSION_DENIED");
            _mockUserActionLogFacade.Verify(log => log.AddNewActionLog(ActionType.ChangeUserPassword, It.IsAny<string>(), "loggedInUserId", false), Times.Once);
            _mockUserManager.Verify(um => um.AddPasswordAsync(It.IsAny<ApplicationUser>(), It.IsAny<string>()), Times.Never);
        }

        [Fact]
        public async Task ChangeUserPasswordAsync_TargetUserNotFound_FailsWithUserNotFound()
        {
            // Arrange
            var loggedInUser = CreateUser("loggedInUserId", "logger");
            SetupUser(_mockUserManager, loggedInUser, RoleType.SUPERADMIN.ToString(), "loggedInUserId");
            SetupUser(_mockUserManager, null, null, "targetUserId"); // Target user will not be found

            // Act
            var result = await _facade.ChangeUserPasswordAsync("targetUserId", "newPassword", "loggedInUserId");

            // Assert
            Assert.False(result.Succeeded);
            Assert.Contains(result.Errors, e => e.Code == "USER_NOT_FOUND");
            _mockUserActionLogFacade.Verify(log => log.AddNewActionLog(ActionType.ChangeUserPassword, It.Is<string>(s => s.Contains("non-existent target user ID targetUserId")), "loggedInUserId", false), Times.Once);
        }
        
        [Fact]
        public async Task ChangeUserPasswordAsync_LoggedInUserNotFound_FailsWithRequesterNotFound()
        {
            // Arrange
            // LoggedInUser is not found
            SetupUser(_mockUserManager, null, null, "loggedInUserId_NotFound"); 
            var targetUser = CreateUser("targetUserId", "target");
            SetupUser(_mockUserManager, targetUser, RoleType.USER.ToString(), "targetUserId");

            // Act
            var result = await _facade.ChangeUserPasswordAsync("targetUserId", "newPassword", "loggedInUserId_NotFound");

            // Assert
            Assert.False(result.Succeeded);
            Assert.Contains(result.Errors, e => e.Code == "REQUESTER_NOT_FOUND");
            // No action log for this specific internal error as per facade implementation
            _mockUserActionLogFacade.Verify(log => log.AddNewActionLog(It.IsAny<ActionType>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<bool>()), Times.Never);
        }


        [Fact]
        public async Task ChangeUserPasswordAsync_AddPasswordFails_ReturnsFailureAndLogs()
        {
            // Arrange
            var loggedInUser = CreateUser("loggedInUserId", "logger");
            var targetUser = CreateUser("targetUserId", "target");
            SetupUser(_mockUserManager, loggedInUser, RoleType.SUPERADMIN.ToString(), "loggedInUserId");
            SetupUser(_mockUserManager, targetUser, RoleType.USER.ToString(), "targetUserId");

            _mockUserManager.Setup(um => um.RemovePasswordAsync(targetUser)).ReturnsAsync(IdentityResult.Success);
            _mockUserManager.Setup(um => um.AddPasswordAsync(targetUser, "newPassword"))
                .ReturnsAsync(IdentityResult.Failed(new IdentityError { Code = "PasswordError" }));

            // Act
            var result = await _facade.ChangeUserPasswordAsync("targetUserId", "newPassword", "loggedInUserId");

            // Assert
            Assert.False(result.Succeeded);
            Assert.Contains(result.Errors, e => e.Code == "PasswordError");
            _mockUserActionLogFacade.Verify(log => log.AddNewActionLog(ActionType.ChangeUserPassword, It.IsAny<string>(), "loggedInUserId", false), Times.Once);
        }
        
        [Fact]
        public async Task ChangeUserPasswordAsync_RemovePasswordFails_StillAttemptsToAddPasswordAndSucceeds()
        {
            // Arrange
            var loggedInUser = CreateUser("loggedInUserId", "logger");
            var targetUser = CreateUser("targetUserId", "target");
            SetupUser(_mockUserManager, loggedInUser, RoleType.SUPERADMIN.ToString(), "loggedInUserId");
            SetupUser(_mockUserManager, targetUser, RoleType.USER.ToString(), "targetUserId");

            _mockUserManager.Setup(um => um.RemovePasswordAsync(targetUser))
                .ReturnsAsync(IdentityResult.Failed(new IdentityError { Code = "CannotRemove" })); // Remove fails
            _mockUserManager.Setup(um => um.AddPasswordAsync(targetUser, "newPassword"))
                .ReturnsAsync(IdentityResult.Success); // Add still succeeds

            // Act
            var result = await _facade.ChangeUserPasswordAsync("targetUserId", "newPassword", "loggedInUserId");

            // Assert
            Assert.True(result.Succeeded); // Overall success
            _mockUserManager.Verify(um => um.RemovePasswordAsync(targetUser), Times.Once);
            _mockUserManager.Verify(um => um.AddPasswordAsync(targetUser, "newPassword"), Times.Once);
            _mockUserActionLogFacade.Verify(log => log.AddNewActionLog(ActionType.ChangeUserPassword, It.IsAny<string>(), "loggedInUserId", true), Times.Once);
        }
    }
}
