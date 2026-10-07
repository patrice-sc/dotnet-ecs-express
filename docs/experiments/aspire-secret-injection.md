# Experiment: startup secret injection with Aspire and AWS Secrets Manager

## Purpose

Explore how .NET Aspire can inject settings into an ASP.NET Core application before it starts, mimicking how Amazon ECS on AWS Fargate injects secrets into a container at startup.

The intended local workflow is for the Aspire AppHost to retrieve a client ID and client secret from AWS Secrets Manager using the developer's AWS credentials, then pass those values to the API as environment variables. The API should consume ordinary ASP.NET Core configuration without needing to know whether the values came from local settings or AWS.

## Current implementation

The experiment currently simulates retrieval; it does not call AWS or use a developer AWS account.

- The [API settings](../../src/MyApp.ApiService/appsettings.json) provide a fake local client ID and the `FROM_APPSETTINGS` client secret.
- On each startup, the [AppHost](../../aspire/MyApp.AppHost/AppHost.cs) has a 50% chance of injecting a fake client ID and the `FROM_AWS_SECRETS_MANAGER` placeholder.
- Injection uses `Authentication__ClientId` and `Authentication__ClientSecret`. ASP.NET Core maps double underscores to nested configuration keys and gives environment variables precedence over JSON settings.
- When injection is skipped, the local settings remain active. This random choice is a demonstration device, not an AWS failure-handling strategy.
- The frontend displays the selected source and only allowlisted demo credential values. Real client secrets must never be sent to a browser.

## Intended AWS-backed extension

1. Authenticate locally using the developer's AWS profile or temporary credentials, with permission to read the designated development secret.
2. Have the AppHost retrieve the values from AWS Secrets Manager before starting the API.
3. Inject them through the same environment-variable keys, keeping the API independent of AWS-specific retrieval logic.
4. Surface retrieval failures explicitly rather than silently falling back to local credentials when AWS retrieval is requested.

Do not commit AWS credentials or real secret values, print them in logs, or expose them through API responses. Use a dedicated development secret and least-privilege access.

## Developer onboarding without exchanging secret files

Another goal of the AWS-backed extension is to avoid developers exchanging `.env` files, uncommitted configuration files, or copied credentials. Each developer should authenticate using their own AWS identity with access to the designated development secret; the AppHost can then retrieve and inject the required values at startup.

Commit only non-sensitive configuration, such as configuration key names and setup instructions. Keep real values in Secrets Manager and local AWS authentication material outside the repository. Ignoring a file in Git does not make sharing it safe. Centralized retrieval reduces manual copying and stale local values, but still requires appropriate access permissions and a restart to pick up rotated secrets.

## How this relates to ECS Fargate

In ECS, a task definition can reference Secrets Manager secrets for injection into container environment variables. ECS retrieves the secrets using the task execution role, rather than the developer's local AWS credentials.

The shared behavior being explored is the configuration boundary: secret values are supplied before the application starts, overriding its local defaults. Aspire orchestrates local processes here; it does not reproduce the ECS runtime or IAM model.

Startup injection does not automatically refresh a running application's environment when a secret rotates. In ECS, new tasks must be started to receive updated values; the local experiment likewise needs a restart to inject new values.

## Success criteria

- Without injection, the API uses the local demo settings.
- With injection, both client ID and client secret override the JSON defaults.
- The API reads the same configuration keys in both modes.
- An AWS-backed implementation uses developer credentials only in the local retrieval layer and does not expose real secrets to the frontend.
