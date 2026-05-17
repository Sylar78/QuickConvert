const sharp = require('sharp');
const { PDFDocument } = require('pdf-lib');
const { getDocument } = require('pdfjs-dist/legacy/build/pdf.js');
const mammoth = require('mammoth');
const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { v4: uuidv4 } = require('uuid');

const tmpDir = path.join(os.tmpdir(), 'quickconvert');
if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir, { recursive: true });

function findChrome() {
  const candidates = [
    process.env.CHROME_EXECUTABLE_PATH,
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    '/usr/bin/google-chrome',
    '/usr/bin/chromium-browser',
    '/usr/bin/chromium',
  ].filter(Boolean);
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  throw new Error('Chrome introuvable. Définir CHROME_EXECUTABLE_PATH.');
}

// ── PDF → JPG ──────────────────────────────────────────────────────────────
async function convertPdfToJpg(pdfPath) {
  const pdfBuffer = fs.readFileSync(pdfPath);
  const pdfDoc = await getDocument({ data: new Uint8Array(pdfBuffer) }).promise;
  const pageCount = pdfDoc.numPages;
  const outputPaths = [];

  for (let i = 1; i <= pageCount; i++) {
    const page = await pdfDoc.getPage(i);
    const viewport = page.getViewport({ scale: 2.0 });

    const { createCanvas } = require('canvas');
    const canvas = createCanvas(viewport.width, viewport.height);
    const ctx = canvas.getContext('2d');

    await page.render({ canvasContext: ctx, viewport }).promise;

    const outPath = path.join(tmpDir, `${uuidv4()}_page_${i}.jpg`);
    const buffer = canvas.toBuffer('image/jpeg', { quality: 0.92 });
    fs.writeFileSync(outPath, buffer);
    outputPaths.push(outPath);
  }

  return outputPaths;
}

// ── Images → PDF ───────────────────────────────────────────────────────────
async function convertImagesToPdf(imagePaths) {
  const pdfDoc = await PDFDocument.create();

  for (const imgPath of imagePaths) {
    const ext = path.extname(imgPath).toLowerCase();
    const imgBuffer = fs.readFileSync(imgPath);

    // Normaliser en JPEG avec sharp
    const jpgBuffer = await sharp(imgBuffer).jpeg({ quality: 90 }).toBuffer();
    const pdfImage = await pdfDoc.embedJpg(jpgBuffer);

    const { width, height } = pdfImage.scale(1);
    const page = pdfDoc.addPage([width, height]);
    page.drawImage(pdfImage, { x: 0, y: 0, width, height });
  }

  const pdfBytes = await pdfDoc.save();
  const outPath = path.join(tmpDir, `${uuidv4()}.pdf`);
  fs.writeFileSync(outPath, pdfBytes);
  return outPath;
}

// ── DOC/DOCX → PDF ─────────────────────────────────────────────────────────
async function convertDocToPdf(docPath) {
  // DOCX → HTML
  const { value: htmlBody } = await mammoth.convertToHtml({ path: docPath });
  const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><style>
    body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; font-size: 12pt; }
    table { border-collapse: collapse; width: 100%; }
    td, th { border: 1px solid #ccc; padding: 4px 8px; }
    img { max-width: 100%; }
  </style></head><body>${htmlBody}</body></html>`;

  // HTML → PDF via Chrome headless
  const browser = await puppeteer.launch({
    executablePath: findChrome(),
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });
  try {
    const page = await browser.newPage();
    await page.setContent(html, { waitUntil: 'networkidle0' });
    const outPath = path.join(tmpDir, `${uuidv4()}.pdf`);
    await page.pdf({ path: outPath, format: 'A4', printBackground: true });
    return outPath;
  } finally {
    await browser.close();
  }
}

// ── Format image (PNG↔JPG) ─────────────────────────────────────────────────
async function convertImageFormat(imgPath, targetFormat, quality = 90) {
  const outPath = path.join(tmpDir, `${uuidv4()}.${targetFormat}`);

  if (targetFormat === 'png') {
    await sharp(imgPath).png({ compressionLevel: 8 }).toFile(outPath);
  } else {
    await sharp(imgPath).jpeg({ quality }).toFile(outPath);
  }

  return outPath;
}

module.exports = {
  convertPdfToJpg,
  convertImagesToPdf,
  convertDocToPdf,
  convertImageFormat,
};
