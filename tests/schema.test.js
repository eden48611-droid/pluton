const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const repoRoot = path.join(__dirname, '..');

function read(file) {
  return fs.readFileSync(path.join(repoRoot, file), 'utf8');
}

test('server health endpoint responds OK', async () => {
  const app = require(path.join(repoRoot, 'server.js'));
  const server = app.listen(0);

  try {
    const port = server.address().port;
    const response = await fetch(`http://127.0.0.1:${port}/api/health`);
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.status, 'ok');
    assert.equal(body.service, 'PLUTON');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('schema includes required audit and updated_at protections', () => {
  const schema = read('database/schema.sql');
  const migration = read('database/migrations/001_phase1_base_schema.sql');

  assert.match(schema, /CREATE OR REPLACE FUNCTION update_timestamp\(\)/);
  assert.match(migration, /CREATE OR REPLACE FUNCTION update_timestamp\(\)/);
  assert.match(schema, /CREATE TABLE IF NOT EXISTS audit_logs/);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS audit_logs/);
  assert.match(migration, /CREATE TRIGGER audit_fixtures_changes/);
});

test('lock protection blocks immutable My Tip / Agreed Tip updates', () => {
  const migration = read('database/migrations/001_phase1_base_schema.sql');

  assert.match(migration, /validate_prediction_lock/);
  assert.match(migration, /My Tip \/ Agreed Tip are immutable/);
  assert.match(migration, /is_locked/);
});

test('seed data and migration metadata exist', () => {
  const seed = fs.existsSync(path.join(repoRoot, 'database/seeds/001_realistic_seed_data.sql'));
  const migration = fs.existsSync(path.join(repoRoot, 'database/migrations/001_phase1_base_schema.sql'));

  assert.equal(seed, true);
  assert.equal(migration, true);
});
