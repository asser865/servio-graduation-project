require('dotenv').config({ path: require('path').resolve(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const bcrypt   = require('bcryptjs');
const Service  = require('../src/modules/services/service.model');
const User     = require('../src/modules/users/user.model');

const TEST_TECHNICIANS = [
  {
    name:       'Ahmed Multi',
    email:      'ahmed.multi@test.com',
    password:   'Test1234!',
    categories: ['plumbing', 'electrical'],
    phone:      '+201000000011',
    bio:        'Dual-skilled technician covering plumbing and electrical work.',
    hourlyRate: 160,
  },
  {
    name:       'Sara Multi',
    email:      'sara.multi@test.com',
    password:   'Test1234!',
    categories: ['carpentry', 'painting', 'flooring'],
    phone:      '+201000000012',
    bio:        'Home finishing specialist in carpentry, painting, and flooring.',
    hourlyRate: 170,
  },
  {
    name:       'Omar Multi',
    email:      'omar.multi@test.com',
    password:   'Test1234!',
    categories: ['hvac', 'cleaning'],
    phone:      '+201000000013',
    bio:        'All-round technician for HVAC systems and professional cleaning.',
    hourlyRate: 190,
  },
];

async function seed() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('✅ Connected to MongoDB');

  const results = [];

  for (const tech of TEST_TECHNICIANS) {
    const services = await Service.find({ category: { $in: tech.categories }, isActive: true });

    const foundCategories = services.map(s => s.category);
    const missing = tech.categories.filter(c => !foundCategories.includes(c));
    if (missing.length) {
      console.warn(`⚠️  Missing services for categories: ${missing.join(', ')} — skipping ${tech.name}`);
      continue;
    }

    await User.deleteOne({ email: tech.email });

    const hashedPassword = await bcrypt.hash(tech.password, 12);

    const worker = await User.create({
      name:               tech.name,
      email:              tech.email,
      password:           hashedPassword,
      phone:              tech.phone,
      role:               'worker',
      isVerified:         true,
      verificationStatus: 'approved',
      verificationSubmittedAt: new Date(),
      verificationReviewedAt:  new Date(),
      services:           services.map(s => s._id),
      categories:         tech.categories,
      bio:                tech.bio,
      hourlyRate:         tech.hourlyRate,
      yearsExperience:    5,
      availabilityType:   'both',
      isActive:           true,
      address: { city: 'Cairo', state: 'Cairo Governorate' },
    });

    results.push({
      id:       worker._id.toString(),
      name:     worker.name,
      email:    tech.email,
      password: tech.password,
      services: services.map(s => s.title).join(' | '),
      verified: worker.isVerified,
      status:   worker.verificationStatus,
    });

    console.log(`✅ Created: ${worker.name} (${tech.email}) → services: ${services.map(s => s.title).join(', ')}`);
  }

  console.log('\n📋 Summary:\n');
  console.table(results);

  await mongoose.disconnect();
  console.log('\n✅ Done.');
}

seed().catch(e => { console.error('❌ Seed failed:', e.message); process.exit(1); });
