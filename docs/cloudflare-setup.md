# Cloudflare DNS Integration Guide

This guide explains how to integrate your Cloudflare-managed domain with the Cosmonaut AI infrastructure.

## Overview

The infrastructure uses:

- **AWS CloudFront** for CDN and HTTPS
- **AWS ACM** for SSL certificates
- **Cloudflare DNS** for domain name resolution

## Prerequisites

1. A domain registered and managed in Cloudflare (e.g., `cosmonaut-ai.com`)
2. Cloudflare account with API access
3. AWS account with appropriate permissions

## Step 1: Create a Cloudflare API Token

You need an API token with DNS edit permissions for Terraform to manage your DNS records.

### Instructions:

1. **Log in to Cloudflare Dashboard**: https://dash.cloudflare.com/
2. **Navigate to API Tokens**:

   - Click on your profile icon (top right)
   - Select "My Profile"
   - Go to "API Tokens" tab
   - Click "Create Token"

3. **Configure the Token**:

   - Use the **"Edit zone DNS"** template
   - Under "Zone Resources":
     - Include → Specific zone → Select your domain (e.g., `cosmonaut-ai.com`)
   - Under "Client IP Address Filtering" (optional but recommended):
     - Add your development machine's IP
     - Add your CI/CD runner's IP (if applicable)
   - Set an expiration date (optional but recommended for security)

4. **Create and Save the Token**:
   - Click "Continue to summary"
   - Click "Create Token"
   - **IMPORTANT**: Copy the token immediately - you won't be able to see it again!

### Token Permissions Required:

```
Zone - DNS - Edit
Zone - Zone - Read
```

## Step 2: Configure the API Token

The Cloudflare API token should be set as an environment variable for security (never commit it to git).

### For Local Development:

```bash
# Add to your shell profile (~/.zshrc, ~/.bashrc, etc.)
export TF_VAR_cloudflare_api_token="your-cloudflare-api-token-here"

# Or set it temporarily in your current session
export TF_VAR_cloudflare_api_token="your-cloudflare-api-token-here"
```

### For CI/CD (GitHub Actions):

1. Go to your GitHub repository settings
2. Navigate to "Secrets and variables" → "Actions"
3. Add a new repository secret:

   - Name: `CLOUDFLARE_API_TOKEN`
   - Value: Your Cloudflare API token

4. Update your workflow files to set the environment variable:
   ```yaml
   env:
     TF_VAR_cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
   ```

## Step 3: Verify Your Domain Configuration

Ensure your domain is active in Cloudflare:

1. Log in to Cloudflare Dashboard
2. Select your domain (e.g., `cosmonaut-ai.com`)
3. Verify the status shows "Active"
4. Note your nameservers - they should be Cloudflare's nameservers

## Step 4: Set Up Secrets in AWS SSM Parameter Store

Before deploying, you need to set up your secrets in AWS SSM Parameter Store. The infrastructure expects these secrets to be stored securely.

### Required Secrets:

1. **Google Client Secret** - For Google OAuth authentication
2. **Pinecone API Key** - For vector database access
3. **Gemini API Key** - For Google Gemini LLM API access

### Option A: Use the Setup Script (Recommended)

A helper script is provided to set up all secrets interactively:

```bash
# For dev environment
./scripts/setup_secrets.sh dev

# For prod environment
./scripts/setup_secrets.sh prod
```

The script will prompt you to enter each secret securely (input is hidden).

### Option B: Manual Setup via AWS CLI

You can also set secrets manually using the AWS CLI:

```bash
# Set Google Client Secret
aws ssm put-parameter \
  --name "/dev/cosmonaut/google_client_secret" \
  --value "your-google-client-secret-here" \
  --type "SecureString" \
  --overwrite

# Set Pinecone API Key
aws ssm put-parameter \
  --name "/dev/cosmonaut/pinecone_api_key" \
  --value "your-pinecone-api-key-here" \
  --type "SecureString" \
  --overwrite

# Set Gemini API Key
aws ssm put-parameter \
  --name "/dev/cosmonaut/gemini_api_key" \
  --value "your-gemini-api-key-here" \
  --type "SecureString" \
  --overwrite
```

**Important Notes:**

- Replace `/dev/` with `/prod/` for production environment
- The `--overwrite` flag allows updating existing values
- Secrets are encrypted using AWS KMS (default key: `alias/aws/ssm`)

### Getting Your Google Client Secret

1. **Go to Google Cloud Console**: https://console.cloud.google.com/
2. **Navigate to APIs & Services → Credentials**
3. **Find your OAuth 2.0 Client ID** (or create one if needed)
4. **Click on the client ID** to view details
5. **Copy the "Client secret"** value
6. **Store it in SSM** using one of the methods above

**Note**: The Google Client ID goes in `terraform.tfvars`, but the Client Secret must be stored in SSM Parameter Store for security.

### Getting Your Gemini API Key

1. **Go to Google AI Studio**: https://aistudio.google.com/app/apikey
2. **Sign in** with your Google account
3. **Click "Create API Key"** or use an existing key
4. **Copy the API key** (you'll see it once - save it securely)
5. **Store it in SSM** using one of the methods above

**Note**: Make sure the Gemini API is enabled in your Google Cloud project. The API key is used by your Lambda functions to access Google's Gemini LLM service.

## Step 5: Update Terraform Variables

The `terraform.tfvars` files have already been updated. You just need to set your Google Client ID:

### For Dev Environment (`envs/dev/terraform.tfvars`):

```hcl
google_client_id = "YOUR_GOOGLE_CLIENT_ID"
```

### For Prod Environment (`envs/prod/terraform.tfvars`):

```hcl
google_client_id = "YOUR_GOOGLE_CLIENT_ID"
```

**Remember**: The Google Client Secret is stored in SSM Parameter Store (see Step 4), not in `terraform.tfvars`.

## Step 6: Initialize and Apply Terraform

### For Dev Environment:

```bash
cd envs/dev

# Initialize Terraform (downloads providers)
terraform init

# Review the planned changes
terraform plan

# Apply the configuration
terraform apply
```

### For Prod Environment:

```bash
cd envs/prod

# Initialize Terraform
terraform init

# Review the planned changes
terraform plan

# Apply the configuration
terraform apply
```

## What Terraform Will Create

### AWS Resources:

1. **ACM Certificate** - SSL certificate for your domain
2. **CloudFront Distribution** - CDN for your frontend
3. **S3 Bucket** - Storage for your static frontend files

### Cloudflare Resources:

1. **DNS CNAME Record** - Points your domain to CloudFront
   - Dev: `dev.cosmonaut-ai.com` → CloudFront distribution
   - Prod: `cosmonaut-ai.com` → CloudFront distribution
2. **DNS Validation Records** - For ACM certificate validation

## Certificate Validation Process

The ACM certificate validation happens automatically:

1. Terraform creates the ACM certificate in AWS
2. AWS provides DNS validation records
3. Terraform creates these validation records in Cloudflare
4. AWS detects the DNS records and validates the certificate
5. The certificate becomes "Issued" (usually takes 5-30 minutes)

You can monitor the certificate status in the AWS Console:

- Service: Certificate Manager
- Region: **us-east-1** (CloudFront requires certificates in this region)

## DNS Configuration Details

### Dev Environment:

- **Record**: `dev.cosmonaut-ai.com`
- **Type**: CNAME
- **Target**: CloudFront distribution domain (e.g., `d1234567890.cloudfront.net`)
- **Proxy Status**: DNS only (orange cloud OFF)

### Prod Environment:

- **Record**: `cosmonaut-ai.com` (root domain)
- **Type**: CNAME
- **Target**: CloudFront distribution domain
- **Proxy Status**: DNS only (orange cloud OFF)

**Important**: The Cloudflare proxy (orange cloud) must be **disabled** for CloudFront to work properly with custom SSL certificates.

## Troubleshooting

### Certificate Stuck in "Pending Validation"

**Symptoms**: ACM certificate shows "Pending validation" for more than 30 minutes.

**Solutions**:

1. Check that DNS records were created in Cloudflare:
   ```bash
   terraform output -module=dns
   ```
2. Verify DNS propagation:
   ```bash
   dig _acm-validation.dev.cosmonaut-ai.com
   ```
3. Check Cloudflare DNS settings - ensure the validation records exist
4. Wait up to 72 hours (though it usually takes 5-30 minutes)

### "Error creating DNS record: already exists"

**Symptoms**: Terraform fails because DNS records already exist.

**Solutions**:

1. Import existing records into Terraform state:
   ```bash
   terraform import module.dns.cloudflare_record.frontend <record_id>
   ```
2. Or delete the existing records in Cloudflare and re-run `terraform apply`

### CloudFront Shows "Invalid SSL Certificate"

**Symptoms**: Browser shows SSL errors when accessing your domain.

**Solutions**:

1. Verify the certificate is "Issued" in ACM
2. Check that CloudFront is using the correct certificate
3. Ensure the domain name matches exactly (including subdomain)
4. Wait for CloudFront distribution to fully deploy (can take 15-30 minutes)

### DNS Not Resolving

**Symptoms**: Domain doesn't resolve or shows DNS errors.

**Solutions**:

1. Verify DNS records exist in Cloudflare dashboard
2. Check DNS propagation:
   ```bash
   dig dev.cosmonaut-ai.com
   nslookup dev.cosmonaut-ai.com
   ```
3. Ensure Cloudflare proxy is **disabled** (DNS only mode)
4. Wait for DNS propagation (can take up to 48 hours, usually 5-10 minutes)

### Terraform Authentication Errors

**Symptoms**: `Error: failed to verify API token`

**Solutions**:

1. Verify your API token is set correctly:
   ```bash
   echo $TF_VAR_cloudflare_api_token
   ```
2. Check token permissions in Cloudflare dashboard
3. Ensure token hasn't expired
4. Verify token has access to the specific zone

## Security Best Practices

1. **Never commit API tokens to git**

   - Use environment variables
   - Add `*.tfvars` with sensitive data to `.gitignore`

2. **Rotate API tokens regularly**

   - Set expiration dates on tokens
   - Update tokens every 90 days

3. **Use IP restrictions**

   - Limit token usage to known IPs
   - Update when your IP changes

4. **Use minimal permissions**

   - Only grant DNS edit permissions
   - Don't use Global API keys

5. **Monitor token usage**
   - Check Cloudflare audit logs
   - Review API token activity regularly

## Verification Checklist

After applying Terraform, verify:

- [ ] All secrets are set in SSM Parameter Store (check AWS Console)
- [ ] ACM certificate shows "Issued" status in AWS Console (us-east-1)
- [ ] CloudFront distribution shows "Deployed" status
- [ ] DNS records exist in Cloudflare dashboard
- [ ] DNS resolves correctly: `dig dev.cosmonaut-ai.com`
- [ ] HTTPS works: `curl -I https://dev.cosmonaut-ai.com`
- [ ] Certificate is valid: Check in browser (no SSL warnings)
- [ ] Cognito User Pool is configured with Google provider

## Additional Resources

- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [Cloudflare Terraform Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [AWS ACM Documentation](https://docs.aws.amazon.com/acm/)
- [AWS CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)

## Support

If you encounter issues not covered in this guide:

1. Check Terraform output for specific error messages
2. Review AWS CloudWatch logs for CloudFront/Lambda errors
3. Check Cloudflare audit logs for API activity
4. Verify all prerequisites are met

## Next Steps

After successful deployment:

1. **Upload your frontend**: Deploy your SvelteKit app to the S3 bucket
2. **Configure Google OAuth**: Set up Google Sign-In credentials
3. **Test the application**: Verify all functionality works end-to-end
4. **Set up monitoring**: Configure CloudWatch alarms and Cloudflare analytics
