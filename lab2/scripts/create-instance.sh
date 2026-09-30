#!/usr/bin/env bash
set -euo pipefail

# Launch the week 2 web server with our own key pair and security group.
# No instance profile: the web server doesn't need AWS API access.

EXISTING=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=acs730-week2" "Name=instance-state-name,Values=pending,running,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text)

if [ -n "$EXISTING" ]; then
  echo "Instance already exists: $EXISTING (run delete-instance.sh first)"
  exit 1
fi

GROUP_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=acs730-week2-sg" \
  --query 'SecurityGroups[0].GroupId' --output text)

if [ "$GROUP_ID" = "None" ]; then
  echo "Security group acs730-week2-sg not found (run create-security-group.sh first)"
  exit 1
fi

AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameters[0].Value' --output text)

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --count 1 \
  --key-name acs730-week2 \
  --security-group-ids "$GROUP_ID" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=acs730-week2}]' \
  --query 'Instances[0].InstanceId' --output text)

echo "Instance launched: $INSTANCE_ID (waiting for running...)"
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Instance running: $INSTANCE_ID at $PUBLIC_IP"
echo "Connect with: ssh -i ~/.ssh/acs730-key ec2-user@$PUBLIC_IP"
