# PLUTON

PLUTON is a sports intelligence platform foundation and database contract.

## Included in this repository

- `index.html` — landing page and interface design
- `database/schema.sql` — canonical schema reference
- `database/migrations/001_phase1_base_schema.sql` — migration package for Phase 1
- `database/seeds/001_realistic_seed_data.sql` — realistic seed data
- `server.js` — minimal Express app for runtime verification
- `tests/schema.test.js` — SQL contract and runtime checks

## Run locally

```bash
npm install
npm test
npm start
```

## Notes

This repository now includes a minimal runtime and validation layer so the Phase 1 package can be checked in a real project environment.
