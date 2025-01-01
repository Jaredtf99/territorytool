using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace webapi.Migrations
{
    /// <inheritdoc />
    public partial class OnDeleteFixes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Territory_Person_PersonId",
                table: "Territory");

            migrationBuilder.DropForeignKey(
                name: "FK_Transaction_AspNetUsers_GivenBy",
                table: "Transaction");

            migrationBuilder.DropForeignKey(
                name: "FK_Transaction_AspNetUsers_PickedBy",
                table: "Transaction");

            migrationBuilder.DropForeignKey(
                name: "FK_Transaction_Person_PersonId",
                table: "Transaction");

            migrationBuilder.AddForeignKey(
                name: "FK_Territory_Person_PersonId",
                table: "Territory",
                column: "PersonId",
                principalTable: "Person",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_Transaction_AspNetUsers_GivenBy",
                table: "Transaction",
                column: "GivenBy",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Transaction_AspNetUsers_PickedBy",
                table: "Transaction",
                column: "PickedBy",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_Transaction_Person_PersonId",
                table: "Transaction",
                column: "PersonId",
                principalTable: "Person",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Territory_Person_PersonId",
                table: "Territory");

            migrationBuilder.DropForeignKey(
                name: "FK_Transaction_AspNetUsers_GivenBy",
                table: "Transaction");

            migrationBuilder.DropForeignKey(
                name: "FK_Transaction_AspNetUsers_PickedBy",
                table: "Transaction");

            migrationBuilder.DropForeignKey(
                name: "FK_Transaction_Person_PersonId",
                table: "Transaction");

            migrationBuilder.AddForeignKey(
                name: "FK_Territory_Person_PersonId",
                table: "Territory",
                column: "PersonId",
                principalTable: "Person",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Transaction_AspNetUsers_GivenBy",
                table: "Transaction",
                column: "GivenBy",
                principalTable: "AspNetUsers",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Transaction_AspNetUsers_PickedBy",
                table: "Transaction",
                column: "PickedBy",
                principalTable: "AspNetUsers",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Transaction_Person_PersonId",
                table: "Transaction",
                column: "PersonId",
                principalTable: "Person",
                principalColumn: "Id");
        }
    }
}
