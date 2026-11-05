# Lab 5: Terraform Introduction and Reliable CI

## Why for_each here and count there

- Subnets use for_each because they are distinct things with stable names. Add key "c" and the plan is "1 to add, 0 to change, 0 to destroy"; remove "a" and it is "1 to destroy", "b" untouched.
- The same subnets with count would be a trap. Addresses would be [0], [1], [2]; delete the middle entry and everything after shifts down a slot, so Terraform compares public[1] in state against a different subnet in config and plans to destroy and recreate two subnets to remove one.
- The bucket uses count because the input is a yes/no about one resource: exactly two plans, "0 to add" and "1 to add", and no key to be stable about. In short — count when the question is how many, for_each when the question is which ones.

If they were mixed up: using count for the subnets means removing one subnet can destroy and recreate others that did not change, which would break anything running in them. Using for_each for the bucket adds a map of keys for something that is only ever on or off, which makes the code harder to read for no benefit.
