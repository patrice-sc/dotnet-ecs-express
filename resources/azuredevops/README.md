# Azure DevOps pipeline building blocks

These reusable **step templates** provide CI for the .NET API/Aspire solution and
Angular frontend. The root [pipeline](../../azure-pipelines.yml) runs them in
parallel jobs on Microsoft-hosted Ubuntu agents for branch pushes and pull
requests. Azure Repos Git requires a branch-policy build validation rule instead
of the YAML `pr` trigger.

## .NET: `dotnet-ci.yml`

Installs the SDK, restores and builds the solution, runs the supplied test
projects, builds an application container with the .NET SDK's `PublishContainer`
target, and uploads the image archive as a pipeline artifact. No Dockerfile,
Docker daemon, or registry credentials are required.

| Parameter | Default | Purpose |
| --- | --- | --- |
| `solution` | Required | Repository-relative solution path. |
| `publishProject` | Required | Repository-relative application project path. |
| `sdkVersion` | `10.0.x` | SDK version accepted by `UseDotNet@2`. |
| `configuration` | `Release` | Build, test, and publish configuration. |
| `testProjects` | `[]` | List of test project paths or globs included in the solution build. |
| `runtimeIdentifier` | `linux-x64` | Target OS and architecture for the containerized application. |
| `containerRepository` | `myapp-api` | Container image repository name (lowercase). |
| `containerImageTag` | `$(Build.BuildId)` | Container image tag, unique per pipeline run by default. |
| `artifactName` | `api` | Output directory name and pipeline artifact name. |

The sample currently has no .NET test projects, so `testProjects` is empty.
When adding tests, include their projects in the solution and pass their paths:

```yaml
steps:
- template: resources/azuredevops/dotnet-ci.yml
  parameters:
    solution: DotnetEcsExpress.sln
    publishProject: src/MyApp.ApiService/MyApp.ApiService.csproj
    testProjects:
    - tests/MyApp.ApiService.Tests/MyApp.ApiService.Tests.csproj
```

Test results are published by `DotNetCoreCLI@2`. The API artifact contains
`image.tar.gz`, a container image archive that can be loaded with
`docker load --input image.tar.gz`. The SDK selects the matching ASP.NET Core
base image for this Web SDK project. The container publish step restores and
builds for the selected runtime separately from the solution build, so its
runtime-specific assets are available. The agent needs network access to NuGet
and the base-image registry.

The Aspire AppHost is built, not started or packaged as a deployment target.
No local or simulated secrets are injected, and the image is not pushed to a
registry. Supply runtime configuration and secrets when deploying the container.

## Angular: `angular-ci.yml`

Installs Node.js, restores locked dependencies with `npm ci`, optionally runs
Karma tests once in headless Chrome, builds Angular, and uploads the output.

| Parameter | Default | Purpose |
| --- | --- | --- |
| `workingDirectory` | Required | Repository-relative directory containing `package.json` and `package-lock.json`. |
| `nodeVersion` | `22.x` | Node.js version accepted by `NodeTool@0`. |
| `configuration` | `production` | Angular build configuration. |
| `runTests` | `true` | Run the project's existing `npm test` script in headless Chrome. |
| `artifactName` | `spa` | Output directory name and pipeline artifact name. |

The root pipeline explicitly sets `runTests: false` because the sample currently
has no Angular test specs. Change it to `true` when specs are added. Test failures
fail the job; this template does not configure a JUnit reporter or upload test
results. Agents running tests must have Chrome installed (Microsoft-hosted Ubuntu
agents do). The build step uses Bash and therefore requires a Linux agent.

The sample's `spa` artifact contains the Angular output, with static site files
under `browser/`. Serve that directory and provide same-origin `/api` routing
or appropriate API CORS configuration; the development proxy is not packaged.

## Usage and boundaries

Create an Azure DevOps YAML pipeline pointing at `azure-pipelines.yml`. No cloud
service connection is required for CI. Each template assumes a normal repository
checkout and should run once per job; use unique artifact names if reusing them.
Template paths are relative to the YAML file referencing them, so adjust paths
when calling these templates from another folder.

Artifact upload uses `PublishPipelineArtifact@1`, which is supported by Azure
DevOps Services, not Azure DevOps Server. Deployment, credentials, registry pushes,
and Terraform execution are intentionally outside these CI templates. Keep
target-specific deployment configuration under `infra/<target>/`.
