const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

const CAIRO_FONT = path.join(__dirname, '../../assets/fonts/Cairo-Regular.ttf');

async function generate(invoice) {
  if (!invoice) throw new Error('Invoice required');
  const outDir = path.join(process.cwd(), 'storage', 'receipts');
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  const filePath = path.join(outDir, `${invoice.number}.pdf`);

  await new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: 50 });
    const stream = fs.createWriteStream(filePath);
    doc.pipe(stream);

    try { if (fs.existsSync(CAIRO_FONT)) doc.font(CAIRO_FONT); } catch (_) {}

    doc.fontSize(20).text('Servio - Receipt', { align: 'center' });
    doc.moveDown();
    doc.fontSize(12);
    doc.text(`Invoice: ${invoice.number}`);
    const issued = invoice.issuedAt ? new Date(invoice.issuedAt) : new Date();
    doc.text(`Date: ${issued.toISOString().slice(0, 10)}`);
    doc.moveDown();
    doc.text(`Customer: ${invoice.customer?.name || invoice.customer || ''}`);
    if (invoice.worker?.name) doc.text(`Technician: ${invoice.worker.name}`);
    doc.moveDown();
    doc.text('-----------------------------------');
    const cur = (invoice.currency || 'EGP').toUpperCase();
    doc.text(`Subtotal: ${Number(invoice.subtotal).toFixed(2)} ${cur}`);
    doc.text(`VAT (${(Number(invoice.vatRate) * 100).toFixed(0)}%): ${Number(invoice.vat).toFixed(2)} ${cur}`);
    doc.fontSize(14).text(`Total: ${Number(invoice.total).toFixed(2)} ${cur}`, { underline: true });
    doc.end();

    stream.on('finish', resolve);
    stream.on('error', reject);
  });

  invoice.pdfPath = filePath;
  if (typeof invoice.save === 'function') await invoice.save();
  return { path: filePath };
}

module.exports = { generate };
