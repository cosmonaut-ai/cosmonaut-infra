# Email/Password Authentication Setup Guide

This guide covers everything needed to enable traditional email/password sign-in alongside the existing Google OAuth provider in Cognito.

## Summary of Infrastructure Changes

The following changes were made to `modules/identity/main.tf`:

### User Pool

| Change | Purpose |
|--------|---------|
| `username_attributes = ["email"]` | Users sign in with their email address instead of a separate username |
| `username_configuration.case_sensitive = false` | `User@example.com` and `user@example.com` are treated as the same account |
| `account_recovery_setting` | Enables "Forgot Password" flow via verified email |
| `verification_message_template` | Customizes the verification code email sent during sign-up |
| `schema "email"` (required) | Explicitly marks email as a required attribute for native sign-up |

### User Pool Client

| Change | Purpose |
|--------|---------|
| `supported_identity_providers = ["COGNITO", "Google"]` | Enables native email/password alongside Google |
| `explicit_auth_flows` | Enables `USER_PASSWORD_AUTH`, `USER_SRP_AUTH`, and `ALLOW_REFRESH_TOKEN_AUTH` for programmatic sign-in |

---

## CRITICAL: User Pool Recreation

> **Adding `username_attributes` is an immutable setting in Cognito.** Terraform will **destroy and recreate** the user pool on the next apply.

### What this means

- All existing users in the pool will be **permanently deleted**.
- The user pool ID and client ID will change.
- Google-authenticated users will simply re-authenticate on their next visit (Cognito recreates their profile automatically).
- Any locally cached tokens in browsers will become invalid.

### Before you apply

1. **Check for existing user data** tied to Cognito user IDs in DynamoDB. If users are keyed by Cognito `sub`, those references will break because new `sub` values are assigned on re-authentication.

   ```bash
   # Check how many users currently exist (per environment)
   aws cognito-idp list-users \
     --user-pool-id <POOL_ID> \
     --query 'Users | length(@)'
   ```

2. **If you have users with data**, you'll need a migration plan:
   - Export user data from DynamoDB before applying.
   - After apply, when users re-authenticate via Google, update the DynamoDB records to point to their new Cognito `sub`.
   - Alternatively, if the app uses email as the primary key (not Cognito `sub`), no migration is needed.

3. **Plan for brief downtime** — between the destroy and recreate, the auth endpoint will be unavailable (typically under 60 seconds during `terraform apply`).

---

## Step 1: Deploy to Dev First

Always apply to dev before prod.

```bash
cd envs/dev
terraform init
terraform plan
```

Review the plan carefully. You should see:

- `aws_cognito_user_pool.main` — **destroy and recreate**
- `aws_cognito_user_pool_client.main` — **destroy and recreate** (depends on pool)
- `aws_cognito_user_pool_domain.main` — **destroy and recreate**
- `aws_cognito_identity_provider.google` — **destroy and recreate**

Once satisfied:

```bash
terraform apply
```

---

## Step 2: Configure Email Sending (Production Readiness)

### Default Cognito Email (Dev — No Action Needed)

Cognito ships with a built-in email sender, but it has a **50 emails/day limit** and sends from `no-reply@verificationemail.com`. This is fine for dev/testing.

### Amazon SES Integration (Recommended for Prod)

For production, configure SES so Cognito sends from your own domain with no daily cap.

1. **Verify your sending domain in SES** (us-east-2, matching your provider region):

   ```bash
   aws ses verify-domain-identity --domain cosmonaut-ai.com --region us-east-2
   ```

2. **Add the TXT record** SES returns to your Cloudflare DNS.

3. **Request production access** — new SES accounts start in sandbox mode (can only send to verified addresses). Open a support case in the AWS console:
   - Service: SES
   - Category: Sending Limits
   - Request type: "Move out of sandbox"

4. **Once SES is verified**, add an `email_configuration` block to the user pool in `modules/identity/main.tf`:

   ```hcl
   email_configuration {
     email_sending_account = "DEVELOPER"
     from_email_address    = "noreply@cosmonaut-ai.com"
     source_arn            = "arn:aws:ses:us-east-2:<ACCOUNT_ID>:identity/cosmonaut-ai.com"
   }
   ```

   Then re-apply Terraform.

> **If you skip this step**, everything still works — Cognito just uses its default sender with the 50/day limit.

---

## Step 3: Update the Frontend (cosmonaut-web)

The Cognito Hosted UI will automatically show an email/password form alongside the "Sign in with Google" button — no changes needed if you're using the Hosted UI redirect flow.

If your frontend uses the **AWS Amplify SDK** or **direct Cognito API calls**, you'll need to add:

### Sign-Up Flow

```
cognito-idp:SignUp
```

- Collect: email, password (and optionally name)
- Cognito sends a verification code to the email
- User enters the code → call `ConfirmSignUp`

### Sign-In Flow

```
cognito-idp:InitiateAuth (AuthFlow: USER_PASSWORD_AUTH or USER_SRP_AUTH)
```

- Collect: email, password
- Returns: ID token, access token, refresh token (same shape as Google OAuth tokens)

### Forgot Password Flow

```
cognito-idp:ForgotPassword → cognito-idp:ConfirmForgotPassword
```

- User enters email → Cognito sends a reset code
- User enters code + new password → password is reset

### Key Implementation Notes

- The JWT tokens from email/password sign-in have the **same structure** as Google OAuth tokens. Your existing API Gateway JWT authorizer and Lambda auth logic will work without changes.
- The `sub` claim in the token will be a Cognito-generated UUID (e.g., `abcd1234-...`), not a Google `sub`. Ensure your backend handles both.

---

## Step 4: Account Linking Considerations

When a user signs up with email/password using the same email that exists on a Google-authenticated account, Cognito treats them as **two separate users** by default.

### Options

| Approach | Description |
|----------|-------------|
| **Do nothing** | Users have separate accounts per provider. Simple, but may confuse users. |
| **Pre Sign-Up Lambda trigger** | Auto-link accounts by email. Add a Lambda trigger that checks if the email already exists and links the identities. |
| **Admin-link after the fact** | Use `admin-link-provider-for-user` API to merge accounts manually or on demand. |

If you want auto-linking, you'd add a `lambda_config` block to the user pool:

```hcl
lambda_config {
  pre_sign_up = aws_lambda_function.pre_sign_up_trigger.arn
}
```

This is optional and can be added later.

---

## Step 5: Apply to Production

Once dev is verified and working:

```bash
cd envs/prod
terraform plan
terraform apply
```

The same pool recreation will happen in prod. Follow the same migration precautions from the "Before you apply" section above.

---

## Step 6: Verify

After applying to each environment, confirm:

- [ ] `terraform output` shows new pool/client IDs
- [ ] Cognito console (AWS → Cognito → User Pools) shows:
  - Sign-in: **Email** listed under sign-in options
  - Providers: **Cognito** and **Google** both listed
  - App client: `explicit_auth_flows` includes `ALLOW_USER_PASSWORD_AUTH`
- [ ] Hosted UI (`https://cosmonaut-<env>.auth.us-east-2.amazoncognito.com/login?client_id=<CLIENT_ID>&response_type=code&scope=email+openid+profile&redirect_uri=<CALLBACK_URL>`) shows both email/password fields and "Sign in with Google"
- [ ] Test sign-up with a new email address — verification code arrives
- [ ] Test sign-in with the new email/password — tokens are returned
- [ ] Test sign-in with Google — still works as before
- [ ] API calls with the new token work (JWT authorizer accepts it)

---

## Rollback

If something goes wrong, revert the Terraform changes and re-apply:

```bash
git checkout -- modules/identity/main.tf
cd envs/<env>
terraform apply
```

This will recreate the pool with the original configuration (Google-only). The same pool recreation / user loss caveats apply in reverse.

---

## Reference: Password Policy

The password policy is unchanged from the existing configuration:

| Requirement | Value |
|-------------|-------|
| Minimum length | 8 characters |
| Lowercase | Required |
| Uppercase | Required |
| Numbers | Required |
| Symbols | Required |
