"""
Cognito Custom Message Lambda Trigger

Intercepts Cognito email events and returns branded HTML templates
for verification codes and password reset codes.  Template styling
mirrors the Cosmonaut website dark theme.
"""

from __future__ import annotations

import os
from typing import TypedDict

# CDN domain for branded assets (e.g. images.cosmonaut-ai.com)
_CDN_DOMAIN = os.environ.get("STATIC_CONTENT_CDN_DOMAIN", "")

# ---------------------------------------------------------------------------
# Brand constants (dark-theme palette from the Cosmonaut website)
# ---------------------------------------------------------------------------
_BG = "#1a2030"
_CARD_BG = "#242d3e"
_CARD_BORDER = "#3d4d63"
_PRIMARY = "#e8c949"
_PRIMARY_FG = "#1a2030"
_FG = "#f1f4f7"
_MUTED = "#b1bfcc"
_MUTED_DARK = "#7a8a9e"
_FOOTER_TEXT = "#6b7a8e"
_DIVIDER = "#3d4d63"
_CODE_BG = "#1a2030"
_CODE_BORDER = "#e8c949"
_FONT = "Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"


# ---------------------------------------------------------------------------
# Cognito Custom Message event types
# ---------------------------------------------------------------------------


class _Request(TypedDict, total=False):
    userAttributes: dict[str, str]
    codeParameter: str


class _Response(TypedDict, total=False):
    emailMessage: str
    emailSubject: str
    smsMessage: str


class _CognitoEvent(TypedDict):
    triggerSource: str
    userPoolId: str
    userName: str
    request: _Request
    response: _Response


def handler(event: _CognitoEvent, _context: object) -> _CognitoEvent:
    trigger = event.get("triggerSource", "")
    code_param = event["request"].get("codeParameter", "{####}")
    user_attrs = event["request"].get("userAttributes", {})
    name: str = user_attrs.get("given_name") or user_attrs.get("name") or ""

    if trigger == "CustomMessage_SignUp":
        event["response"]["emailSubject"] = "Welcome to Cosmonaut — Verify your email"
        event["response"]["emailMessage"] = _verification_email(code_param, name)

    elif trigger == "CustomMessage_ResendCode":
        event["response"]["emailSubject"] = "Your Cosmonaut verification code"
        event["response"]["emailMessage"] = _verification_email(code_param, name)

    elif trigger == "CustomMessage_ForgotPassword":
        event["response"]["emailSubject"] = "Reset your Cosmonaut password"
        event["response"]["emailMessage"] = _reset_password_email(code_param, name)

    return event


def _logo_html() -> str:
    """Return the logo markup — an <img> from the CDN or a text fallback."""
    if _CDN_DOMAIN:
        return (
            f'<img src="https://{_CDN_DOMAIN}/meta/favicon.png" '
            f'alt="Cosmonaut" width="36" height="36" '
            f'style="display:block;border:0;border-radius:8px;" />'
        )
    return (
        f'<div style="width:36px;height:36px;border-radius:8px;'
        f"background-color:{_PRIMARY};text-align:center;line-height:36px;"
        f'font-size:20px;color:{_PRIMARY_FG};">C</div>'
    )


def _base_template(title: str, body_content: str) -> str:
    """Shared branded email wrapper matching the Cosmonaut dark theme."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title>
</head>
<body style="margin:0;padding:0;background-color:{_BG};font-family:{_FONT};">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:{_BG};min-height:100vh;">
<tr><td align="center" style="padding:40px 16px;">

<!-- Main card -->
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background-color:{_CARD_BG};border-radius:16px;border:1px solid {_CARD_BORDER};overflow:hidden;">

<!-- Logo header -->
<tr><td align="center" style="padding:32px 32px 16px;">
  <table role="presentation" cellpadding="0" cellspacing="0">
  <tr>
    <td style="padding-right:10px;vertical-align:middle;">
      {_logo_html()}
    </td>
    <td style="vertical-align:middle;">
      <span style="font-size:20px;font-weight:700;color:{_FG};letter-spacing:0.5px;">Cosmonaut</span>
    </td>
  </tr>
  </table>
</td></tr>

<!-- Divider -->
<tr><td style="padding:0 32px;">
  <div style="height:1px;background:linear-gradient(90deg,transparent,{_DIVIDER},transparent);"></div>
</td></tr>

<!-- Body content -->
<tr><td style="padding:24px 32px 32px;">
  {body_content}
</td></tr>

</table>

<!-- Footer -->
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;">
<tr><td align="center" style="padding:24px 32px;">
  <p style="margin:0;font-size:12px;color:{_FOOTER_TEXT};line-height:1.6;">
    You received this email because an action was taken on your Cosmonaut account.<br>
    If you didn't request this, you can safely ignore it.
  </p>
  <p style="margin:12px 0 0;font-size:12px;color:{_FOOTER_TEXT};">
    Matson Software LLC &middot; <a href="https://cosmonaut-ai.com" style="color:{_PRIMARY};text-decoration:none;">cosmonaut-ai.com</a>
  </p>
</td></tr>
</table>

</td></tr>
</table>
</body>
</html>"""


def _verification_email(code_param: str, name: str) -> str:
    greeting = f"Hi {name}," if name else "Hi there,"
    body = f"""
  <p style="margin:0 0 16px;font-size:15px;color:{_MUTED};line-height:1.6;">
    {greeting}
  </p>
  <p style="margin:0 0 24px;font-size:15px;color:{_MUTED};line-height:1.6;">
    Welcome to Cosmonaut! Use the code below to verify your email address and start creating interactive story worlds.
  </p>

  <!-- Code box -->
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
  <tr><td align="center">
    <div style="display:inline-block;padding:16px 40px;background-color:{_CODE_BG};border:2px solid {_CODE_BORDER};border-radius:12px;letter-spacing:6px;font-size:28px;font-weight:700;color:{_FG};font-family:'Courier New',monospace;">
      {code_param}
    </div>
  </td></tr>
  </table>

  <p style="margin:24px 0 0;font-size:13px;color:{_MUTED_DARK};line-height:1.6;">
    This code expires in 24 hours. If you didn't create a Cosmonaut account, you can ignore this email.
  </p>"""
    return _base_template("Verify your email", body)


def _reset_password_email(code_param: str, name: str) -> str:
    greeting = f"Hi {name}," if name else "Hi there,"
    body = f"""
  <p style="margin:0 0 16px;font-size:15px;color:{_MUTED};line-height:1.6;">
    {greeting}
  </p>
  <p style="margin:0 0 24px;font-size:15px;color:{_MUTED};line-height:1.6;">
    We received a request to reset your Cosmonaut password. Enter the code below to choose a new password.
  </p>

  <!-- Code box -->
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
  <tr><td align="center">
    <div style="display:inline-block;padding:16px 40px;background-color:{_CODE_BG};border:2px solid {_CODE_BORDER};border-radius:12px;letter-spacing:6px;font-size:28px;font-weight:700;color:{_FG};font-family:'Courier New',monospace;">
      {code_param}
    </div>
  </td></tr>
  </table>

  <p style="margin:24px 0 0;font-size:13px;color:{_MUTED_DARK};line-height:1.6;">
    This code expires in 1 hour. If you didn't request a password reset, you can safely ignore this email &mdash; your password won't change.
  </p>"""
    return _base_template("Reset your password", body)
