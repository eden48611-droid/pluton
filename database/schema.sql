-- =========================================
-- PLUTON Phase 1: Final canonical schema reference
-- =========================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION validate_prediction_lock()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.is_locked = TRUE AND NEW.is_locked = FALSE THEN
        RAISE EXCEPTION 'Locked prediction cannot be unlocked';
    END IF;

    IF OLD.is_locked = TRUE AND NEW.predicted_result IS DISTINCT FROM OLD.predicted_result THEN
        RAISE EXCEPTION 'Cannot update locked prediction. My Tip / Agreed Tip are immutable.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION audit_record_change()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_logs (table_name, record_id, action, old_values, new_values)
    VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.fixture_id, OLD.fixture_id),
        TG_OP,
        row_to_json(OLD),
        row_to_json(NEW)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS sports (
    sport_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL CHECK (category IN ('Team', 'Individual', 'Motor', 'Other')),
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER update_sports_timestamp BEFORE UPDATE ON sports
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TABLE IF NOT EXISTS seasons (
    season_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id UUID NOT NULL REFERENCES sports(sport_id) ON DELETE CASCADE,
    season_name VARCHAR(50) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, season_name),
    CONSTRAINT date_range_valid CHECK (start_date < end_date)
);

CREATE TRIGGER update_seasons_timestamp BEFORE UPDATE ON seasons
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TABLE IF NOT EXISTS teams (
    team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id UUID NOT NULL REFERENCES sports(sport_id) ON DELETE CASCADE,
    team_name VARCHAR(150) NOT NULL,
    short_name VARCHAR(50),
    country VARCHAR(100),
    logo_url VARCHAR(500),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, team_name)
);

CREATE TRIGGER update_teams_timestamp BEFORE UPDATE ON teams
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TABLE IF NOT EXISTS players (
    player_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id UUID NOT NULL REFERENCES sports(sport_id) ON DELETE CASCADE,
    team_id UUID REFERENCES teams(team_id) ON DELETE SET NULL,
    full_name VARCHAR(150) NOT NULL,
    short_name VARCHAR(80),
    country VARCHAR(100),
    position VARCHAR(50),
    jersey_number INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, full_name)
);

CREATE TRIGGER update_players_timestamp BEFORE UPDATE ON players
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TABLE IF NOT EXISTS competitions (
    competition_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id UUID NOT NULL REFERENCES sports(sport_id) ON DELETE CASCADE,
    season_id UUID NOT NULL REFERENCES seasons(season_id) ON DELETE CASCADE,
    competition_name VARCHAR(150) NOT NULL,
    competition_type VARCHAR(80) NOT NULL,
    country VARCHAR(100),
    tier INTEGER DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, season_id, competition_name)
);

CREATE TRIGGER update_competitions_timestamp BEFORE UPDATE ON competitions
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

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
    status VARCHAR(50) NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'live', 'finished', 'postponed', 'cancelled')),
    home_score INTEGER,
    away_score INTEGER,
    actual_result VARCHAR(50),
    source_reference VARCHAR(200),
    source_name VARCHAR(150),
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, season_id, event_date, COALESCE(home_team_id, home_player_id), COALESCE(away_team_id, away_player_id))
);

CREATE TRIGGER update_fixtures_timestamp BEFORE UPDATE ON fixtures
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER audit_fixtures_changes AFTER INSERT OR UPDATE OR DELETE ON fixtures
FOR EACH ROW EXECUTE FUNCTION audit_record_change();

CREATE TABLE IF NOT EXISTS standings (
    standing_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    competition_id UUID NOT NULL REFERENCES competitions(competition_id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES teams(team_id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
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
    UNIQUE(competition_id, team_id),
    CONSTRAINT position_positive CHECK (position > 0),
    CONSTRAINT stats_non_negative CHECK (played >= 0 AND wins >= 0 AND draws >= 0 AND losses >= 0)
);

CREATE TRIGGER update_standings_timestamp BEFORE UPDATE ON standings
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TABLE IF NOT EXISTS team_form (
    form_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES teams(team_id) ON DELETE CASCADE,
    season_id UUID NOT NULL REFERENCES seasons(season_id) ON DELETE CASCADE,
    last_5_matches JSONB,
    form_rating NUMERIC(5,2) CHECK (form_rating >= 0 AND form_rating <= 100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(team_id, season_id)
);

CREATE TRIGGER update_team_form_timestamp BEFORE UPDATE ON team_form
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TABLE IF NOT EXISTS prediction_types (
    prediction_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_system_locked BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS predictions (
    prediction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fixture_id UUID NOT NULL REFERENCES fixtures(fixture_id) ON DELETE CASCADE,
    prediction_type_id UUID NOT NULL REFERENCES prediction_types(prediction_type_id) ON DELETE RESTRICT,
    predicted_result VARCHAR(50) NOT NULL,
    confidence_level VARCHAR(20) NOT NULL CHECK (confidence_level IN ('HIGH', 'MEDIUM', 'LOW', 'NO_STRONG_SIGNAL')),
    confidence_value NUMERIC(5,2) CHECK (confidence_value >= 0 AND confidence_value <= 100),
    reasoning JSONB,
    source_summary JSONB,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    locked_by_user_id UUID,
    locked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(fixture_id, prediction_type_id)
);

CREATE TRIGGER update_predictions_timestamp BEFORE UPDATE ON predictions
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER validate_prediction_immutability BEFORE UPDATE ON predictions
FOR EACH ROW EXECUTE FUNCTION validate_prediction_lock();

CREATE TABLE IF NOT EXISTS match_results (
    result_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fixture_id UUID NOT NULL UNIQUE REFERENCES fixtures(fixture_id) ON DELETE CASCADE,
    home_score INTEGER NOT NULL,
    away_score INTEGER NOT NULL,
    actual_result VARCHAR(50) NOT NULL,
    my_tip_result VARCHAR(20) CHECK (my_tip_result IN ('WIN', 'LOSS', 'PUSH', NULL)),
    agreed_tip_result VARCHAR(20) CHECK (agreed_tip_result IN ('WIN', 'LOSS', 'PUSH', NULL)),
    pluton_tip_result VARCHAR(20) CHECK (pluton_tip_result IN ('WIN', 'LOSS', 'PUSH', NULL)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER update_results_timestamp BEFORE UPDATE ON match_results
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TABLE IF NOT EXISTS performance_history (
    performance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id UUID REFERENCES sports(sport_id) ON DELETE SET NULL,
    competition_id UUID REFERENCES competitions(competition_id) ON DELETE SET NULL,
    prediction_type_id UUID REFERENCES prediction_types(prediction_type_id) ON DELETE SET NULL,
    period VARCHAR(30) NOT NULL CHECK (period IN ('daily', 'weekly', 'monthly', 'seasonal')),
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

CREATE TABLE IF NOT EXISTS data_sources (
    source_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sport_id UUID REFERENCES sports(sport_id) ON DELETE CASCADE,
    source_name VARCHAR(150) NOT NULL,
    source_type VARCHAR(50) NOT NULL,
    source_priority INTEGER NOT NULL DEFAULT 100,
    is_main BOOLEAN NOT NULL DEFAULT FALSE,
    is_backup BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    reliability_score NUMERIC(5,2) DEFAULT 0 CHECK (reliability_score >= 0 AND reliability_score <= 100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER update_data_sources_timestamp BEFORE UPDATE ON data_sources
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TABLE IF NOT EXISTS source_quality (
    quality_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES data_sources(source_id) ON DELETE CASCADE,
    accuracy_score NUMERIC(5,2) CHECK (accuracy_score >= 0 AND accuracy_score <= 100),
    timeliness_score NUMERIC(5,2) CHECK (timeliness_score >= 0 AND timeliness_score <= 100),
    completeness_score NUMERIC(5,2) CHECK (completeness_score >= 0 AND completeness_score <= 100),
    status VARCHAR(30) NOT NULL DEFAULT 'healthy' CHECK (status IN ('healthy', 'degraded', 'failed', 'unknown')),
    last_checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes TEXT
);

CREATE TABLE IF NOT EXISTS sync_logs (
    sync_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID REFERENCES data_sources(source_id) ON DELETE SET NULL,
    sync_type VARCHAR(100) NOT NULL,
    status VARCHAR(30) NOT NULL CHECK (status IN ('success', 'failed', 'partial', 'skipped')),
    message TEXT,
    records_processed INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_type VARCHAR(80) NOT NULL,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('CRITICAL', 'WARNING', 'INFO')),
    title VARCHAR(200) NOT NULL,
    details TEXT,
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS roles (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
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

CREATE TRIGGER update_users_timestamp BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TABLE IF NOT EXISTS audit_logs (
    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(100) NOT NULL,
    record_id UUID,
    action VARCHAR(50) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    actor_user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fixtures_sport_date ON fixtures(sport_id, event_date DESC);
CREATE INDEX IF NOT EXISTS idx_fixtures_status ON fixtures(status);
CREATE INDEX IF NOT EXISTS idx_fixtures_locked ON fixtures(is_locked);
CREATE INDEX IF NOT EXISTS idx_fixtures_competition ON fixtures(competition_id);
CREATE INDEX IF NOT EXISTS idx_predictions_fixture ON predictions(fixture_id);
CREATE INDEX IF NOT EXISTS idx_predictions_type ON predictions(prediction_type_id);
CREATE INDEX IF NOT EXISTS idx_predictions_locked ON predictions(is_locked);
CREATE INDEX IF NOT EXISTS idx_standings_competition ON standings(competition_id, position);
CREATE INDEX IF NOT EXISTS idx_standings_team ON standings(team_id);
CREATE INDEX IF NOT EXISTS idx_data_sources_sport ON data_sources(sport_id);
CREATE INDEX IF NOT EXISTS idx_data_sources_active ON data_sources(is_active);
CREATE INDEX IF NOT EXISTS idx_alerts_unresolved ON alerts(is_resolved, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_alerts_severity ON alerts(severity);
CREATE INDEX IF NOT EXISTS idx_performance_date ON performance_history(recorded_date DESC);
CREATE INDEX IF NOT EXISTS idx_performance_sport ON performance_history(sport_id);
CREATE INDEX IF NOT EXISTS idx_audit_table_record ON audit_logs(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sync_logs_source ON sync_logs(source_id);
CREATE INDEX IF NOT EXISTS idx_sync_logs_timestamp ON sync_logs(created_at DESC);

CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO schema_migrations (version, name)
VALUES (1, '001_phase1_base_schema.sql')
ON CONFLICT (version) DO NOTHING;
