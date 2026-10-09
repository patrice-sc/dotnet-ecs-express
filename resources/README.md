This folder contains reusable resources shared across application components. Store reusable Terraform modules in `terraform/` and Azure DevOps templates in `azuredevops/`. Keep environment-specific deployment configurations under `infra/`, organized by target (for example, `infra/aws/`, `infra/azure/`, or `infra/kubernetes/`).

See [Azure DevOps pipeline building blocks](azuredevops/README.md) for the reusable .NET and Angular CI templates, their parameters, and artifact layout.

See [ECS Express Mode infrastructure](terraform/ecs-express/README.md) for a reusable AWS module provisioning ECR, an Express Mode service, and Aurora PostgreSQL in an existing VPC.
