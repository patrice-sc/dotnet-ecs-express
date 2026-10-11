# Minimal AWS Terraform starter

This configuration manages **one empty ECR repository**. It does not call the
full [ECS Express module](../../resources/terraform/ecs-express/README.md), start
containers, create networking, or provision a database. Empty ECR repositories
have no image storage charges; S3 state requests/storage can incur small charges.

## Run in Azure DevOps

1. Install the Microsoft DevLabs
   [Terraform extension](https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks)
   in your Azure DevOps organization. This is an Azure Pipelines extension, not
   a VS Code extension.
2. Create an AWS service connection named `aws-terraform-dev`, configure its
   region as `eu-west-3`, and authorize it for this pipeline. Do not store
   credentials in YAML.
3. Confirm that `devops-594109395220-eu-west-3-an` is an existing S3 bucket in
   `eu-west-3`. Enable bucket versioning, block public access, and restrict access
   to the deployment identity. The starter does not create or manage this bucket.
4. Create a YAML pipeline pointing at
   [azure-pipelines-terraform.yml](../../azure-pipelines-terraform.yml).
5. Run it with the defaults to install Terraform, check formatting, initialize
   S3 state, validate, and plan. Select **apply** when ready to create the
   repository. The apply step consumes that run's saved plan in the same job.

The pipeline is manual (`trigger: none`, `pr: none`) and defaults to plan-only.
It uses the [reusable AWS step template](../../resources/azuredevops/terraform-aws.yml)
and state key `dotnet-ecs-express/aws-starter/terraform.tfstate`, separate from
the full AWS deployment. Plan-only initialization can still write provider/state
metadata and acquire a lock in S3, but does not create ECR resources.

The service connection needs `s3:ListBucket` on the bucket;
`s3:GetObject` and `s3:PutObject` on the state and its `.tflock` object; and
`s3:DeleteObject` on the lock object. If the bucket requires a customer-managed
KMS key, also grant its required decrypt/encrypt/data-key permissions.
For ECR, allow `ecr:CreateRepository`, `ecr:DescribeRepositories`,
`ecr:ListTagsForResource`, and `ecr:DeleteRepository` for cleanup, scoped to
the starter repository where supported. SCPs or permission boundaries may
impose additional requirements.

Use a different state key for each independent deployment. Do not run concurrent
applies to the same key; S3 native locking protects state, and an overlapping
saved plan can be rejected as stale. Do not publish state or saved plans as
unrestricted build artifacts. Keep this repository separate from the full ECS
deployment; Terraform must not manage the same AWS resource in two states.

## Local credential-free checks

From the repository root:

```powershell
terraform -chdir=infra/aws-starter fmt -check -recursive
terraform -chdir=infra/aws-starter init -backend=false -input=false
terraform -chdir=infra/aws-starter validate
terraform -chdir=infra/aws-starter test
```

Tests use a mocked AWS provider. They exercise apply and input validation
without AWS credentials, contacting AWS, or creating real resources. Commit
the generated provider lock file; the pipeline uses it read-only.

## Cleanup

Using credentials authorized for the same account and region:

```powershell
terraform -chdir=infra/aws-starter init -reconfigure -backend-config="bucket=devops-594109395220-eu-west-3-an" -backend-config="key=dotnet-ecs-express/aws-starter/terraform.tfstate" -backend-config="region=eu-west-3"
terraform -chdir=infra/aws-starter plan -destroy -out=destroy.tfplan
terraform -chdir=infra/aws-starter apply destroy.tfplan
```

If you changed the pipeline region/name, supply the same values with
`TF_VAR_aws_region` and `TF_VAR_repository_name`. Deletion fails if images were
pushed; `force_delete` is deliberately disabled. Destroy removes only the ECR
repository, not the existing state bucket.
