'use strict';

const path = require('path');
const { resolveUploadRoot } = require('../src/config/uploadPath');

describe('upload path configuration', () => {
  const originalUploadDir = process.env.SERVIO_UPLOAD_DIR;

  afterEach(() => {
    if (originalUploadDir === undefined) {
      delete process.env.SERVIO_UPLOAD_DIR;
    } else {
      process.env.SERVIO_UPLOAD_DIR = originalUploadDir;
    }
  });

  test('uses a persistent backend uploads directory by default', () => {
    delete process.env.SERVIO_UPLOAD_DIR;

    expect(resolveUploadRoot()).toBe(path.resolve(__dirname, '..', 'uploads'));
  });

  test('allows SERVIO_UPLOAD_DIR to override the default', () => {
    process.env.SERVIO_UPLOAD_DIR = path.join('custom', 'uploads');

    expect(resolveUploadRoot()).toBe(path.resolve('custom', 'uploads'));
  });
});
