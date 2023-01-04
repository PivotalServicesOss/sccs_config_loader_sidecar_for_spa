using System.Text.Json.Serialization;

namespace ConfigLoader.SideCar;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum Status
{
    Success,
    Failed,
    Timeout,
    Error,
    AuthFailure
}
