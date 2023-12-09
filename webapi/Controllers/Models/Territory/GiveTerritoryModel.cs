namespace TerritoryTool.ServerSide.Controllers.Models.Person
{
    public class GiveTerritoryModel
    {
        public string TerritoryCode { get; set; }
        public string PersonName { get; set; }
        public bool IsCustomDate { get; set; }
        public DateTime? CustomDate { get; set; }
    }
}
