# Cosmonaut Infrastructure Documentation

This directory contains infrastructure setup guides, architecture notes, and feature-specific implementation notes.

## Current References

- [`structure.md`](structure.md): module layout and how the Terraform pieces fit together.
- [`cloudflare-setup.md`](cloudflare-setup.md): Cloudflare DNS token setup, Terraform DNS resources, and verification.
- [`email-password-auth-setup.md`](email-password-auth-setup.md): Cognito email/password setup and rollout notes.
- [`audio-implementation.md`](audio-implementation.md): infrastructure requirements for ElevenLabs audio narration.

## Product Background

- [`project-description.md`](project-description.md): high-level product goals and narrative consistency requirements.

## Maintenance Notes

- Keep Terraform examples generic. Do not paste real secret values, Terraform state, or private `.tfvars` content.
- If a guide is environment-specific, call out whether it applies to dev, prod, or both.
- Prefer commands that can be copied into a clean checkout without depending on local absolute paths.
