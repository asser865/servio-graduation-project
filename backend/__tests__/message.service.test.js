'use strict';

jest.mock('../src/modules/messages/message.model.js');
jest.mock('../src/modules/messages/conversation.model.js');
jest.mock('../src/modules/bookings/booking.model.js');
jest.mock('../src/modules/users/user.model.js');

const Message = require('../src/modules/messages/message.model.js');
const Conversation = require('../src/modules/messages/conversation.model.js');
const Booking = require('../src/modules/bookings/booking.model.js');
const User = require('../src/modules/users/user.model.js');
const service = require('../src/modules/messages/message.service.js');

const CUSTOMER = '664000000000000000000001';
const WORKER = '664000000000000000000002';
const OTHER = '664000000000000000000003';
const CONVERSATION = '664000000000000000000010';
const BOOKING = '664000000000000000000020';
const MESSAGE = '664000000000000000000030';

function query(result) {
  const chain = {
    select: jest.fn(() => chain),
    sort: jest.fn(() => chain),
    limit: jest.fn(() => chain),
    populate: jest.fn(() => chain),
    then: (resolve, reject) => Promise.resolve(result).then(resolve, reject),
    catch: (reject) => Promise.resolve(result).catch(reject),
  };
  return chain;
}

function conversation(overrides = {}) {
  return {
    _id: CONVERSATION,
    participants: [CUSTOMER, WORKER],
    customer: CUSTOMER,
    worker: WORKER,
    booking: null,
    lastMessage: null,
    lastMessageText: '',
    lastMessageAt: null,
    unreadCounts: new Map([[CUSTOMER, 0], [WORKER, 0]]),
    createdAt: new Date('2026-05-11T10:00:00.000Z'),
    updatedAt: new Date('2026-05-11T10:00:00.000Z'),
    save: jest.fn().mockResolvedValue(undefined),
    ...overrides,
  };
}

function populatedConversation(overrides = {}) {
  return conversation({
    customer: { _id: CUSTOMER, name: 'Nour', role: 'user', profileImage: null },
    worker: { _id: WORKER, name: 'Omar', role: 'worker', profileImage: null },
    ...overrides,
  });
}

function message(overrides = {}) {
  return {
    _id: MESSAGE,
    conversation: CONVERSATION,
    booking: null,
    sender: CUSTOMER,
    recipient: WORKER,
    content: 'Hello',
    read: false,
    readAt: null,
    createdAt: new Date('2026-05-11T10:05:00.000Z'),
    updatedAt: new Date('2026-05-11T10:05:00.000Z'),
    populate: jest.fn().mockImplementation(function () {
      return Promise.resolve(this);
    }),
    ...overrides,
  };
}

beforeEach(() => {
  jest.clearAllMocks();
  User.findById = jest.fn((id) =>
    query({
      _id: id,
      role: id === WORKER ? 'worker' : 'user',
      isActive: true,
    })
  );
  Conversation.findById = jest.fn(() => query(populatedConversation()));
  Conversation.findOne = jest.fn().mockResolvedValue(null);
  Conversation.create = jest.fn().mockImplementation(async (payload) =>
    conversation({ ...payload, _id: CONVERSATION })
  );
  Conversation.find = jest.fn(() => query([populatedConversation()]));
  Conversation.deleteOne = jest.fn().mockResolvedValue({ deletedCount: 1 });
  Message.create = jest.fn().mockResolvedValue(message());
  Message.updateMany = jest.fn().mockResolvedValue({ modifiedCount: 1 });
  Message.countDocuments = jest.fn().mockResolvedValue(3);
  Message.find = jest.fn(() => query([message(), message({ _id: OTHER })]));
  Message.deleteMany = jest.fn().mockResolvedValue({ deletedCount: 2 });
  Booking.findById = jest.fn().mockResolvedValue({
    _id: BOOKING,
    user: CUSTOMER,
    worker: WORKER,
  });
});

describe('message.service persistent conversations', () => {
  test('customer can send message to worker and message is saved', async () => {
    const result = await service.sendMessage(CUSTOMER, {
      receiverId: WORKER,
      content: 'Hello worker',
      senderId: OTHER,
    });

    expect(Conversation.create).toHaveBeenCalledWith(
      expect.objectContaining({ customer: CUSTOMER, worker: WORKER })
    );
    expect(Message.create).toHaveBeenCalledWith(
      expect.objectContaining({
        conversation: CONVERSATION,
        sender: CUSTOMER,
        recipient: WORKER,
        content: 'Hello worker',
      })
    );
    expect(result.message.senderId).toBe(CUSTOMER);
  });

  test('worker can send message to customer', async () => {
    await service.sendMessage(WORKER, {
      receiverId: CUSTOMER,
      content: 'On my way',
    });

    expect(Message.create).toHaveBeenCalledWith(
      expect.objectContaining({ sender: WORKER, recipient: CUSTOMER })
    );
  });

  test('existing conversation is reused for same customer-worker pair', async () => {
    const existing = conversation();
    Conversation.findOne = jest.fn().mockResolvedValue(existing);

    await service.sendMessage(CUSTOMER, {
      receiverId: WORKER,
      content: 'Again',
    });

    expect(Conversation.create).not.toHaveBeenCalled();
    expect(Message.create).toHaveBeenCalledWith(
      expect.objectContaining({ conversation: existing._id })
    );
  });

  test('booking conversation derives receiver from booking participants', async () => {
    await service.sendMessage(CUSTOMER, {
      bookingId: BOOKING,
      content: 'Booking chat',
    });

    expect(Booking.findById).toHaveBeenCalledWith(BOOKING);
    expect(Message.create).toHaveBeenCalledWith(
      expect.objectContaining({ booking: BOOKING, recipient: WORKER })
    );
  });

  test('conversation list returns participant summary and unread count', async () => {
    const conversations = await service.getConversations(CUSTOMER);

    expect(Conversation.find).toHaveBeenCalledWith({ participants: CUSTOMER });
    expect(conversations[0]).toMatchObject({
      conversationId: CONVERSATION,
      otherUser: { id: WORKER, name: 'Omar', role: 'worker' },
    });
  });

  test('message history marks incoming messages read and returns ordered list', async () => {
    const result = await service.getMessages(CUSTOMER, CONVERSATION);

    expect(Message.updateMany).toHaveBeenCalledWith(
      { conversation: CONVERSATION, recipient: CUSTOMER, read: false },
      expect.objectContaining({ read: true })
    );
    expect(Message.find).toHaveBeenCalledWith({ conversation: CONVERSATION });
    expect(result.messages).toHaveLength(2);
  });

  test('participant can delete a conversation and its messages', async () => {
    const result = await service.deleteConversation(CUSTOMER, CONVERSATION);

    expect(Message.deleteMany).toHaveBeenCalledWith({ conversation: CONVERSATION });
    expect(Conversation.deleteOne).toHaveBeenCalledWith({ _id: CONVERSATION });
    expect(result).toEqual({
      conversationId: CONVERSATION,
      deletedMessages: 2,
    });
  });

  test('non-participant cannot delete another conversation', async () => {
    await expect(service.deleteConversation(OTHER, CONVERSATION)).rejects.toMatchObject({
      statusCode: 403,
    });
    expect(Message.deleteMany).not.toHaveBeenCalled();
    expect(Conversation.deleteOne).not.toHaveBeenCalled();
  });

  test('unauthorized user cannot access another conversation', async () => {
    Conversation.findById = jest.fn(() =>
      query(populatedConversation({ participants: [CUSTOMER, WORKER] }))
    );

    await expect(service.getMessages(OTHER, CONVERSATION)).rejects.toMatchObject({
      statusCode: 403,
    });
  });

  test('empty message is rejected', async () => {
    await expect(
      service.sendMessage(CUSTOMER, { receiverId: WORKER, content: '   ' })
    ).rejects.toMatchObject({ statusCode: 400 });
    expect(Message.create).not.toHaveBeenCalled();
  });

  test('invalid receiver is rejected', async () => {
    User.findById = jest.fn((id) =>
      query(id === WORKER ? null : { _id: id, role: 'user', isActive: true })
    );

    await expect(
      service.sendMessage(CUSTOMER, { receiverId: WORKER, content: 'Hello' })
    ).rejects.toMatchObject({ statusCode: 404 });
  });
});
