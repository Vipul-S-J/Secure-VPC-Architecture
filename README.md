# HMD AWS infrastructure (eu-north-1, Stockholm)

Record of the kh_hmd production environment in the **HMD AWS account**.
The environment was built manually in the AWS console. This repo documents it as
Terraform code plus a written description. KaHa account resources are not included,
apart from the HMD side of the VPC peering.

> **Documentation only.** These resources already exist. Do not run `terraform apply`
> against the HMD account: it would try to create a second copy of everything.

## Contents

| Path | Describes |
|---|---|
| `docs/architecture.md` | Architectural considerations and resource details from the design document |
| `vpc.tf` | VPC `kh_hmd-eu-pd-vpc` 10.91.0.0/17, 6 subnets, internet gateway, NAT gateway `kh_hmd-eu-pd-pub-nat`, route tables incl. `kh_hmd-pd-pvt-rtb` |
| `vpc_peering.tf` | HMD side of the peering with the KaHa VPC and the MongoDB Atlas VPC |
| `security_groups.tf` | `kh_hmd-eu-pd-elb-sg`, `khmd-eu-pd-app-srv-sg`, EFS, DB and OpenVPN security groups |
| `kms.tf` | KMS key `kh_hmd-prod-eu-key` (symmetric, single region) |
| `cloudtrail.tf` | Multi-region trail `kh_hmd-eu-pd-cloudtrail`, bucket `khmd-eu-pd-cloudtrail-logs`, log group `kh_hmd-eu-pd-cloudtrail-logs` |
| `alb.tf` | Internet ALB `khmd-eu-pd-ELB` in the public subnets |
| `efs.tf` | EFS `khmd-eu-pd-app-srv-efs` (fs-06610e73d51fe5c59), regional |
| `iam.tf` | Instance role `KhmdPdEc2BasicRole` |
| `ec2.tf`, `user_data/app-server.sh` | App server `khmd-eu-pd-app-srv` and base AMI `khmd-srv-base-ami` |
| `s3.tf` | User static data bucket |
| `rds.tf` | RDS MySQL |
| `monitoring.tf` | SNS alerts topic and CloudWatch alarms |
| `guardduty.tf` | GuardDuty |
| `config.tf` | AWS Config |
| `openvpn.tf` | OpenVPN server used by KaHa DevOps |
| `variables.tf`, `terraform.tfvars.example`, `outputs.tf` | Inputs and outputs of the code |

## Note on the code

Names and CIDRs come from the design document. Settings the document doesn't
mention (RDS engine version, alarm thresholds, encryption options and similar)
are typical values and may differ from what is configured in the console.
The console is the source of truth.
