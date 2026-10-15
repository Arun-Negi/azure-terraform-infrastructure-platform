resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_kind             = "StorageV2"
  account_tier             = var.account_tier
  account_replication_type = var.replication_type

  https_traffic_only_enabled        = true
  min_tls_version                   = var.min_tls_version
  public_network_access_enabled     = var.public_network_access_enabled
  shared_access_key_enabled         = var.shared_access_key_enabled
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true

  tags = var.tags
}
