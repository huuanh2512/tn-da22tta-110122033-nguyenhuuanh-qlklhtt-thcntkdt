const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const User = require('../models/user.model');

const connectDB = async () => {
  try {
    const uri = process.env.MONGODB_URI;
    if (!uri) {
      throw new Error('MONGODB_URI is not defined in environment variables');
    }

    await mongoose.connect(uri);
    console.log('MongoDB connected successfully');

    const adminExist = await User.findOne({ role: 'ADMIN' });
        if (!adminExist && process.env.ALLOW_DEVELOPMENT_SEED === 'true') {
            const hashedPassword = await bcrypt.hash('123456', 10);
            
            await User.create({
                email: 'admin.system@gmail.com',
                password: hashedPassword,
                role: 'ADMIN',
                status: 'ACTIVE',
                emailVerifiedAt: new Date(),
                profile: {
                    name: 'System Admin',
                    phone: '',
                    avatar_url: ''
                }
            });
            
            console.log('[Init] Super Admin account created automatically: admin.system@gmail.com / 123456');
        }
  } catch (error) {
    console.error('MongoDB connection error:', error.message);
    process.exit(1);
  }
};

module.exports = connectDB;
