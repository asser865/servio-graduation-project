'use strict';

jest.mock('../src/modules/users/user.model');
jest.mock('axios');

const { extractAreaKeywords } = require('../src/modules/ai/ai.controller');

describe('extractAreaKeywords', () => {
  test('drops city token when district is present', () => {
    expect(extractAreaKeywords('Heliopolis, Cairo')).toEqual(['Heliopolis']);
  });

  test('drops Giza when district token is present', () => {
    expect(extractAreaKeywords('Nasr City, Cairo')).toEqual(['Nasr City']);
  });

  test('returns city when no district exists', () => {
    expect(extractAreaKeywords('Cairo')).toEqual(['Cairo']);
  });

  test('strips street prefix, keeps district', () => {
    const result = extractAreaKeywords('El-Nasr St., Heliopolis, Cairo');
    expect(result).toContain('Heliopolis');
    expect(result).not.toContain('Cairo');
  });

  test('returns empty array for empty string', () => {
    expect(extractAreaKeywords('')).toEqual([]);
  });

  test('returns empty array for null', () => {
    expect(extractAreaKeywords(null)).toEqual([]);
  });

  test('filters pure-number tokens', () => {
    const result = extractAreaKeywords('123, Heliopolis');
    expect(result).not.toContain('123');
    expect(result).toContain('Heliopolis');
  });

  test('handles forward-slash separator', () => {
    const result = extractAreaKeywords('Giza/Cairo');
    // Both are generic so both remain — no specific token to prefer
    expect(result).toEqual(expect.arrayContaining(['Giza', 'Cairo']));
  });

  test('expands space-compound "Dokki Giza" — Dokki is kept, Giza dropped', () => {
    const result = extractAreaKeywords('Dokki Giza');
    expect(result).toContain('Dokki');
    expect(result).not.toContain('Giza');
  });

  test('expands space-compound "Haram Giza" — Haram is kept, Giza dropped', () => {
    const result = extractAreaKeywords('Haram Giza');
    expect(result).toContain('Haram');
    expect(result).not.toContain('Giza');
  });

  test('space-compound with city suffix from prompt — Dokki Giza, budget 300 EGP', () => {
    const result = extractAreaKeywords('Dokki Giza, budget 300 EGP');
    expect(result.length).toBeGreaterThan(0);
    expect(result).toContain('Dokki');
    expect(result).not.toContain('Giza');
  });
});

const axios = require('axios');
const User  = require('../src/modules/users/user.model');
const { getServiceRecommendation, analyzeRoom } = require('../src/modules/ai/ai.controller');

const buildQuery = (users) => ({
  select: jest.fn().mockReturnThis(),
  sort:   jest.fn().mockReturnThis(),
  limit:  jest.fn().mockResolvedValue(users),
});

const mockRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json   = jest.fn().mockReturnValue(res);
  return res;
};

beforeEach(() => {
  process.env.AI_SERVICE_URL = 'http://localhost:5001';
  delete process.env.AI_FINISHER_SERVICE_URL;
  jest.clearAllMocks();
});

describe('analyzeRoom - website AI Finisher routing', () => {
  const roomRequest = () => ({
    file: {
      buffer: Buffer.from('room-image'),
      originalname: 'room.jpg',
      mimetype: 'image/jpeg',
    },
    body: {
      length_m: '4',
      width_m: '5',
      height_m: '2.8',
      budget_egp: '50000',
      style: 'modern',
      include_render: 'false',
    },
  });

  test('prefers the isolated website AI Finisher service URL', async () => {
    process.env.AI_FINISHER_SERVICE_URL = 'http://localhost:8003';
    axios.post = jest.fn().mockResolvedValue({ data: { status: 'success' } });

    await analyzeRoom(roomRequest(), mockRes());

    expect(axios.post).toHaveBeenCalledWith(
      'http://localhost:8003/ai/analyze-room',
      expect.anything(),
      expect.any(Object)
    );
  });

  test('falls back to AI_SERVICE_URL for existing deployments', async () => {
    axios.post = jest.fn().mockResolvedValue({ data: { status: 'success' } });

    await analyzeRoom(roomRequest(), mockRes());

    expect(axios.post).toHaveBeenCalledWith(
      'http://localhost:5001/ai/analyze-room',
      expect.anything(),
      expect.any(Object)
    );
  });
});

describe('getServiceRecommendation — effectiveLocation', () => {
  test('uses req.body.location when AI extracted.location is null', async () => {
    axios.post = jest.fn().mockResolvedValue({
      data: {
        scenario: 'single', recommended_service: 'Plumbing',
        extracted: { location: null, budget: null, time_range: null },
        missing_fields: [], missing_field_labels: [], needs_follow_up: false, issue_mode: 'single',
      },
    });
    User.find = jest.fn().mockReturnValue(buildQuery([]));

    const req = { body: { prompt: 'fix my pipes', location: 'Heliopolis, Cairo' } };
    const res = mockRes();

    await getServiceRecommendation(req, res);

    const envelope = res.json.mock.calls[0][0];
    expect(envelope.data.effectiveLocation).toBe('Heliopolis, Cairo');
  });

  test('AI extracted.location takes precedence over req.body.location', async () => {
    axios.post = jest.fn().mockResolvedValue({
      data: {
        scenario: 'single', recommended_service: 'Plumbing',
        extracted: { location: 'Maadi', budget: null, time_range: null },
        missing_fields: [], missing_field_labels: [], needs_follow_up: false, issue_mode: 'single',
      },
    });
    User.find = jest.fn().mockReturnValue(buildQuery([]));

    const req = { body: { prompt: 'plumber in Maadi', location: 'Heliopolis' } };
    const res = mockRes();

    await getServiceRecommendation(req, res);

    const envelope = res.json.mock.calls[0][0];
    expect(envelope.data.effectiveLocation).toBe('Maadi');
  });

  test('room-only AI location does not override req.body.location', async () => {
    axios.post = jest.fn().mockResolvedValue({
      data: {
        scenario: 'multi', recommended_service: 'Electrical',
        extracted: { location: 'bathroom', budget: '800 EGP', time_range: 'today' },
        steps: [
          { service: 'Electrical', step: 1, urgency: 'urgent' },
          { service: 'Plumbing', step: 2, urgency: 'same_day' },
        ],
        missing_fields: [], missing_field_labels: [], needs_follow_up: false, issue_mode: 'multi',
      },
    });
    User.find = jest.fn().mockReturnValue(buildQuery([]));

    const req = { body: { prompt: 'water on electrical panel in bathroom', location: 'Cairo' } };
    const res = mockRes();

    await getServiceRecommendation(req, res);

    const envelope = res.json.mock.calls[0][0];
    expect(envelope.data.effectiveLocation).toBe('Cairo');
    expect(envelope.data.extracted.location).toBe('Cairo');
    expect(User.find).toHaveBeenCalledWith(
      expect.objectContaining({ $or: expect.any(Array) })
    );
    const filterArg = User.find.mock.calls[0][0];
    const orPatterns = filterArg.$or.map((clause) => Object.values(clause)[0].toString());
    expect(orPatterns.some((p) => /Cairo/i.test(p))).toBe(true);
    expect(orPatterns.some((p) => /bathroom/i.test(p))).toBe(false);
  });

  test('deictic "near me" AI location falls back to req.body.location', async () => {
    axios.post = jest.fn().mockResolvedValue({
      data: {
        scenario: 'single', recommended_service: 'Plumbing',
        extracted: { location: 'Near Me', budget: null, time_range: null },
        missing_fields: [], missing_field_labels: [], needs_follow_up: false, issue_mode: 'single',
      },
    });
    User.find = jest.fn().mockReturnValue(buildQuery([]));

    const req = { body: { prompt: 'i need plumber near me now', location: 'Maadi St, B12, Cairo' } };
    const res = mockRes();

    await getServiceRecommendation(req, res);

    const envelope = res.json.mock.calls[0][0];
    expect(envelope.data.effectiveLocation).toBe('Maadi St, B12, Cairo');
    expect(envelope.data.extracted.location).toBe('Maadi St, B12, Cairo');
    const filterArg = User.find.mock.calls[0][0];
    const orPatterns = filterArg.$or.map((clause) => Object.values(clause)[0].toString());
    expect(orPatterns.some((p) => /Maadi/i.test(p))).toBe(true);
    expect(orPatterns.some((p) => /near me/i.test(p))).toBe(false);
  });

  test('multi-service AI response keeps all service categories for matching', async () => {
    axios.post = jest.fn().mockResolvedValue({
      data: {
        scenario: 'multi', recommended_service: 'Electrical',
        extracted: { location: null, budget: '800 EGP', time_range: 'today' },
        steps: [
          { service: 'Electrical', step: 1, urgency: 'urgent' },
          { service: 'Plumbing', step: 2, urgency: 'same_day' },
          { service: 'Painting', step: 3, urgency: 'low' },
        ],
        missing_fields: [], missing_field_labels: [], needs_follow_up: false, issue_mode: 'multi',
      },
    });
    User.find = jest.fn().mockReturnValue(buildQuery([]));

    const req = {
      body: {
        prompt: 'water dripping on electrical panel and paint bubbling off walls',
        location: 'Cairo',
      },
    };
    const res = mockRes();

    await getServiceRecommendation(req, res);

    const filterArg = User.find.mock.calls[0][0];
    expect(filterArg.categories.$in).toEqual(
      expect.arrayContaining(['electrical', 'plumbing', 'painting'])
    );
  });

  test('effectiveLocation returned for unrecognised (no category)', async () => {
    axios.post = jest.fn().mockResolvedValue({
      data: {
        scenario: 'unrecognized', recommended_service: null,
        extracted: { location: null, budget: null, time_range: null },
        missing_fields: ['problem_details'], missing_field_labels: ['A clearer description of the problem'],
        needs_follow_up: true, issue_mode: 'unrecognized',
      },
    });
    User.find = jest.fn();

    const req = { body: { prompt: 'I need a chef', location: 'Nasr City' } };
    const res = mockRes();

    await getServiceRecommendation(req, res);

    const envelope = res.json.mock.calls[0][0];
    expect(envelope.data.effectiveLocation).toBe('Nasr City');
    expect(User.find).not.toHaveBeenCalled();
  });

  test('no location — $or filter absent from User.find', async () => {
    axios.post = jest.fn().mockResolvedValue({
      data: {
        scenario: 'single', recommended_service: 'Plumbing',
        extracted: { location: null, budget: null, time_range: null },
        missing_fields: [], missing_field_labels: [], needs_follow_up: false, issue_mode: 'single',
      },
    });
    User.find = jest.fn().mockReturnValue(buildQuery([]));

    const req = { body: { prompt: 'fix my pipes' } };
    const res = mockRes();

    await getServiceRecommendation(req, res);

    expect(User.find).toHaveBeenCalledWith(
      expect.not.objectContaining({ $or: expect.anything() })
    );
  });

  test('room-only AI location is removed when no usable location exists', async () => {
    axios.post = jest.fn().mockResolvedValue({
      data: {
        scenario: 'single', recommended_service: 'Plumbing',
        extracted: { location: 'bathroom', budget: null, time_range: null },
        missing_fields: [], missing_field_labels: [], needs_follow_up: false, issue_mode: 'single',
      },
    });
    User.find = jest.fn().mockReturnValue(buildQuery([]));

    const req = { body: { prompt: 'leak in my bathroom' } };
    const res = mockRes();

    await getServiceRecommendation(req, res);

    const envelope = res.json.mock.calls[0][0];
    expect(envelope.data.effectiveLocation).toBe('');
    expect(envelope.data.extracted.location).toBeNull();
  });

  test('district keyword builds $or; generic "Cairo" is absent from filter', async () => {
    axios.post = jest.fn().mockResolvedValue({
      data: {
        scenario: 'single', recommended_service: 'Plumbing',
        extracted: { location: null, budget: null, time_range: null },
        missing_fields: [], missing_field_labels: [], needs_follow_up: false, issue_mode: 'single',
      },
    });
    User.find = jest.fn().mockReturnValue(buildQuery([]));

    const req = { body: { prompt: 'fix my pipes', location: 'Heliopolis, Cairo' } };
    const res = mockRes();

    await getServiceRecommendation(req, res);

    const filterArg = User.find.mock.calls[0][0];
    const orPatterns = filterArg.$or.map((clause) =>
      Object.values(clause)[0].toString()
    );
    expect(orPatterns.some((p) => p.includes('Heliopolis'))).toBe(true);
    expect(orPatterns.some((p) => p.includes('Cairo'))).toBe(false);
  });
});

describe('getServiceRecommendation — AI response post-processing', () => {
  test('removes location from missing_fields when effectiveLocation is set', async () => {
    axios.post = jest.fn().mockResolvedValue({
      data: {
        scenario: 'vague', recommended_service: 'Plumbing',
        extracted: { location: null, budget: '200 EGP', time_range: 'today' },
        missing_fields: ['location'],
        missing_field_labels: ['Location (neighbourhood or city)'],
        needs_follow_up: true, issue_mode: 'single',
        follow_up_message: 'This looks like Plumbing. Add Location (neighbourhood or city) to get better results.',
      },
    });
    User.find = jest.fn().mockReturnValue(buildQuery([]));

    const req = { body: { prompt: 'plumber budget 200 today', location: 'Heliopolis' } };
    const res = mockRes();

    await getServiceRecommendation(req, res);

    const envelope = res.json.mock.calls[0][0];
    expect(envelope.data.missing_fields).not.toContain('location');
    expect(envelope.data.needs_follow_up).toBe(false);
    expect(envelope.data.scenario).toBe('single');
    expect(envelope.data.extracted.location).toBe('Heliopolis');
    expect(envelope.data.follow_up_message).toBe('');
  });

  test('keeps vague if other fields still missing after location is resolved', async () => {
    axios.post = jest.fn().mockResolvedValue({
      data: {
        scenario: 'vague', recommended_service: 'Plumbing',
        extracted: { location: null, budget: null, time_range: null },
        missing_fields: ['location', 'budget'],
        missing_field_labels: ['Location (neighbourhood or city)', 'Budget (EGP amount or range)'],
        needs_follow_up: true, issue_mode: 'single',
        follow_up_message: 'Add Location (neighbourhood or city), Budget (EGP amount or range) to get better results.',
      },
    });
    User.find = jest.fn().mockReturnValue(buildQuery([]));

    const req = { body: { prompt: 'plumber', location: 'Heliopolis' } };
    const res = mockRes();

    await getServiceRecommendation(req, res);

    const envelope = res.json.mock.calls[0][0];
    expect(envelope.data.missing_fields).not.toContain('location');
    expect(envelope.data.missing_fields).toContain('budget');
    expect(envelope.data.needs_follow_up).toBe(true);
    expect(envelope.data.scenario).toBe('vague');
    expect(envelope.data.extracted.location).toBe('Heliopolis');
    expect(envelope.data.follow_up_message).toBe('');
  });

  test('no post-processing when effectiveLocation is empty', async () => {
    axios.post = jest.fn().mockResolvedValue({
      data: {
        scenario: 'vague', recommended_service: 'Plumbing',
        extracted: { location: null, budget: null, time_range: null },
        missing_fields: ['location', 'budget'],
        missing_field_labels: ['Location (neighbourhood or city)', 'Budget (EGP amount or range)'],
        needs_follow_up: true, issue_mode: 'single',
        follow_up_message: 'Add Location (neighbourhood or city), Budget (EGP amount or range).',
      },
    });
    User.find = jest.fn().mockReturnValue(buildQuery([]));

    const req = { body: { prompt: 'plumber' } };
    const res = mockRes();

    await getServiceRecommendation(req, res);

    const envelope = res.json.mock.calls[0][0];
    expect(envelope.data.missing_fields).toContain('location');
    expect(envelope.data.scenario).toBe('vague');
    expect(envelope.data.extracted.location).toBeNull();
    expect(envelope.data.follow_up_message).toContain('Location');
  });
});
