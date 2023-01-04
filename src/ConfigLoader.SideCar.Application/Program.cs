using System.Diagnostics.CodeAnalysis;
using Serilog;
using Serilog.Events;
using Steeltoe.Common;
using Steeltoe.Extensions.Configuration.Placeholder;
using Steeltoe.Extensions.Configuration.ConfigServer;
using Microsoft.FeatureManagement;

namespace ConfigLoader.SideCar.Application;

[ExcludeFromCodeCoverage]
public partial class Program
{
    public static void Main(string[] args)
    {
        CreateBootstrapLogger();

        try
        {
            Log.Information("Application is starting");

            var builder = WebApplication.CreateBuilder(args);

            //Configure services
            ConfigureAppConfiguration(args, builder);
            ConfigureAppConfigurationLogging(builder);

            builder.Services.AddOptions();
            builder.Services.AddControllers();
            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen();
            builder.Services.AddFeatureManagement(builder.Configuration);

            builder.Services.AddHostedService<ConfigFileRefresher>();

            var app = builder.Build();

            //Configure request pipeline
            app.AddCustomLogging();
            app.UseMiddleware<ErrorHandlerMiddleware>();
            if (app.Environment.IsDevelopment())
            {
                app.UseSwagger();
                app.UseSwaggerUI();
            }
            app.UseHttpsRedirection();
            app.UseAuthorization();
            app.MapControllers();
            app.Run();
        }
        catch (Exception exception)
        {
            Log.Fatal(exception, "Application failed to start");
        }
        finally
        {
            Log.CloseAndFlush();
        }

        static void ConfigureAppConfiguration(string[] args, WebApplicationBuilder builder)
        {
            builder.Configuration.AddUserSecrets<Program>(optional: true);
            builder.Configuration.AddEnvironmentVariables();
            builder.Configuration.AddJsonFile("appsettings.json", optional: false, reloadOnChange: false);
            builder.Configuration.AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: false);

            builder.Configuration.AddPlaceholderResolver();
            builder.Configuration.AddConfigServer(GetLoggerFactory());
            builder.Configuration.AddEnvironmentVariables();
            builder.Configuration.AddCommandLine(args);
        }

        static void ConfigureAppConfigurationLogging(WebApplicationBuilder builder)
        {
            builder.Logging.ClearProviders();
            builder.Host.UseSerilog((context, loggingConfiguration) =>
            {
                loggingConfiguration.ReadFrom.Configuration(context.Configuration);
            });
        }

        static void CreateBootstrapLogger()
        {
            var outputTemplate = "[{Timestamp:yyyy-MM-ddTMM-HH:mm:ss.fffzzz}] [{Level}] [{SourceContext}] {Properties} {PathBase} {EventId} {Message:lj}{NewLine}{Exception}";
            Log.Logger = new LoggerConfiguration()
                .MinimumLevel.Override("Microsoft", LogEventLevel.Information)
                .Enrich.FromLogContext()
                .WriteTo.Console(outputTemplate: outputTemplate)
                .WriteTo.Debug(outputTemplate: outputTemplate)
                .CreateBootstrapLogger();
        }

        static ILoggerFactory GetLoggerFactory()
        {
            var serviceCollection = new ServiceCollection();
            serviceCollection.AddLogging(builder => builder.AddSerilog(Log.Logger));
            return serviceCollection.BuildServiceProvider().GetService<ILoggerFactory>();
        }
    }
}









