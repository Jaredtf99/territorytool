namespace TerritoryTool.ServerSide.Domain.Enums
{
    public enum SearchMatchType
    {
        None = 0,            // No match or lowest priority
        ExactContains = 1,   // Highest priority - an exact match or the search term is fully contained
        PrefixFull = 2,      // Matches the prefix of the full string
        FuzzyFull = 3,       // Fuzzy match on the full string
        PrefixWord = 4,      // Matches the prefix of a word within the string
        FuzzyWord = 5        // Fuzzy match on a word within the string 
                             // Lower value means higher priority / better match type
    }
}
