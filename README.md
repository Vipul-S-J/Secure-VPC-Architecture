# AWS infrastructure (eu-north-1, Stockholm)

Terraform code for the production environment shown below.

![Architecture](docs/architecture.png)

## How to create the resources

### 1. Install the tools

- [Terraform](https://developer.hashicorp.com/terraform/install) 1.10 or newer
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

```bash
terraform version
aws --version
```

### 2. Log in to the AWS account

```bash
aws configure --profile myaccount      # enter access key, secret key, region eu-north-1
export AWS_PROFILE=myaccount
aws sts get-caller-identity            # shows the account ID you are logged in to
```

### 3. Download the code

```bash
git clone <repository-url>
cd <repository-folder>
```

### 4. Fill in your values

```bash
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` and replace every `<...>` placeholder:

| Variable | What to enter |
|---|---|
| `aws_account_id` | The account ID from step 2 |
| `vpc_cidr` | IP range of the VPC, e.g. `10.0.0.0/16` |
| `subnet_cidrs` | 6 ranges inside the VPC range, e.g. `10.0.0.0/24` … `10.0.5.0/24` |
| `user_static_bucket_name`, `cloudtrail_bucket_name`, `config_bucket_name` | 3 S3 bucket names that are unique worldwide |
| `alert_emails` | Email addresses that receive alerts |
| `openvpn_ami_id` | OpenVPN Access Server AMI from AWS Marketplace, or set `create_openvpn = false` |
| `vpn_client_cidrs`, `vpn_admin_cidrs` | IP ranges allowed to use the VPN and its admin page |

Leave a value as `""` for optional features you don't use (HTTPS certificate, VPC peering).

### 5. Create the resources

```bash
terraform init                  # downloads the AWS provider
terraform validate              # checks the code
terraform plan -out=tfplan      # shows what will be created
terraform apply tfplan          # creates everything (about 15–25 minutes)
```

Check the last line of `terraform plan` before applying. It should say
`<number> to add, 0 to change, 0 to destroy`.

### 6. See the results

```bash
terraform output
```

This shows the ALB address, RDS endpoint, VPC ID, NAT IP and other values you need next.

### 7. After creating

- Confirm the subscription email that AWS sends to each address in `alert_emails`.
- Get the database password:

  ```bash
  aws secretsmanager get-secret-value \
    --secret-id "$(terraform output -raw rds_master_secret_arn)" \
    --query SecretString --output text
  ```

- Connect to the app server (no SSH key needed):

  ```bash
  aws ssm start-session --target "$(terraform output -raw app_instance_id)"
  ```

- For VPC peering: share `vpc_id` with the other side, put the `pcx-...` ID they send you in
  `terraform.tfvars`, then run `terraform plan -out=tfplan` and `terraform apply tfplan` again.

### 8. Delete everything (when no longer needed)

1. Set `enable_deletion_protection = false` in `alb.tf` and `deletion_protection = false` in `rds.tf`, then run `terraform apply`.
2. Empty the 3 S3 buckets in the S3 console.
3. Run `terraform destroy`.

More detail on every step, optional settings and common errors: **[INSTRUCTIONS.md](INSTRUCTIONS.md)**.

## Files

| File | Creates |
|---|---|
| `vpc.tf` | VPC, 6 subnets, internet gateway, NAT gateway, route tables |
| `vpc_peering.tf` | Accepts VPC peering from the partner and database provider VPCs |
| `security_groups.tf` | Security groups for ALB, app server, EFS, RDS and OpenVPN |
| `kms.tf` | KMS encryption key |
| `cloudtrail.tf` | CloudTrail with S3 bucket and CloudWatch log group |
| `alb.tf` | Application Load Balancer, target group, listeners |
| `efs.tf` | EFS file system and mount targets |
| `iam.tf` | IAM role for EC2 |
| `ec2.tf`, `user_data/app-server.sh` | App server and optional base AMI |
| `s3.tf` | S3 bucket for user static data |
| `rds.tf` | RDS MySQL database |
| `monitoring.tf` | SNS alerts and CloudWatch alarms |
| `guardduty.tf` | GuardDuty |
| `config.tf` | AWS Config |
| `openvpn.tf` | OpenVPN server |
| `variables.tf`, `terraform.tfvars.example` | Input values |
| `outputs.tf` | Values shown after `apply` |
| `docs/` | Architecture diagram (`.png`, editable `.drawio`) and description |
