using Microsoft.AspNetCore.Mvc;

namespace ConfigLoader.SideCar;

public class StatusDetail
{
    public string FieldName { get; init; }

    public string Description { get; init; }

    public ProblemDetails ProblemDetails { get; init; }
}
