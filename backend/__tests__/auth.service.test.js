/**
 * Unit tests for auth.service.js — services validation during worker registration.
 */

'use strict';

const { StatusCodes } = require('http-status-codes');

jest.mock('../src/modules/users/user.model');
jest.mock('../src/modules/services/service.model');
jest.mock('../src/utils/email');

const User    = require('../src/modules/users/user.model');
const Service = require('../src/modules/services/service.model');

const { registerUser } = require('../src/modules/auth/auth.service');

process.env.JWT_SECRET    = 'test-secret';
process.env.JWT_EXPIRES_IN = '7d';

const PLUMBING_ID = '664000000000000000000001';
const HVAC_ID     = '664000000000000000000002';
const BAD_ID      = '664000000000000000000099';

const makeCreatedUser = (overrides = {}) => ({
  _id:         '664000000000000000000010',
  name:        'Ali Samir',
  email:       'ali@example.com',
  role:        'worker',
  authVersion: 0,
  services:    [],
  toJSON:      () => ({}),
  ...overrides,
});

beforeEach(() => {
  jest.clearAllMocks();
  User.findOne = jest.fn().mockResolvedValue(null); // no duplicate email
  User.create  = jest.fn().mockResolvedValue(makeCreatedUser());
});

describe('registerUser — services validation', () => {
  test('worker registration with valid service IDs succeeds and stores [{serviceId, startsFrom}] subdocs', async () => {
    const select = jest.fn().mockResolvedValue([
      { _id: PLUMBING_ID, basePrice: 200 },
      { _id: HVAC_ID, basePrice: 350 },
    ]);
    Service.find = jest.fn().mockReturnValue({ select });
    User.create = jest.fn().mockResolvedValue(
      makeCreatedUser({
        services: [
          { serviceId: PLUMBING_ID, startsFrom: 200 },
          { serviceId: HVAC_ID, startsFrom: 350 },
        ],
      })
    );

    const { user } = await registerUser({
      name:     'Ali Samir',
      email:    'ali@example.com',
      password: 'Password1',
      role:     'worker',
      services: [PLUMBING_ID, HVAC_ID],
    });

    expect(Service.find).toHaveBeenCalledWith({
      _id:      { $in: [PLUMBING_ID, HVAC_ID] },
      isActive: true,
    });
    expect(select).toHaveBeenCalledWith('basePrice');
    expect(User.create).toHaveBeenCalledWith(
      expect.objectContaining({
        services: [
          { serviceId: PLUMBING_ID, startsFrom: 200 },
          { serviceId: HVAC_ID, startsFrom: 350 },
        ],
      })
    );
  });

  test('worker registration rejects invalid service IDs', async () => {
    // Only 1 of the 2 submitted IDs resolves to an active service
    const select = jest.fn().mockResolvedValue([{ _id: PLUMBING_ID, basePrice: 200 }]);
    Service.find = jest.fn().mockReturnValue({ select });

    await expect(
      registerUser({
        name:     'Ali Samir',
        email:    'ali@example.com',
        password: 'Password1',
        role:     'worker',
        services: [PLUMBING_ID, BAD_ID],
      })
    ).rejects.toMatchObject({
      statusCode: StatusCodes.BAD_REQUEST,
      message:    expect.stringContaining('invalid or inactive'),
    });

    expect(User.create).not.toHaveBeenCalled();
  });

  test('worker registration with no services skips validation', async () => {
    Service.find = jest.fn();

    await registerUser({
      name:     'Ali Samir',
      email:    'ali@example.com',
      password: 'Password1',
      role:     'worker',
    });

    expect(Service.find).not.toHaveBeenCalled();
    expect(User.create).toHaveBeenCalledWith(
      expect.not.objectContaining({ services: expect.anything() })
    );
  });

  test('customer registration ignores services field', async () => {
    Service.find = jest.fn();

    await registerUser({
      name:     'Nour Ahmed',
      email:    'nour@example.com',
      password: 'Password1',
      role:     'user',
      services: [PLUMBING_ID],
    });

    // Non-workers: services are not validated and not stored
    expect(Service.find).not.toHaveBeenCalled();
    expect(User.create).toHaveBeenCalledWith(
      expect.not.objectContaining({ services: expect.anything() })
    );
  });
});
