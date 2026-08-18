# Partial backend configuration.
#
# Remote state is the committed default so nobody can apply against local
# state by accident and strand the real state file on a laptop. CI supplies
# the concrete values:
#
#   terraform init \
#     -backend-config="bucket=<state-bucket>" \
#     -backend-config="key=hello-world/terraform.tfstate" \
#     -backend-config="region=eu-west-1" \
#     -backend-config="use_lockfile=true"
#
# use_lockfile is S3-native state locking (Terraform >= 1.10), which replaces
# the old DynamoDB lock table. terraform/bootstrap/ creates the bucket.
#
# To try the stack locally without provisioning a state bucket first, run
# `make local-init`. That writes a backend_override.tf switching to local
# state; Terraform's override-file mechanism replaces this block entirely.
# Override files are gitignored, so the committed default stays remote.

terraform {
  backend "s3" {}
}
