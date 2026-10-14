locals {
  generated_names = {
    for key, resource in var.resources :
    key => lower("${var.org}-${var.app}-${var.env}-${resource.type_code}-${resource.instance}")
  }
}

resource "terraform_data" "validate_names" {
  for_each = local.generated_names

  input = each.value

  lifecycle {
    precondition {
      condition     = length(each.value) <= var.resources[each.key].max_length
      error_message = "Generated name '${each.value}' is ${length(each.value)} characters, exceeding the ${var.resources[each.key].max_length}-character limit for naming request '${each.key}'. Shorten naming.org, naming.app, naming.env, or this resource's instance."
    }

    precondition {
      condition     = can(regex(var.resources[each.key].allowed_pattern, each.value))
      error_message = "Generated name '${each.value}' does not match the allowed naming pattern for '${each.key}'."
    }
  }
}
