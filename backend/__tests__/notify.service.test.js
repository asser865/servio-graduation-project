'use strict';

jest.mock('../src/modules/notifications/notifyRequest.model.js');
jest.mock('../src/utils/email.js', () => ({ sendTechAvailableEmail: jest.fn().mockResolvedValue(undefined) }));

const NotifyRequest              = require('../src/modules/notifications/notifyRequest.model.js');
const { sendTechAvailableEmail } = require('../src/utils/email.js');
const { dispatchAvailabilityMatches } = require('../src/modules/notifications/notify.service.js');

beforeEach(() => jest.clearAllMocks());

describe('dispatchAvailabilityMatches', () => {
  test('sends email and marks fulfilled for each matching unfulfilled request', async () => {
    const worker = {
      _id:        '507f1f77bcf86cd799439011',
      name:       'Khaled Mohamed',
      categories: ['plumbing'],
      locationLabel: 'Maadi',
    };

    const fakeRequest = {
      _id:             '507f1f77bcf86cd799439022',
      email:           'user@test.com',
      serviceCategory: 'plumbing',
      serviceArea:     '',
      save:            jest.fn().mockResolvedValue(true),
    };

    NotifyRequest.find = jest.fn().mockResolvedValue([fakeRequest]);

    await dispatchAvailabilityMatches(worker, 'http://localhost:5502');

    expect(NotifyRequest.find).toHaveBeenCalledWith({
      fulfilledAt:     null,
      serviceCategory: { $in: ['plumbing'] },
    });

    expect(sendTechAvailableEmail).toHaveBeenCalledWith(
      'user@test.com',
      'Khaled Mohamed',
      'plumbing',
      'http://localhost:5502/html/technician-listing.html?service=plumbing'
    );

    expect(fakeRequest.fulfilledAt).not.toBeNull();
    expect(fakeRequest.save).toHaveBeenCalled();
  });

  test('does nothing when no matching requests exist', async () => {
    NotifyRequest.find = jest.fn().mockResolvedValue([]);

    await dispatchAvailabilityMatches(
      { name: 'Test', categories: ['electrical'] },
      'http://localhost:5502'
    );

    expect(sendTechAvailableEmail).not.toHaveBeenCalled();
  });

  test('does not throw if email sending fails for one recipient', async () => {
    const worker = { name: 'Ali', categories: ['hvac'] };
    const fakeRequest = {
      email:           'bad@test.com',
      serviceCategory: 'hvac',
      save:            jest.fn(),
    };

    NotifyRequest.find = jest.fn().mockResolvedValue([fakeRequest]);
    sendTechAvailableEmail.mockRejectedValueOnce(new Error('SMTP failure'));

    await expect(dispatchAvailabilityMatches(worker, 'http://localhost:5502')).resolves.not.toThrow();
  });
});
