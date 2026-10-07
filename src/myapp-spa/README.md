This folder contains the Angular frontend for the application.

The front page displays the server greeting, version, uptime, and simulated client credentials with their source. Only known demo placeholders are displayed; other credential values are hidden by the API.

## Run locally

To start both the API and frontend together, run `aspire run` from the repository root. Node.js and npm must be installed. The frontend is available at `http://localhost:4200`, and its proxy uses the API endpoint supplied by Aspire.

Alternatively, run the services separately from this directory:

Start the API in one terminal:

```sh
dotnet run --project ../MyApp.ApiService/MyApp.ApiService.csproj
```

Then install dependencies and start the Angular development server in this folder:

```sh
npm install
npm start
```

Open `http://localhost:4200`. The development server proxies `/api` requests to the API at `http://localhost:5000`.