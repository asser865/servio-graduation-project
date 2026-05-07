const nodemailer = require('nodemailer');

function buildTransporter() {
  if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
    return nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT || '587', 10),
      secure: process.env.SMTP_SECURE === 'true',
      auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    });
  }
  return null;
}

async function sendPasswordResetEmail(toEmail, resetUrl) {
  const transporter = buildTransporter();

  if (!transporter) {
    // Dev mode — no SMTP configured, print to console
    console.log('\n─── PASSWORD RESET LINK (dev — no SMTP configured) ───');
    console.log(`To: ${toEmail}`);
    console.log(`Reset URL: ${resetUrl}`);
    console.log('──────────────────────────────────────────────────────\n');
    return;
  }

  await transporter.sendMail({
    from: process.env.SMTP_FROM || `"SERVIO" <${process.env.SMTP_USER}>`,
    to: toEmail,
    subject: '[UPDATED] Reset your SERVIO password',
    html: `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Reset your SERVIO password</title>
</head>
<body style="margin:0;padding:0;background-color:#FAF8F5;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">

  <!-- Outer wrapper -->
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#FAF8F5;padding:40px 16px;">
    <tr>
      <td align="center">

        <!-- Card -->
        <table width="100%" cellpadding="0" cellspacing="0" border="0"
               style="max-width:560px;background:#ffffff;border-radius:20px;
                      box-shadow:0 14px 36px rgba(34,40,49,0.10);overflow:hidden;">

          <!-- ── Header ── -->
          <tr>
            <td style="background:#3C2415;padding:36px 40px 32px;text-align:center;">

              <!-- Logo row -->
              <table align="center" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="padding-right:12px;">
                    <table cellpadding="0" cellspacing="0" border="0" style="background:rgba(227,213,202,0.2);border-radius:12px;">
                      <tr>
                        <td width="42" height="42" align="center" valign="middle" style="font-size:24px;">🛡️</td>
                      </tr>
                    </table>
                  </td>
                  <td>
                    <span style="font-size:26px;font-weight:800;color:#E3D5CA;letter-spacing:2px;">SERVIO</span>
                  </td>
                </tr>
              </table>

              <!-- Divider -->
              <div style="width:48px;height:3px;background:#9A8C73;border-radius:2px;margin:20px auto 0;"></div>
            </td>
          </tr>

          <!-- ── Body ── -->
          <tr>
            <td style="padding:40px 40px 32px;">

              <!-- Hero Icon (Simplified for maximum compatibility) -->
              <table align="center" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:24px;">
                <tr>
                  <td width="80" height="80" align="center" valign="middle" 
                      style="background:#F3EDE7;border:2px solid #E3D5CA;border-radius:40px;font-size:40px;">
                    🔐
                  </td>
                </tr>
              </table>

              <!-- Heading -->
              <h1 style="margin:0 0 12px;font-size:24px;font-weight:700;color:#222831;
                         text-align:center;letter-spacing:-0.3px;">
                Secure Password Reset
              </h1>

              <!-- Subtext -->
              <p style="margin:0 0 28px;font-size:15px;color:#6B6560;text-align:center;line-height:1.6;">
                We received a request to reset your password.<br/>
                Click the button below to proceed securely.
              </p>

              <!-- CTA Button -->
              <table align="center" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:28px;">
                <tr>
                  <td>
                    <a href="${resetUrl}"
                       style="display:inline-block;padding:16px 44px;background:#3C2415;
                              color:#E3D5CA;font-size:15px;font-weight:700;
                              text-decoration:none;border-radius:14px;">
                      Reset My Password
                    </a>
                  </td>
                </tr>
              </table>

              <!-- Expiry notice -->
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F7F3EF;border-radius:12px;">
                <tr>
                  <td style="padding:16px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td width="24" valign="top" style="font-size:18px;">🕒</td>
                        <td style="padding-left:12px;font-size:13px;color:#6B6560;line-height:1.5;">
                          Valid for <strong style="color:#3C2415;">1 hour</strong>.
                          If you didn't request this, please ignore this email.
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Fallback -->
              <p style="margin:24px 0 0;font-size:12px;color:#9A8C73;text-align:center;">
                Button not working? Copy this link:<br/>
                <a href="${resetUrl}" style="color:#3C2415;">${resetUrl}</a>
              </p>

            </td>
          </tr>

          <!-- ── Footer ── -->
          <tr>
            <td style="background:#F7F3EF;border-top:1px solid #DDD5CC;padding:24px 40px;text-align:center;">
              <table align="center" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:16px;">
                <tr>
                  <td style="padding:0 10px;font-size:12px;color:#9A8C73;">🛡️ Verified</td>
                  <td style="padding:0 10px;font-size:12px;color:#9A8C73;">🔒 Secure</td>
                  <td style="padding:0 10px;font-size:12px;color:#9A8C73;">⭐ 4.9 Rating</td>
                </tr>
              </table>
              <p style="margin:0;font-size:12px;color:#9A8C73;">
                © 2026 SERVIO — Home Services Marketplace
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>

</body>
</html>`,
  });
}

async function sendTechAvailableEmail(toEmail, techName, serviceCategory, bookingUrl) {
  const transporter = buildTransporter();
  const displayCategory = serviceCategory.charAt(0).toUpperCase() + serviceCategory.slice(1);

  if (!transporter) {
    console.log('\n─── TECH AVAILABLE NOTIFICATION (dev — no SMTP configured) ───');
    console.log(`To: ${toEmail}`);
    console.log(`Tech: ${techName} | Category: ${displayCategory}`);
    console.log(`Book Now: ${bookingUrl}`);
    console.log('──────────────────────────────────────────────────────────────\n');
    return;
  }

  await transporter.sendMail({
    from: process.env.SMTP_FROM || `"SERVIO" <${process.env.SMTP_USER}>`,
    to:   toEmail,
    subject: `A ${displayCategory} technician is now available on SERVIO`,
    html: `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Technician Available — SERVIO</title>
</head>
<body style="margin:0;padding:0;background-color:#FAF8F5;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">

  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#FAF8F5;padding:40px 16px;">
    <tr>
      <td align="center">

        <table width="100%" cellpadding="0" cellspacing="0" border="0"
               style="max-width:560px;background:#ffffff;border-radius:20px;
                      box-shadow:0 14px 36px rgba(34,40,49,0.10);overflow:hidden;">

          <!-- Header -->
          <tr>
            <td style="background:#3C2415;padding:36px 40px 32px;text-align:center;">
              <table align="center" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="padding-right:12px;">
                    <table cellpadding="0" cellspacing="0" border="0" style="background:rgba(227,213,202,0.2);border-radius:12px;">
                      <tr>
                        <td width="42" height="42" align="center" valign="middle" style="font-size:24px;">🛡️</td>
                      </tr>
                    </table>
                  </td>
                  <td>
                    <span style="font-size:26px;font-weight:800;color:#E3D5CA;letter-spacing:2px;">SERVIO</span>
                  </td>
                </tr>
              </table>
              <div style="width:48px;height:3px;background:#9A8C73;border-radius:2px;margin:20px auto 0;"></div>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:40px 40px 32px;">

              <!-- Icon -->
              <table align="center" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:24px;">
                <tr>
                  <td width="80" height="80" align="center" valign="middle"
                      style="background:#F3EDE7;border:2px solid #E3D5CA;border-radius:40px;font-size:40px;">
                    🟢
                  </td>
                </tr>
              </table>

              <!-- Heading -->
              <h1 style="margin:0 0 12px;font-size:24px;font-weight:700;color:#222831;
                         text-align:center;letter-spacing:-0.3px;">
                Your Technician Is Online
              </h1>

              <!-- Body text -->
              <p style="margin:0 0 8px;font-size:15px;color:#6B6560;text-align:center;line-height:1.6;">
                Good news! A verified <strong style="color:#3C2415;">${displayCategory}</strong> technician
                is now available and accepting bookings.
              </p>
              <p style="margin:0 0 28px;font-size:14px;color:#9A8C73;text-align:center;line-height:1.6;">
                You requested to be notified when one came online. Book now before their slots fill up.
              </p>

              <!-- CTA Button -->
              <table align="center" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:28px;">
                <tr>
                  <td>
                    <a href="${bookingUrl}"
                       style="display:inline-block;padding:16px 44px;background:#3C2415;
                              color:#E3D5CA;font-size:15px;font-weight:700;
                              text-decoration:none;border-radius:14px;">
                      Book Now →
                    </a>
                  </td>
                </tr>
              </table>

              <!-- Note box -->
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F7F3EF;border-radius:12px;">
                <tr>
                  <td style="padding:16px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td width="24" valign="top" style="font-size:18px;">⏰</td>
                        <td style="padding-left:12px;font-size:13px;color:#6B6560;line-height:1.5;">
                          Availability is real-time. Slots may fill quickly — book early to secure your preferred time.
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background:#F7F3EF;border-top:1px solid #DDD5CC;padding:24px 40px;text-align:center;">
              <table align="center" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:16px;">
                <tr>
                  <td style="padding:0 10px;font-size:12px;color:#9A8C73;">🛡️ Verified</td>
                  <td style="padding:0 10px;font-size:12px;color:#9A8C73;">🔒 Secure</td>
                  <td style="padding:0 10px;font-size:12px;color:#9A8C73;">⭐ 4.9 Rating</td>
                </tr>
              </table>
              <p style="margin:0;font-size:12px;color:#9A8C73;">
                © 2026 SERVIO — Home Services Marketplace
              </p>
              <p style="margin:8px 0 0;font-size:11px;color:#C4B9B0;">
                You received this because you subscribed to availability notifications on SERVIO.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>

</body>
</html>`,
  });
}

module.exports = { sendPasswordResetEmail, sendTechAvailableEmail };
