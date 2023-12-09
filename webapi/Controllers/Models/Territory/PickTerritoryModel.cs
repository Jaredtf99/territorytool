namespace TerritoryTool.ServerSide.Controllers.Models.Person
{
    public class PickTerritoryModel
    {
        public string TerritoryCode { get; set; }
        public bool IsCustomDate { get; set; }
        public DateTime? CustomDate { get; set; }
    }
}
