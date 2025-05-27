using TerritoryTool.ServerSide.Domain.Enums;

namespace TerritoryTool.ServerSide.Domain.Classes
{
    public class SearchResultItem<T>
    {
        public T Item { get; set; }
        public int Score { get; set; } // Higher is better
        public SearchMatchType MatchType { get; set; }

        public SearchResultItem(T item, int score, SearchMatchType matchType)
        {
            Item = item;
            Score = score;
            MatchType = matchType;
        }
    }
}
