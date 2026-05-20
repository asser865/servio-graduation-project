'use strict';
jest.mock('../src/modules/users/user.model.js');
jest.mock('../src/modules/admin/settings.model.js');

const User     = require('../src/modules/users/user.model.js');
const Settings = require('../src/modules/admin/settings.model.js');
const fav      = require('../src/modules/favorites/favorite.service.js');

const USER_A = '664000000000000000000020';
const WORKER_1 = '664000000000000000000031';
const WORKER_2 = '664000000000000000000032';

beforeEach(() => {
  jest.clearAllMocks();
  Settings.findOne.mockReturnValue({ lean: () => Promise.resolve({ favoritesSoftCap: 50 }) });
});

describe('addFavorite', () => {
  test('adds worker to user.favorites at head', async () => {
    User.findById.mockResolvedValue({ _id: USER_A, favorites: [WORKER_2] });
    User.findOne.mockResolvedValue({ _id: WORKER_1, role: 'worker' });
    User.updateOne.mockResolvedValue({ acknowledged: true });
    await fav.addFavorite(USER_A, WORKER_1);
    expect(User.updateOne).toHaveBeenCalledWith(
      { _id: USER_A },
      { $set: { favorites: [WORKER_1, WORKER_2] } }
    );
  });

  test('idempotent when already favourited', async () => {
    User.findById.mockResolvedValue({ _id: USER_A, favorites: [WORKER_1] });
    User.findOne.mockResolvedValue({ _id: WORKER_1, role: 'worker' });
    await fav.addFavorite(USER_A, WORKER_1);
    expect(User.updateOne).not.toHaveBeenCalled();
  });

  test('rejects non-worker target', async () => {
    User.findById.mockResolvedValue({ _id: USER_A, favorites: [] });
    User.findOne.mockResolvedValue(null);
    await expect(fav.addFavorite(USER_A, WORKER_1)).rejects.toThrow(/not found|not a worker/i);
  });

  test('rejects past the soft cap', async () => {
    User.findById.mockResolvedValue({ _id: USER_A, favorites: new Array(50).fill('x') });
    User.findOne.mockResolvedValue({ _id: WORKER_1, role: 'worker' });
    await expect(fav.addFavorite(USER_A, WORKER_1)).rejects.toThrow(/limit/i);
  });
});

describe('removeFavorite', () => {
  test('pulls from list', async () => {
    User.updateOne.mockResolvedValue({ acknowledged: true });
    await fav.removeFavorite(USER_A, WORKER_1);
    expect(User.updateOne).toHaveBeenCalledWith(
      { _id: USER_A },
      { $pull: { favorites: WORKER_1 } }
    );
  });
});

describe('listFavoriteIds', () => {
  test('returns just the array of ids', async () => {
    User.findById.mockReturnValue({ select: () => ({ lean: () => Promise.resolve({ favorites: [WORKER_1, WORKER_2] }) }) });
    const ids = await fav.listFavoriteIds(USER_A);
    expect(ids).toEqual([WORKER_1, WORKER_2]);
  });
});
