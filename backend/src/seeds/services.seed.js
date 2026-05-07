require('dotenv').config({ path: require('path').resolve(__dirname, '../..', '.env') });
const mongoose = require('mongoose');
const Service  = require('../modules/services/service.model');
const User     = require('../modules/users/user.model');

const SERVICES_DATA = [
  // ── Plumbing ──────────────────────────────────────────────────────────────
  { title: 'Pipe Repair & Replacement',   description: 'Repair or replace leaking, burst, or corroded pipes.',             category: 'plumbing',     basePrice: 150, priceUnit: 'per_hour' },
  { title: 'Drain Cleaning & Unclogging', description: 'Clear blocked drains, sinks, showers, and sewer lines.',           category: 'plumbing',     basePrice: 120, priceUnit: 'fixed'    },
  { title: 'Water Heater Installation',   description: 'Install or replace electric and gas water heaters.',                category: 'plumbing',     basePrice: 350, priceUnit: 'fixed'    },
  { title: 'Faucet & Fixture Repair',     description: 'Fix dripping faucets, replace fixtures, and seal leaks.',          category: 'plumbing',     basePrice: 100, priceUnit: 'fixed'    },
  { title: 'Toilet Repair & Installation',description: 'Repair running toilets, leaks, or install new toilet units.',      category: 'plumbing',     basePrice: 130, priceUnit: 'fixed'    },

  // ── Electrical ────────────────────────────────────────────────────────────
  { title: 'Electrical Wiring',           description: 'Install, repair, or upgrade electrical wiring and cables.',        category: 'electrical',   basePrice: 120, priceUnit: 'per_hour' },
  { title: 'Light Fixture Installation',  description: 'Install chandeliers, ceiling lights, and outdoor fixtures.',       category: 'electrical',   basePrice: 80,  priceUnit: 'fixed'    },
  { title: 'Outlet & Switch Repair',      description: 'Replace faulty outlets, switches, and socket panels.',             category: 'electrical',   basePrice: 70,  priceUnit: 'fixed'    },
  { title: 'Breaker Panel Service',       description: 'Inspect, upgrade, or replace circuit breaker panels.',             category: 'electrical',   basePrice: 250, priceUnit: 'fixed'    },
  { title: 'Electrical Safety Inspection',description: 'Full home electrical safety audit and compliance check.',          category: 'electrical',   basePrice: 200, priceUnit: 'fixed'    },

  // ── HVAC ──────────────────────────────────────────────────────────────────
  { title: 'A/C Installation',            description: 'Install split, window, or central air conditioning units.',        category: 'hvac',         basePrice: 500, priceUnit: 'fixed'    },
  { title: 'A/C Servicing & Cleaning',    description: 'Deep clean filters, coils, and inspect refrigerant levels.',       category: 'hvac',         basePrice: 150, priceUnit: 'fixed'    },
  { title: 'A/C Repair',                  description: 'Diagnose and repair cooling failures, leaks, and electrical faults.',category: 'hvac',        basePrice: 200, priceUnit: 'fixed'    },
  { title: 'Heating System Repair',       description: 'Service and repair central heating and radiator systems.',         category: 'hvac',         basePrice: 180, priceUnit: 'fixed'    },

  // ── Carpentry ─────────────────────────────────────────────────────────────
  { title: 'Door Repair & Installation',  description: 'Fix sticking doors, replace hinges, or install new doors.',        category: 'carpentry',    basePrice: 150, priceUnit: 'fixed'    },
  { title: 'Cabinet & Closet Work',       description: 'Build, repair, or modify kitchen and bedroom cabinets.',           category: 'carpentry',    basePrice: 180, priceUnit: 'per_hour' },
  { title: 'Furniture Assembly',          description: 'Assemble flat-pack and ready-to-assemble furniture.',              category: 'carpentry',    basePrice: 80,  priceUnit: 'per_hour' },
  { title: 'Custom Woodwork',             description: 'Custom shelving, built-ins, and decorative woodwork.',             category: 'carpentry',    basePrice: 200, priceUnit: 'per_hour' },

  // ── Appliances ────────────────────────────────────────────────────────────
  { title: 'Washing Machine Repair',      description: 'Diagnose and fix washing machine faults and drainage issues.',     category: 'appliance',    basePrice: 150, priceUnit: 'fixed'    },
  { title: 'Refrigerator Repair',         description: 'Repair cooling problems, gas leaks, and compressor faults.',       category: 'appliance',    basePrice: 180, priceUnit: 'fixed'    },
  { title: 'Dishwasher Repair',           description: 'Fix leaks, draining issues, and electrical faults in dishwashers.',category: 'appliance',    basePrice: 130, priceUnit: 'fixed'    },
  { title: 'Oven & Stove Repair',         description: 'Service gas and electric ovens, hobs, and cooking ranges.',        category: 'appliance',    basePrice: 140, priceUnit: 'fixed'    },

  // ── Handyman ──────────────────────────────────────────────────────────────
  { title: 'TV & Picture Mounting',       description: 'Wall-mount TVs, mirrors, and picture frames with precision.',      category: 'handyman',     basePrice: 80,  priceUnit: 'fixed'    },
  { title: 'Shelf & Storage Installation',description: 'Install floating shelves, racks, and storage units.',              category: 'handyman',     basePrice: 70,  priceUnit: 'fixed'    },
  { title: 'Door Lock & Key Repair',      description: 'Replace door locks, deadbolts, and repair jammed mechanisms.',     category: 'handyman',     basePrice: 90,  priceUnit: 'fixed'    },
  { title: 'General Repairs',             description: 'Small home fix-it jobs — caulking, patching, tightening, and more.',category: 'handyman',    basePrice: 80,  priceUnit: 'per_hour' },

  // ── Painting ──────────────────────────────────────────────────────────────
  { title: 'Interior Wall Painting',      description: 'Paint rooms with smooth, even coats and clean finish lines.',      category: 'painting',     basePrice: 25,  priceUnit: 'per_sqm'  },
  { title: 'Exterior Painting',           description: 'Paint outdoor walls, gates, and facades for weather protection.',  category: 'painting',     basePrice: 30,  priceUnit: 'per_sqm'  },
  { title: 'Wallpaper Installation',      description: 'Measure, cut, and hang wallpaper with precise alignment.',         category: 'painting',     basePrice: 35,  priceUnit: 'per_sqm'  },

  // ── Flooring ──────────────────────────────────────────────────────────────
  { title: 'Ceramic & Tile Installation', description: 'Lay ceramic, porcelain, and mosaic floor and wall tiles.',         category: 'flooring',     basePrice: 120, priceUnit: 'per_sqm'  },
  { title: 'Hardwood & Parquet Flooring', description: 'Install and refinish solid and engineered hardwood floors.',       category: 'flooring',     basePrice: 180, priceUnit: 'per_sqm'  },
  { title: 'Vinyl & Laminate Flooring',   description: 'Install click-lock vinyl plank and laminate flooring.',            category: 'flooring',     basePrice: 80,  priceUnit: 'per_sqm'  },

  // ── Cleaning ──────────────────────────────────────────────────────────────
  { title: 'Home Deep Cleaning',          description: 'Thorough full-home sanitization including appliances and cabinets.',category: 'cleaning',     basePrice: 350, priceUnit: 'fixed'    },
  { title: 'Regular Home Cleaning',       description: 'Recurring home cleaning service — dusting, mopping, vacuuming.',   category: 'cleaning',     basePrice: 150, priceUnit: 'fixed'    },
  { title: 'Post-Construction Cleaning',  description: 'Remove construction dust and debris after renovation work.',       category: 'cleaning',     basePrice: 30,  priceUnit: 'per_sqm'  },
  { title: 'Move-In / Move-Out Cleaning', description: 'Complete clean for vacant properties before or after moving.',     category: 'cleaning',     basePrice: 400, priceUnit: 'fixed'    },

  // ── Pest Control ──────────────────────────────────────────────────────────
  { title: 'Ant & Cockroach Treatment',   description: 'Targeted treatment to eliminate common household insects.',        category: 'pest-control', basePrice: 200, priceUnit: 'fixed'    },
  { title: 'Termite Treatment',           description: 'Chemical barrier or baiting system for termite elimination.',      category: 'pest-control', basePrice: 450, priceUnit: 'fixed'    },
  { title: 'Rodent Control',              description: 'Set traps and seal entry points to eliminate mice and rats.',      category: 'pest-control', basePrice: 250, priceUnit: 'fixed'    },

  // ── Roofing ───────────────────────────────────────────────────────────────
  { title: 'Roof Leak Repair',            description: 'Locate and seal roof leaks with waterproofing compounds.',         category: 'roofing',      basePrice: 300, priceUnit: 'fixed'    },
  { title: 'Tile & Shingle Replacement',  description: 'Replace cracked or missing roof tiles and shingles.',             category: 'roofing',      basePrice: 25,  priceUnit: 'per_sqm'  },

  // ── Drywall ───────────────────────────────────────────────────────────────
  { title: 'Drywall Installation',        description: 'Install gypsum board partitions, ceilings, and wall panels.',     category: 'drywall',      basePrice: 80,  priceUnit: 'per_sqm'  },
  { title: 'Drywall Patching & Repair',   description: 'Fill holes, cracks, and sand smooth for a seamless finish.',      category: 'drywall',      basePrice: 60,  priceUnit: 'fixed'    },

  // ── Renovation ────────────────────────────────────────────────────────────
  { title: 'Room Renovation',             description: 'Complete room renovation — flooring, walls, and finishing.',       category: 'renovation',   basePrice: 500, priceUnit: 'per_sqm'  },
  { title: 'Kitchen Renovation',          description: 'Full kitchen remodel including cabinets, countertops, and tiling.',category: 'renovation',   basePrice: 600, priceUnit: 'per_sqm'  },
  { title: 'Bathroom Renovation',         description: 'Renovate bathrooms with new tiles, fixtures, and waterproofing.', category: 'renovation',   basePrice: 550, priceUnit: 'per_sqm'  },

  // ── Landscaping ───────────────────────────────────────────────────────────
  { title: 'Garden Maintenance',          description: 'Trim hedges, weed flower beds, and maintain garden health.',       category: 'landscaping',  basePrice: 150, priceUnit: 'per_hour' },
  { title: 'Lawn Care & Mowing',          description: 'Mow, edge, and fertilize lawns for healthy growth.',               category: 'landscaping',  basePrice: 100, priceUnit: 'fixed'    },

  // ── Installation ──────────────────────────────────────────────────────────
  { title: 'Curtain & Blind Installation',description: 'Fit curtain rods, tracks, and blinds with precision.',            category: 'installation', basePrice: 80,  priceUnit: 'fixed'    },
  { title: 'Water Filter Installation',   description: 'Install under-sink or whole-house water filtration systems.',     category: 'installation', basePrice: 150, priceUnit: 'fixed'    },
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
