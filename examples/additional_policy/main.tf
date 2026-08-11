provider "aws" {
  region = "eu-central-1"
}

data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid = "Allow all Network Firewalls in this account"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe",
      "kms:RetireGrant"
    ]
    effect    = "Allow"
    resources = ["*"]

    principals {
      identifiers = ["network-firewall.amazonaws.com"]
      type        = "Service"
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:network-firewall:resource-id"

      values = [
        "arn:aws:network-firewall:${data.aws_region.default.region}:${data.aws_caller_identity.default.account_id}:*"
      ]
    }
  }
}

data "aws_region" "default" {}

data "aws_caller_identity" "default" {}

module "additional_policy" {
  source = "../.."

  name = "additional_policy"

  default_policy = {
    iam_arns_administrator  = ["arn:aws:iam::${data.aws_caller_identity.default.account_id}:role/key-admins"]
    source_policy_documents = [data.aws_iam_policy_document.kms_key_policy.json]
  }
}
