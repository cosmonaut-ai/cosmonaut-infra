# Email/Password Authentication Setup Guide

This guide covers everything needed to enable traditional email/password sign-in alongside the existing Google OAuth provider in Cognito.

## Implementation Status

All infrastructure and application code has been implemented. The following components are in place:

| Component | Status | Location |
|-----------|--------|----------|
| Cognito user pool (email/password) | Implemented | `modules/identity/main.tf` |
| SES domain identity + DKIM | Implemented | `modules/email/main.tf` |
| SES DNS records (Cloudflare) | Implemented | `modules/dns/main.tf` |
| Cognito → SES integration | Implemented | `modules/identity/main.tf` (`email_configuration`) |
| Branded email templates | Implemented | `lambdas/custom_message/index.py` |
| Account de-duplication | Implemented | `lambdas/pre_sign_up/index.py` |
| Frontend login/signup page | Implemented | `cosmonaut-web/src/routes/login/` |
| Frontend auth module | Implemented | `cosmonaut-web/src/lib/auth/auth.svelte.ts` |
| API account deletion | Implemented | `cosmonaut-api/app/services/account.py` |
| API invite emails | Implemented | `cosmonaut-api/app/services/email.py` |
| IAM permissions (SES, Cognito) | Implemented | `modules/compute/iam.tf` |

---

## Deployment Steps

### Step 1: Deploy Infrastructure (Dev First)

```bash
cd envs/dev
terraform init
terraform plan
```

Review the plan carefully. You should see:

- `module.email` — new SES resources
- `module.identity` — updated with `email_configuration`, `lambda_config`, new Lambda functions
- `module.dns` — new SES DNS records (TXT, CNAME, MX)
- `module.compute` — updated IAM policy (SES + Cognito admin)

**CRITICAL: User Pool Recreation**

> Adding `username_attributes` is an immutable setting in Cognito. If this hasn't been applied yet, Terraform will **destroy and recreate** the user pool.

Before applying:

1. Check for existing user data tied to Cognito `sub` in DynamoDB
2. If users exist, plan for migration (new `sub` values will be assigned)
3. Plan for brief downtime (~60 seconds during apply)

```bash
terraform apply
```

### Step 2: SES Production Access

SES starts in **sandbox mode** (can only send to verified addresses, 50 emails/day limit).

To move to production:

1. Go to AWS Console → SES → Account dashboard
2. Click "Request production access"
3. Fill out the form:
   - **Mail type**: Transactional
   - **Website URL**: https://cosmonaut-ai.com
   - **Use case description**: Account verification emails, password reset emails, and world sharing invitations for our interactive storytelling platform
4. Wait for approval (typically 24-48 hours)

Until approved, the dev environment falls back to Cognito's built-in sender (50 emails/day from `no-reply@verificationemail.com`).

### Step 3: Deploy API

Push the `cosmonaut-api` changes to trigger the CI/CD pipeline:

```bash
cd cosmonaut-api
git push origin main  # or develop for dev
```

The API deploy will pick up:
- New email service (`app/services/email.py`)
- New account service (`app/services/account.py`)
- Updated auth endpoints (`DELETE /auth/account`)
- Updated world sharing with invite emails
- New environment variables (`SES_FROM_EMAIL`, `SES_ENABLED`)

### Step 4: Deploy Frontend

Push the `cosmonaut-web` changes:

```bash
cd cosmonaut-web
git push origin main  # or develop for dev
```

The frontend deploy will pick up:
- New `/login` route with sign-in, sign-up, forgot-password flows
- Updated auth module with email/password support
- Updated landing page and layout navigation
- Account deletion in settings

### Step 5: Verify

After deploying to each environment:

- [ ] `terraform output` shows new pool/client IDs (if pool was recreated)
- [ ] Cognito console shows email sign-in options + Google provider
- [ ] Sign up with a new email → verification code arrives (branded template)
- [ ] Confirm sign-up → can sign in with email/password
- [ ] Sign in with Google → still works
- [ ] Sign in with Google using same email → accounts are linked
- [ ] Share a world → invite email arrives (branded template)
- [ ] Forgot password → reset code arrives → can reset password
- [ ] Delete account → all data removed, redirected to landing page
- [ ] API calls with new tokens work

### Step 6: Deploy to Production

Once dev is verified:

```bash
cd envs/prod
terraform plan
terraform apply
```

Follow the same migration precautions and verification steps.

---

## Architecture Details

### Authentication Flow

```
User → /login page
  ├── Email/Password → Amplify signUp/signIn → Cognito → JWT
  └── Google → Amplify signInWithRedirect → Cognito → JWT → /callback

Pre-sign-up Lambda (account linking):
  ├── Google sign-in + existing native user → auto-link
  └── Native sign-up + existing Google user → link on next Google sign-in

Custom message Lambda (branded emails):
  ├── CustomMessage_SignUp → verification code email
  ├── CustomMessage_ForgotPassword → password reset email
  └── CustomMessage_ResendCode → resend verification email
```

### Email Templates

All emails use a consistent Cosmonaut brand:
- Dark background (`#0a0a0f`)
- Card layout (`#111118` with `#1e1e2e` border)
- Purple accent (`#7c3aed`)
- Rocket emoji logo
- Footer with Matson Software LLC branding

Three template types:
1. **Verification** — Welcome message + 6-digit code
2. **Password Reset** — Reset instructions + 6-digit code
3. **World Invite** — Inviter name, world title card, "Explore World" CTA button

### Account Deletion Cascade

`DELETE /auth/account` performs:
1. Cancel active Stripe subscriptions
2. Delete all user-owned worlds (metadata + story nodes + Pinecone vectors)
3. Delete UserUsage DynamoDB record
4. Delete Cognito user identity

### Password Policy

| Requirement | Value |
|-------------|-------|
| Minimum length | 8 characters |
| Lowercase | Required |
| Uppercase | Required |
| Numbers | Required |
| Symbols | Required |

---

## Rollback

To revert to Google-only auth:

1. Remove `lambda_config` and `email_configuration` from `modules/identity/main.tf`
2. Revert the Lambda trigger resources
3. Re-apply Terraform (note: removing `username_attributes` will recreate the pool again)
4. Revert frontend to direct Google OAuth redirect
5. Revert API changes (email service, account deletion)
