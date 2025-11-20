terraform {
  required_providers {
    # This example uses the null provider for demonstration.
    # In a real-world scenario, you would use a cloud provider like 'aws' or 'azurerm'.
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
  }
}

variable "virtual_machines" {
  type = map(object({
    hostname      = string
    instance_type = string
    region        = string
    os_image      = string
    tags          = map(string)
  }))
  description = "A map of virtual machines to create, generated from the rescile graph."
}

# This resource block iterates over the map provided by terraform.tfvars.json.
# For each key-value pair in var.virtual_machines, it creates one instance of this resource.
resource "null_resource" "vm" {
  for_each = var.virtual_machines

  # 'each.key' is the server name (e.g., "api-gateway-prod-eu")
  # 'each.value' is the object containing the server's properties
  triggers = {
    hostname      = each.value.hostname
    instance_type = each.value.instance_type
    region        = each.value.region
    os_image      = each.value.os_image
    tags          = jsonencode(each.value.tags)
  }

  provisioner "local-exec" {
    command = "echo 'Provisioning VM ${each.key} with instance type ${each.value.instance_type} in ${each.value.region}...'"
  }
}

