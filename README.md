# .NET ECS Express

This is an end-to-end learning sandbox: keep the sample application deliberately small, and use it to explore selected software delivery and operations practices—from client experience and data collection to data lineage and deployment.

The [topic list](https://github.com/patrice-sc/README#readme-ov-file) is a menu of possible explorations, not a required checklist.

The initial experiment explores [startup secret injection with Aspire and AWS Secrets Manager](docs/experiments/aspire-secret-injection.md), mimicking ECS Fargate configuration injection. It currently uses local placeholders; retrieval using a developer's AWS credentials is a planned extension.

The current structure includes a .NET API, an Angular frontend, and a .NET Aspire AppHost. Infrastructure is separated by deployment target so additional environments can be added without mixing provider-specific configuration.

Run the Aspire application from the repository root with:

```sh
dotnet run --project aspire/MyApp.AppHost/MyApp.AppHost.csproj
```

`DotnetEcsExpress.sln` includes the AppHost and API projects for opening or building the solution in an IDE.

You can also run `aspire run` from the repository root. The AppHost starts both the API and Angular frontend; open `http://localhost:4200`. Node.js and npm are required for the frontend.

## Local API proxy and CORS

The Angular development server uses [proxy.conf.cjs](src/myapp-spa/proxy.conf.cjs) to forward `/api/**` requests to the API endpoint supplied by Aspire, or to `http://localhost:5000` when running separately. The browser makes same-origin requests to the frontend, so no API CORS configuration is needed for this local workflow.

This proxy is only used by the development server; it is not included in the production build. A deployment must either provide equivalent same-origin routing through a reverse proxy or configure API CORS for the intended frontend origin.

## Repository layout

- `src/MyApp.ApiService/` — server-side .NET API.
- `src/myapp-spa/` — Angular frontend.
- `aspire/MyApp.AppHost/` — .NET Aspire AppHost for starting the API and Angular frontend and demonstrating secret-parameter injection.
- `infra/aws/` — AWS-specific infrastructure configuration. Add other targets, such as Azure or Kubernetes, in their own subfolders under `infra/`.
- `resources/terraform/` — reusable Terraform modules shared across deployment targets.
- `resources/azuredevops/` — reusable Azure DevOps pipeline templates.

Keep deployment configuration specific to a provider under `infra/<target>/`; keep shared building blocks under `resources/`.

## Continuous integration

[azure-pipelines.yml](azure-pipelines.yml) runs parallel .NET and Angular CI jobs
using the [reusable Azure DevOps templates](resources/azuredevops/README.md).
The jobs build the Aspire/API solution, an API container using the .NET SDK
(no Dockerfile required), and the production frontend, then upload `api`
(container image archive) and `spa` pipeline artifacts. Test execution is configurable but currently
disabled because the sample has no test suites. Deployment is not included.

## AWS infrastructure

The [AWS Terraform configuration](infra/aws/README.md) uses the
[ECS Express Mode module](resources/terraform/ecs-express/README.md) to provision
ECR, an ECS Express Mode service, and Aurora PostgreSQL Serverless v2 in existing
private subnets. Bootstrap ECR and the database first, push the CI container
image, then enable the service. The sample API does not yet query the database.
