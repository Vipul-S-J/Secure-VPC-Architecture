# kh_hmd production architecture: HMD account

Region: Europe (Stockholm), `eu-north-1`.
All resources below were created manually in the AWS console.

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

## HMD account services (from the architecture diagram)

CloudWatch, SNS, CloudTrail, GuardDuty, Config, KMS, S3 (user static data), RDS MySQL,
VPC peering with the KaHa VPC, VPC peering with the MongoDB Atlas VPC, OpenVPN for KaHa DevOps.

## VPC

| Name | CIDR |
|---|---|
| kh_hmd-eu-pd-vpc | 10.91.0.0/17 |

| Subnet | CIDR |
|---|---|
| kh_hmd-pd-1a-pub-subnet | 10.91.0.0/23 |
| kh_hmd-pd-1b-pub-subnet | 10.91.2.0/23 |
| kh_hmd-pd-1a-pvt-subnet | 10.91.4.0/23 |
| kh_hmd-pd-1b-pvt-subnet | 10.91.6.0/23 |
| kh_hmd-pd-db-1a-pvt-subnet | 10.91.8.0/23 |
| kh_hmd-pd-db-1b-pvt-subnet | 10.91.10.0/23 |

## NAT gateway: `kh_hmd-eu-pd-pub-nat`

- Created in a public subnet.
- Attached to the private route table `kh_hmd-pd-pvt-rtb`.

## CloudTrail: `kh_hmd-eu-pd-cloudtrail`

- Created in the Stockholm region.
- Multi-region trail.
- Logs go to the CloudWatch log group `kh_hmd-eu-pd-cloudtrail-logs`.
- Logs are stored in the S3 bucket `khmd-eu-pd-cloudtrail-logs`.

## KMS: `kh_hmd-prod-eu-key`

- Single-region key.
- Symmetric, used to encrypt and decrypt.

## ALB: `khmd-eu-pd-ELB`

- Internet-facing Application Load Balancer.
- Spread across the public subnets.
- Security group: `kh_hmd-eu-pd-elb-sg`.

## EFS: `khmd-eu-pd-app-srv-efs` (fs-06610e73d51fe5c59)

- Regional availability.

## AMI: `khmd-srv-base-ami`

Built from this instance:

| Setting | Value |
|---|---|
| Name | khmd-eu-pd-app-srv |
| OS image | Amazon Linux |
| Architecture | x86_64 |
| Instance type | t3a.micro |
| Key pair | None |
| VPC | kh_hmd-eu-pd-vpc |
| Security group | khmd-eu-pd-app-srv-sg |
| Storage | 20 GB gp3 |
| IAM instance profile | KhmdPdEc2BasicRole |
| User data | [`user_data/app-server.sh`](../user_data/app-server.sh) (installs the SSM agent, CloudWatch agent and cron) |
