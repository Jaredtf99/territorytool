public class PagedResult<T>
{
    public IEnumerable<T> data { get; set; }
    public int TotalCount { get; set; }
    public int PageNumber { get; set; }
    public int PageSize { get; set; }
    public int last_page => (int)Math.Ceiling((double)TotalCount / PageSize);
} 