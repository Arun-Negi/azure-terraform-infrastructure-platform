output "names" {
  description = "Generated, validated Azure resource names keyed by the resource request key."
  value       = local.generated_names

  depends_on = [terraform_data.validate_names]
}
