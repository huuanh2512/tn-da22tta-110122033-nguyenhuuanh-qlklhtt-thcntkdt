type ErrorLike = {
  code?: unknown;
  message?: unknown;
  response?: { data?: { code?: unknown; message?: unknown } };
};

const messages: Record<string, string> = {
  'auth/invalid-credential': 'Email hoặc mật khẩu không chính xác.',
  'auth/wrong-password': 'Email hoặc mật khẩu không chính xác.',
  'auth/user-not-found': 'Email hoặc mật khẩu không chính xác.',
  'auth/user-disabled': 'Tài khoản này đã bị vô hiệu hóa. Vui lòng liên hệ quản trị viên.',
  'auth/invalid-email': 'Địa chỉ email không đúng định dạng.',
  'auth/email-already-in-use': 'Địa chỉ email này đã được đăng ký.',
  'auth/weak-password': 'Mật khẩu cần có ít nhất 6 ký tự.',
  'auth/too-many-requests': 'Bạn đã thử quá nhiều lần. Vui lòng chờ ít phút rồi thử lại.',
  'auth/network-request-failed': 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng và thử lại.',
  'auth/requires-recent-login': 'Vui lòng đăng nhập lại rồi thực hiện thao tác này.',
  'auth/operation-not-allowed': 'Phương thức đăng nhập này hiện chưa được hỗ trợ.',
  'auth/expired-action-code': 'Liên kết đã hết hạn. Vui lòng yêu cầu một liên kết mới.',
  'auth/invalid-action-code': 'Liên kết xác thực không hợp lệ hoặc đã được sử dụng.',
  'no-current-user': 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
  'EMAIL_NOT_VERIFIED': 'Email chưa được xác thực. Vui lòng kiểm tra hộp thư của bạn.',
};

/** Converts Firebase Auth errors into messages that are safe to show to users. */
export function firebaseErrorMessage(
  error: unknown,
  fallback = 'Có lỗi xảy ra. Vui lòng thử lại.',
): string {
  const value = error as ErrorLike | undefined;
  const code = String(value?.code ?? value?.response?.data?.code ?? '');
  if (messages[code]) return messages[code];

  const message = String(value?.message ?? '');
  const firebaseCode = message.match(/auth\/([a-z-]+)/i)?.[0];
  if (firebaseCode && messages[firebaseCode]) return messages[firebaseCode];

  // Firebase has changed the wording of some errors between SDK releases.
  if (/invalid-credential|wrong-password|user-not-found/i.test(message)) {
    return messages['auth/invalid-credential'];
  }
  if (/firebase|auth\//i.test(message)) {
    return fallback;
  }

  const backendMessage = value?.response?.data?.message;
  return typeof backendMessage === 'string' && backendMessage.trim()
      ? backendMessage
      : message.trim() || fallback;
}
