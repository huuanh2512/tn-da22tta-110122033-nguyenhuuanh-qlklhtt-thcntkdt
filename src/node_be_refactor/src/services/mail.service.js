const nodemailer = require('nodemailer');
const dns = require('node:dns');
const net = require('node:net');

// Render's outbound network does not provide IPv6. Nodemailer resolves both
// address families internally and can otherwise select an unreachable IPv6
// address for smtp.gmail.com. Open the connection through an IPv4 A record
// while keeping the hostname intact for STARTTLS/SNI.
const getIpv4Socket = (options, callback) => {
  dns.resolve4(options.host, (resolveError, addresses) => {
    if (resolveError) return callback(resolveError);
    if (!addresses?.length) return callback(new Error(`No IPv4 address found for ${options.host}`));

    const socket = net.connect({ host: addresses[Math.floor(Math.random() * addresses.length)], port: Number(options.port) });
    let settled = false;
    const finish = (error, result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      callback(error, result);
    };
    const timeout = setTimeout(() => {
      socket.destroy();
      finish(new Error(`SMTP IPv4 connection timed out after ${options.connectionTimeout || 10000}ms`));
    }, options.connectionTimeout || 10000);

    socket.once('error', error => {
      finish(error);
    });
    socket.once('connect', () => {
      finish(null, { connection: socket });
    });
  });
};

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: parseInt(process.env.SMTP_PORT || '587'),
  secure: process.env.SMTP_SECURE === 'true', // true for port 465, false for other ports
  connectionTimeout: 10000,
  greetingTimeout: 10000,
  socketTimeout: 15000,
  getSocket: getIpv4Socket,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

const sender = () => process.env.SMTP_FROM || process.env.SMTP_USER || 'no-reply@sportenergy.com';

const sendAccountVerificationOtpEmail = async (email, otp) => {
  if (!process.env.SMTP_USER || !process.env.SMTP_PASS) {
    const error = new Error('SMTP credentials are not configured');
    error.code = 'SMTP_NOT_CONFIGURED';
    throw error;
  }
  const mailOptions = {
    from: `"Sport Energy" <${sender()}>`,
    to: email,
    subject: 'Mã xác thực tài khoản Sport Energy',
    html: `
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#333;max-width:600px;margin:auto">
        <h2 style="color:#FF5600">Xác thực tài khoản Sport Energy</h2>
        <p>Chào bạn,</p>
        <p>Mã xác thực tài khoản của bạn là:</p>
        <p style="font-size:28px;font-weight:bold;letter-spacing:6px;color:#FF5600">${otp}</p>
        <p>Mã có hiệu lực trong <strong>10 phút</strong> và chỉ dùng một lần.</p>
        <p>Không chia sẻ mã này với bất kỳ ai. Nếu bạn không tạo tài khoản, hãy bỏ qua email này.</p>
      </div>`
  };
  return transporter.sendMail(mailOptions);
};

const sendVerificationEmail = async (email, otp) => {
  const htmlTemplate = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Xác thực đặt lại mật khẩu</title>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 20px auto; padding: 20px; border: 1px solid #dddddd; border-radius: 8px; background-color: #f9f9f9; }
        .header { text-align: center; border-bottom: 2px solid #FF5600; padding-bottom: 10px; }
        .header h2 { color: #FF5600; margin: 0; }
        .content { padding: 20px 0; }
        .otp-box { font-size: 24px; font-weight: bold; letter-spacing: 4px; text-align: center; padding: 15px; margin: 20px 0; background-color: #ffebe0; border: 1px dashed #FF5600; border-radius: 6px; color: #FF5600; }
        .footer { font-size: 12px; color: #777777; text-align: center; border-top: 1px solid #dddddd; padding-top: 10px; margin-top: 20px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h2>SPORT ENERGY</h2>
        </div>
        <div class="content">
          <p>Xin chào,</p>
          <p>Bạn nhận được email này vì bạn (hoặc ai đó) đã yêu cầu đặt lại mật khẩu cho tài khoản của bạn trên ứng dụng Sport Energy.</p>
          <p>Mã xác thực (OTP) của bạn là:</p>
          <div class="otp-box">${otp}</div>
          <p>Mã xác thực này có hiệu lực trong vòng <strong>10 phút</strong>. Vui lòng không chia sẻ mã này với bất kỳ ai.</p>
          <p>If you did not request a password reset, please ignore this email.</p>
        </div>
        <div class="footer">
          <p>© 2026 Sport Energy. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
  `;

  const mailOptions = {
    from: `"Sport Energy" <${sender()}>`,
    to: email,
    subject: 'Mã xác thực đặt lại mật khẩu - Sport Energy',
    html: htmlTemplate,
  };

  return transporter.sendMail(mailOptions);
};

const sendPasswordChangedEmail = async (email) => {
  const htmlTemplate = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Mật khẩu đã được thay đổi</title>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 20px auto; padding: 20px; border: 1px solid #dddddd; border-radius: 8px; background-color: #f9f9f9; }
        .header { text-align: center; border-bottom: 2px solid #FF5600; padding-bottom: 10px; }
        .header h2 { color: #FF5600; margin: 0; }
        .content { padding: 20px 0; }
        .warning-box { padding: 15px; background-color: #fff9e6; border-left: 4px solid #ffcc00; margin: 20px 0; border-radius: 4px; }
        .footer { font-size: 12px; color: #777777; text-align: center; border-top: 1px solid #dddddd; padding-top: 10px; margin-top: 20px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h2>SPORT ENERGY</h2>
        </div>
        <div class="content">
          <p>Xin chào,</p>
          <p>Chúng tôi xin thông báo rằng mật khẩu cho tài khoản Sport Energy của bạn đã được thay đổi thành công.</p>
          <div class="warning-box">
            <strong>Cảnh báo bảo mật:</strong> Nếu bạn không thực hiện thay đổi này, hãy liên hệ ngay với ban quản trị hoặc bộ phận hỗ trợ của Sport Energy để bảo vệ tài khoản của bạn.
          </div>
        </div>
        <div class="footer">
          <p>© 2026 Sport Energy. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
  `;

  const mailOptions = {
    from: `"Sport Energy" <${sender()}>`,
    to: email,
    subject: 'Cập nhật bảo mật: Mật khẩu tài khoản đã thay đổi - Sport Energy',
    html: htmlTemplate,
  };

  return transporter.sendMail(mailOptions);
};

module.exports = {
  sendAccountVerificationOtpEmail,
  sendVerificationEmail,
  sendPasswordChangedEmail,
};
