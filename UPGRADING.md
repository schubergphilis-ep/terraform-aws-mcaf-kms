# Upgrading Notes

This document captures required refactoring on your part when upgrading to a module version that contains breaking changes.

## Upgrading to v3.0.0

### Key Changes

- The module **no longer falls back to the calling identity** when `default_policy.iam_arns_administrator` is empty; the `aws_iam_session_context` data source has been removed.
- When the generated default policy is used, at least one principal ARN is now **required** in `default_policy.iam_arns_administrator` or `default_policy.iam_arns_owner`.
- `iam_all_principals_read` now also delegates `kms:GetKeyRotationStatus` and `kms:ListResourceTags` to IAM, so a read-only plan role can refresh the key without being a key administrator.

The fallback resolved the administrator from whichever identity executed Terraform. With separate plan and apply roles that is the read-only plan role, so the key policy granted it key administration and left the apply role unable to manage the key it had just created.

### Required actions

Nothing to do if you already pass `var.policy` or set `default_policy.enable = false` — the generated policy is not used, so the requirement does not apply.

Otherwise, name the administrator explicitly. **Pass the ARN of the role used for apply**, since that is the identity that has to manage the key:

```hcl
default_policy = {
  iam_arns_administrator = [var.tfc_aws_apply_role_arn]
}
```

The plan role does not need to be listed — `iam_all_principals_read` delegates the read-only actions a refresh needs to IAM.

If a **single** identity runs both plan and apply, resolving the caller yourself is still fine and reproduces the old behaviour exactly:

```hcl
data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}
```

Do not do this when plan and apply use separate identities: it locks you out of the key.

#### Workspaces provided by `mcaf-avm` or `mcaf-workspace`

Set `set_terraform_role_arn_variables` to `true` to publish each pipeline role ARN as a Terraform-category workspace variable (`tfc_aws_run_role_arn`, `tfc_aws_plan_role_arn`, `tfc_aws_apply_role_arn`) for use as `iam_arns_administrator`.

This is preferred over the `aws_iam_session_context` data source even with a single run role: the value is a static input, identical in every phase, so plan and apply can never disagree about who administers the key.

### Before you upgrade

Keys created by an earlier version list whichever role ran Terraform as administrator. Check the live policy and carry the principal you want to keep into `iam_arns_administrator`, otherwise the next apply removes it.

## Upgrading to v2.0.0

### Key Changes

- The module now generates a **least-privilege key policy by default**. When `default_policy.enable` is `true` (the new default) and no explicit `policy` is provided, the module builds the key policy from the new `default_policy` object instead of letting AWS apply its built-in default key policy.
- **This changes how access to the key is granted.** AWS's default key policy delegates full control to IAM via an unconditional `arn:aws:iam::<account>:root` principal, meaning any IAM principal with the right IAM permissions can use the key. The generated policy instead constrains the root-account statement with `aws:PrincipalType = "Account"` (break-glass for the account root user only) and grants encryption/decryption, signing and administration **explicitly** through the `default_policy.iam_arns_*` fields. After upgrading, IAM-policy-based access that previously worked implicitly will stop working unless the principals are listed explicitly. Read-only metadata access remains delegated to IAM for all account principals while `iam_all_principals_read` is `true`.
- If `default_policy.iam_arns_administrator` is empty, the calling identity (`aws_iam_session_context.issuer_arn`) is added as administrator so the key is never left without a manageable principal.

### Required actions

**This release is backwards compatible if you already pass `var.policy`**: it still takes precedence over the generated policy, so the resulting key policy is unchanged.
Note: the module now always reads the `aws_caller_identity`, `aws_partition` and `aws_iam_session_context` data sources,
so the principal running Terraform needs `sts:GetCallerIdentity` and (for assumed-role sessions) `iam:GetRole`/`iam:GetUser`.
If you relied on AWS's default key policy (no `policy` set) and want to **keep that behaviour**, set `default_policy = { enable = false }`.

To **adopt the new model**, set `var.policy` to `null` and grant access using `var.default_policy`, for example:

```hcl
default_policy = {
  iam_arns_administrator   = ["arn:aws:iam::123456789012:role/key-admins"]
  iam_arns_decrypt_encrypt = ["arn:aws:iam::123456789012:role/app"]
}
```

## Upgrading to v1.0.0

### Key Changes

- This module now requires a minimum AWS provider version of 6.0 to support the `region` parameter. If you are using multiple AWS provider blocks, please read [migrating from multiple provider configurations](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/enhanced-region-support#migrating-from-multiple-provider-configurations).
