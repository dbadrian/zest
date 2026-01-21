from email.message import EmailMessage
from email.utils import formataddr
import aiosmtplib

from app.core.config import settings

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
                This link is valid for the next <strong>78 hours</strong>.
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




def format_from(name: str | None, email: str) -> str:
    assert isinstance(email, str), "SMTP From email must be a string"
    assert email.strip(), "SMTP From email must not be empty"
    assert "@" in email, "SMTP From email must be a valid email address"

    if name is not None:
        assert isinstance(name, str), "SMTP From name must be a string"
        assert name.strip(), "SMTP From name must not be empty if provided"

    return formataddr((name, email)) if name else email


async def send_email(
    to: str | list[str],
    subject: str,
    body: str,
    html: bool = False,
):
    assert to, "`to` must not be empty"
    assert subject and subject.strip(), "`subject` must not be empty"
    assert body and body.strip(), "`body` must not be empty"

    
    
    message = EmailMessage()
    message["From"] = format_from('zest', "no-reply@dbadrian.com")
    message["To"] = to if isinstance(to, str) else ", ".join(to)
    message["Subject"] = subject

    if html:
        message.add_alternative(body, subtype="html")
    else:
        message.set_content(body)

    await aiosmtplib.send(
        message,
        hostname="smtp.mailbox.org",
        port=587,
        username="dbadrian@mailbox.org",
        password="siwv-xhzd-tmeq-rcpp",
        start_tls=settings.SMTP_TLS,
    )



if __name__ == "__main__":
    html_body = WELCOME_EMAIL_HTML.format(
        user="Alice",
        reset_link="https://zest.example/reset?token=abc",
        download_link_desktop="https://zest.example/downloads"
        download_link_playstore="https://zest.example/downloads"
    )
    import asyncio
    asyncio.run(
    send_email("yezwiki@gmail.com", "This is a test mail", html_body, html=True))