
using System.Dynamic;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Primitives;

namespace ConfigLoader.SideCar.Application;

public class ConfigFileRefresher : BackgroundService
{
    private readonly IConfiguration _configuration;
    private readonly IChangeToken _changeToken;
    private readonly IHostApplicationLifetime _lifetime;
    private readonly ILogger<ConfigFileRefresher> _logger;
    private readonly CancellationToken _cancellationToken;

    public ConfigFileRefresher(
        IConfiguration configuration, 
        IHostApplicationLifetime lifetime,
        ILogger<ConfigFileRefresher> logger)
    {
        _configuration = configuration;
        _changeToken = _configuration.GetReloadToken();
        _lifetime = lifetime;
        _logger = logger;
        _cancellationToken = lifetime.ApplicationStopping;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        CreateConfigurationFiles();
        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(TimeSpan.FromMinutes(15), stoppingToken);
            if(_changeToken.HasChanged)
            {
                _logger.LogInformation("Configuration has changed!");
                CreateConfigurationFiles();
            }
        }
    }

    private void CreateConfigurationFiles()
    {
        var filePath = _configuration["CONFIG_FOLDER_PATH"];
		var fileName = _configuration["CONFIG_FILE_NAME"];

        _logger.LogInformation($"Creating configuration file {Path.Combine(filePath, fileName)}");

        var configExpando = new ExpandoObject();

        foreach (var config in _configuration.AsEnumerable())
        {
            configExpando.TryAdd(config.Key, config.Value);
        }

        JsonSerializerOptions options = new() { DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
			PropertyNamingPolicy = JsonNamingPolicy.CamelCase
		};

		var jsonString = JsonSerializer.Serialize(configExpando, options);

        if (!Directory.Exists(filePath))
        {
            Directory.CreateDirectory(filePath);
        }

        System.IO.File.WriteAllText(Path.Combine(filePath, fileName), jsonString);
    }
}