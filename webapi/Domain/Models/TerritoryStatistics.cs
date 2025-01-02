public class TerritoryStatistics
{
    public int TotalTerritories { get; set; }
    public int UsageRank { get; set; }
    public bool IsHighUsage { get; set; }
    public bool IsLowUsage { get; set; }

    public double AssignedTimePercentage { get; set; }
    public double GlobalAverageAssignedTimePercentage { get; set; }

    public double AverageReassignmentTime { get; set; }
    public double GlobalAverageReassignmentTime { get; set; }

    public double AverageHoldingTime { get; set; }
    public double GlobalAverageHoldingTime { get; set; }

    public double CurrentUnassignedTime { get; set; }

    public int UniqueUsersCount { get; set; }
    public double GlobalAverageUniqueUsersCount { get; set; }
} 