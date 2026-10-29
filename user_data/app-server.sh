#!/bin/bash
# Installs SSM and CloudWatch agents and cron (from the architecture document).
cd /tmp
sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
sudo yum install -y amazon-cloudwatch-agent
sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl start amazon-cloudwatch-agent
sudo yum install -y cronie
sudo systemctl enable crond
sudo systemctl start crond
