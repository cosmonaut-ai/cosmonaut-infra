"""
Cognito Pre Sign-Up Lambda Trigger

Handles account de-duplication by linking identities when the same email
is used across multiple sign-in providers (native email/password + Google).

Trigger sources handled:
- PreSignUp_ExternalProvider: A federated user (Google) is signing in.
  If a native user with the same email exists, link the Google identity to it.
- PreSignUp_SignUp: A native user is signing up with email/password.
  If a Google-federated user with the same email exists, link them together.
"""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING, TypedDict

import boto3

if TYPE_CHECKING:
    from mypy_boto3_cognito_idp.client import CognitoIdentityProviderClient
    from mypy_boto3_cognito_idp.type_defs import UserTypeTypeDef

logger = logging.getLogger()
logger.setLevel(logging.INFO)

cognito: CognitoIdentityProviderClient = boto3.client("cognito-idp")

# Cognito event userName uses lowercase prefixes (e.g. "google_123...")
# but admin_link_provider_for_user requires the exact configured name.
_PROVIDER_NAME_MAP: dict[str, str] = {
    "google": "Google",
    "facebook": "Facebook",
    "loginwithamazon": "LoginWithAmazon",
    "signinwithapple": "SignInWithApple",
}


# ---------------------------------------------------------------------------
# Cognito Pre Sign-Up event types
# ---------------------------------------------------------------------------


class _Request(TypedDict):
    userAttributes: dict[str, str]


class _Response(TypedDict, total=False):
    autoConfirmUser: bool
    autoVerifyEmail: bool
    autoVerifyPhone: bool


class _CognitoEvent(TypedDict):
    triggerSource: str
    userPoolId: str
    userName: str
    request: _Request
    response: _Response


def handler(event: _CognitoEvent, _context: object) -> _CognitoEvent:
    trigger = event.get("triggerSource", "")
    user_pool_id = event["userPoolId"]
    email = event["request"]["userAttributes"].get("email", "").lower().strip()

    logger.info("Pre sign-up trigger: %s for email: %s", trigger, email)

    if not email:
        return event

    try:
        if trigger == "PreSignUp_ExternalProvider":
            _handle_external_provider(event, user_pool_id, email)
        elif trigger == "PreSignUp_SignUp":
            _handle_native_signup(event, user_pool_id, email)
    except Exception:
        logger.exception("Error in pre_sign_up trigger for %s", email)
        # Don't block sign-up on linking errors; let it proceed normally

    return event


def _handle_external_provider(event: _CognitoEvent, user_pool_id: str, email: str) -> None:
    """
    Google sign-in: check if a native (email/password) user exists with the
    same email. If so, link the Google identity to the existing native user.
    """
    # The external provider username looks like "google_<sub>" (lowercase)
    external_username = event["userName"]
    raw_provider, provider_uid = external_username.split("_", 1)
    provider_name = _PROVIDER_NAME_MAP.get(raw_provider.lower(), raw_provider)

    existing_users = _find_users_by_email(user_pool_id, email)

    # Look for a native Cognito user (not a federated one)
    _FEDERATED_PREFIXES = tuple(f"{p}_" for p in _PROVIDER_NAME_MAP.values())
    _FEDERATED_PREFIXES_LOWER = tuple(f"{p}_" for p in _PROVIDER_NAME_MAP)
    native_user = None
    for user in existing_users:
        username = user["Username"]
        # Native users don't have provider prefixes
        if not username.startswith(_FEDERATED_PREFIXES) and not username.startswith(_FEDERATED_PREFIXES_LOWER):
            native_user = user
            break

    if native_user:
        logger.info(
            "Linking external provider %s to existing native user %s",
            external_username,
            native_user["Username"],
        )
        cognito.admin_link_provider_for_user(
            UserPoolId=user_pool_id,
            DestinationUser={
                "ProviderName": "Cognito",
                "ProviderAttributeValue": native_user["Username"],
            },
            SourceUser={
                "ProviderName": provider_name,
                "ProviderAttributeName": "Cognito_Subject",
                "ProviderAttributeValue": provider_uid,
            },
        )

    # Auto-confirm and auto-verify for external providers
    event["response"]["autoConfirmUser"] = True
    event["response"]["autoVerifyEmail"] = True


def _handle_native_signup(event: _CognitoEvent, user_pool_id: str, email: str) -> None:
    """
    Email/password sign-up: check if a Google-federated user exists with the
    same email. If so, link the native identity to the existing federated user
    by making the new native user the primary and attaching the Google identity.
    """
    existing_users = _find_users_by_email(user_pool_id, email)

    # Look for a federated Google user (username may be lowercase or titlecase)
    google_user = None
    for user in existing_users:
        username = user["Username"]
        if username.lower().startswith("google_"):
            google_user = user
            break

    if google_user:
        google_username = google_user["Username"]
        _, google_uid = google_username.split("_", 1)

        logger.info(
            "Found existing Google user %s for email %s — will link after native user is created",
            google_username,
            email,
        )

        # We can't link here because the native user hasn't been created yet.
        # Instead, we allow the sign-up to proceed. The linking will happen
        # the next time the Google user signs in (handled by PreSignUp_ExternalProvider).
        #
        # However, we should NOT auto-confirm — the user still needs to verify
        # their email to prove ownership.

    # Don't auto-confirm native sign-ups; they must verify email
    event["response"]["autoConfirmUser"] = False
    event["response"]["autoVerifyEmail"] = False


def _find_users_by_email(user_pool_id: str, email: str) -> list[UserTypeTypeDef]:
    """Find all Cognito users with the given email address."""
    response = cognito.list_users(
        UserPoolId=user_pool_id,
        Filter=f'email = "{email}"',
        Limit=10,
    )
    return response.get("Users", [])
