require('dotenv').config({ path: require('path').resolve(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const bcrypt   = require('bcryptjs');
const Service  = require('../src/modules/services/service.model');
const User     = require('../src/modules/users/user.model');

const TEST_TECHNICIANS = [
  {
    name: 'Plumbing', email: 'plumbing@test.com', password: 'Test1234!',
    category: 'plumbing', phone: '+201000000001',
    bio: 'Expert plumber specialising in leak repairs and pipe installations.',
    hourlyRate: 150,
    locationLabel: 'Nasr City',
    serviceArea: 'Nasr City, Cairo',
    coverageAreas: ['Nasr City', 'Heliopolis', 'Madinaty', 'New Cairo', 'Cairo'],
  },
  {
    name: 'Electrical', email: 'electrical@test.com', password: 'Test1234!',
    category: 'electrical', phone: '+201000000002',
    bio: 'Licensed electrician for wiring, lighting, and electrical repairs.',
    hourlyRate: 120,
    locationLabel: 'Heliopolis',
    serviceArea: 'Heliopolis, Cairo',
    coverageAreas: ['Heliopolis', 'Nasr City', 'Madinaty', 'New Cairo', 'Cairo'],
  },
  {
    name: 'Carpentry', email: 'carpentry@test.com', password: 'Test1234!',
    category: 'carpentry', phone: '+201000000003',
    bio: 'Skilled carpenter for furniture repairs and custom woodwork.',
    hourlyRate: 180,
    locationLabel: 'Maadi',
    serviceArea: 'Maadi, Cairo',
    coverageAreas: ['Maadi', 'Zamalek', 'Garden City', 'Giza', 'Cairo'],
  },
  {
    name: 'HVAC', email: 'hvac@test.com', password: 'Test1234!',
    category: 'hvac', phone: '+201000000004',
    bio: 'Certified HVAC technician for AC installation, servicing, and repair.',
    hourlyRate: 200,
    locationLabel: 'Giza',
    serviceArea: 'Giza',
    coverageAreas: ['Giza', 'Dokki', 'Haram', 'October City', 'Cairo'],
  },
  {
    name: 'Cleaning', email: 'cleaning@test.com', password: 'Test1234!',
    category: 'cleaning', phone: '+201000000005',
    bio: 'Professional cleaner providing deep cleaning and sanitation services.',
    hourlyRate: 100,
    locationLabel: 'Downtown Cairo',
    serviceArea: 'Downtown Cairo',
    coverageAreas: ['Downtown Cairo', 'Zamalek', 'Garden City', 'Maadi', 'Cairo'],
  },
  {
    name: 'Painting', email: 'painting@test.com', password: 'Test1234!',
    category: 'painting', phone: '+201000000006',
    bio: 'Professional painter for interior and exterior wall painting.',
    hourlyRate: 130,
    locationLabel: 'October City',
    serviceArea: 'October City, Giza',
    coverageAreas: ['October City', 'Giza', 'Maadi', 'Dokki', 'Cairo'],
  },
  {
    name: 'Appliance', email: 'appliance@test.com', password: 'Test1234!',
    category: 'appliance', phone: '+201000000007',
    bio: 'Appliance repair specialist for washing machines, ovens, and refrigerators.',
    hourlyRate: 140,
    locationLabel: 'Nasr City',
    serviceArea: 'Nasr City, Cairo',
    coverageAreas: ['Nasr City', 'Heliopolis', 'Madinaty', 'New Cairo', 'Cairo'],
  },
  {
    name: 'Handyman', email: 'handyman@test.com', password: 'Test1234!',
    category: 'handyman', phone: '+201000000008',
    bio: 'General handyman for mounting, assembly, and small household repairs.',
    hourlyRate: 110,
    locationLabel: 'Maadi',
    serviceArea: 'Maadi, Cairo',
    coverageAreas: ['Maadi', 'Zamalek', 'Garden City', 'Giza', 'Cairo'],
  },
];

async function seed() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('✅ Connected to MongoDB');

  const results = [];

  for (const tech of TEST_TECHNICIANS) {
    // Find the matching service by category
    const service = await Service.findOne({ category: tech.category, isActive: true });
    if (!service) {
      console.warn(`⚠️  No active service found for category "${tech.category}" — skipping ${tech.name}`);
      continue;
    }

    // Remove any existing test account with this email
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
      services:           [{ serviceId: service._id, startsFrom: service.basePrice }],
      categories:         [tech.category],
      bio:                tech.bio,
      hourlyRate:         tech.hourlyRate,
      yearsExperience:    3,
      availabilityType:   'both',
      isActive:           true,
      isAvailable:        true,
      locationLabel:      tech.locationLabel,
      serviceArea:        tech.serviceArea,
      coverageAreas:      tech.coverageAreas,
      address: {
        city:  'Cairo',
        state: 'Cairo Governorate',
      },
    });

    results.push({
      id:       worker._id.toString(),
      name:     worker.name,
      email:    tech.email,
      password: tech.password,
      service:  service.title,
      serviceId: service._id.toString(),
      verified: worker.isVerified,
      status:   worker.verificationStatus,
    });

    console.log(`✅ Created technician: ${worker.name} (${tech.email}) → service: "${service.title}"`);
  }

  console.log('\n📋 Summary of created test technicians:\n');
  console.table(results);

  await mongoose.disconnect();
  console.log('\n✅ Done. All test technicians seeded successfully.');
}

seed().catch(e => { console.error('❌ Seed failed:', e.message); process.exit(1); });
