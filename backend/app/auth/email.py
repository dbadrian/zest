HTML_PASSWORD_RESET_EMAIL_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Password Reset</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <style>
    body {{
      margin: 0;
      padding: 0;
      background-color: #f4f6f8;
      font-family: Arial, Helvetica, sans-serif;
      color: #333333;
    }}
    .container {{
      max-width: 600px;
      margin: 40px auto;
      background-color: #ffffff;
      padding: 32px;
      border-radius: 6px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
    }}
    h1 {{
      font-size: 20px;
      margin-bottom: 16px;
    }}
    p {{
      font-size: 14px;
      line-height: 1.6;
      margin: 0 0 16px;
    }}
    .button {{
      display: inline-block;
      margin: 24px 0;
      padding: 12px 24px;
      background-color: #0066cc;
      color: #ffffff !important;
      text-decoration: none;
      font-size: 14px;
      font-weight: bold;
      border-radius: 4px;
    }}
    .footer {{
      font-size: 12px;
      color: #777777;
      margin-top: 32px;
    }}
  </style>
</head>
<body>
  <div class="container">
    <h1>Password Reset Request</h1>

    <p>Dear User,</p>

    <p>
      We received a request to reset the password associated with your account.
      You can reset your password by clicking the button below.
    </p>

    <p>
      This password reset link is valid for <strong>30 minutes</strong>.
    </p>

    <a href="{reset_link}" class="button">
      Reset Password
    </a>

    <p>
      If you did not request a password reset, please contact us immediately at
      <a href="mailto:admin@dbadrian.com">admin@dbadrian.com</a>.
    </p>

    <div class="footer">
      <p>
        For security reasons, please do not share this email or link with anyone.
      </p>
    </div>
  </div>
</body>
</html>
"""