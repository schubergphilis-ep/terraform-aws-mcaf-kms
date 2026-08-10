provider "aws" {
  region = "eu-central-1"
}

module "basic" {
  source = "../.."

  name = "basic"

  # The generated default policy grants key management explicitly, so at least one
  # administrator (or owner) must always be named. 
  # If using this module in combination with the `mcaf-avm` or `mcaf-workspace` module, add at least the run/apply role as key administrator.
  default_policy = {
    iam_arns_administrator = ["arn:aws:iam::123456789012:role/key-admin"]
  }
}
