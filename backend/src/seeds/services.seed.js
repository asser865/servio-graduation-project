require('dotenv').config({ path: require('path').resolve(__dirname, '../..', '.env') });
const mongoose = require('mongoose');
const Service  = require('../modules/services/service.model');
const User     = require('../modules/users/user.model');

const SERVICES_DATA = [
  // ── Home Maintenance & Repair ─────────────────────────────────────────────
  {
    title:       'Plumbing',
    description: 'Leak repairs, pipe fixes, and general plumbing work.',
    category:    'plumbing',
    basePrice:   150,
    priceUnit:   'per_hour',
  },
  {
    title:       'Electrical',
    description: 'Wiring, lighting installation, and precision electrical repairs.',
    category:    'electrical',
    basePrice:   120,
    priceUnit:   'per_hour',
  },
  {
    title:       'A/C Maintenance & HVAC',
    description: 'Installation, servicing, and repair of air conditioning units.',
    category:    'hvac',
    basePrice:   300,
    priceUnit:   'fixed',
  },
  {
    title:       'Carpentry',
    description: 'Woodwork, precision furniture repairs, and structural fixes.',
    category:    'carpentry',
    basePrice:   180,
    priceUnit:   'per_hour',
  },
  {
    title:       'Appliance Services',
    description: 'Installation, maintenance, and repair of complex household appliances.',
    category:    'appliance',
    basePrice:   150,
    priceUnit:   'fixed',
  },
  {
    title:       'Handyman Tasks',
    description: 'General repairs and small fix-it jobs executed with mastery.',
    category:    'handyman',
    basePrice:   80,
    priceUnit:   'per_hour',
  },

  // ── Home Improvement & Finishing ──────────────────────────────────────────
  {
    title:       'Home Finishing & Renovation',
    description: 'Complete renovation projects, planning, and material estimation.',
    category:    'renovation',
    basePrice:   500,
    priceUnit:   'per_sqm',
  },
  {
    title:       'Painting',
    description: 'Interior wall painting, wallpapering, and premium finishing.',
    category:    'painting',
    basePrice:   25,
    priceUnit:   'per_sqm',
  },
  {
    title:       'Flooring',
    description: 'Installation and repair of hardwood, stone, and bespoke surfaces.',
    category:    'flooring',
    basePrice:   120,
    priceUnit:   'per_sqm',
  },
  {
    title:       'Drywall',
    description: 'Drywall installation, seamless patching, and professional finishing.',
    category:    'drywall',
    basePrice:   80,
    priceUnit:   'per_sqm',
  },
  {
    title:       'Roofing',
    description: 'Leak repair, tile replacement, and general architectural roofing.',
    category:    'roofing',
    basePrice:   350,
    priceUnit:   'fixed',
  },

  // ── Specialized & Exterior Services ──────────────────────────────────────
  {
    title:       'Professional Cleaning',
    description: 'Regular cleaning, deep restorative sanitation, and construction cleanup.',
    category:    'cleaning',
    basePrice:   250,
    priceUnit:   'fixed',
  },
  {
    title:       'Pest Control',
    description: 'Elimination of household pests with eco-conscious precision.',
    category:    'pest-control',
    basePrice:   280,
    priceUnit:   'fixed',
  },
  {
    title:       'Landscaping',
    description: 'Garden maintenance, lawn care, and exterior plantings.',
    category:    'landscaping',
    basePrice:   150,
    priceUnit:   'per_hour',
  },
  {
    title:       'Installation Services',
    description: 'Proper integration of TVs, shelves, and other wall-mounted items.',
    category:    'installation',
    basePrice:   100,
    priceUnit:   'fixed',
  },
];

async function seed() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('✅ Connected to MongoDB');

  const admin = await User.findOne({ role: 'admin' });
  if (!admin) {
    console.error('❌ No admin user found. Create an admin account first, then re-run this seed.');
    process.exit(1);
  }
  console.log(`👤 Using admin: ${admin.email}`);

  await Service.deleteMany({});
  console.log('🗑️  Cleared existing services');

  const docs = SERVICES_DATA.map(s => ({ ...s, createdBy: admin._id }));
  await Service.insertMany(docs);

  console.log(`✅ Seeded ${docs.length} services successfully`);
  await mongoose.disconnect();
}

seed().catch(e => { console.error('Seed failed:', e.message); process.exit(1); });
