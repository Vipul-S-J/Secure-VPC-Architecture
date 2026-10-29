# Instructions: creating the resources with Terraform

This guide builds the whole architecture in an **empty AWS account** (or an account
that has none of these resources yet).

> **Do not run this against the account where the resources were built by hand.**
> Terraform doesn't know about resources created in the console. It would try to
> build a second copy and fail partway on names that already exist.
> To manage existing resources, see [Section 10](#10-using-the-code-with-resources-that-already-exist).

## Contents

1. [What gets created](#1-what-gets-created)
2. [Prerequisites](#2-prerequisites)
3. [Get the code](#3-get-the-code)
4. [Optional: store the state in S3](#4-optional-store-the-state-in-s3)
5. [Fill in the variables](#5-fill-in-the-variables)
6. [Create the resources](#6-create-the-resources)
7. [After the first apply](#7-after-the-first-apply)
8. [Check that everything works](#8-check-that-everything-works)
9. [Making changes later](#9-making-changes-later)
10. [Using the code with resources that already exist](#10-using-the-code-with-resources-that-already-exist)
11. [Deleting everything](#11-deleting-everything)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. What gets created

All resources are created in `eu-north-1` (Stockholm) and named
`<project>-<environment>-<resource>`, for example `app-prod-vpc`.

| Area | Resources |
|---|---|
| Network | VPC, 2 public, 2 private and 2 DB subnets, internet gateway, NAT gateway with Elastic IP, 3 route tables |
| Peering | Accepts peering requests from a partner VPC and a database provider VPC, and adds routes (optional) |
| Security | Security groups for ALB, app server, EFS, RDS and OpenVPN; the default security group is emptied |
| Encryption | One KMS key (with yearly rotation) used for EBS, EFS, RDS, S3, SNS, CloudTrail and CloudWatch Logs |
| Load balancer | Internet-facing ALB, target group, HTTP listener, HTTPS listener if a certificate is given |
| Compute | App server (EC2), IAM role and instance profile, optional base AMI |
| Storage | EFS with mount targets in both private subnets, S3 bucket for user static data |
| Database | RDS MySQL (Multi-AZ by default), master password kept in Secrets Manager |
| Logging and security services | CloudTrail (multi-region) to S3 and CloudWatch Logs, AWS Config, GuardDuty |
| Monitoring | SNS alerts topic, email subscriptions, CloudWatch alarms for EC2, ALB and RDS |
| VPN | OpenVPN server in a public subnet with an Elastic IP (optional) |

**Cost:** these resources are billed as soon as they exist. The largest monthly costs are
the NAT gateway, the ALB, RDS (doubled with Multi-AZ), the OpenVPN license from
AWS Marketplace, AWS Config and GuardDuty. Check prices for your region before you start.

---

## 2. Prerequisites

### Tools

| Tool | Version | Check with |
|---|---|---|
| Terraform | 1.10 or newer | `terraform version` |
| AWS CLI | v2 | `aws --version` |
| Git | any | `git --version` |

The AWS provider version is pinned in `.terraform.lock.hcl` (provider `~> 6.0`).

### AWS access

You need credentials for the target account with permission to create IAM roles,
KMS keys, VPC, EC2, ELB, RDS, EFS, S3, CloudTrail, Config, GuardDuty, SNS and
CloudWatch resources. An administrator role is the simplest option.

Set up a CLI profile and check that it points to the right account:

```bash
aws configure --profile <profile-name>        # or: aws configure sso
export AWS_PROFILE=<profile-name>
aws sts get-caller-identity                    # note the "Account" value
```

### Check the account is empty for these services

Some services allow only one instance per region. If they already exist, `apply` fails.

```bash
# Must return an empty list: only one AWS Config recorder is allowed per region
aws configservice describe-configuration-recorders --region eu-north-1

# Must return an empty list: only one GuardDuty detector is allowed per region
aws guardduty list-detectors --region eu-north-1
```

If either already exists, remove `config.tf` or `guardduty.tf` from your copy, or import
the existing one (see [Section 10](#10-using-the-code-with-resources-that-already-exist)).

### Things to prepare before you start

| Item | Needed for | How to get it |
|---|---|---|
| VPC and subnet CIDRs | Network | Choose ranges that don't overlap with the partner or database provider VPCs |
| 3 globally unique S3 bucket names | S3, CloudTrail, Config | Lowercase letters, digits and hyphens only |
| ACM certificate ARN in `eu-north-1` | HTTPS on the ALB (optional) | AWS Certificate Manager → Request certificate |
| OpenVPN AMI ID | OpenVPN server (optional) | See below |
| Alert email addresses | SNS alerts | Any mailbox your team reads |

**OpenVPN AMI.** The code expects an AMI that already has OpenVPN on it, for example
*OpenVPN Access Server* from AWS Marketplace:

1. Open AWS Marketplace in the console, search for **OpenVPN Access Server**, and subscribe.
2. Find the AMI ID for `eu-north-1`:

   ```bash
   aws ec2 describe-images --region eu-north-1 --owners aws-marketplace \
     --filters "Name=name,Values=OpenVPN Access Server*" \
     --query 'sort_by(Images,&CreationDate)[-1].[ImageId,Name]' --output text
   ```

If you don't need the VPN, set `create_openvpn = false` and skip this.

---

## 3. Get the code

```bash
git clone <repository-url>
cd <repository-folder>
```

---

## 4. Optional: store the state in S3

Terraform keeps a **state file** that maps the code to real resources. By default it is
saved as `terraform.tfstate` in the project folder. That's fine for one person, but if you
lose it Terraform can't manage the resources any more. For a team, store it in S3.

**4.1 Create the state bucket once** (choose your own globally unique name):

```bash
STATE_BUCKET=<state-bucket-name>
aws s3api create-bucket --bucket "$STATE_BUCKET" --region eu-north-1 \
  --create-bucket-configuration LocationConstraint=eu-north-1
aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$STATE_BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

**4.2 Create a file `backend.tf`** in the project folder:

```hcl
terraform {
  backend "s3" {
    bucket       = "<state-bucket-name>"
    key          = "prod/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true   # prevents two people running apply at the same time
  }
}
```

> The state file contains resource IDs and other details of your account.
> Never commit it to Git. `.gitignore` already excludes `*.tfstate`.

---

## 5. Fill in the variables

Copy the template:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` and replace every `<...>` placeholder.
`terraform.tfvars` is listed in `.gitignore`, so your real values stay out of Git.

**Important:** for optional features you don't use, set the value to an empty string `""`.
Leaving a placeholder such as `"<ACM_CERTIFICATE_ARN>"` makes Terraform treat it as a real value.

### Required

| Variable | Example | Notes |
|---|---|---|
| `aws_account_id` | `"123456789012"` | Terraform refuses to run in any other account |
| `vpc_cidr` | `"10.0.0.0/16"` | |
| `subnet_cidrs` | see template | 6 ranges inside `vpc_cidr` that don't overlap |
| `user_static_bucket_name` | `"mycompany-prod-user-static"` | Globally unique |
| `cloudtrail_bucket_name` | `"mycompany-prod-cloudtrail-logs"` | Globally unique |
| `config_bucket_name` | `"mycompany-prod-config-logs"` | Globally unique |
| `openvpn_ami_id` | `"ami-..."` | Only while `create_openvpn = true` |

### Optional (defaults shown)

| Variable | Default | Notes |
|---|---|---|
| `project` / `environment` | `"app"` / `"prod"` | Used in every resource name |
| `region` | `"eu-north-1"` | |
| `partner_peering_connection_id` / `partner_vpc_cidr` | `""` | Fill in after the first apply, see [Section 7.3](#73-vpc-peering) |
| `db_provider_peering_connection_id` / `db_provider_cidr` | `""` | Same as above |
| `certificate_arn` | `""` | Empty = HTTP only. With a certificate, HTTP redirects to HTTPS |
| `app_port` / `health_check_path` | `80` / `"/"` | Must match the application |
| `app_instance_type` | `"t3a.micro"` | |
| `app_ami_id` | `""` | Empty = latest Amazon Linux 2023 |
| `create_base_ami` | `false` | See [Section 7.4](#74-optional-create-the-base-ami) |
| `db_engine_version` | `"8.4"` | |
| `db_instance_class` | `"db.t4g.micro"` | |
| `db_allocated_storage` / `db_max_allocated_storage` | `20` / `100` | GB |
| `db_multi_az` | `true` | `false` halves the RDS cost but removes failover |
| `db_name` / `db_username` | `"appdb"` / `"admin"` | The password is generated by RDS |
| `log_retention_days` | `365` | CloudWatch Logs retention |
| `alert_emails` | `[]` | Each address gets a confirmation email |
| `create_openvpn` | `true` | |
| `openvpn_instance_type` | `"t3a.small"` | |
| `openvpn_key_name` | `null` | Optional EC2 key pair; SSM works without one |
| `vpn_client_cidrs` | `[]` | Who can connect to the VPN, e.g. `["0.0.0.0/0"]`. Empty = nobody |
| `vpn_admin_cidrs` | `[]` | Who can open the admin UI on port 943, e.g. your office IP `/32` |

---

## 6. Create the resources

Run all commands from the project folder.

**6.1 Download the provider (once, and after changing `backend.tf`):**

```bash
terraform init
```

**6.2 Check formatting and syntax:**

```bash
terraform fmt -check
terraform validate
```

**6.3 Preview the changes:**

```bash
terraform plan -out=tfplan
```

Read the summary at the end: `Plan: <number> to add, 0 to change, 0 to destroy.`
The number depends on which optional features you turned on.
On a fresh account it should only add. If it shows anything to change or destroy,
stop and find out why before going further.

**6.4 Create the resources:**

```bash
terraform apply tfplan
```

This takes about **15–25 minutes**. RDS (especially Multi-AZ) and the NAT gateway take the longest.

**6.5 Show the outputs:**

```bash
terraform output
```

| Output | Use |
|---|---|
| `vpc_id` | Give this to the partner and the database provider for peering |
| `alb_dns_name` | Point your domain (CNAME or Route 53 alias) here |
| `nat_public_ip` | Outbound IP of the private subnets; whitelist it at external providers |
| `app_instance_id` | For SSM sessions |
| `rds_endpoint` | Database host for the application |
| `rds_master_secret_arn` | Where the MySQL master password is stored |
| `efs_id` / `efs_dns_name` | For mounting EFS on the app server |
| `openvpn_public_ip` | VPN server address |
| `kms_key_arn`, `user_static_bucket`, `alerts_topic_arn` | Reference |

---

## 7. After the first apply

### 7.1 Confirm the alert emails

Each address in `alert_emails` receives an email from AWS Notifications.
Click **Confirm subscription**, or that address gets no alerts.

### 7.2 Get the database password

```bash
aws secretsmanager get-secret-value \
  --secret-id "$(terraform output -raw rds_master_secret_arn)" \
  --query SecretString --output text
```

RDS rotates this password automatically (every 7 days by default).
Applications should read it from Secrets Manager instead of copying it.

### 7.3 VPC peering

The code **accepts** peering requests. It doesn't send them. For each peer:

1. Give the other side your `vpc_id`, your AWS account ID, the region `eu-north-1` and your `vpc_cidr`.
2. They create the peering request from their side. You get a `pcx-...` ID.
3. Add it to `terraform.tfvars`:

   ```hcl
   partner_peering_connection_id = "pcx-..."
   partner_vpc_cidr              = "<partner VPC CIDR>"

   db_provider_peering_connection_id = "pcx-..."
   db_provider_cidr                  = "<provider VPC CIDR>"
   ```

4. Run `terraform plan` and then `terraform apply`. This accepts the peering, adds routes in the
   private and DB route tables, and allows MySQL from the partner VPC.
5. The other side must also add a route back to your `vpc_cidr` in their route tables.

### 7.4 Optional: create the base AMI

After the app server is set up the way you want, set `create_base_ami = true` and run
`terraform apply`. This creates the AMI `<project>-<environment>-base-ami`.
To launch new servers from it, put its ID in `app_ami_id`.

### 7.5 Deploy the application

The user data script (`user_data/app-server.sh`) only installs the SSM agent, the CloudWatch agent
and cron. It doesn't install the application. The ALB target will show as **unhealthy** until the
application answers on `app_port` at `health_check_path`.

Connect to the server without SSH:

```bash
aws ssm start-session --target "$(terraform output -raw app_instance_id)"
```

To mount EFS on the server (inside the session):

```bash
sudo dnf install -y amazon-efs-utils
sudo mkdir -p /mnt/efs
sudo mount -t efs -o tls <efs_id>:/ /mnt/efs
```

### 7.6 Set up OpenVPN

Connect to the OpenVPN server through SSM, or open `https://<openvpn_public_ip>:943/admin`
from an address in `vpn_admin_cidrs`. Then follow the OpenVPN Access Server setup to create users.
The VPN clients connect on UDP 1194 or TCP 443 from addresses in `vpn_client_cidrs`.

---

## 8. Check that everything works

| Check | How |
|---|---|
| No pending changes | `terraform plan` shows `No changes.` |
| ALB answers | `curl -I http://$(terraform output -raw alb_dns_name)` |
| Target healthy | EC2 console → Target groups → `<project>-<environment>-app-tg` → Targets |
| SSM works | `aws ssm start-session --target <app_instance_id>` opens a shell |
| Database reachable | From the app server: `mysql -h <rds_endpoint host> -u admin -p` |
| CloudTrail logging | CloudTrail console → Trails → status **Logging** |
| Config recording | Config console → Settings → recording **On** |
| GuardDuty enabled | GuardDuty console → Summary |
| Alarms present | CloudWatch console → Alarms |

---

## 9. Making changes later

1. Edit the `.tf` files or `terraform.tfvars`.
2. `terraform fmt` and `terraform validate`.
3. `terraform plan -out=tfplan`. Read every change carefully.
   Lines marked `-/+` or `must be replaced` delete and recreate the resource.
   For RDS, EFS or S3 that can mean **data loss**.
4. `terraform apply tfplan`.
5. Commit the code changes to Git (never `terraform.tfvars` or state files).

Don't change these resources in the console once Terraform manages them.
The next `plan` would show the console change as drift and try to undo it.

---

## 10. Using the code with resources that already exist

If the resources were created by hand, Terraform must **import** them before it can manage them.

1. Create `imports.tf` with one block per existing resource:

   ```hcl
   import {
     to = aws_vpc.main
     id = "vpc-0123456789abcdef0"
   }

   import {
     to = aws_subnet.public["1a"]
     id = "subnet-0123456789abcdef0"
   }

   import {
     to = aws_efs_file_system.app
     id = "fs-0123456789abcdef0"
   }
   ```

   The Terraform address of each resource is in the `.tf` files (`resource "<type>" "<name>"`).
   The ID format for each type is at the bottom of its page in the
   [AWS provider docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) under *Import*.

2. Set the variables in `terraform.tfvars` to the real values (CIDRs, names) so the code matches.
3. Run `terraform plan`. The goal is `N to import, 0 to add, 0 to change, 0 to destroy`.
   Edit the code until the plan shows no changes or only harmless ones.
4. Run `terraform apply`. This only writes the resources into the state. Nothing in AWS changes.
5. Delete `imports.tf`.

Resource names in this code (`<project>-<environment>-...`) are probably different from the
names used in the console. Renaming is a change for most resources and a **replacement**
for some (for example security groups, the ALB and RDS). Adjust the names in the code to match
the real resources before applying.

---

## 11. Deleting everything

Some resources are protected on purpose. To remove the whole environment:

1. Turn off deletion protection:
   - `alb.tf`: `enable_deletion_protection = false`
   - `rds.tf`: `deletion_protection = false`
2. Run `terraform apply`.
3. Empty the three S3 buckets, including all object versions (S3 console → bucket → **Empty**).
   Terraform can't delete buckets that still contain objects.
4. Run:

   ```bash
   terraform destroy
   ```

Notes:

- RDS takes a final snapshot named `<project>-<environment>-mysql-final`. Delete it by hand when you no longer need it.
- The KMS key is scheduled for deletion after 30 days. Until then you can cancel the deletion.
  After that, anything encrypted with it can't be decrypted.
- EFS backups in AWS Backup are kept according to the backup vault rules.

---

## 12. Troubleshooting

| Error | Cause and fix |
|---|---|
| `AWS account ID not allowed` | Your credentials point to a different account than `aws_account_id`. Check `aws sts get-caller-identity`. |
| `BucketAlreadyExists` | S3 bucket names are global. Choose another name. |
| `MaxNumberOfConfigurationRecordersExceededException` | Config is already set up in this region. See [Section 2](#check-the-account-is-empty-for-these-services). |
| `a detector already exists for the current account` | GuardDuty is already enabled. See [Section 2](#check-the-account-is-empty-for-these-services). |
| `Set openvpn_ami_id ...` | `create_openvpn = true` but no AMI ID. Set it, or set `create_openvpn = false`. |
| `OptInRequired` when launching OpenVPN | Subscribe to the AMI in AWS Marketplace first. |
| `Set partner_vpc_cidr when partner_peering_connection_id is set` | Both values are needed together (same for the database provider). |
| `InvalidVpcPeeringConnectionID.NotFound` | The peering request doesn't exist yet or was sent to another region or account. |
| `Error acquiring the state lock` | Someone else is running Terraform. Wait. Use `terraform force-unlock <ID>` only if you are sure nobody is. |
| ALB returns 502 / 503 | The application isn't running on `app_port`, or the health check path is wrong. |
| `InvalidParameterCombination` on RDS | The engine version or instance class isn't available in the region. Check `aws rds describe-orderable-db-instance-options --engine mysql --region eu-north-1`. |
