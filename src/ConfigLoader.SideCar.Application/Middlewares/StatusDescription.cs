namespace ConfigLoader.SideCar;

public static class StatusDescription
{
    public const string Error = "A server error occurred, please contact the application owner";
    public const string Timeout = "Sorry, timed out while processing the request, please try again or contact the application owner";
    public const string UnAuthorized = "Auth failure occurred (Unauthorized), Not authorized to access the resource";
    public const string Forbidden = "Auth failure occurred (Forbidden), Not authorized to access the resource";
}