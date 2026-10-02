# Lab 3

Instructions for this section will be provided in class and on Blackboard when we reach it.

Put your work for Lab 3 in this folder.



A real AWS account would use OIDC because GitHub Actions then gets short-lived credentials for each run by proving its identity to AWS, so no key is stored in GitHub that could leak or need rotating.

This course uses session-scoped secrets because AWS Academy blocks the IAM changes needed to set up OIDC, and if they leak the damage is limited because they expire when the lab session ends and only carry LabRole's permissions in a sandbox account.
