using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace webapi.Migrations
{
    /// <inheritdoc />
    public partial class OnDeleteFixes2 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Transaction_Territory_TerritoryId",
                table: "Transaction");

            migrationBuilder.AddForeignKey(
                name: "FK_Transaction_Territory_TerritoryId",
                table: "Transaction",
                column: "TerritoryId",
                principalTable: "Territory",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Transaction_Territory_TerritoryId",
                table: "Transaction");

            migrationBuilder.AddForeignKey(
                name: "FK_Transaction_Territory_TerritoryId",
                table: "Transaction",
                column: "TerritoryId",
                principalTable: "Territory",
                principalColumn: "Id");
        }
    }
}
