const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

app.get('/api/health', (_req, res) => {
  res.json({
    status: 'ok',
    service: 'PLUTON',
    phase: '1',
    timestamp: new Date().toISOString(),
  });
});

app.use(express.static(path.join(__dirname, '.')));

app.get('/', (_req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`PLUTON server listening on http://localhost:${PORT}`);
  });
}

module.exports = app;
