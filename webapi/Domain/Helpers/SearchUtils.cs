using System;
using System.Globalization;
using System.Linq;
using System.Text;
using TerritoryTool.ServerSide.Domain.Enums;

namespace TerritoryTool.ServerSide.Domain.Helpers
{
    public static class SearchUtils
    {
        // Score Constants
        private const int ScoreExactContains = 100;
        private const int ScorePrefixFull = 90;
        private const int ScoreFuzzyFull = 80;
        private const int ScorePrefixWord = 70;
        private const int ScoreFuzzyWord = 60;
        private const int ScoreNone = 0;
        
        private const int LevenshteinThreshold = 2;

        // Private helper struct for returning match details
        public struct MatchResult // Made public to be accessible by Repositories that will use CalculateMatchResult
        {
            public SearchMatchType MatchType { get; }
            public int Score { get; }

            public MatchResult(SearchMatchType matchType, int score)
            {
                MatchType = matchType;
                Score = score;
            }
        }

        public static string RemoveDiacritics(string text)
        {
            if (string.IsNullOrWhiteSpace(text))
                return string.Empty;

            var normalizedString = text.Normalize(NormalizationForm.FormD);
            var stringBuilder = new StringBuilder();

            foreach (var c in normalizedString)
            {
                var unicodeCategory = CharUnicodeInfo.GetUnicodeCategory(c);
                if (unicodeCategory != UnicodeCategory.NonSpacingMark)
                {
                    stringBuilder.Append(c);
                }
            }

            return stringBuilder.ToString().Normalize(NormalizationForm.FormC);
        }

        public static int LevenshteinDistance(string s, string t)
        {
            if (string.IsNullOrEmpty(s))
                return string.IsNullOrEmpty(t) ? 0 : t.Length;
            if (string.IsNullOrEmpty(t))
                return s.Length;

            int n = s.Length;
            int m = t.Length;
            int[,] d = new int[n + 1, m + 1];

            for (int i = 0; i <= n; d[i, 0] = i++) { }
            for (int j = 0; j <= m; d[0, j] = j++) { }

            for (int i = 1; i <= n; i++)
            {
                for (int j = 1; j <= m; j++)
                {
                    int cost = (t[j - 1] == s[i - 1]) ? 0 : 1;
                    d[i, j] = Math.Min(
                        Math.Min(d[i - 1, j] + 1, d[i, j - 1] + 1),
                        d[i - 1, j - 1] + cost);
                }
            }
            return d[n, m];
        }

        public static string[] TokenizeString(string text)
        {
            if (string.IsNullOrWhiteSpace(text))
            {
                return Array.Empty<string>();
            }
            // Split by space and filter out empty strings that may result from multiple spaces.
            // Other delimiters like hyphens could be added if needed, e.g., new char[] {' ', '-'}
            return text.Split(new char[] {' '}, StringSplitOptions.RemoveEmptyEntries);
        }

        public static MatchResult CalculateMatchResult(string rawSearchTerm, string rawTargetText)
        {
            if (string.IsNullOrWhiteSpace(rawSearchTerm) || string.IsNullOrWhiteSpace(rawTargetText))
            {
                return new MatchResult(SearchMatchType.None, ScoreNone);
            }

            string normalizedSearchTerm = RemoveDiacritics(rawSearchTerm.ToLowerInvariant());
            string normalizedTargetText = RemoveDiacritics(rawTargetText.ToLowerInvariant());

            if (string.IsNullOrWhiteSpace(normalizedSearchTerm) || string.IsNullOrWhiteSpace(normalizedTargetText)) // Re-check after normalization
            {
                 return new MatchResult(SearchMatchType.None, ScoreNone);
            }

            // Priority 1: Exact Contains
            if (normalizedTargetText.Contains(normalizedSearchTerm, StringComparison.Ordinal))
            {
                return new MatchResult(SearchMatchType.ExactContains, ScoreExactContains);
            }

            // Priority 2: Prefix on Full String
            if (normalizedTargetText.StartsWith(normalizedSearchTerm, StringComparison.Ordinal))
            {
                return new MatchResult(SearchMatchType.PrefixFull, ScorePrefixFull);
            }

            // Priority 3: Fuzzy Match on Full String
            if (LevenshteinDistance(normalizedSearchTerm, normalizedTargetText) <= LevenshteinThreshold)
            {
                return new MatchResult(SearchMatchType.FuzzyFull, ScoreFuzzyFull);
            }

            // Priority 4 & 5: Word-level matches
            string[] targetWords = TokenizeString(normalizedTargetText);
            SearchMatchType bestWordMatchType = SearchMatchType.None;
            int bestWordScore = ScoreNone;

            foreach (string word in targetWords)
            {
                // Word Prefix Match
                if (word.StartsWith(normalizedSearchTerm, StringComparison.Ordinal))
                {
                    if (ScorePrefixWord > bestWordScore) 
                    {
                        bestWordScore = ScorePrefixWord;
                        bestWordMatchType = SearchMatchType.PrefixWord;
                    }
                }
                // Fuzzy Word Match (only if not a better word prefix match already found for this or other word)
                // And only if current word didn't start with search term (to avoid double counting logic if prefix is also fuzzy)
                else if (LevenshteinDistance(normalizedSearchTerm, word) <= LevenshteinThreshold)
                {
                    if (ScoreFuzzyWord > bestWordScore)
                    {
                        bestWordScore = ScoreFuzzyWord;
                        bestWordMatchType = SearchMatchType.FuzzyWord;
                    }
                }
            }

            if (bestWordMatchType != SearchMatchType.None)
            {
                return new MatchResult(bestWordMatchType, bestWordScore);
            }

            return new MatchResult(SearchMatchType.None, ScoreNone);
        }
    }
}
