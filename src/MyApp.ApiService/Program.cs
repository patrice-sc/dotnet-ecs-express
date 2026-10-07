using System.Diagnostics;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddProblemDetails();

var app = builder.Build();
var startedAt = Stopwatch.GetTimestamp();
var version = typeof(Program).Assembly.GetName().Version?.ToString(3)
    ?? throw new InvalidOperationException("The application assembly version is not available.");

app.UseExceptionHandler();
app.UseStatusCodePages();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapGet("/health", () => TypedResults.Ok(new HealthResponse("ok")))
    .WithName("GetHealth")
    .WithSummary("Check API health")
    .WithDescription("Returns an OK status when the API is responding.")
    .Produces<HealthResponse>(StatusCodes.Status200OK);

app.MapGet("/api/hello", () => TypedResults.Ok(new HelloResponse(
        "Hello, world!",
        version,
        Stopwatch.GetElapsedTime(startedAt).TotalSeconds)))
    .WithName("GetHello")
    .WithSummary("Get the greeting and server details")
    .WithDescription("Returns a greeting, the server application version, and its current uptime in seconds.")
    .Produces<HelloResponse>(StatusCodes.Status200OK);

app.MapGet("/api/secret-status", () =>
    {
        var clientId = builder.Configuration["Authentication:ClientId"];
        var clientSecret = builder.Configuration["Authentication:ClientSecret"];
        var isConfigured = !string.IsNullOrWhiteSpace(clientId) && !string.IsNullOrWhiteSpace(clientSecret);
        var source = isConfigured ? builder.Configuration["Authentication:Source"] : "Not configured";

        return TypedResults.Ok(new SecretStatusResponse(
            isConfigured,
            source,
            clientId is "local-demo-client" or "aws-demo-client" ? clientId : null,
            clientSecret is "FROM_APPSETTINGS" or "FROM_AWS_SECRETS_MANAGER" ? clientSecret : null));
    })
    .WithName("GetSecretStatus")
    .WithSummary("Check whether simulated client credentials are configured")
    .WithDescription("Reports credential status and source, returning only allowlisted demo credential values.")
    .Produces<SecretStatusResponse>(StatusCodes.Status200OK);

app.Run();

/// <summary>Represents the API health status.</summary>
public sealed record HealthResponse(string Status);

/// <summary>Represents the greeting and server runtime details.</summary>
public sealed record HelloResponse(string Message, string Version, double UptimeSeconds);

/// <summary>Indicates whether both simulated client credentials are configured.</summary>
public sealed record SecretStatusResponse(bool IsConfigured, string? Source, string? ClientId, string? ClientSecret);
