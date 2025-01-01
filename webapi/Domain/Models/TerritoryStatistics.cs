public class TerritoryStatistics
{
    public int TotalTerritories { get; set; }
    public int UsageRank { get; set; }  // Posición en ranking de uso
    public double AssignedTimePercentage { get; set; }  // Porcentaje de tiempo asignado
    public double AverageReassignmentTime { get; set; }  // Tiempo promedio que tarda en reasignarse
    public double CurrentUnassignedTime { get; set; }  // En días
    public int UnassignedTimeRank { get; set; }  // Posición en ranking de tiempo sin asignar
    public double AverageHoldingTime { get; set; }  // Promedio de días que cada persona mantiene el territorio
    public bool IsHighUsage { get; set; }  // Si está en el top 25% de uso
    public bool IsLowUsage { get; set; }  // Si está en el bottom 25% de uso
    public double UsageFrequencyDays { get; set; }  // Promedio de días entre cada uso
    public string LastUsedAgo { get; set; }  // Tiempo desde el último uso (ej: "2 meses")
    public int TotalTimesUsed { get; set; }  // Número total de veces que se ha usado
    public double AverageHoldingTimeVsGlobal { get; set; }  // % por encima/debajo de la media global
    public double ReassignmentTimeVsGlobal { get; set; }  // % por encima/debajo de la media global
    public bool IsQuicklyReassigned { get; set; }  // Si se reasigna más rápido que la media
    public bool IsLongHeld { get; set; }  // Si se mantiene más tiempo que la media
} 