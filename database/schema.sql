-- =========================================
-- PLUTON Phase 1: Core Database Schema
-- =========================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ===============================
-- 1. Sports
-- ===============================
CREATE TABLE IF NOT EXISTS sports (
    sport_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===============================
-- 2. Seasons
-- ===============================
CREATE TABLE IF NOT EXISTS seasons (
    season_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id UUID NOT NULL REFERENCES sports(sport_id) ON DELETE CASCADE,
    season_name VARCHAR(50) NOT NULL,
    start_date DATE,
    end_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, season_name)
);

-- ===============================
-- 3. Teams / Players / Competitors
-- ===============================
CREATE TABLE IF NOT EXISTS teams (
    team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id UUID NOT NULL REFERENCES sports(sport_id) ON DELETE CASCADE,
    team_name VARCHAR(150) NOT NULL,
    short_name VARCHAR(50),
    country VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, team_name)
);

CREATE TABLE IF NOT EXISTS players (
    player_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id UUID NOT NULL REFERENCES sports(sport_id) ON DELETE CASCADE,
    team_id UUID REFERENCES teams(team_id) ON DELETE SET NULL,
    full_name VARCHAR(150) NOT NULL,
    short_name VARCHAR(80),
    country VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, full_name)
);

-- ===============================
-- 4. Competitions / Leagues
-- ===============================
CREATE TABLE IF NOT EXISTS competitions (
    competition_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id UUID NOT NULL REFERENCES sports(sport_id) ON DELETE CASCADE,
    season_id UUID NOT NULL REFERENCES seasons(season_id) ON DELETE CASCADE,
    competition_name VARCHAR(150) NOT NULL,
    competition_type VARCHAR(80),
    country VARCHAR(100),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, season_id, competition_name)
);

-- ===============================
-- 5. Fixtures / Events / Matches
-- ===============================
CREATE TABLE IF NOT EXISTS fixtures (
    fixture_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id UUID NOT NULL REFERENCES sports(sport_id) ON DELETE CASCADE,
    season_id UUID NOT NULL REFERENCES seasons(season_id) ON DELETE CASCADE,
    competition_id UUID REFERENCES competitions(competition_id) ON DELETE SET NULL,
    home_team_id UUID REFERENCES teams(team_id) ON DELETE SET NULL,
    away_team_id UUID REFERENCES teams(team_id) ON DELETE SET NULL,
    home_player_id UUID REFERENCES players(player_id) ON DELETE SET NULL,
    away_player_id UUID REFERENCES players(player_id) ON DELETE SET NULL,
    event_date TIMESTAMPTZ NOT NULL,
    event_name VARCHAR(200),
    status VARCHAR(50) NOT NULL DEFAULT 'scheduled',
    actual_result VARCHAR(50),
    home_score INTEGER,
    away_score INTEGER,
    source_reference VARCHAR(200),
    source_name VARCHAR(150),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, season_id, event_date, home_team_id, away_team_id)
);

-- ===============================
-- 6. Standings / Form / Stats
-- ===============================
CREATE TABLE IF NOT EXISTS standings (
    standing_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    competition_id UUID NOT NULL REFERENCES competitions(competition_id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES teams(team_id) ON DELETE CASCADE,
    position INTEGER,
    played INTEGER NOT NULL DEFAULT 0,
    wins INTEGER NOT NULL DEFAULT 0,
    draws INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    goals_for INTEGER NOT NULL DEFAULT 0,
    goals_against INTEGER NOT NULL DEFAULT 0,
    goal_difference INTEGER NOT NULL DEFAULT 0,
    points INTEGER NOT NULL DEFAULT 0,
    form VARCHAR(30),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(competition_id, team_id)
);

CREATE TABLE IF NOT EXISTS team_form (
    form_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES teams(team_id) ON DELETE CASCADE,
    season_id UUID NOT NULL REFERENCES seasons(season_id) ON DELETE CASCADE,
    last_5_matches JSONB,
    form_rating NUMERIC(5,2),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(team_id, season_id)
);

-- ===============================
-- 7. Prediction Types
-- ===============================
CREATE TABLE IF NOT EXISTS prediction_types (
    prediction_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE
);

-- ===============================
-- 8. Predictions
-- ===============================
CREATE TABLE IF NOT EXISTS predictions (
    prediction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fixture_id UUID NOT NULL REFERENCES fixtures(fixture_id) ON DELETE CASCADE,
    prediction_type_id UUID NOT NULL REFERENCES prediction_types(prediction_type_id) ON DELETE RESTRICT,
    predicted_result VARCHAR(50) NOT NULL,
    confidence_level VARCHAR(20) NOT NULL,
    confidence_value NUMERIC(5,2),
    reasoning JSONB,
    source_summary JSONB,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===============================
-- 9. Results / Performance
-- ===============================
CREATE TABLE IF NOT EXISTS match_results (
    result_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fixture_id UUID NOT NULL UNIQUE REFERENCES fixtures(fixture_id) ON DELETE CASCADE,
    actual_result VARCHAR(50) NOT NULL,
    home_score INTEGER NOT NULL,
    away_score INTEGER NOT NULL,
    my_tip_result VARCHAR(20),
    agreed_tip_result VARCHAR(20),
    pluton_tip_result VARCHAR(20),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS performance_history (
    performance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id UUID REFERENCES sports(sport_id) ON DELETE SET NULL,
    competition_id UUID REFERENCES competitions(competition_id) ON DELETE SET NULL,
    prediction_type_id UUID REFERENCES prediction_types(prediction_type_id) ON DELETE SET NULL,
    period VARCHAR(30) NOT NULL,
    total_predictions INTEGER NOT NULL DEFAULT 0,
    wins INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    pushes INTEGER NOT NULL DEFAULT 0,
    win_rate NUMERIC(5,2),
    confidence_distribution JSONB,
    recorded_date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, competition_id, prediction_type_id, period, recorded_date)
);

-- ===============================
-- 10. Data Sources / API management
-- ===============================
CREATE TABLE IF NOT EXISTS data_sources (
    source_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id UUID REFERENCES sports(sport_id) ON DELETE CASCADE,
    source_name VARCHAR(150) NOT NULL,
    source_type VARCHAR(50) NOT NULL,
    source_priority INTEGER NOT NULL DEFAULT 1,
    is_main BOOLEAN NOT NULL DEFAULT FALSE,
    is_backup BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    reliability_score NUMERIC(5,2) DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS source_quality (
    quality_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES data_sources(source_id) ON DELETE CASCADE,
    accuracy_score NUMERIC(5,2),
    timeliness_score NUMERIC(5,2),
    completeness_score NUMERIC(5,2),
    status VARCHAR(30) NOT NULL DEFAULT 'healthy',
    last_checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes TEXT
);

CREATE TABLE IF NOT EXISTS sync_logs (
    sync_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID REFERENCES data_sources(source_id) ON DELETE SET NULL,
    sync_type VARCHAR(100) NOT NULL,
    status VARCHAR(30) NOT NULL,
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===============================
-- 11. Alerts / Source issues
-- ===============================
CREATE TABLE IF NOT EXISTS alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_type VARCHAR(80) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    title VARCHAR(200) NOT NULL,
    details TEXT,
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- ===============================
-- 12. Users / Roles (for Phase 2+)
-- ===============================
CREATE TABLE IF NOT EXISTS roles (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_name VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID REFERENCES roles(role_id) ON DELETE SET NULL,
    username VARCHAR(80) NOT NULL UNIQUE,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===============================
-- 13. Audit / History protection
-- ===============================
CREATE TABLE IF NOT EXISTS audit_logs (
    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(100) NOT NULL,
    record_id UUID,
    action VARCHAR(50) NOT NULL,
    actor_user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===============================
-- 14. Indexes
-- ===============================
CREATE INDEX IF NOT EXISTS idx_fixtures_sport_date ON fixtures(sport_id, event_date);
CREATE INDEX IF NOT EXISTS idx_fixtures_status ON fixtures(status);
CREATE INDEX IF NOT EXISTS idx_predictions_fixture ON predictions(fixture_id);
CREATE INDEX IF NOT EXISTS idx_predictions_type ON predictions(prediction_type_id);
CREATE INDEX IF NOT EXISTS idx_data_sources_sport ON data_sources(sport_id);
CREATE INDEX IF NOT EXISTS idx_alerts_unresolved ON alerts(is_resolved, created_at);
CREATE INDEX IF NOT EXISTS idx_performance_date ON performance_history(recorded_date);

-- =========================================
-- 15. Seed baseline values
-- =========================================
INSERT INTO prediction_types (name, description, is_locked)
VALUES
    ('my_tip', 'Manual user-entered tip', TRUE),
    ('agreed_tip', 'Validated agreed tip', TRUE),
    ('pluton_tip', 'Automated PLUTON generated prediction', FALSE)
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles (role_name)
VALUES
    ('admin'),
    ('manager'),
    ('analyst'),
    ('user')
ON CONFLICT (role_name) DO NOTHING;

-- =========================================
-- END OF PHASE 1 SCHEMA
-- =========================================
