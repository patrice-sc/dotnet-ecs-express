This folder contains the server-side .NET API for the application.

## Run locally

From this directory, run:

```sh
dotnet run
```

The API listens at `http://localhost:5000`. Check its health with `GET /health`, or fetch the greeting, server version, and uptime with `GET /api/hello`. In development, the OpenAPI document is available at `/openapi/v1.json`.

`appsettings.json` contains a simulated `Authentication` configuration with `ClientId` set to `local-demo-client` and `ClientSecret` set to `FROM_APPSETTINGS`. On 50% of AppHost startups, environment variables `Authentication__ClientId` and `Authentication__ClientSecret` override both values with simulated AWS credentials. The double underscore maps to nested JSON configuration keys.

`GET /api/secret-status` reports whether both credentials are configured and the labeled source. It returns only the allowlisted demo client IDs (`local-demo-client`, `aws-demo-client`) and secrets (`FROM_APPSETTINGS`, `FROM_AWS_SECRETS_MANAGER`) for display on the frontend; other credential values are returned as `null`. These are fake placeholders, not working OAuth credentials; no authentication or AWS connection is implemented. Never store real client secrets in committed configuration.