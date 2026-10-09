# ECS Express Mode, ECR, and Aurora PostgreSQL

Reusable AWS module for a containerized HTTP API in an **existing VPC**:

- Immutable-tag ECR repository with scan-on-push and encryption.
- ECS cluster and Express Mode service with AWS-managed load balancing and
  scaling, execution/infrastructure IAM roles, and a separate unprivileged task role.
- CloudWatch logs with 30-day retention.
- Private Aurora PostgreSQL Serverless v2 cluster, encrypted storage, seven-day
  backups, and two instances across Availability Zones.
- Database security group allowing PostgreSQL only from the application security
  group. Application port 8080 accepts traffic from the supplied subnet CIDRs
  so Express Mode's generated load balancer can perform requests and health checks.

This is PostgreSQL-compatible, **not Cassandra-compatible**. The deployment
example is under [infra/aws](../../../infra/aws/README.md).

## Requirements and inputs

Terraform >= 1.7 and AWS provider >= 6.68, < 7. The caller configures the provider
and AWS authentication; this module contains no provider configuration.

| Input | Default | Purpose |
| --- | --- | --- |
| `name` | Required | Unique lowercase resource prefix, 3-31 characters. |
| `vpc_id` | Required | Existing VPC. |
| `private_subnet_ids` | Required | At least two private subnets across two AZs in that VPC. |
| `database_engine_version` | Required | Region-supported Aurora PostgreSQL Serverless v2 version. |
| `database_name` | `myapp` | Initial database. |
| `database_instance_count` | `2` | One to three instances; two enables a failover reader. |
| `deploy_service` | `false` | Enable only after pushing an image. |
| `container_image_tag` | `initial` | Existing ECR image tag, resolved to a digest. |
| `tags` | `{}` | Resource tags. |

The module checks VPC membership, AZ diversity, and disabled automatic public
IP assignment. It does not change or fully validate the existing route tables.
Provide private routes with NAT or all needed VPC endpoints for ECR API/Docker,
S3 image layers, CloudWatch Logs, and other runtime AWS dependencies. Enable
VPC DNS support and DNS hostnames. Network ACLs must allow the required traffic.
The private subnet choice is intended for private service access, not an
internet-facing application. Inspect `service_ingress_paths` after deployment;
clients need network connectivity to its private endpoint.

## Container and application contract

The image must target Linux/x64, listen on port 8080, and return HTTP 200 at
`/health`. This matches the .NET SDK container pipeline and sample API.
`deploy_service = true` reads the image from this module's ECR repository and
deploys its digest; a missing image fails rather than silently using another.
Service creation waits for steady state.

The container receives `PGHOST`, `PGPORT`, `PGDATABASE`, and
`PGSSLMODE=verify-full` as non-secret connection metadata. These are not an
automatic .NET/Npgsql connection string. The current API has no database client,
schema, migrations, or queries; none are added by this infrastructure module.

RDS generates and rotates the administrator password in Secrets Manager.
Terraform exports only the secret ARN, never reads the secret value, and does
not inject administrator credentials into application tasks. Before adding
database functionality, provision a least-privilege application database user
through an authorized database administration workflow, store its credentials
in a separate secret, and wire scoped ECS secret injection and execution-role
permissions. Configure the database client with the AWS RDS CA trust bundle
and hostname verification. Injected credentials require task replacement after
rotation; do not put passwords in tfvars or plaintext environment variables.

## Outputs and lifecycle

Outputs include the ECR URL, Express service ARN/ingress paths, database
endpoint/port, admin secret ARN, and application security group ID. Service
outputs are null/empty until `deploy_service` is enabled.

Aurora deletion protection is on, and a final snapshot is required. Planned
teardown requires an intentional code change to disable deletion protection
and an apply before destroy. The final snapshot name is `<name>-final`; remove
or rename an existing snapshot before a later teardown with the same prefix.
ECR rejects deletion while it contains images. These protections are deliberate.
Expect charges for Aurora, Fargate, load balancing, logs, and existing networking
even in this small configuration. Serverless capacity is 0.5-2 ACUs per instance;
this configuration does not auto-pause.

## Local validation

From this directory:

```powershell
terraform init -backend=false
terraform validate
terraform test
```

Tests use a mock AWS provider: bootstrap, container deployment, database safety
settings, and invalid networking are checked without AWS credentials or cloud
resource creation. They do not prove live AWS reachability, regional engine
availability, or deployment permissions.

References:
[Express Mode](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/express-service-overview.html),
[provider resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_express_gateway_service),
[required IAM roles](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/express-service-getting-started.html).
