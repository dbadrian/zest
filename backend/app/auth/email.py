HTML_PASSWORD_RESET_EMAIL_TEMPLATE = """\
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

WELCOME_EMAIL_HTML = """\
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Welcome to Zest</title>
</head>
<body style="margin:0; padding:0; font-family: Arial, Helvetica, sans-serif; background-color:#f6f6f6;">
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr>
      <td align="center" style="padding:30px 10px;">
        <table width="600" cellpadding="0" cellspacing="0"
               style="background-color:#ffffff; border-radius:6px; overflow:hidden;">

          <tr>
            <td style="padding:30px; text-align:center; background-color:#1f2937; color:#ffffff;">
              <h1 style="margin:0; font-size:28px;">WELCOME TO ZEST</h1>
            </td>
          </tr>

          <tr>
            <td style="padding:30px; color:#333333;">
              <p style="font-size:16px;">
                Dear <strong>{user}</strong>,
              </p>

              <p style="font-size:16px; line-height:1.5;">
                We invite you to try out <strong>Zest</strong> — your private,
                forward-thinking recipe management solution.
              </p>

              <p style="font-size:16px; line-height:1.5;">
                You can set yourself a new password using the link below.
                This link is valid for the next <strong>{reset_time}</strong>.
              </p>

              <p style="text-align:center; margin:30px 0;">
                <a href="{reset_link}"
                   style="background-color:#2563eb; color:#ffffff; text-decoration:none;
                          padding:12px 24px; border-radius:4px; font-size:16px;">
                  Set Your Password
                </a>
              </p>

              <p style="font-size:16px; line-height:1.5;">
                Download the Zest desktop app for <strong>Linux</strong> or
                <strong>Windows</strong>, or install the Android app from the Play Store:
              </p>

              <p style="font-size:16px;">
                👉 <a href="{download_link_playstore}" style="color:#2563eb;">
                  Download Zest Apps
                </a>
              </p>

              <p style="font-size:16px; margin-top:30px;">
                Happy cooking,<br>
                <strong>The Zest Team</strong>
              </p>
            </td>
          </tr>

          <tr>
            <td style="padding:20px; text-align:center; font-size:12px;
                       color:#777777; background-color:#f3f4f6;">
              © Zest — All rights reserved
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
"""
