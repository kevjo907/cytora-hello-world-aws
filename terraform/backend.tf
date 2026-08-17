# Partial backend configuration.
#
# Left empty so `terraform init` works out of the box with local state for a
# quick local try, while CI supplies the real remote state with:
#
#   terraform init \
#     -backend-config="bucket=<state-bucket>" \
#     -backend-config="key=hello-world/terraform.tfstate" \
#     -backend-config="region=eu-west-1" \
#     -backend-config="use_lockfile=true"
#
# use_lockfile is S3-native state locking (Terraform >= 1.10), which replaces
# the old DynamoDB lock table. terraform/bootstrap/ creates the bucket.

terraform {
  backend "s3" {}
}
