class BookingPriceService {
  _businessError(message, statusCode = 400, code = 'BUSINESS_RULE_VIOLATION') {
    const error = new Error(message);
    error.statusCode = statusCode;
    error.code = code;
    return error;
  }

  calculateBookingPrice(court, startMinutes, endMinutes) {
    if (
      !Number.isInteger(startMinutes)
      || !Number.isInteger(endMinutes)
      || startMinutes < 0
      || endMinutes > 1440
      || startMinutes >= endMinutes
    ) {
      throw this._businessError(
        'Khung giờ đặt sân không hợp lệ.',
        400,
        'INVALID_BOOKING_TIME'
      );
    }

    const pricePerHour = Number(court?.price_per_hour);
    if (!Number.isFinite(pricePerHour) || pricePerHour <= 0) {
      throw this._businessError(
        'Sân chưa được cấu hình giá hợp lệ.',
        400,
        'COURT_PRICE_NOT_CONFIGURED'
      );
    }

    const durationMinutes = endMinutes - startMinutes;
    const totalPrice = Math.round(pricePerHour * durationMinutes / 60);
    if (!Number.isFinite(totalPrice) || totalPrice < 0) {
      throw this._businessError(
        'Giá đặt sân không hợp lệ.',
        400,
        'COURT_PRICE_NOT_CONFIGURED'
      );
    }

    return totalPrice;
  }
}

module.exports = new BookingPriceService();
