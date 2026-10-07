# .NET ECS Express

This is an end-to-end learning sandbox: keep the sample application deliberately small, and use it to explore selected software delivery and operations practices—from client experience and data collection to data lineage and deployment.

The [topic list](https://github.com/patrice-sc/README#readme-ov-file) is a menu of possible explorations, not a required checklist.

The current structure includes a .NET API, an Angular frontend, and a .NET Aspire AppHost. Infrastructure is separated by deployment target so additional environments can be added without mixing provider-specific configuration.

## Repository layout

- `src/MyApp.ApiService/` — server-side .NET API.
- `src/myapp-spa/` — Angular frontend.
- `aspire/MyApp.AppHost/` — .NET Aspire AppHost for configuring and orchestrating application services.
- `infra/aws/` — AWS-specific infrastructure configuration. Add other targets, such as Azure or Kubernetes, in their own subfolders under `infra/`.
- `resources/terraform/` — reusable Terraform modules shared across deployment targets.
- `resources/azuredevops/` — reusable Azure DevOps pipeline templates.

Keep deployment configuration specific to a provider under `infra/<target>/`; keep shared building blocks under `resources/`.
