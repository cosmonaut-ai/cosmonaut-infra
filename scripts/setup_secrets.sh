#!/bin/bash

# Helper script to push secrets to SSM Parameter Store

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <env>"
  echo "Example: $0 dev"
  exit 1
fi

ENV=$1
PROJECT="cosmonaut"

echo "Setting up secrets for $ENV environment..."

read_secret() {
  local name=$1
  local param_name="/$ENV/$PROJECT/$name"
  
  read -s -p "Enter value for $param_name: " value
  echo
  
  aws ssm put-parameter \
    --name "$param_name" \
    --value "$value" \
    --type "SecureString" \
    --overwrite

  echo "Successfully updated $param_name"
}

# List of secrets to set up
read_secret "pinecone_api_key"
read_secret "gemini_api_key"
read_secret "google_client_secret"
read_secret "elevenlabs_api_key"

echo "All secrets updated for $ENV."

