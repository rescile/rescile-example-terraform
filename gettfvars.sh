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
