using Serilog;
using System.Diagnostics.CodeAnalysis;

namespace ConfigLoader.SideCar.Application;

[ExcludeFromCodeCoverage]
public static class ApplicationExtensions
{
    /// <summary>
    /// This should be called in the beginning of the pipeline
    /// </summary>
    public static IApplicationBuilder AddCustomLogging(this IApplicationBuilder app)
    {
        app.UseMiddleware<LogEnrichingMiddleware>();
        app.UseSerilogRequestLogging();

        return app;
    }
}
