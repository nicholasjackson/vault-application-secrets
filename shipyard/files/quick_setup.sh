#!/bin/bash

# Create the secrets
vault kv put secret/api api_key=abcdefg timeout=5s

# Create the policy
cat << EOF | vault policy write api -
path "secret/data/api" {
  capabilities = ["read"]
}
EOF

# Enable and configure JWT Auth
vault auth enable jwt
vault write auth/jwt/config \
  jwt_validation_pubkeys="$(cat /files/public.pem)"

# Create the role
vault write auth/jwt/role/api \
    bound_subject="api" \
    bound_audiences="vault" \
    policies=api \
    user_claim="sub" \
    role_type=jwt \
    ttl=1h