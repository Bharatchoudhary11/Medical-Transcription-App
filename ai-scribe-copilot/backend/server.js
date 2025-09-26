const express = require('express');
const cors = require('cors');
const multer = require('multer');
const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');
const bodyParser = require('body-parser');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = Number.parseInt(process.env.PORT ?? '3000', 10);
const PREFERRED_HOST = process.env.HOST || '::';
const FALLBACK_HOST = '0.0.0.0';

const IPV6_FALLBACK_ERRORS = new Set([
  'EADDRNOTAVAIL',
  'EAFNOSUPPORT',
  'EINVAL',
]);

function formatAddressForUrl(addressInfo) {
  if (!addressInfo || typeof addressInfo === 'string') {
    return addressInfo || 'localhost';
  }

  const { address, family } = addressInfo;
  if (family === 'IPv6') {
    return `[${address}]`;
  }
  return address;
}

function logServerDetails(server) {
  const addressInfo = server.address();
  if (!addressInfo) {
    console.log('AI Scribe Copilot Backend running.');
    console.log(`Health check: http://localhost:${PORT}/health`);
    return;
  }

  if (typeof addressInfo === 'string') {
    console.log(`AI Scribe Copilot Backend running on ${addressInfo}`);
    return;
  }

  const { address, family, port } = addressInfo;
  const urlHost = formatAddressForUrl(addressInfo);

  console.log(
    `AI Scribe Copilot Backend listening on ${address}:${port} (${family}).`,
  );
  console.log(`Health check: http://${urlHost}:${port}/health`);
}

function startServer(host, { isFallback = false } = {}) {
  const server = app.listen({ port: PORT, host, ipv6Only: false }, () => {
    logServerDetails(server);
  });

  server.on('error', (error) => {
    if (
      !isFallback &&
      host !== FALLBACK_HOST &&
      IPV6_FALLBACK_ERRORS.has(error.code)
    ) {
      console.warn(
        `Could not bind to ${host} (${error.code}). Falling back to ${FALLBACK_HOST}.`,
      );
      startServer(FALLBACK_HOST, { isFallback: true });
      return;
    }

    console.error('Failed to start server:', error);
    process.exitCode = 1;
  });

  return server;
}

// Middleware
app.use(helmet());
app.use(morgan('combined'));
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Configure AWS S3 (mock)
const s3 = new AWS.S3({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'mock-key',
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'mock-secret',
  region: process.env.AWS_REGION || 'us-east-1',
  endpoint: process.env.AWS_ENDPOINT || 'http://localhost:4566', // LocalStack
  s3ForcePathStyle: true
});

// In-memory storage for demo
const sessions = new Map();
const patients = new Map();
const chunks = new Map();

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, 'uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    cb(null, `${uuidv4()}-${file.originalname}`);
  }
});

const upload = multer({ storage });

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Session Management Endpoints
app.post('/api/v1/upload-session', (req, res) => {
  try {
    const { patientId, userId } = req.body;
    
    if (!patientId || !userId) {
      return res.status(400).json({ error: 'patientId and userId are required' });
    }

    const sessionId = uuidv4();
    const session = {
      id: sessionId,
      patientId,
      userId,
      status: 'recording',
      startTime: new Date().toISOString(),
      totalChunks: 0,
      uploadedChunks: 0,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    sessions.set(sessionId, session);

    res.json({ sessionId, message: 'Session created successfully' });
  } catch (error) {
    console.error('Error creating session:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/v1/get-presigned-url', (req, res) => {
  try {
    const { sessionId, chunkNumber } = req.body;
    
    if (!sessionId || chunkNumber === undefined) {
      return res.status(400).json({ error: 'sessionId and chunkNumber are required' });
    }

    // Generate mock presigned URL
    const presignedUrl = `http://localhost:${PORT}/api/upload-chunk/${sessionId}/${chunkNumber}`;
    
    res.json({ presignedUrl });
  } catch (error) {
    console.error('Error getting presigned URL:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.put('/api/upload-chunk/:sessionId/:chunkNumber', upload.single('audio'), (req, res) => {
  try {
    const { sessionId, chunkNumber } = req.params;
    
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    // Store chunk info
    const chunkId = uuidv4();
    const chunk = {
      id: chunkId,
      sessionId,
      chunkNumber: parseInt(chunkNumber),
      filePath: req.file.path,
      sizeBytes: req.file.size,
      uploadedAt: new Date().toISOString()
    };

    chunks.set(chunkId, chunk);

    // Update session
    const session = sessions.get(sessionId);
    if (session) {
      session.totalChunks = (session.totalChunks || 0) + 1;
      session.uploadedChunks = (session.uploadedChunks || 0) + 1;
      session.updatedAt = new Date().toISOString();
      sessions.set(sessionId, session);
    }

    res.json({ message: 'Chunk uploaded successfully', chunkId });
  } catch (error) {
    console.error('Error uploading chunk:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/v1/notify-chunk-uploaded', (req, res) => {
  try {
    const { sessionId, chunkNumber } = req.body;
    
    if (!sessionId || chunkNumber === undefined) {
      return res.status(400).json({ error: 'sessionId and chunkNumber are required' });
    }

    console.log(`Chunk ${chunkNumber} uploaded for session ${sessionId}`);
    
    res.json({ message: 'Chunk upload notification received' });
  } catch (error) {
    console.error('Error notifying chunk upload:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Patient Management Endpoints
app.get('/api/v1/patients', (req, res) => {
  try {
    const { userId } = req.query;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    const userPatients = Array.from(patients.values())
      .filter(patient => patient.userId === userId);

    res.json({ patients: userPatients });
  } catch (error) {
    console.error('Error getting patients:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/v1/add-patient-ext', (req, res) => {
  try {
    const { id, name, email, phone, dateOfBirth, medicalRecordNumber, userId } = req.body;
    
    if (!name || !dateOfBirth) {
      return res.status(400).json({ error: 'name and dateOfBirth are required' });
    }

    const patient = {
      id: id || uuidv4(),
      name,
      email: email || null,
      phone: phone || null,
      dateOfBirth,
      medicalRecordNumber: medicalRecordNumber || null,
      userId: userId || 'default-user',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    patients.set(patient.id, patient);

    res.json(patient);
  } catch (error) {
    console.error('Error adding patient:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/api/v1/fetch-session-by-patient/:patientId', (req, res) => {
  try {
    const { patientId } = req.params;
    
    const patientSessions = Array.from(sessions.values())
      .filter(session => session.patientId === patientId);

    res.json({ sessions: patientSessions });
  } catch (error) {
    console.error('Error fetching sessions by patient:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Transcription endpoint
app.get('/api/v1/transcription/:sessionId', (req, res) => {
  try {
    const { sessionId } = req.params;
    
    // Mock transcription
    const transcription = `This is a mock transcription for session ${sessionId}. 
    In a real implementation, this would be generated by AI transcription services 
    like AWS Transcribe, Google Speech-to-Text, or Azure Speech Services.`;
    
    res.json({ transcription });
  } catch (error) {
    console.error('Error getting transcription:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Start server
startServer(PREFERRED_HOST);

module.exports = app;
