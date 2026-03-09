"""
Cognito Pre Sign-Up Lambda Trigger

Prevents duplicate accounts by enforcing one-user-per-email across all
sign-in providers (native email/password, Google, Apple, etc.).

Trigger sources handled:

- PreSignUp_ExternalProvider: A federated user is signing in for the first
  time. If any user with the same email already exists, the new provider
  identity is linked to the existing user via adminLinkProviderForUser.
  Errors block signup to prevent duplicates (fail closed).

- PreSignUp_SignUp: A native user is signing up with email/password.
  If any user with the same email already exists, signup is blocked
  outright — the user must sign in with their existing provider.
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

    if trigger == "PreSignUp_ExternalProvider":
        _handle_external_provider(event, user_pool_id, email)
    elif trigger == "PreSignUp_SignUp":
        _handle_native_signup(event, user_pool_id, email)

    return event


def _handle_external_provider(event: _CognitoEvent, user_pool_id: str, email: str) -> None:
    """
    Federated sign-in (Google, Apple, etc.): if any user with the same
    email already exists, link the new provider identity to that user.
    If linking fails, the exception propagates and blocks signup.
    """
    external_username = event["userName"]
    raw_provider, provider_uid = external_username.split("_", 1)
    provider_name = _PROVIDER_NAME_MAP.get(raw_provider.lower(), raw_provider)

    existing_user = _find_existing_user(user_pool_id, email, exclude_username=external_username)

    if existing_user:
        dest_username = existing_user.get("Username", "")
        logger.info(
            "Linking external provider %s to existing user %s",
            external_username,
            dest_username,
        )
        cognito.admin_link_provider_for_user(
            UserPoolId=user_pool_id,
            DestinationUser={
                "ProviderName": "Cognito",
                "ProviderAttributeValue": dest_username,
            },
            SourceUser={
                "ProviderName": provider_name,
                "ProviderAttributeName": "Cognito_Subject",
                "ProviderAttributeValue": provider_uid,
            },
        )

    event["response"]["autoConfirmUser"] = True
    event["response"]["autoVerifyEmail"] = True


def _handle_native_signup(event: _CognitoEvent, user_pool_id: str, email: str) -> None:
    """
    Email/password sign-up: block if any user with this email already
    exists. The unverified email at this stage makes linking unsafe, so
    we direct the user to sign in with their existing provider instead.
    """
    existing_user = _find_existing_user(user_pool_id, email)

    if existing_user:
        logger.warning("Blocking native signup for %s — account already exists", email)
        raise Exception("AccountAlreadyExists")

    event["response"]["autoConfirmUser"] = False
    event["response"]["autoVerifyEmail"] = False


def _find_existing_user(
    user_pool_id: str, email: str, *, exclude_username: str | None = None
) -> UserTypeTypeDef | None:
    """Return the first existing user with this email, or None.

    When called from the external-provider path, *exclude_username* filters
    out the incoming federated identity (which hasn't been created yet but
    whose username is known from the event).
    """
    users = _find_users_by_email(user_pool_id, email)
    for user in users:
        if exclude_username and user.get("Username", "").lower() == exclude_username.lower():
            continue
        return user
    return None


def _find_users_by_email(user_pool_id: str, email: str) -> list[UserTypeTypeDef]:
    """Find all Cognito users with the given email address."""
    response = cognito.list_users(
        UserPoolId=user_pool_id,
        Filter=f'email = "{email}"',
        Limit=10,
    )
    return response.get("Users", [])
