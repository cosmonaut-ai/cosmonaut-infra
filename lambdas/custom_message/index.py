"""
Cognito Custom Message Lambda Trigger

Intercepts Cognito email events and returns branded HTML templates
for verification codes and password reset codes.
"""


def handler(event, context):
    trigger = event.get("triggerSource", "")
    code_param = event["request"].get("codeParameter", "{####}")
    user_attrs = event["request"].get("userAttributes", {})
    name = user_attrs.get("given_name") or user_attrs.get("name") or ""

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


def _base_template(title: str, body_content: str) -> str:
    """Shared branded email wrapper with Cosmonaut space theme."""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title>
</head>
<body style="margin:0;padding:0;background-color:#0a0a0f;font-family:'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#0a0a0f;min-height:100vh;">
<tr><td align="center" style="padding:40px 16px;">

<!-- Main card -->
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background-color:#111118;border-radius:16px;border:1px solid #1e1e2e;overflow:hidden;">

<!-- Logo header -->
<tr><td align="center" style="padding:32px 32px 16px;">
  <table role="presentation" cellpadding="0" cellspacing="0">
  <tr>
    <td style="padding-right:10px;vertical-align:middle;">
      <div style="width:36px;height:36px;border-radius:8px;background-color:rgba(124,58,237,0.15);text-align:center;line-height:36px;font-size:20px;">&#128640;</div>
    </td>
    <td style="vertical-align:middle;">
      <span style="font-size:20px;font-weight:700;color:#f0f0f5;letter-spacing:0.5px;">Cosmonaut</span>
    </td>
  </tr>
  </table>
</td></tr>

<!-- Divider -->
<tr><td style="padding:0 32px;">
  <div style="height:1px;background:linear-gradient(90deg,transparent,#2a2a3a,transparent);"></div>
</td></tr>

<!-- Body content -->
<tr><td style="padding:24px 32px 32px;">
  {body_content}
</td></tr>

</table>

<!-- Footer -->
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;">
<tr><td align="center" style="padding:24px 32px;">
  <p style="margin:0;font-size:12px;color:#555566;line-height:1.6;">
    You received this email because an action was taken on your Cosmonaut account.<br>
    If you didn't request this, you can safely ignore it.
  </p>
  <p style="margin:12px 0 0;font-size:12px;color:#444455;">
    Matson Software LLC &middot; <a href="https://cosmonaut-ai.com" style="color:#7c3aed;text-decoration:none;">cosmonaut-ai.com</a>
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
  <p style="margin:0 0 16px;font-size:15px;color:#c8c8d4;line-height:1.6;">
    {greeting}
  </p>
  <p style="margin:0 0 24px;font-size:15px;color:#c8c8d4;line-height:1.6;">
    Welcome to Cosmonaut! Use the code below to verify your email address and start creating interactive story worlds.
  </p>

  <!-- Code box -->
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
  <tr><td align="center">
    <div style="display:inline-block;padding:16px 40px;background-color:#1a1a28;border:2px solid #7c3aed;border-radius:12px;letter-spacing:6px;font-size:28px;font-weight:700;color:#f0f0f5;font-family:'Courier New',monospace;">
      {code_param}
    </div>
  </td></tr>
  </table>

  <p style="margin:24px 0 0;font-size:13px;color:#888899;line-height:1.6;">
    This code expires in 24 hours. If you didn't create a Cosmonaut account, you can ignore this email.
  </p>"""
    return _base_template("Verify your email", body)


def _reset_password_email(code_param: str, name: str) -> str:
    greeting = f"Hi {name}," if name else "Hi there,"
    body = f"""
  <p style="margin:0 0 16px;font-size:15px;color:#c8c8d4;line-height:1.6;">
    {greeting}
  </p>
  <p style="margin:0 0 24px;font-size:15px;color:#c8c8d4;line-height:1.6;">
    We received a request to reset your Cosmonaut password. Enter the code below to choose a new password.
  </p>

  <!-- Code box -->
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
  <tr><td align="center">
    <div style="display:inline-block;padding:16px 40px;background-color:#1a1a28;border:2px solid #7c3aed;border-radius:12px;letter-spacing:6px;font-size:28px;font-weight:700;color:#f0f0f5;font-family:'Courier New',monospace;">
      {code_param}
    </div>
  </td></tr>
  </table>

  <p style="margin:24px 0 0;font-size:13px;color:#888899;line-height:1.6;">
    This code expires in 1 hour. If you didn't request a password reset, you can safely ignore this email &mdash; your password won't change.
  </p>"""
    return _base_template("Reset your password", body)
