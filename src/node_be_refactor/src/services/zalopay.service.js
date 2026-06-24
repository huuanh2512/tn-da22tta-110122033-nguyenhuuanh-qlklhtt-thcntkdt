const crypto = require('crypto');
const https = require('https');
const querystring = require('querystring');

/**
 * ZaloPay Sandbox Service
 * Xử lý tất cả tương tác với ZaloPay Sandbox API:
 *  - Tạo đơn hàng (create order)
 *  - Xác minh callback từ ZaloPay server
 *  - Truy vấn trạng thái đơn hàng
 */
class ZaloPayService {
  constructor() {
    this.appId   = parseInt(process.env.ZALOPAY_APP_ID, 10);
    this.key1    = process.env.ZALOPAY_KEY1;
    this.key2    = process.env.ZALOPAY_KEY2;
    this.baseUrl = process.env.ZALOPAY_SANDBOX_URL || 'https://sb-openapi.zalopay.vn/v2';
    this.callbackUrl = process.env.ZALOPAY_CALLBACK_URL;
  }

  /**
   * Tạo HMAC-SHA256
   */
  _hmacSha256(data, key) {
    return crypto.createHmac('sha256', key).update(data).digest('hex');
  }

  /**
   * Gọi HTTP POST tới ZaloPay API (x-www-form-urlencoded)
   * @returns {Promise<object>} parsed JSON response
   */
  _post(path, params) {
    return new Promise((resolve, reject) => {
      const postData = querystring.stringify(params);
      const url = new URL(`${this.baseUrl}${path}`);

      const options = {
        hostname: url.hostname,
        port: 443,
        path: url.pathname,
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': Buffer.byteLength(postData),
        },
      };

      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(new Error(`ZaloPay response parse error: ${data}`));
          }
        });
      });

      req.on('error', reject);
      req.write(postData);
      req.end();
    });
  }

  /**
   * Tạo app_trans_id theo format ZaloPay: yyMMdd_<suffix>
   * Tổng chiều dài tối đa 40 ký tự, suffix tối đa 33 ký tự
   */
  _buildAppTransId(paymentId) {
    const now = new Date();
    const yy = String(now.getFullYear()).slice(2);
    const MM = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
    const datePrefix = `${yy}${MM}${dd}`;          // 6 ký tự

    // Lấy 20 ký tự đầu của paymentId + timestamp ngắn để tránh trùng
    const shortId  = paymentId.replace(/[^a-zA-Z0-9]/g, '').substring(0, 16);
    const tsShort  = (Date.now() % 100000).toString().padStart(5, '0'); // 5 chữ số
    const suffix   = `${shortId}${tsShort}`;       // tối đa 21 ký tự

    return `${datePrefix}_${suffix}`;              // tổng: 6+1+21 = 28 ký tự ✓
  }

  /**
   * Tạo đơn hàng trên ZaloPay Sandbox
   * @param {object} params
   * @param {string} params.paymentId  - MongoDB Payment._id
   * @param {string} params.bookingId  - MongoDB Booking._id
   * @param {number} params.amount     - Số tiền (VND, phải là integer)
   * @returns {Promise<{order_url, app_trans_id, qr_code}|null>}
   */
  async createOrder({ paymentId, bookingId, amount }) {
    const appTransId = this._buildAppTransId(paymentId);
    const appTime    = Date.now();
    const amountInt  = Math.round(Number(amount));

    const embedData = JSON.stringify({
      redirecturl: `${this.callbackUrl}`,
      bookingId,
      paymentId,
    });
    const item = JSON.stringify([]);

    // MAC formula: app_id|app_trans_id|app_user|amount|app_time|embed_data|item
    const macInput = `${this.appId}|${appTransId}|sport_user|${amountInt}|${appTime}|${embedData}|${item}`;
    const mac = this._hmacSha256(macInput, this.key1);

    const params = {
      app_id:       this.appId,
      app_user:     'sport_user',
      app_trans_id: appTransId,
      app_time:     appTime,
      amount:       amountInt,
      item,
      embed_data:   embedData,
      description:  `Sport Energy - Thanh toan dat san #${String(bookingId).substring(0, 8)}`,
      bank_code:    '',
      callback_url: this.callbackUrl,
      mac,
    };

    console.log(`[ZaloPay] Creating order: appTransId=${appTransId}, amount=${amountInt}`);

    try {
      const res = await this._post('/create', params);
      console.log(`[ZaloPay] Create order response: return_code=${res.return_code}, msg=${res.return_message}`);

      if (res.return_code === 1) {
        // Tạo deeplink để mở thẳng ZaloPay sandbox app (scheme: zalopay://)
        const zpTransToken = res.zp_trans_token || null;
        // deeplink format: zalopay://zalopay.vn/v2/order?zptoken=<token>
        const deeplinkUrl = zpTransToken
          ? `zalopay://zalopay.vn/v2/order?zptoken=${zpTransToken}`
          : res.order_url; // fallback về web nếu không có token

        if (!res.qr_code) {
          console.warn('[ZaloPay] Sandbox did not return qr_code; using order_url for the QR fallback.');
        }

        return {
          order_url:      res.order_url,
          deeplink_url:   deeplinkUrl,
          zp_trans_token: zpTransToken,
          app_trans_id:   appTransId,
          // A gateway URL is scannable from another device, unlike a custom
          // zalopay:// deep link which is intended for the current device.
          qr_code:        res.qr_code || res.order_url || deeplinkUrl || null,
        };
      }

      console.error(`[ZaloPay] Create order failed: ${res.return_message} (sub: ${res.sub_return_message})`);
      return null;
    } catch (err) {
      console.error('[ZaloPay] Create order error:', err.message);
      throw err;
    }
  }

  /**
   * Xác minh chữ ký MAC trong callback từ ZaloPay server
   * ZaloPay gửi: { data, mac, type }
   * MAC formula: HMAC-SHA256(data, key2)
   * @returns {{ valid: boolean, parsedData: object|null }}
   */
  verifyCallback({ data, mac }) {
    try {
      const expectedMac = this._hmacSha256(data, this.key2);
      const expectedBuffer = Buffer.from(expectedMac, 'hex');
      const receivedBuffer = Buffer.from(String(mac), 'hex');
      if (
        expectedBuffer.length !== receivedBuffer.length
        || !crypto.timingSafeEqual(expectedBuffer, receivedBuffer)
      ) {
        console.warn('[ZaloPay] Callback MAC mismatch!');
        return { valid: false, parsedData: null };
      }
      const parsedData = JSON.parse(data);
      return { valid: true, parsedData };
    } catch (err) {
      console.error('[ZaloPay] verifyCallback error:', err.message);
      return { valid: false, parsedData: null };
    }
  }

  /**
   * Truy vấn trạng thái đơn hàng trực tiếp từ ZaloPay
   * @param {string} appTransId
   * @returns {Promise<{isPaid: boolean, returnCode: number, message: string}>}
   */
  async queryOrder(appTransId) {
    // MAC formula: app_id|app_trans_id|key1
    const macInput = `${this.appId}|${appTransId}|${this.key1}`;
    const mac = this._hmacSha256(macInput, this.key1);

    const params = {
      app_id:       this.appId,
      app_trans_id: appTransId,
      mac,
    };

    console.log(`[ZaloPay] Querying order: appTransId=${appTransId}`);

    try {
      const res = await this._post('/query', params);
      console.log(
        `[ZaloPay] Query response: return_code=${res.return_code}, `
        + `sub_return_code=${res.sub_return_code ?? ''}, `
        + `message=${res.return_message || ''}, `
        + `sub_message=${res.sub_return_message || ''}`
      );

      return {
        isPaid:     res.return_code === 1,
        returnCode: res.return_code,
        message:    res.return_message || '',
        subReturnCode: res.sub_return_code ?? null,
        subMessage: res.sub_return_message || '',
      };
    } catch (err) {
      console.error('[ZaloPay] Query order error:', err.message);
      throw err;
    }
  }
}

module.exports = new ZaloPayService();
