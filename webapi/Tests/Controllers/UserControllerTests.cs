using Xunit;
using Moq;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;
using System.Security.Claims;
using System.Threading.Tasks;
using TerritoryTool.ServerSide.Controllers;
using TerritoryTool.ServerSide.Domain.FacadeServices.Interfaces;
using webapi.Controllers.Models.User; // Corrected namespace for ChangeUserPasswordModel
using TerritoryTool.ServerSide.Domain.Enums; // For RoleType

namespace webapi.Tests.Controllers
{
    public class UserControllerTests
    {
        private readonly Mock<IUserConfigurationFacade> _mockFacade;
        private readonly Mock<ILogger<ActionLogController>> _mockLogger; // Assuming ActionLogController's logger, adjust if UserController has its own
        private readonly UserController _controller;

        public UserControllerTests()
        {
            _mockFacade = new Mock<IUserConfigurationFacade>();
            _mockLogger = new Mock<ILogger<ActionLogController>>(); // Or ILogger<UserController> if specific
        }

        private UserController CreateControllerWithUser(string role, string userId = "test-user-id")
        {
            var claims = new[] { 
                new Claim(ClaimTypes.NameIdentifier, userId),
                new Claim(ClaimTypes.Role, role) 
            };
            var identity = new ClaimsIdentity(claims, "TestAuthType");
            var claimsPrincipal = new ClaimsPrincipal(identity);

            var controller = new UserController(_mockLogger.Object, _mockFacade.Object)
            {
                ControllerContext = new ControllerContext
                {
                    HttpContext = new DefaultHttpContext { User = claimsPrincipal }
                }
            };
            return controller;
        }

        [Fact]
        public async Task ChangeUserPassword_SuperAdminChangesUser_ReturnsOk()
        {
            // Arrange
            var controller = CreateControllerWithUser(RoleType.SUPERADMIN.ToString());
            var model = new ChangeUserPasswordModel { NewPassword = "newPassword123" };
            var targetUserId = "user-to-change-id";

            _mockFacade.Setup(f => f.ChangeUserPasswordAsync(targetUserId, model.NewPassword, "test-user-id"))
                .ReturnsAsync(IdentityResult.Success);

            // Act
            var result = await controller.ChangeUserPassword(targetUserId, model);

            // Assert
            _mockFacade.Verify(f => f.ChangeUserPasswordAsync(targetUserId, model.NewPassword, "test-user-id"), Times.Once);
            Assert.IsType<OkResult>(result);
        }

        [Fact]
        public async Task ChangeUserPassword_AdminChangesAdmin_ReturnsForbid()
        {
            // Arrange
            var controller = CreateControllerWithUser(RoleType.ADMIN.ToString(), "admin-user-id");
            var model = new ChangeUserPasswordModel { NewPassword = "newPassword123" };
            var targetUserId = "other-admin-id";
            var permissionDeniedError = new IdentityError { Code = "PERMISSION_DENIED", Description = "Permission denied." };

            _mockFacade.Setup(f => f.ChangeUserPasswordAsync(targetUserId, model.NewPassword, "admin-user-id"))
                .ReturnsAsync(IdentityResult.Failed(permissionDeniedError));

            // Act
            var result = await controller.ChangeUserPassword(targetUserId, model);

            // Assert
            _mockFacade.Verify(f => f.ChangeUserPasswordAsync(targetUserId, model.NewPassword, "admin-user-id"), Times.Once);
            Assert.IsType<ForbidResult>(result);
        }

        [Fact]
        public async Task ChangeUserPassword_UserNotFound_ReturnsNotFound()
        {
            // Arrange
            var controller = CreateControllerWithUser(RoleType.SUPERADMIN.ToString());
            var model = new ChangeUserPasswordModel { NewPassword = "newPassword123" };
            var targetUserId = "non-existent-user-id";
            var userNotFoundError = new IdentityError { Code = "USER_NOT_FOUND", Description = "User not found." };

            _mockFacade.Setup(f => f.ChangeUserPasswordAsync(targetUserId, model.NewPassword, "test-user-id"))
                .ReturnsAsync(IdentityResult.Failed(userNotFoundError));

            // Act
            var result = await controller.ChangeUserPassword(targetUserId, model);

            // Assert
            _mockFacade.Verify(f => f.ChangeUserPasswordAsync(targetUserId, model.NewPassword, "test-user-id"), Times.Once);
            var notFoundResult = Assert.IsType<NotFoundObjectResult>(result);
            Assert.Equal("USER_NOT_FOUND", notFoundResult.Value);
        }
        
        [Fact]
        public async Task ChangeUserPassword_InvalidUserId_ReturnsBadRequest()
        {
            // Arrange
            var controller = CreateControllerWithUser(RoleType.SUPERADMIN.ToString());
            var model = new ChangeUserPasswordModel { NewPassword = "newPassword123" };
            
            // Act
            var result = await controller.ChangeUserPassword(" ", model); // Invalid userId

            // Assert
            _mockFacade.Verify(f => f.ChangeUserPasswordAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()), Times.Never);
            var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
            Assert.Equal("INVALID_USER_ID", badRequestResult.Value);
        }


        [Fact]
        public async Task ChangeUserPassword_InvalidModel_ReturnsBadRequest()
        {
            // Arrange
            var controller = CreateControllerWithUser(RoleType.SUPERADMIN.ToString());
            var model = new ChangeUserPasswordModel { NewPassword = null }; // Invalid: NewPassword is required
            var targetUserId = "user-to-change-id";
            controller.ModelState.AddModelError("NewPassword", "Password is required");

            // Act
            var result = await controller.ChangeUserPassword(targetUserId, model);

            // Assert
            _mockFacade.Verify(f => f.ChangeUserPasswordAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()), Times.Never);
            var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
            Assert.Equal("INVALID_PASSWORD", badRequestResult.Value); // Based on controller logic
        }
        
        [Fact]
        public async Task ChangeUserPassword_FacadeReturnsNull_ReturnsInternalServerError()
        {
            // Arrange
            var controller = CreateControllerWithUser(RoleType.SUPERADMIN.ToString());
            var model = new ChangeUserPasswordModel { NewPassword = "newPassword123" };
            var targetUserId = "user-to-change-id";

            _mockFacade.Setup(f => f.ChangeUserPasswordAsync(targetUserId, model.NewPassword, "test-user-id"))
                .ReturnsAsync((IdentityResult)null); // Facade returns null

            // Act
            var result = await controller.ChangeUserPassword(targetUserId, model);

            // Assert
            _mockFacade.Verify(f => f.ChangeUserPasswordAsync(targetUserId, model.NewPassword, "test-user-id"), Times.Once);
            var statusCodeResult = Assert.IsType<ObjectResult>(result);
            Assert.Equal(500, statusCodeResult.StatusCode);
            Assert.Equal("Error processing request", statusCodeResult.Value);
        }
        
        [Fact]
        public async Task ChangeUserPassword_FacadeReturnsGeneralError_ReturnsBadRequestWithErrors()
        {
            // Arrange
            var controller = CreateControllerWithUser(RoleType.SUPERADMIN.ToString());
            var model = new ChangeUserPasswordModel { NewPassword = "newPassword123" };
            var targetUserId = "user-to-change-id";
            var errors = new[] { new IdentityError { Code = "Error1", Description = "Desc1" } };
            _mockFacade.Setup(f => f.ChangeUserPasswordAsync(targetUserId, model.NewPassword, "test-user-id"))
                .ReturnsAsync(IdentityResult.Failed(errors));

            // Act
            var result = await controller.ChangeUserPassword(targetUserId, model);

            // Assert
            _mockFacade.Verify(f => f.ChangeUserPasswordAsync(targetUserId, model.NewPassword, "test-user-id"), Times.Once);
            var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
            Assert.Equal(errors, badRequestResult.Value);
        }
    }
}
