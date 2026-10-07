This folder contains the .NET Aspire AppHost, which starts the API and Angular frontend for local development. On each AppHost startup, there is a 50% chance of injecting a simulated client ID (`aws-demo-client`) and client secret (`FROM_AWS_SECRETS_MANAGER`) as if they came from AWS Secrets Manager. The `Authentication__ClientId` and `Authentication__ClientSecret` environment variables override the API's nested JSON configuration; `Authentication__Source` labels the simulated source. Otherwise, the local configuration remains in use.

The decision is logged without the values and stays fixed for that run. These are fake placeholders, not working OAuth credentials or a connection to AWS. The frontend displays the selected demo credentials and source. The API returns only allowlisted demo credential values; other values remain hidden.

Run the AppHost from the repository root:

```sh
dotnet run --project aspire/MyApp.AppHost/MyApp.AppHost.csproj
```

The AppHost starts the Aspire dashboard, API, and Angular frontend. You can also use `aspire run` from the repository root. Node.js and npm must be installed for the frontend.

Open `http://localhost:4200` to view the frontend. Its development proxy uses the API endpoint supplied by Aspire. Check the injected secret status at the API's `/api/secret-status` endpoint.