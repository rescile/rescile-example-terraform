<p align="center">
  <a href="https://rescile.com" target="_blank" rel="noopener">
    <img width="280" src="https://www.rescile.com/images/logos/rescile_logo.svg" alt="rescile logo">
  </a>
</p>

<h1 align="center">rescile: Hybrid Cloud Controller</h1>

<p align="center">
  <strong>From Complexity to Clarity — Build a Living Blueprint of Your Hybrid World.</strong>
  <br><br>
  This repository contains the source for <a href="https://rescile.com">rescile.com</a>, including comprehensive documentation and real-world examples for modeling, governing, and automating your hybrid cloud.
</p>

## What is rescile?

rescile transforms scattered data from your hybrid environment into a single, queryable dependency graph. It creates a "digital twin" of your entire estate, allowing you to go from fragmented data to decisive answers.

With rescile, you can:

- **Generate Complete Deployment Recipes** for Terraform, Ansible, and Kubernetes.
- **Automate Audits** with compliance-as-code for SOX, GDPR, DORA, and more.
- **Achieve True FinOps Cost Attribution** by connecting technical assets to business owners.
- **Proactively Manage Risk** by tracing vulnerabilities from an SBOM to every affected application.
- **Enforce Architectural Standards** and validate your deployed reality against your blueprint.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue for bugs, feature requests, or suggestions.

---

<p align="center">
  Built with ❤️ by the team at <a href="https://rescile.com">rescile.com</a>
</p>

---

## Overview

Rescile acts as a "blueprint factory" for your infrastructure, creating a single source of truth that connects business logic to technical reality. A powerful application of this blueprint is to drive your Infrastructure as Code (IaC) deployments, ensuring that what you provision always matches your validated architectural model.

This example demonstrates a complete workflow for generating a `terraform.tfvars.json` file from your rescile graph. We will model virtual machines, define a structured output for Terraform, query the graph, and use the generated variables to provision resources.

### The Scenario

We need to provision virtual machines for our applications. The instance size and OS image depend on the application and its deployment environment (e.g., `prod`, `dev`). We want to define this logic in rescile and have Terraform automatically build the correct set of VMs.

---

## Step 1: Model the Infrastructure in Rescile

First, we provide the raw data for our applications and their deployments in simple CSV files.

#### `data/assets/application.csv`

This file defines our applications, their owner, and the required OS.

```csv
name,owner_team,os_image
api-gateway,team-alpha,ubuntu-22.04-lts
user-service,team-alpha,ubuntu-22.04-lts
billing-service,team-beta,rhel-8.7
```

#### `data/assets/subscription.csv`

This file defines specific deployments of our applications, linking them to an environment, region, and a conceptual instance size.

```csv
subscription,application,environment,region,instance_size
api-gateway-prod-eu,api-gateway,prod,westeurope,small
user-service-prod-eu,user-service,prod,westeurope,medium
billing-service-dev-us,billing-service,dev,eastus,small
```

#### `data/models/server.toml`

Next, we create a model to transform these abstract subscriptions into concrete `server` resources. This model uses a map to translate our conceptual sizes (`small`, `medium`) into specific cloud provider SKUs based on the environment.

```toml
origin_resource = "subscription"

# This map provides data for the template to look up instance SKUs.
instance_types = { "prod" = { small = "Standard_B2s", medium = "Standard_B4ms" }, "dev"  = { small = "Standard_B1s", medium = "Standard_B2s" } }

[[create_resource]]
resource_type = "server"
relation_type = "IS_INSTANCE_OF"
name = "{{ origin_resource.subscription }}_server"
[create_resource.properties]
hostname      = "{{ origin_resource.subscription }}"
environment   = "{{ origin_resource.environment }}"
region        = "{{ origin_resource.region }}"
instance_type = "{{ instance_types[origin_resource.environment][origin_resource.instance_size] }}"

# The 'server' resource needs properties from the 'application' resource.
# The path is: (application) <--> (subscription) <--> (server).
# We propagate properties along this path in two steps.

# Step 1: Join with 'application' and copy its properties to 'subscription'.
# This is done for every 'subscription' based on its 'application' property.
[[link_resources]]
with = "application"
on = { local = "application", remote = "name" }
copy_properties = [ "os_image", "owner_team" ]

# Step 2: Propagate the newly acquired properties from 'subscription' to the new 'server' resource.
[[copy_property]]
to = "server"
properties = [
  "os_image",
  { from = "owner_team", as = "owner" } # Rename property to match output template
]
```

After running the importer, our graph now contains `server` nodes with all the properties needed for provisioning, like `hostname`, `instance_type`, and `region`.

---

## Step 2: Define the Terraform Output

Rescile's `output` definitions allow you to query the graph and generate new, structured data resources. We'll use this feature to create a resource specifically formatted for Terraform.

Create a file in `data/output/` to define this transformation.

#### `data/output/terraform_vms.toml`

This file iterates over every `server` resource that matches our criteria (in this case, all `prod` servers) and uses a template to generate a JSON object for each one. The result is a new resource type in the graph, `terraform_vm_config`, whose properties are the generated JSON.

```toml
origin_resource = "server"

[[output]]
# The type of the new resource to create in the graph.
resource_type = "terraform_vm_config"
# The name for the new resource, derived from the server's hostname.
name = "{{ origin_resource.hostname | replace(from='-', to='_') }}"

# Only generate this output for servers in the 'prod' environment.
match_on = [
    { property = "environment", value = "prod" }
]

# This template renders a complete JSON object. The keys and values of this
# object will become the properties of the new 'terraform_vm_config' resource.
template = """
{
    "hostname": "{{ origin_resource.hostname }}",
    "instance_type": "{{ origin_resource.instance_type }}",
    "region": "{{ origin_resource.region }}",
    "os_image": "{{ origin_resource.os_image }}",
    "tags": {
        "Owner": "{{ origin_resource.owner }}",
        "Environment": "{{ origin_resource.environment }}",
        "ManagedBy": "rescile"
    }
}
"""
```

After running `rescile-ce` again, the graph will contain two `terraform_vm_config` nodes (one for each production server), each holding a perfectly formatted JSON object as its properties.

---

## Step 3: Generate `terraform.tfvars.json`

With the data prepared in the graph, we can now extract it using a GraphQL query and format it into a `.tfvars.json` file.

#### GraphQL Query

This query retrieves all `terraform_vm_config` resources. Because the output template defined a flat JSON object, we can query its fields directly.

```graphql
query GetTerraformVmConfigs {
  terraform_vm_config {
    instance_type
    hostname
    region
    name
    os_image
  } 
}
```

Running this query against the `rescile-ce` server will produce a list of VM configuration objects:

```json
{
  "data": {
    "terraform_vm_config": [
      {
        "instance_type": "Standard_B2s",
        "hostname": "api-gateway-prod-eu",
        "region": "westeurope",
        "name": "api_gateway_prod_eu",
        "os_image": "ubuntu-22.04-lts"
      },
      {
        "instance_type": "Standard_B4ms",
        "hostname": "user-service-prod-eu",
        "region": "westeurope",
        "name": "user_service_prod_eu",
        "os_image": "ubuntu-22.04-lts"
      }
    ]
  }
}
```

#### Transformation Script

Terraform works best with a map of objects for iteration. We can use a simple `curl` and `jq` command to transform the GraphQL array output into the required map structure, keyed by hostname, and save it as `terraform.tfvars.json`.

```bash
#!/bin/bash

# The GraphQL query as a single-line JSON string
GQL_QUERY='{"query": "query GetTerraformVmConfigs { terraform_vm_config { name api_gateway_prod_eu user_service_prod_eu } }"}'

# The jq filter to transform the array into a map of maps
JQ_FILTER='{ "virtual_machines": (.data.terraform_vm_config[0] | del(.name) | values | map({(.hostname): .}) | add) }'

# Execute, transform, and save
curl -s -X POST -H "Content-Type: application/json" \
  --data "$GQL_QUERY" http://localhost:7600/graphql | \
  jq "$JQ_FILTER" > terraform.tfvars.json

echo "✅ terraform.tfvars.json generated."
```

This produces the final `terraform.tfvars.json` file:

```json
{
  "virtual_machines": {
    "api-gateway-prod-eu": {
      "hostname": "api-gateway-prod-eu",
      "instance_type": "Standard_B2s",
      "os_image": "ubuntu-22.04-lts",
      "region": "westeurope",
      "tags": { "Environment": "prod", "ManagedBy": "rescile", "Owner": "team-alpha" }
    },
    "user-service-prod-eu": {
      "hostname": "user-service-prod-eu",
      "instance_type": "Standard_B4ms",
      "os_image": "ubuntu-22.04-lts",
      "region": "westeurope",
      "tags": { "Environment": "prod", "ManagedBy": "rescile", "Owner": "team-alpha" }
    }
  }
}
```

---

## Step 4: Consume Variables in Terraform

Finally, our Terraform configuration can consume this generated file. The `main.tf` declares a variable that matches the structure of our JSON and uses `for_each` to create a resource for every VM defined in the blueprint.

#### `main.tf`

```hcl
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
```

Now, running `terraform apply` will automatically read the `terraform.tfvars.json` file and create exactly two resources, one for each production server defined in our model. This creates a powerful, auditable, and automated link between your architectural design and your deployed infrastructure.

```shell
Terraform used the selected providers to generate the following execution plan. Resource actions are
indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # null_resource.vm["api-gateway-prod-eu"] will be created
  + resource "null_resource" "vm" {
      + id       = (known after apply)
      + triggers = {
          + "hostname"      = "api-gateway-prod-eu"
          + "instance_type" = "Standard_B2s"
          + "os_image"      = "ubuntu-22.04-lts"
          + "region"        = "westeurope"
          + "tags"          = jsonencode(
                {
                  + Environment = "prod"
                  + ManagedBy   = "rescile"
                  + Owner       = "team-alpha"
                }
            )
        }
    }

  # null_resource.vm["user-service-prod-eu"] will be created
  + resource "null_resource" "vm" {
      + id       = (known after apply)
      + triggers = {
          + "hostname"      = "user-service-prod-eu"
          + "instance_type" = "Standard_B4ms"
          + "os_image"      = "ubuntu-22.04-lts"
          + "region"        = "westeurope"
          + "tags"          = jsonencode(
                {
                  + Environment = "prod"
                  + ManagedBy   = "rescile"
                  + Owner       = "team-alpha"
                }
            )
        }
    }

Plan: 2 to add, 0 to change, 0 to destroy.
```
