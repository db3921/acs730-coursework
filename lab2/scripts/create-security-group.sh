#!/usr/bin/env bash
set -euo pipefail

# Usage: ./lab2/scripts/create-security-group.sh [laptop-ip]
# Least privilege: SSH only from this workstation, HTTP only from your laptop
# (or from this workstation if no laptop IP is given).
MY_IP=$(curl -s https://checkip.amazonaws.com)
HTTP_IP="${1:-$MY_IP}"

GROUP_ID=$(aws ec2 create-security-group \
  --group-name acs730-week2-sg \
  --description "ACS730 week 2 web server security group" \
  --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress \
  --group-id "$GROUP_ID" \
  --protocol tcp --port 22 --cidr "${MY_IP}/32" > /dev/null

aws ec2 authorize-security-group-ingress \
  --group-id "$GROUP_ID" \
  --protocol tcp --port 80 --cidr "${HTTP_IP}/32" > /dev/null

echo "Security group created: $GROUP_ID"
echo "  SSH  (22) allowed from ${MY_IP}/32 (workstation)"
echo "  HTTP (80) allowed from ${HTTP_IP}/32 ($([ $# -ge 1 ] && echo laptop || echo workstation))"
