# Mock aws provider, otherwise Terraform tries to connect to the service API.
# account_id is interpolated into the principal ARNs of the generated policy, so
# it needs a syntactically valid mocked value rather than a generated one.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

run "setup" {
  module {
    source = "./tests/setup"
  }
}

# The default test checks logic in module when using it's default values when creating a plan.
# Additional tests below check individual variables and changes to their defaults. Try not to
# create assertions for resource fields that reference just the variable.
run "default" {
  command = plan

  module {
    source = "./"
  }

  # aws_iam_policy_document is rendered by the AWS provider, so under mock_provider
  # its `json` attribute is a generated value rather than the real policy. We can't
  # assert on individual statements here; overriding it with a known value lets us
  # assert the policy-selection logic (default_policy.enable + var.policy) instead.
  override_data {
    target = data.aws_iam_policy_document.kms_key_policy
    values = {
      json = "{\"Sid\":\"GeneratedDefault\"}"
    }
  }

  variables {
    name = "default-${run.setup.random_string}"

    default_policy = {
      iam_arns_administrator = ["arn:aws:iam::123456789012:role/key-admins"]
    }
  }

  # KMS key alias
  assert {
    condition     = aws_kms_alias.default.name == "alias/default-${run.setup.random_string}"
    error_message = "Expected KMS alias name to be alias/default-${run.setup.random_string}, got: ${aws_kms_alias.default.name}"
  }

  # KMS key
  assert {
    condition     = aws_kms_key.default.deletion_window_in_days == 30
    error_message = "Expected KMS key deletion window to be 30 days, got: ${aws_kms_key.default.deletion_window_in_days}"
  }

  assert {
    condition     = aws_kms_key.default.description == "default-${run.setup.random_string}"
    error_message = "Expected KMS key description to be default-${run.setup.random_string}, got: ${aws_kms_key.default.description}"
  }

  assert {
    condition     = aws_kms_key.default.enable_key_rotation == true
    error_message = "Expected KMS key rotation to be enabled, got: ${aws_kms_key.default.enable_key_rotation}"
  }

  assert {
    condition     = aws_kms_key.default.is_enabled == true
    error_message = "Expected KMS key to be enabled, got: ${aws_kms_key.default.is_enabled}"
  }

  # KMS key policy: with no explicit policy and default_policy.enable defaulting to
  # true, the generated default policy is applied to the key.
  assert {
    condition     = aws_kms_key.default.policy == "{\"Sid\":\"GeneratedDefault\"}"
    error_message = "Expected the generated default policy to be applied, got: ${aws_kms_key.default.policy}"
  }
}

# An explicit policy must take precedence over the generated default policy. Setting
# var.policy also exempts the caller from having to name administrators, since the
# generated policy is discarded.
run "explicit_policy_takes_precedence" {
  command = plan

  module {
    source = "./"
  }

  override_data {
    target = data.aws_iam_policy_document.kms_key_policy
    values = {
      json = "{\"Sid\":\"GeneratedDefault\"}"
    }
  }

  variables {
    name   = "explicit-${run.setup.random_string}"
    policy = "{\"Sid\":\"Explicit\"}"
  }

  assert {
    condition     = aws_kms_key.default.policy == "{\"Sid\":\"Explicit\"}"
    error_message = "Expected the explicit policy to take precedence over the generated default, got: ${aws_kms_key.default.policy}"
  }
}

# When default_policy.enable is false and no explicit policy is set, the key policy
# is left unmanaged so AWS applies its built-in default key policy. The module
# output reflects this as null.
run "default_policy_disabled_is_unmanaged" {
  command = plan

  module {
    source = "./"
  }

  variables {
    name = "disabled-${run.setup.random_string}"
    default_policy = {
      enable = false
    }
  }

  assert {
    condition     = output.policy == null
    error_message = "Expected output.policy to be null when default_policy.enable is false and no policy is set"
  }
}

# When default_policy.enable is false but an explicit policy is supplied, that
# policy is used verbatim and the generated default is not consulted.
run "default_policy_disabled_with_explicit_policy" {
  command = plan

  module {
    source = "./"
  }

  variables {
    name   = "disabled-explicit-${run.setup.random_string}"
    policy = "{\"Sid\":\"Explicit\"}"
    default_policy = {
      enable = false
    }
  }

  assert {
    condition     = output.policy == "{\"Sid\":\"Explicit\"}"
    error_message = "Expected the explicit policy to be used when default_policy.enable is false, got: ${output.policy}"
  }
}

# The generated policy grants key management explicitly and never falls back to the
# calling identity, so it must be rejected when nobody is able to manage the key.
run "default_policy_requires_a_managing_principal" {
  command = plan

  module {
    source = "./"
  }

  variables {
    name = "no-admin-${run.setup.random_string}"
  }

  expect_failures = [var.default_policy]
}

# iam_arns_owner grants kms:* and is therefore a superset of iam_arns_administrator,
# so naming an owner is enough to keep the key manageable.
run "default_policy_owner_satisfies_managing_principal" {
  command = plan

  module {
    source = "./"
  }

  override_data {
    target = data.aws_iam_policy_document.kms_key_policy
    values = {
      json = "{\"Sid\":\"GeneratedDefault\"}"
    }
  }

  variables {
    name = "owner-only-${run.setup.random_string}"

    default_policy = {
      iam_arns_owner = ["arn:aws:iam::123456789012:role/key-owners"]
    }
  }

  assert {
    condition     = output.policy == "{\"Sid\":\"GeneratedDefault\"}"
    error_message = "Expected the generated default policy to be applied when only iam_arns_owner is set, got: ${output.policy}"
  }
}
