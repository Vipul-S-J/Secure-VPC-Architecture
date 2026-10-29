# Production architecture: HMD account

Region: Europe (Stockholm), `eu-north-1`.
All resources below were created manually in the AWS console.
IP ranges, resource IDs, account IDs and bucket names are intentionally left out of this repo.

## Naming

Resources follow the pattern `<project>-<environment>-<resource>`.
With the defaults (`project = "app"`, `environment = "prod"`) the VPC is `app-prod-vpc`
and the EC2 role is `app-prod-ec2-role`.

## Architecture diagram

![HMD account architecture](architecture.png)

Editable source: [`architecture.drawio`](architecture.drawio). Open it in [draw.io](https://app.diagrams.net) and export it again as `architecture.png` after changes.

## Architectural considerations

1. Region: Stockholm.
2. All servers and databases are in private subnets. They are exposed to the internet only through load balancers.
3. An Application Load Balancer is the main endpoint for web users. It scales with traffic and adds a layer of protection in front of the application servers.
4. A NAT gateway gives the private subnets outbound internet access.
5. Instances run in the Stockholm region, with the required database connectivity.
6. S3 buckets hold static content.
7. Security groups allow only web/app traffic from outside. The DB layer accepts traffic only from the app layer.
8. AWS CloudTrail logs all activity in the account.
9. Application configuration was checked with the application team for the new environment.
10. EC2 instance family and size can be changed later based on load.

## VPC: `app-prod-vpc`

| Subnet | Tier | AZ |
|---|---|---|
| app-prod-public-1a | Public | eu-north-1a |
| app-prod-public-1b | Public | eu-north-1b |
| app-prod-private-1a | Private (app) | eu-north-1a |
| app-prod-private-1b | Private (app) | eu-north-1b |
| app-prod-db-1a | Private (DB) | eu-north-1a |
| app-prod-db-1b | Private (DB) | eu-north-1b |

## NAT gateway: `app-prod-nat`

- Created in a public subnet.
- Attached to the private route table `app-prod-private-rt`.

## CloudTrail: `app-prod-cloudtrail`

- Created in the Stockholm region.
- Multi-region trail.
- Logs go to a CloudWatch log group and to an S3 bucket.

## KMS: `alias/app-prod-key`

- Single-region key.
- Symmetric, used to encrypt and decrypt.

## ALB: `app-prod-alb`

- Internet-facing Application Load Balancer.
- Spread across the public subnets.
- Security group: `app-prod-alb-sg`.

## EFS: `app-prod-efs`

- Regional availability.

## App server base AMI: `app-prod-base-ami`

Built from this instance:

| Setting | Value |
|---|---|
| Name | app-prod-app |
| OS image | Amazon Linux |
| Architecture | x86_64 |
| Instance type | t3a.micro |
| Key pair | None (access through SSM) |
| Security group | app-prod-app-sg |
| Storage | 20 GB gp3 |
| IAM instance profile | app-prod-ec2-role |
| User data | [`user_data/app-server.sh`](../user_data/app-server.sh) (installs the SSM agent, CloudWatch agent and cron) |
