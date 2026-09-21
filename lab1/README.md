# Lab 1

create-security-group.sh

Gets your current public IP address from checkip.amazonaws.com, creates an EC2 security group named acs730-week1-sg, and adds an inbound rule allowing SSH traffic on TCP port 22 only from your current IP address using a /32 CIDR. This is more secure than allowing SSH from anywhere on the internet.


create-instance.sh

Uses AWS Systems Manager Parameter Store to find the current Amazon Linux 2023 AMI ID, then launches one t3.micro EC2 instance from that image. It attaches the LabInstanceProfile IAM role and adds a Name tag of acs730-week1 so the instance can be easily identified later.


delete-instance.sh

Searches for EC2 instances with the Name tag acs730-week1 that are currently pending, running, or stopped. If matching instances are found, it sends a terminate command for all of them. If none are found, it simply reports that there is nothing to delete.


delete-security-group.sh

Deletes the security group named acs730-week1-sg from AWS. This is the cleanup counterpart to create-security-group.sh and helps ensure unused AWS resources are removed after the lab.
