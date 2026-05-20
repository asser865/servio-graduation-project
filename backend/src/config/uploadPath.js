const path = require('path');

function resolveUploadRoot() {
  if (process.env.SERVIO_UPLOAD_DIR) {
    return path.resolve(process.env.SERVIO_UPLOAD_DIR);
  }

  return path.resolve(__dirname, '..', '..', 'uploads');
}

module.exports = {
  resolveUploadRoot,
};
