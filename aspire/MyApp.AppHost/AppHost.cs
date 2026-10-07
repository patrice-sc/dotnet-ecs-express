var builder = DistributedApplication.CreateBuilder(args);

var api = builder.AddProject<Projects.MyApp_ApiService>("apiservice");

if (Random.Shared.Next(2) == 0)
{
    api.WithEnvironment("Authentication__ClientId", "aws-demo-client")
        .WithEnvironment("Authentication__ClientSecret", "FROM_AWS_SECRETS_MANAGER")
        .WithEnvironment("Authentication__Source", "AWS Secrets Manager (simulated)");
    Console.WriteLine("Simulated secret injection enabled for this run.");
}
else
{
    Console.WriteLine("Simulated secret injection skipped for this run; using the API configuration fallback.");
}

builder.AddJavaScriptApp("myapp-spa", "../../src/myapp-spa", "start")
    .WithEnvironment("API_URL", api.GetEndpoint("http"))
    .WithHttpEndpoint(port: 4200, targetPort: 4200, isProxied: false)
    .WaitFor(api);

builder.Build().Run();
