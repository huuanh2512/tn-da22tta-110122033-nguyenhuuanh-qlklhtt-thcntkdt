const sendSuccess = (res, data = null, message = 'Operation successful', code = 'OK') => {
    return res.status(200).json({
        success: true,
        message,
        code,
        ...(data && { data })
    });
};

const sendError = (res, statusCode = 400, message = 'Error occurred', code = 'ERROR', errors = null) => {
    return res.status(statusCode).json({
        success: false,
        message,
        code,
        ...(errors && { errors })
    });
};

module.exports = {
    sendSuccess,
    sendError
};