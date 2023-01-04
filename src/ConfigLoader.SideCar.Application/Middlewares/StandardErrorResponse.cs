namespace ConfigLoader.SideCar;

public class StandardErrorResponse : StandardResponse
{
    public IList<StatusDetail> StatusDetails { get; init; }
}