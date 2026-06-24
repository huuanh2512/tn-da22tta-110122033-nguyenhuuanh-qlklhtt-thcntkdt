class UploadService {
  _formatFileResponse(file, req) {
    // Cloudinary: multer-storage-cloudinary đặt full URL vào file.path
    const isCloudinary = !!(
      process.env.CLOUDINARY_CLOUD_NAME &&
      process.env.CLOUDINARY_API_KEY &&
      process.env.CLOUDINARY_API_SECRET
    );

    let url;
    if (isCloudinary && file.path && file.path.startsWith('http')) {
      url = file.path; // URL Cloudinary CDN – ổn định vĩnh viễn
    } else {
      const configuredBaseUrl = process.env.UPLOAD_PUBLIC_BASE_URL?.replace(/\/+$/, '');
      const baseUrl = configuredBaseUrl || `${req.protocol}://${req.get('host')}`;
      url = `${baseUrl}/uploads/${file.filename}`;
    }

    return {
      filename: file.filename || file.public_id,
      originalName: file.originalname,
      mimeType: file.mimetype,
      size: file.size,
      url,
    };
  }

  async processSingleUpload(file, req) {
    return { file: this._formatFileResponse(file, req) };
  }

  async processMultipleUpload(files, req) {
    const formattedFiles = files.map(file => this._formatFileResponse(file, req));
    return { files: formattedFiles };
  }
}

module.exports = new UploadService();
