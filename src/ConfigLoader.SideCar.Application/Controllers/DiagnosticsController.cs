using Microsoft.AspNetCore.Mvc;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.FeatureManagement.Mvc;

namespace ConfigLoader.SideCar.Application;

[ApiController]
[Route("[controller]")]
[FeatureGate(FeatureFlags.EnableDiagnostics)] 
public class DiagnosticsController : ControllerBase
{
    private IConfigurationRoot _config { get; set; }

    private readonly ILogger<DiagnosticsController> _logger;

    public DiagnosticsController(ILogger<DiagnosticsController> logger, IConfiguration config)
    {
        _logger = logger;
        _config = config as IConfigurationRoot;
    }

    [HttpGet("/config")]
    public IActionResult GetAppConfig()
    {
        var configdata = _config.AsEnumerable();
        return Ok(configdata);
    }

    [HttpGet("/config/{key}")]
    public IActionResult GetConfig(string key)
    {
        return Ok($"Config returned for {key} is `{_config[key]}`");
    }
}