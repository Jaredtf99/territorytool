namespace TerritoryTool.ServerSide.Persistence.Entities
{
    public class Person : Entity
    {
        public string Name { get; set; }
        public int? IdTerritory { get; set; }
    }
}
