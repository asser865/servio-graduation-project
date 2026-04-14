'use client';

import { useMemo, useState } from 'react';

type Role = 'customer' | 'technician';
type Theme = 'light' | 'dark';
type Locale = 'en' | 'ar';

type Item = {
  title: string;
  body?: string;
  meta?: string;
  badge?: string;
};

const customerTabs = ['Home', 'Services', 'Smart Match', 'Bookings', 'Profile'];
const technicianTabs = ['Dashboard', 'Jobs', 'Earnings', 'Availability', 'Profile'];

const categories = [
  'Plumbing',
  'Electrical',
  'Carpentry',
  'Interior Design',
  'Architecture',
  'HVAC',
  'Cleaning',
];

const topTechnicians: Item[] = [
  { title: 'Ahmed Samir', body: 'Plumbing specialist', meta: '4.9 · 188 jobs', badge: 'Verified' },
  { title: 'Mariam Adel', body: 'Electrical systems', meta: '4.8 · 142 jobs', badge: 'Fast reply' },
  { title: 'Omar Nabil', body: 'Interior finishing', meta: '5.0 · 96 jobs', badge: 'Premium' },
];

const quickBook: Item[] = [
  { title: 'Leak inspection', meta: '250 - 450 EGP' },
  { title: 'AC maintenance', meta: '400 - 700 EGP' },
  { title: 'Apartment painting', meta: '3,500 - 8,000 EGP' },
  { title: 'Socket replacement', meta: '180 - 320 EGP' },
];

const bookingTimeline = ['Booked', 'Confirmed', 'En Route', 'In Progress', 'Done'];

const messages: Array<{ sender: 'user' | 'tech'; text: string }> = [
  { sender: 'tech', text: 'I can arrive around 6:30 PM today.' },
  { sender: 'user', text: 'Perfect. Please bring a replacement valve if needed.' },
  { sender: 'tech', text: 'Already noted. I will confirm once I am on the way.' },
];

const kpis: Item[] = [
  { title: "Today's Earnings", meta: '1,860 EGP' },
  { title: 'Pending Jobs', meta: '4' },
  { title: 'Completed This Week', meta: '17' },
  { title: 'Rating', meta: '4.9 / 5' },
];

function formatTabs(role: Role) {
  return role === 'customer' ? customerTabs : technicianTabs;
}

function StatPill({ label }: { label: string }) {
  return <span className="pill subtle">{label}</span>;
}

function SectionTitle({
  eyebrow,
  title,
  body,
}: {
  eyebrow: string;
  title: string;
  body: string;
}) {
  return (
    <div className="section-heading">
      <span className="eyebrow">{eyebrow}</span>
      <h2>{title}</h2>
      <p>{body}</p>
    </div>
  );
}

function PhoneFrame({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle: string;
  children: React.ReactNode;
}) {
  return (
    <article className="phone-frame">
      <div className="phone-top">
        <div>
          <p>{subtitle}</p>
          <h3>{title}</h3>
        </div>
        <span className="signal-dot" />
      </div>
      <div className="phone-body">{children}</div>
    </article>
  );
}

function MiniCard({ item }: { item: Item }) {
  return (
    <div className="mini-card">
      <div className="mini-card-row">
        <strong>{item.title}</strong>
        {item.badge ? <span className="pill accent">{item.badge}</span> : null}
      </div>
      {item.body ? <p>{item.body}</p> : null}
      {item.meta ? <span className="meta">{item.meta}</span> : null}
    </div>
  );
}

export default function HomePage() {
  const [theme, setTheme] = useState<Theme>('light');
  const [role, setRole] = useState<Role>('customer');
  const [locale, setLocale] = useState<Locale>('en');

  const isArabic = locale === 'ar';
  const tabs = useMemo(() => formatTabs(role), [role]);

  return (
    <main className="servio-shell" data-theme={theme} dir={isArabic ? 'rtl' : 'ltr'}>
      <section className="hero-panel">
        <div className="hero-copy">
          <span className="brand-mark">SERVIO</span>
          <h1>{isArabic ? 'خدمات منزلية موثوقة، بذكاء في الاختيار' : 'Trusted Home Services, Intelligently Matched'}</h1>
          <p>
            {isArabic
              ? 'نموذج منتج متكامل يعرض هوية SERVIO، الرحلات الأساسية للعملاء والفنيين، ودعم العربية والإنجليزية مع واجهة دافئة وواثقة.'
              : 'A premium product prototype for SERVIO with role-aware navigation, bilingual support, warm-minimal visual language, and the core customer and technician journeys.'}
          </p>
          <div className="hero-actions">
            <button className="button primary">Explore Prototype</button>
            <button className="button secondary">Review Components</button>
          </div>
          <div className="hero-stats">
            <StatPill label="Arabic + English" />
            <StatPill label="RTL Ready" />
            <StatPill label="Customer + Technician" />
            <StatPill label="Light + Dark" />
          </div>
        </div>
        <div className="control-panel">
          <div className="control-group">
            <span>Theme</span>
            <div className="segmented">
              <button className={theme === 'light' ? 'active' : ''} onClick={() => setTheme('light')}>
                Light
              </button>
              <button className={theme === 'dark' ? 'active' : ''} onClick={() => setTheme('dark')}>
                Dark
              </button>
            </div>
          </div>
          <div className="control-group">
            <span>Role</span>
            <div className="segmented">
              <button className={role === 'customer' ? 'active' : ''} onClick={() => setRole('customer')}>
                Customer
              </button>
              <button className={role === 'technician' ? 'active' : ''} onClick={() => setRole('technician')}>
                Technician
              </button>
            </div>
          </div>
          <div className="control-group">
            <span>Language</span>
            <div className="segmented">
              <button className={locale === 'en' ? 'active' : ''} onClick={() => setLocale('en')}>
                EN
              </button>
              <button className={locale === 'ar' ? 'active' : ''} onClick={() => setLocale('ar')}>
                AR
              </button>
            </div>
          </div>
          <div className="inline-note">
            <strong>{role === 'customer' ? 'Customer tabs' : 'Technician tabs'}</strong>
            <p>{tabs.join(' · ')}</p>
          </div>
        </div>
      </section>

      <section className="content-section">
        <SectionTitle
          eyebrow="Foundation"
          title="Design System"
          body="The interface uses your warm neutral palette, rounded geometry, soft shadows, gradient CTAs, and calm typography across every state."
        />
        <div className="component-grid">
          <div className="component-card">
            <h3>Buttons</h3>
            <div className="button-stack">
              <button className="button primary">Primary CTA</button>
              <button className="button secondary">Secondary</button>
              <button className="button outline">Outline</button>
              <button className="button ghost">Ghost</button>
              <button className="button danger">Danger</button>
            </div>
          </div>
          <div className="component-card">
            <h3>Tokens</h3>
            <div className="swatch-grid">
              {['bg', 'surface', 'accent', 'primary', 'brown', 'success', 'warning', 'danger'].map((token) => (
                <div className="swatch" key={token}>
                  <span className={`swatch-color ${token}`} />
                  <strong>{token}</strong>
                </div>
              ))}
            </div>
          </div>
          <div className="component-card">
            <h3>Chips & Status</h3>
            <div className="chip-row">
              <span className="pill accent">Verified ✓</span>
              <span className="pill success">Confirmed</span>
              <span className="pill warning">Under Review</span>
              <span className="pill danger">Cancelled</span>
              <span className="pill subtle">Interior Design</span>
            </div>
          </div>
        </div>
      </section>

      <section className="content-section">
        <SectionTitle
          eyebrow="Journey"
          title="Onboarding to Home"
          body="The opening flow establishes the brand, selects the marketplace role, and lands the user on a high-confidence, booking-first home feed."
        />
        <div className="phone-grid">
          <PhoneFrame title="Splash" subtitle="01">
            <div className="splash-screen">
              <span className="brand-mark big">SERVIO</span>
              <p>{isArabic ? 'خدمات منزلية موثوقة' : 'Trusted Home Services'}</p>
            </div>
          </PhoneFrame>
          <PhoneFrame title="Onboarding" subtitle="02">
            <div className="stack">
              <div className="hero-banner warm">
                <h4>{isArabic ? 'منزلك، بأيدٍ خبيرة' : 'Your Home, Expertly Maintained'}</h4>
                <p>{isArabic ? 'احجز سباكة وكهرباء وتشطيب وتنظيف بسهولة.' : 'Book plumbing, electrical, finishing, and cleaning with clarity.'}</p>
              </div>
              <div className="pagination-dots">
                <span className="active" />
                <span />
                <span />
              </div>
              <button className="button primary wide">Get Started</button>
            </div>
          </PhoneFrame>
          <PhoneFrame title="Role Selection" subtitle="03">
            <div className="stack">
              <div className={`choice-card ${role === 'customer' ? 'selected' : ''}`}>
                <strong>I need services</strong>
                <p>Book trusted technicians near you</p>
              </div>
              <div className={`choice-card ${role === 'technician' ? 'selected' : ''}`}>
                <strong>I&apos;m a technician</strong>
                <p>Receive jobs and manage earnings</p>
              </div>
              <button className="button primary wide">Continue</button>
            </div>
          </PhoneFrame>
          <PhoneFrame title="Home Feed" subtitle="04">
            <div className="stack">
              <div className="search-row">
                <span className="pill subtle">Cairo, Maadi</span>
                <div className="search-bar">Search services or technicians</div>
              </div>
              <div className="hero-banner brand">
                <h4>What needs fixing today?</h4>
                <p>Use Smart Match for an instant recommendation.</p>
              </div>
              <div className="horizontal-list">
                {categories.slice(0, 5).map((category) => (
                  <span className="category-chip" key={category}>
                    {category}
                  </span>
                ))}
              </div>
              <div className="stack compact">
                {topTechnicians.map((item) => (
                  <MiniCard item={item} key={item.title} />
                ))}
              </div>
            </div>
          </PhoneFrame>
        </div>
      </section>

      <section className="content-section">
        <SectionTitle
          eyebrow="Customer Flow"
          title="Browse, Compare, Book"
          body="The booking journey keeps pricing, provider trust, and schedule clarity visible from discovery through payment and confirmation."
        />
        <div className="phone-grid">
          <PhoneFrame title="Marketplace" subtitle="05">
            <div className="stack">
              <div className="search-row">
                <div className="search-bar">Plumbing services</div>
                <span className="filter-badge">Filter</span>
              </div>
              <div className="horizontal-list">
                {['All', 'Plumbing', 'Electrical', 'Carpentry'].map((filter) => (
                  <span className={`pill ${filter === 'Plumbing' ? 'accent' : 'subtle'}`} key={filter}>
                    {filter}
                  </span>
                ))}
              </div>
              <MiniCard item={{ title: 'Emergency pipe repair', body: 'Fast same-day plumbing support', meta: '350 - 700 EGP', badge: 'Verified' }} />
              <MiniCard item={{ title: 'Water heater checkup', body: 'Diagnostics and safety inspection', meta: '280 - 520 EGP' }} />
            </div>
          </PhoneFrame>
          <PhoneFrame title="Technician Profile" subtitle="06">
            <div className="stack">
              <div className="profile-hero">
                <div className="avatar large">AS</div>
                <div>
                  <h4>Ahmed Samir</h4>
                  <p>Plumbing specialist · Maadi</p>
                </div>
                <span className="pill success">Available Today</span>
              </div>
              <div className="stat-row">
                <div>
                  <strong>4.9</strong>
                  <span>Rating</span>
                </div>
                <div>
                  <strong>188</strong>
                  <span>Jobs</span>
                </div>
                <div>
                  <strong>35m</strong>
                  <span>Reply</span>
                </div>
                <div>
                  <strong>320</strong>
                  <span>EGP/hr</span>
                </div>
              </div>
              <MiniCard item={{ title: 'Bathroom leak repair', body: 'Includes diagnosis, sealing, and pressure test', meta: 'Approx. 90 mins', badge: 'Emergency' }} />
              <button className="button primary wide">Book Now</button>
            </div>
          </PhoneFrame>
          <PhoneFrame title="Booking Flow" subtitle="07">
            <div className="stack">
              <div className="progress-track">
                <span className="active" />
                <span className="active" />
                <span />
              </div>
              <MiniCard item={{ title: 'Bathroom leak repair', meta: 'Ahmed Samir · Plumbing' }} />
              <div className="calendar-card">
                <strong>28/03/2026</strong>
                <p>Evening slot · 6:00 PM</p>
              </div>
              <div className="payment-card">
                <span>Vodafone Cash</span>
                <strong>680 EGP</strong>
              </div>
              <button className="button primary wide">Confirm Booking</button>
            </div>
          </PhoneFrame>
          <PhoneFrame title="Booking Details" subtitle="08">
            <div className="stack">
              <div className="status-header">
                <span className="pill success">Confirmed</span>
                <strong>Reference SRV-20481</strong>
              </div>
              <div className="timeline">
                {bookingTimeline.map((step, index) => (
                  <div className={`timeline-step ${index < 2 ? 'done' : ''}`} key={step}>
                    <span />
                    <p>{step}</p>
                  </div>
                ))}
              </div>
              <MiniCard item={{ title: 'Ahmed Samir', body: 'Bathroom leak repair', meta: '28/03/2026 · 6:00 PM' }} />
              <div className="button-row">
                <button className="button outline">Message</button>
                <button className="button ghost">Call</button>
              </div>
            </div>
          </PhoneFrame>
        </div>
      </section>

      <section className="content-section">
        <SectionTitle
          eyebrow="AI Tools"
          title="Smart Match and Cost Estimation"
          body="AI entry points stay useful, grounded, and conversion-oriented, ending in a recommended technician or a budget range the customer can act on."
        />
        <div className="phone-grid dual">
          <PhoneFrame title="Smart Match" subtitle="09">
            <div className="stack">
              <div className="hero-banner brand soft">
                <h4>Describe your problem</h4>
                <p>My kitchen sink is leaking under the cabinet.</p>
              </div>
              <div className="horizontal-list">
                {['Water leak', 'Power outage', 'Broken door', 'Paint job'].map((chip) => (
                  <span className="pill subtle" key={chip}>
                    {chip}
                  </span>
                ))}
              </div>
              <button className="button primary wide">Find Match</button>
              <div className="stack compact">
                <MiniCard item={{ title: 'Ahmed Samir', body: 'Matched on leak repair history', meta: '96% match', badge: 'Top fit' }} />
                <MiniCard item={{ title: 'Mina Hany', body: 'Nearby and available this evening', meta: '91% match' }} />
              </div>
            </div>
          </PhoneFrame>
          <PhoneFrame title="Cost Estimator" subtitle="10">
            <div className="stack">
              <div className="progress-track">
                <span className="active" />
                <span className="active" />
                <span className="active" />
                <span />
              </div>
              <div className="mini-card emphasized">
                <strong>Total estimate</strong>
                <h4>85,000 - 120,000 EGP</h4>
                <p>Standard full-apartment finishing in Cairo</p>
              </div>
              <MiniCard item={{ title: 'Materials', meta: '50,000 - 72,000 EGP' }} />
              <MiniCard item={{ title: 'Labor', meta: '25,000 - 36,000 EGP' }} />
              <MiniCard item={{ title: 'Vendor margin', meta: '10,000 - 12,000 EGP' }} />
            </div>
          </PhoneFrame>
        </div>
      </section>

      <section className="content-section">
        <SectionTitle
          eyebrow="Technician Flow"
          title="Accept, Execute, Get Paid"
          body="The technician side favors speed and operational clarity, with urgent requests, job progression, availability control, and earnings visibility."
        />
        <div className="phone-grid">
          <PhoneFrame title="Overview" subtitle="11">
            <div className="stack">
              <div className="profile-hero compact">
                <div>
                  <h4>Good morning, Ahmed</h4>
                  <p>4 pending actions today</p>
                </div>
                <span className="notification-dot" />
              </div>
              <div className="kpi-grid">
                {kpis.map((item) => (
                  <div className="kpi-card" key={item.title}>
                    <span>{item.title}</span>
                    <strong>{item.meta}</strong>
                  </div>
                ))}
              </div>
              <div className="alert-card">
                <strong>Incoming Job Request</strong>
                <p>Emergency pipe repair · 2.4 km away · 45 mins</p>
                <div className="button-row">
                  <button className="button outline success-tone">Accept</button>
                  <button className="button ghost danger-tone">Decline</button>
                </div>
              </div>
            </div>
          </PhoneFrame>
          <PhoneFrame title="Job Queue" subtitle="12">
            <div className="stack">
              <div className="horizontal-list">
                {['Pending', 'Confirmed', 'In Progress', 'Completed'].map((tab, index) => (
                  <span className={`pill ${index === 0 ? 'accent' : 'subtle'}`} key={tab}>
                    {tab}
                  </span>
                ))}
              </div>
              <MiniCard item={{ title: 'Emergency pipe repair', body: 'Customer: Salma Nader · Nasr City', meta: 'Today · 5:30 PM', badge: 'Pending' }} />
              <MiniCard item={{ title: 'AC maintenance', body: 'Customer: Karim Hossam · Maadi', meta: 'Tomorrow · 11:00 AM', badge: 'Confirmed' }} />
            </div>
          </PhoneFrame>
          <PhoneFrame title="Earnings" subtitle="13">
            <div className="stack">
              <div className="mini-card emphasized">
                <strong>This Month</strong>
                <h4>24,680 EGP</h4>
                <p>Paid 18,200 · Pending 6,480</p>
              </div>
              <div className="chart">
                <span style={{ height: '38%' }} />
                <span style={{ height: '62%' }} />
                <span style={{ height: '49%' }} />
                <span style={{ height: '78%' }} />
                <span style={{ height: '55%' }} />
                <span style={{ height: '88%' }} />
              </div>
              <MiniCard item={{ title: 'Apartment painting', meta: '3,800 EGP · Paid' }} />
            </div>
          </PhoneFrame>
          <PhoneFrame title="Availability" subtitle="14">
            <div className="stack">
              <div className="horizontal-list">
                {['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map((day) => (
                  <span className={`pill ${day === 'Fri' ? 'danger' : 'success'}`} key={day}>
                    {day}
                  </span>
                ))}
              </div>
              <div className="availability-grid">
                {['09:00', '11:00', '13:00', '15:00', '17:00', '19:00'].map((slot, index) => (
                  <div className={`slot ${index === 2 || index === 5 ? 'off' : 'on'}`} key={slot}>
                    {slot}
                  </div>
                ))}
              </div>
              <button className="button primary wide">Save Availability</button>
            </div>
          </PhoneFrame>
        </div>
      </section>

      <section className="content-section">
        <SectionTitle
          eyebrow="Support"
          title="Messaging, Reviews, and Settings"
          body="Shared utility surfaces retain the same visual language while adapting to customer and technician needs."
        />
        <div className="phone-grid triple">
          <PhoneFrame title="Messages" subtitle="15">
            <div className="chat-thread">
              {messages.map((message, index) => (
                <div className={`chat-bubble ${message.sender}`} key={`${message.sender}-${index}`}>
                  {message.text}
                </div>
              ))}
              <div className="chat-input">Type a message...</div>
            </div>
          </PhoneFrame>
          <PhoneFrame title="Write a Review" subtitle="16">
            <div className="stack">
              <MiniCard item={{ title: 'Ahmed Samir', body: 'Bathroom leak repair', meta: 'Completed on 24/03/2026' }} />
              <div className="stars">★★★★★</div>
              <div className="review-box">
                Fast response, clear pricing, and tidy work. Would book again.
              </div>
              <button className="button primary wide">Submit Review</button>
            </div>
          </PhoneFrame>
          <PhoneFrame title="Settings" subtitle="17">
            <div className="stack compact">
              {['Edit Profile', 'Notifications', 'Dark Mode', 'Language', 'Help Center', 'Privacy'].map((item) => (
                <div className="settings-row" key={item}>
                  <span>{item}</span>
                  <span>›</span>
                </div>
              ))}
              <button className="button danger wide">Log Out</button>
            </div>
          </PhoneFrame>
        </div>
      </section>
    </main>
  );
}
