output "names" {
  description = "Generated, validated Azure resource names keyed by the resource request key."
  value       = local.generated_names

  precondition {
    condition = alltrue([
      for key, name in local.generated_names :
      length(name) <= var.resources[key].max_length && can(regex(var.resources[key].allowed_pattern, name))
    ])
    error_message = "One or more generated names violate the Azure length or character rules defined by the naming request."
  }

  depends_on = [terraform_data.validate_names]
}
