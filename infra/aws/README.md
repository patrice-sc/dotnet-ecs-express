This folder contains Terraform configuration for deploying the application to AWS. Keep AWS-specific infrastructure here; place configurations for other targets, such as Azure or Kubernetes, in sibling folders under `infra/` (for example, `infra/azure/` or `infra/kubernetes/`). Use `resources/terraform/` for reusable Terraform modules shared across environments.

## ECS Express Mode deployment

This root configuration calls the [reusable module](../../resources/terraform/ecs-express/README.md)
to create ECR, Aurora PostgreSQL Serverless v2, and an optional ECS Express Mode
service in an existing VPC. No AWS resources are created until you run apply.

### 1. Configure and bootstrap

Use Terraform >= 1.7, configure AWS credentials outside the repository, and run
these commands from this directory:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit the copied file with your region, VPC, and at least two private subnets in
different AZs. Replace the example database engine version with one available
for Aurora PostgreSQL Serverless v2 in that region:

```powershell
aws rds describe-db-engine-versions --engine aurora-postgresql --region eu-west-1 --query "DBEngineVersions[].EngineVersion"
aws rds describe-orderable-db-instance-options --engine aurora-postgresql --engine-version 16.6 --db-instance-class db.serverless --region eu-west-1
```

Check private routes, DNS, NAT/endpoints, and access from your intended clients;
the module does not create networking. The selected subnets are used by Express
Mode and Aurora. The resulting service is intended for private access.

```powershell
terraform init
terraform validate
terraform plan -out bootstrap.tfplan
terraform apply bootstrap.tfplan
```

Leave `deploy_service = false` for this first apply. It creates the repository,
database, and supporting resources without trying to pull an absent image.
Use an encrypted remote state backend with locking and restricted access for
shared environments; this example does not configure a backend. Do not commit
state, plans, credentials, or local tfvars. Commit the root provider lock file.

### 2. Load and push the pipeline image

Download and extract the `api` pipeline artifact. It contains `image.tar.gz`,
tagged `myapp-api:<Build.BuildId>` by the default .NET CI template. With Docker
and the AWS CLI installed, replace the example build ID below:

```powershell
$buildId = "42"
$repository = terraform output -raw ecr_repository_url
$registry = $repository.Split('/')[0]
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin $registry
docker load --input image.tar.gz
docker tag "myapp-api:$buildId" "${repository}:$buildId"
docker push "${repository}:$buildId"
```

Use your configured region and the CI template's actual repository/tag values.
Docker is needed for this manual load/push workflow, not for the SDK container
build. Alternatively, publish directly to ECR with the SDK in an authenticated
delivery pipeline. Immutable ECR tags cannot be overwritten.

### 3. Enable the service

Set `deploy_service = true` and `container_image_tag` to the pushed build ID in
your local tfvars, then:

```powershell
terraform plan -out deploy.tfplan
terraform apply deploy.tfplan
terraform output service_ingress_paths
```

The service uses the image digest, port 8080, and `/health`, and waits for healthy
tasks. Use a new tag for each release. The apply identity needs resource-creation
permissions, IAM role/policy management and `iam:PassRole`, as well as permission
to create necessary service-linked roles. IAM propagation can delay a first
deployment; inspect the AWS error and retry after propagation if necessary.

The API is not yet database-enabled. See the module's application contract for
least-privilege credentials, TLS, and database client requirements. Terraform
does not inject the database admin password.

Aurora deletion protection and final snapshots are enabled; ECR cannot be
destroyed while non-empty. Review the module's lifecycle section before teardown.