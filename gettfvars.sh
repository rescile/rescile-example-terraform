#!/bin/bash

# The GraphQL query as a single-line JSON string
GQL_QUERY='{"query": "query GetTerraformVmConfigs { terraform_vm_config { instance_type hostname region name os_image tags { Environment Owner ManagedBy } } }"}'

# The jq filter to transform the array into a map of maps
# We iterate over the entire array, create a new object for each item using its hostname as the key,
# and then use 'add' to merge the resulting array of objects into a single object.
JQ_FILTER='{ "virtual_machines": (.data.terraform_vm_config | map({(.hostname): .}) | add) }'

# Execute, transform, and save
curl -s -X POST -H "Content-Type: application/json" \
  --data "$GQL_QUERY" http://localhost:7600/graphql | \
  jq "$JQ_FILTER" > terraform.tfvars.json

echo "✅ terraform.tfvars.json generated."
