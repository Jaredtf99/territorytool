namespace TerritoryTool.ServerSide.Controllers.Models.Person
{
    public class FilterTerritoriesModel
    {
        public string? Term { get; set; }
        public bool? InUse { get; set; }
        public FilterTerritoriesOrderByEnum? OrderBy { get; set; }
        public bool OrderByAscending { get; set; } = true;
    }
}
