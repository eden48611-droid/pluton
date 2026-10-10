-- =========================================
-- PLUTON Phase 1: Realistic Seed Data
-- File: database/seeds/001_realistic_seed_data.sql
-- Purpose: realistic sports, league, team, and source bootstrap
-- =========================================

BEGIN;

-- Sports
INSERT INTO sports (name, category, description, is_active)
VALUES
    ('Football', 'Team', 'Association Football / Soccer', TRUE),
    ('Basketball', 'Team', 'Basketball competitions', TRUE),
    ('Handball', 'Team', 'Handball competitions', TRUE),
    ('Formula 1', 'Motor', 'Formula 1 Racing', TRUE),
    ('Basketball', 'Team', 'Basketball', TRUE),
    ('Tennis', 'Individual', 'ATP / WTA tennis', TRUE),
    ('Volleyball', 'Team', 'Volleyball', TRUE),
    ('American Football', 'Team', 'NFL and other American Football', TRUE),
    ('Baseball', 'Team', 'MLB and other baseball', TRUE),
    ('Cricket', 'Team', 'Cricket', TRUE),
    ('Rugby', 'Team', 'Rugby union and league', TRUE),
    ('Badminton', 'Individual', 'Badminton', TRUE),
    ('Darts', 'Individual', 'Professional darts', TRUE),
    ('Boxing', 'Individual', 'Professional boxing', TRUE),
    ('MMA', 'Individual', 'Mixed Martial Arts', TRUE),
    ('Esports', 'Other', 'Competitive gaming', TRUE)
ON CONFLICT (name) DO NOTHING;

-- Seasons
INSERT INTO seasons (sport_id, season_name, start_date, end_date, is_active)
SELECT sport_id, '2024/25', '2024-07-01'::date, '2025-06-30'::date, TRUE
FROM sports WHERE name = 'Football'
ON CONFLICT (sport_id, season_name) DO NOTHING;

INSERT INTO seasons (sport_id, season_name, start_date, end_date, is_active)
SELECT sport_id, '2024/25', '2024-10-01'::date, '2025-06-30'::date, TRUE
FROM sports WHERE name = 'Basketball'
ON CONFLICT (sport_id, season_name) DO NOTHING;

INSERT INTO seasons (sport_id, season_name, start_date, end_date, is_active)
SELECT sport_id, '2025', '2025-03-15'::date, '2025-12-07'::date, TRUE
FROM sports WHERE name = 'Formula 1'
ON CONFLICT (sport_id, season_name) DO NOTHING;

-- Football teams
INSERT INTO teams (sport_id, team_name, short_name, country, is_active)
VALUES
    ((SELECT sport_id FROM sports WHERE name = 'Football'), 'Manchester City', 'MCI', 'England', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Football'), 'Arsenal', 'ARS', 'England', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Football'), 'Liverpool', 'LIV', 'England', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Football'), 'Real Madrid', 'RMA', 'Spain', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Football'), 'Barcelona', 'BAR', 'Spain', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Football'), 'Inter Milan', 'INT', 'Italy', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Football'), 'Juventus', 'JUV', 'Italy', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Football'), 'Bayern Munich', 'BAY', 'Germany', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Football'), 'Paris Saint-Germain', 'PSG', 'France', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Football'), 'Borussia Dortmund', 'BVB', 'Germany', TRUE)
ON CONFLICT (sport_id, team_name) DO NOTHING;

-- Basketball teams
INSERT INTO teams (sport_id, team_name, short_name, country, is_active)
VALUES
    ((SELECT sport_id FROM sports WHERE name = 'Basketball'), 'Boston Celtics', 'BOS', 'USA', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Basketball'), 'Los Angeles Lakers', 'LAL', 'USA', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Basketball'), 'Chicago Bulls', 'CHI', 'USA', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Basketball'), 'Golden State Warriors', 'GSW', 'USA', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Basketball'), 'Milwaukee Bucks', 'MIL', 'USA', TRUE)
ON CONFLICT (sport_id, team_name) DO NOTHING;

-- Handball teams
INSERT INTO teams (sport_id, team_name, short_name, country, is_active)
VALUES
    ((SELECT sport_id FROM sports WHERE name = 'Handball'), 'THW Kiel', 'KIE', 'Germany', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Handball'), 'FC Barcelona', 'FCB', 'Spain', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Handball'), 'Paris Saint-Germain Handball', 'PSG', 'France', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Handball'), 'Kolding IF', 'KOL', 'Denmark', TRUE)
ON CONFLICT (sport_id, team_name) DO NOTHING;

-- Formula 1 teams
INSERT INTO teams (sport_id, team_name, short_name, country, is_active)
VALUES
    ((SELECT sport_id FROM sports WHERE name = 'Formula 1'), 'McLaren', 'MCL', 'United Kingdom', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Formula 1'), 'Ferrari', 'FER', 'Italy', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Formula 1'), 'Red Bull Racing', 'RBR', 'Austria', TRUE),
    ((SELECT sport_id FROM sports WHERE name = 'Formula 1'), 'Mercedes', 'MER', 'Germany', TRUE)
ON CONFLICT (sport_id, team_name) DO NOTHING;

-- Roles
INSERT INTO roles (role_name, description)
VALUES
    ('admin', 'System administrator with full access'),
    ('manager', 'Prediction manager and oversight'),
    ('analyst', 'Data analyst and prediction creator'),
    ('viewer', 'Read-only access to predictions and results')
ON CONFLICT (role_name) DO NOTHING;

-- Prediction types
INSERT INTO prediction_types (name, description, is_system_locked)
VALUES
    ('my_tip', 'User-entered manual prediction - immutable once locked', TRUE),
    ('agreed_tip', 'Validated team consensus - immutable once locked', TRUE),
    ('pluton_tip', 'PLUTON-generated prediction - can update until kickoff', FALSE)
ON CONFLICT (name) DO NOTHING;

-- Data sources registry
INSERT INTO data_sources (sport_id, source_name, source_type, source_priority, is_main, is_backup, is_active, reliability_score)
VALUES
    ((SELECT sport_id FROM sports WHERE name = 'Football'), 'API-Football', 'REST API', 1, TRUE, FALSE, TRUE, 98),
    ((SELECT sport_id FROM sports WHERE name = 'Football'), 'ESPN Football', 'REST API', 2, TRUE, FALSE, TRUE, 96),
    ((SELECT sport_id FROM sports WHERE name = 'Football'), 'FlashScore Football', 'Web Scraper', 3, TRUE, FALSE, TRUE, 94),
    ((SELECT sport_id FROM sports WHERE name = 'Basketball'), 'NBA Official API', 'REST API', 1, TRUE, FALSE, TRUE, 100),
    ((SELECT sport_id FROM sports WHERE name = 'Basketball'), 'ESPN Basketball', 'REST API', 2, TRUE, FALSE, TRUE, 97),
    ((SELECT sport_id FROM sports WHERE name = 'Handball'), 'EHF Handball', 'REST API', 1, TRUE, FALSE, TRUE, 99),
    ((SELECT sport_id FROM sports WHERE name = 'Formula 1'), 'F1 Official', 'REST API', 1, TRUE, FALSE, TRUE, 100),
    ((SELECT sport_id FROM sports WHERE name = 'Formula 1'), 'ESPN F1', 'REST API', 2, TRUE, FALSE, TRUE, 98),
    (NULL, 'Backup API-Football', 'REST API', 51, FALSE, TRUE, TRUE, 92),
    (NULL, 'Backup ESPN', 'REST API', 52, FALSE, TRUE, TRUE, 90)
ON CONFLICT DO NOTHING;

COMMIT;
