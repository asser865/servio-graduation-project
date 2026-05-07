// One-time script to seed an admin user.
// Usage: node scripts/create-admin.js <email> <password> [name]
// Example: node scripts/create-admin.js admin@servio.app Admin1234 "SERVIO Admin"

require('dotenv').config();
const dns      = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);
const mongoose = require('mongoose');
const User     = require('../src/modules/users/user.model');

const [,, email, password, name = 'Admin'] = process.argv;

if (!email || !password) {
  console.error('Usage: node scripts/create-admin.js <email> <password> [name]');
  process.exit(1);
}

if (password.length < 8 || !/\d/.test(password)) {
  console.error('Password must be at least 8 characters and contain at least one number.');
  process.exit(1);
}

(async () => {
  await mongoose.connect(process.env.MONGODB_URI);

  const existing = await User.findOne({ email });
  if (existing) {
    console.error(`A user with email "${email}" already exists (role: ${existing.role}).`);
    await mongoose.disconnect();
    process.exit(1);
  }

  await User.create({
    name,
    email,
    password,
    role: 'admin',
    isActive: true,
    isVerified: true,
    verificationStatus: 'approved',
  });

  console.log(`✅ Admin created: ${email}`);
  await mongoose.disconnect();
})();
