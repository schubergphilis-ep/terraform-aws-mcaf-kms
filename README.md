# terraform-aws-mcaf-kms

Terraform module to manage an AWS KMS key and its alias.

## Key policy

By default the module generates a **least-privilege key policy** from the `default_policy` object.
Grant access by listing principal ARNs in its`iam_arns_*` fields:

* `iam_arns_administrator` for key management.
* `iam_arns_decrypt` / `iam_arns_decrypt_encrypt` for data operations.
* `iam_arns_sign_verify` for signing.
* `iam_arns_owner` for full access.

> [!IMPORTANT]
> Unlike AWS's default key policy, this policy does **not** grant the key to IAM principals just because their IAM policy allows `kms:*`.
> Use and administration must be listed explicitly in `default_policy.iam_arns_*`.
> (Read-only metadata access is still delegated to IAM while `iam_all_principals_read` is `true`.)

Because nothing is granted implicitly, at least one principal ARN must be set in `iam_arns_administrator` or `iam_arns_owner` — otherwise the key would end up without any principal able to manage it.
The module deliberately does **not** fall back to the identity running Terraform: when plan and apply run under separate roles, that would bake whichever role happened to read the session context into the key policy, locking out the other one.

To opt out, set `default_policy.enable` to `false` to use AWS's default key policy, or pass a complete document via `var.policy` (which always takes precedence).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_kms_alias.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.kms_key_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | The name of the key | `string` | n/a | yes |
| <a name="input_custom_key_store_id"></a> [custom\_key\_store\_id](#input\_custom\_key\_store\_id) | ID of the KMS Custom Key Store where the key will be stored instead of KMS (eg CloudHSM) | `string` | `null` | no |
| <a name="input_customer_master_key_spec"></a> [customer\_master\_key\_spec](#input\_customer\_master\_key\_spec) | Specifies whether the key contains a symmetric key or an asymmetric key pair and the encryption algorithms or signing algorithms that the key supports. | `string` | `"SYMMETRIC_DEFAULT"` | no |
| <a name="input_default_policy"></a> [default\_policy](#input\_default\_policy) | Configuration object for defining the KMS key policy and permissions. Requires at least one principal ARN in `iam_arns_administrator` or `iam_arns_owner` when the default policy is used. Use `override_policy_documents` to add statements that override the default policy, or `source_policy_documents` to add statements that are merged with the default policy | <pre>object({<br/>    enable                    = optional(bool, true)<br/>    override_policy_documents = optional(list(string), [])<br/>    source_policy_documents   = optional(list(string), [])<br/><br/>    iam_all_principals_read  = optional(bool, true)<br/>    iam_arns_administrator   = optional(list(string), [])<br/>    iam_arns_decrypt         = optional(list(string), [])<br/>    iam_arns_decrypt_encrypt = optional(list(string), [])<br/>    iam_arns_owner           = optional(list(string), [])<br/>    iam_arns_service_grant   = optional(list(string), [])<br/>    iam_arns_sign_verify     = optional(list(string), [])<br/>    iam_aws_config_read      = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_deletion_window_in_days"></a> [deletion\_window\_in\_days](#input\_deletion\_window\_in\_days) | Delay in days after which the key is deleted | `number` | `30` | no |
| <a name="input_description"></a> [description](#input\_description) | The description of the key as viewed in AWS console | `string` | `null` | no |
| <a name="input_enable_key_rotation"></a> [enable\_key\_rotation](#input\_enable\_key\_rotation) | Specifies whether key rotation is enabled | `bool` | `true` | no |
| <a name="input_key_usage"></a> [key\_usage](#input\_key\_usage) | Specifies the intended use of the key. | `string` | `"ENCRYPT_DECRYPT"` | no |
| <a name="input_multi_region"></a> [multi\_region](#input\_multi\_region) | Indicates whether the KMS key is a multi-Region (`true`) or regional (`false`) key. | `bool` | `false` | no |
| <a name="input_path"></a> [path](#input\_path) | Path of the KMS key alias | `string` | `"/"` | no |
| <a name="input_policy"></a> [policy](#input\_policy) | A valid KMS policy JSON document | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | The AWS region where resources will be created; if omitted the default provider region is used | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A mapping of tags to assign to the key | `map(string)` | `{}` | no |
| <a name="input_xks_key_id"></a> [xks\_key\_id](#input\_xks\_key\_id) | Identifies the external key that serves as key material for the KMS key in an external key store | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the key |
| <a name="output_id"></a> [id](#output\_id) | ID of the key |
| <a name="output_policy"></a> [policy](#output\_policy) | The key policy applied to the key, as a JSON-encoded string |
<!-- END_TF_DOCS -->
