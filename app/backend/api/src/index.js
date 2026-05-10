const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const multer = require('multer');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config();

const { convertPdfToJpg, convertImagesToPdf, convertDocToPdf, convertImageFormat } = require('./converters');
const { createClient } = require('@supabase/supabase-js');
const logger = require('./logger');
const os = require('os');

const app = express();
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

// ── Middleware ─────────────────────────────────────────────────────────────
app.use(helmet());
app.use(cors({ origin: '*' })); // Restreindre en production
app.use(express.json());

// Rate limiting: 60 req/min par IP
const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  message: { error: 'Trop de requêtes, réessaie dans une minute.' },
});
app.use('/api/', limiter);

// ── Upload (fichiers temporaires) ─────────────────────────────────────────
const upload = multer({
  dest: path.join(os.tmpdir(), 'quickconvert'),
  limits: { fileSize: 50 * 1024 * 1024 }, // 50 MB
});

// ── Auth middleware ────────────────────────────────────────────────────────
async function requireAuth(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Non authentifié' });

  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) return res.status(401).json({ error: 'Token invalide' });

  req.user = user;
  next();
}

// ── Routes ─────────────────────────────────────────────────────────────────

// Health check
app.get('/health', (_, res) => res.json({ status: 'ok', version: '1.0.0' }));

// PDF → JPG
app.post('/api/convert/pdf-to-jpg', requireAuth, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Fichier manquant' });

    logger.info(`PDF→JPG | user=${req.user.id} | file=${req.file.originalname}`);
    const outputPaths = await convertPdfToJpg(req.file.path);

    // Upload vers Supabase Storage
    const urls = await Promise.all(
      outputPaths.map(async (p, i) => {
        const fileName = `${req.user.id}/${uuidv4()}_page_${i + 1}.jpg`;
        const fileBuffer = require('fs').readFileSync(p);
        await supabase.storage.from('converted-files').upload(fileName, fileBuffer, {
          contentType: 'image/jpeg',
        });
        return supabase.storage.from('converted-files').getPublicUrl(fileName).data.publicUrl;
      })
    );

    await logConversion(supabase, req.user.id, 'pdf_to_jpg', true, req.file.size, null);
    res.json({ success: true, urls, count: urls.length });
  } catch (err) {
    logger.error(`PDF→JPG error: ${err.message}`);
    await logConversion(supabase, req.user.id, 'pdf_to_jpg', false, req.file?.size, null);
    res.status(500).json({ error: 'Conversion échouée', details: err.message });
  }
});

// Images → PDF
app.post('/api/convert/images-to-pdf', requireAuth, upload.array('files', 50), async (req, res) => {
  try {
    if (!req.files?.length) return res.status(400).json({ error: 'Fichiers manquants' });

    logger.info(`Images→PDF | user=${req.user.id} | count=${req.files.length}`);
    const paths = req.files.map(f => f.path);
    const pdfPath = await convertImagesToPdf(paths);

    const fileName = `${req.user.id}/${uuidv4()}_converted.pdf`;
    const pdfBuffer = require('fs').readFileSync(pdfPath);
    await supabase.storage.from('converted-files').upload(fileName, pdfBuffer, {
      contentType: 'application/pdf',
    });

    const { data } = supabase.storage.from('converted-files').getPublicUrl(fileName);
    const totalInputSize = req.files.reduce((acc, f) => acc + f.size, 0);
    await logConversion(supabase, req.user.id, 'images_to_pdf', true, totalInputSize, pdfBuffer.length);

    res.json({ success: true, url: data.publicUrl });
  } catch (err) {
    logger.error(`Images→PDF error: ${err.message}`);
    res.status(500).json({ error: 'Conversion échouée', details: err.message });
  }
});

// DOC → PDF (pas d'auth requise, retourne les bytes directement)
app.post('/api/convert/doc-to-pdf', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Fichier manquant' });

    logger.info(`DOC→PDF | file=${req.file.originalname}`);
    const pdfPath = await convertDocToPdf(req.file.path);

    const pdfBuffer = require('fs').readFileSync(pdfPath);
    res.set('Content-Type', 'application/pdf');
    res.set('Content-Disposition', `attachment; filename="converted.pdf"`);
    res.send(pdfBuffer);
  } catch (err) {
    logger.error(`DOC→PDF error: ${err.message}`);
    res.status(500).json({ error: 'Conversion échouée', details: err.message });
  }
});

// Conversion de format image (PNG↔JPG)
app.post('/api/convert/image-format', requireAuth, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Fichier manquant' });
    const { targetFormat = 'jpg', quality = 90 } = req.body;

    const outputPath = await convertImageFormat(req.file.path, targetFormat, parseInt(quality));
    const mime = targetFormat === 'png' ? 'image/png' : 'image/jpeg';
    const ext = targetFormat === 'png' ? '.png' : '.jpg';

    const fileName = `${req.user.id}/${uuidv4()}${ext}`;
    const buffer = require('fs').readFileSync(outputPath);
    await supabase.storage.from('converted-files').upload(fileName, buffer, { contentType: mime });

    const { data } = supabase.storage.from('converted-files').getPublicUrl(fileName);
    await logConversion(supabase, req.user.id, `image_to_${targetFormat}`, true, req.file.size, buffer.length);

    res.json({ success: true, url: data.publicUrl });
  } catch (err) {
    logger.error(`Image format error: ${err.message}`);
    res.status(500).json({ error: 'Conversion échouée', details: err.message });
  }
});

// ── Helpers ───────────────────────────────────────────────────────────────
async function logConversion(supabase, userId, type, success, inputSize, outputSize) {
  try {
    await supabase.from('conversion_logs').insert({
      user_id: userId,
      type,
      success,
      input_size: inputSize,
      output_size: outputSize,
      created_at: new Date().toISOString(),
    });
  } catch (_) {}
}

// ── Start server ──────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info(`QuickConvert API running on port ${PORT}`);
});

module.exports = app;
