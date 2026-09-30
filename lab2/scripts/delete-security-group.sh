#!/usr/bin/env bash
set -euo pipefail

GROUP_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=acs730-week2-sg" \
  --query 'SecurityGroups[0].GroupId' --output text)

if [ "$GROUP_ID" = "None" ]; then
  echo "Nothing to delete."
else
  aws ec2 delete-security-group --group-id "$GROUP_ID"
  echo "Security group acs730-week2-sg ($GROUP_ID) deleted."
fi
