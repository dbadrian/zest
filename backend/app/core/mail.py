from email.message import EmailMessage
from email.utils import formataddr
import aiosmtplib

from app.core.config import settings


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
    message["From"] = format_from(settings.EMAILS_FROM_NAME, settings.EMAILS_FROM_EMAIL)
    message["To"] = to if isinstance(to, str) else ", ".join(to)
    message["Subject"] = subject

    if html:
        message.add_alternative(body, subtype="html")
    else:
        message.set_content(body)


    await aiosmtplib.send(
        message,
        hostname=settings.SMTP_HOST,
        port=settings.SMTP_PORT,
        username=settings.SMTP_USER,
        password=settings.SMTP_PASSWORD,
        start_tls=settings.SMTP_TLS,
    )

