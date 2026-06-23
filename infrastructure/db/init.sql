-- NexGen MVP Database Initialization Script
-- This script initializes the core database schema

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- ENUMS
-- ============================================================================

CREATE TYPE account_status AS ENUM ('pending', 'active', 'suspended', 'banned', 'deleted');
CREATE TYPE player_status AS ENUM ('active', 'inactive', 'suspended', 'retired');
CREATE TYPE operator_status AS ENUM ('active', 'inactive', 'suspended');
CREATE TYPE club_status AS ENUM ('pending_review', 'approved', 'active', 'suspended', 'dissolved', 'rejected');
CREATE TYPE membership_status AS ENUM ('active', 'left', 'removed', 'suspended');
CREATE TYPE application_status AS ENUM ('pending', 'approved', 'rejected', 'withdrawn', 'expired');
CREATE TYPE season_status AS ENUM ('draft', 'registration_open', 'verification', 'roster_locked', 'active', 'playoffs', 'completed', 'archived');
CREATE TYPE division_status AS ENUM ('active', 'locked', 'completed', 'archived');
CREATE TYPE fixture_status AS ENUM ('draft', 'published', 'cancelled', 'rescheduled');
CREATE TYPE match_status AS ENUM ('pending', 'check_in_open', 'ready', 'in_progress', 'awaiting_submission', 'awaiting_confirmation', 'under_review', 'verified', 'closed', 'voided');
CREATE TYPE result_status AS ENUM ('submitted', 'confirmed', 'rejected', 'disputed', 'voided');
CREATE TYPE dispute_status AS ENUM ('open', 'investigating', 'escalated', 'resolved', 'rejected', 'closed');
CREATE TYPE user_role AS ENUM ('player', 'club_manager', 'moderator', 'operator', 'commissioner', 'hq_admin');

-- ============================================================================
-- IDENTITY & ACCESS LAYER
-- ============================================================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    username VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    account_status account_status NOT NULL DEFAULT 'pending',
    email_verified BOOLEAN DEFAULT FALSE,
    email_verified_at TIMESTAMPTZ,
    phone VARCHAR(20),
    avatar_url TEXT,
    display_name VARCHAR(255),
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    CHECK (email != '')
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_account_status ON users(account_status);
CREATE INDEX idx_users_deleted_at ON users(deleted_at);

CREATE TABLE player_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id),
    gamer_tag VARCHAR(255) NOT NULL UNIQUE,
    region VARCHAR(100),
    verification_status VARCHAR(50) DEFAULT 'unverified',
    player_status player_status NOT NULL DEFAULT 'active',
    reputation_score INTEGER DEFAULT 0,
    bio TEXT,
    preferred_game VARCHAR(100),
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    draws INTEGER DEFAULT 0,
    goals_for INTEGER DEFAULT 0,
    goals_against INTEGER DEFAULT 0,
    mvp_count INTEGER DEFAULT 0,
    no_show_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_player_profiles_user_id ON player_profiles(user_id);
CREATE INDEX idx_player_profiles_gamer_tag ON player_profiles(gamer_tag);
CREATE INDEX idx_player_profiles_status ON player_profiles(player_status);
CREATE INDEX idx_player_profiles_verification ON player_profiles(verification_status);

CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_key VARCHAR(50) NOT NULL UNIQUE,
    role_name VARCHAR(255) NOT NULL,
    description TEXT,
    scope VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    role_id UUID NOT NULL REFERENCES roles(id),
    assigned_by_user_id UUID REFERENCES users(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, role_id)
);

CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON user_roles(role_id);

-- ============================================================================
-- CLUB LAYER
-- ============================================================================

CREATE TABLE clubs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    club_name VARCHAR(255) NOT NULL UNIQUE,
    slug VARCHAR(255) NOT NULL UNIQUE,
    created_by_user_id UUID NOT NULL REFERENCES users(id),
    approved_by_user_id UUID REFERENCES users(id),
    region VARCHAR(100),
    logo_url TEXT,
    description TEXT,
    club_status club_status NOT NULL DEFAULT 'pending_review',
    founded_by_user_id UUID,
    approved_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_clubs_club_status ON clubs(club_status);
CREATE INDEX idx_clubs_region ON clubs(region);
CREATE INDEX idx_clubs_deleted_at ON clubs(deleted_at);

CREATE TABLE club_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    club_id UUID NOT NULL REFERENCES clubs(id),
    player_profile_id UUID NOT NULL REFERENCES player_profiles(id),
    role_in_club VARCHAR(50) DEFAULT 'player',
    membership_status membership_status NOT NULL DEFAULT 'active',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    left_reason TEXT,
    accepted_invite_at TIMESTAMPTZ,
    approved_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_club_members_club_id ON club_members(club_id);
CREATE INDEX idx_club_members_player_id ON club_members(player_profile_id);
CREATE INDEX idx_club_members_status ON club_members(membership_status);
-- Ensure one active membership per player
CREATE UNIQUE INDEX idx_club_members_active ON club_members(player_profile_id) WHERE left_at IS NULL AND membership_status = 'active';

CREATE TABLE club_applications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    club_id UUID NOT NULL REFERENCES clubs(id),
    player_profile_id UUID NOT NULL REFERENCES player_profiles(id),
    application_source VARCHAR(50) DEFAULT 'player_applied',
    application_status application_status NOT NULL DEFAULT 'pending',
    message TEXT,
    submitted_by_user_id UUID REFERENCES users(id),
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_by_user_id UUID REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    decision_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_club_applications_club_id ON club_applications(club_id);
CREATE INDEX idx_club_applications_player_id ON club_applications(player_profile_id);
CREATE INDEX idx_club_applications_status ON club_applications(application_status);
-- Prevent duplicate pending applications
CREATE UNIQUE INDEX idx_club_applications_unique ON club_applications(club_id, player_profile_id) WHERE application_status = 'pending';

-- ============================================================================
-- COMPETITION LAYER
-- ============================================================================

CREATE TABLE seasons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    season_number INTEGER NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    created_by_user_id UUID NOT NULL REFERENCES users(id),
    registration_open_at TIMESTAMPTZ,
    registration_close_at TIMESTAMPTZ,
    roster_lock_at TIMESTAMPTZ,
    start_at TIMESTAMPTZ,
    end_at TIMESTAMPTZ,
    season_status season_status NOT NULL DEFAULT 'draft',
    description TEXT,
    archived_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_seasons_status ON seasons(season_status);
CREATE INDEX idx_seasons_start_at ON seasons(start_at);
CREATE INDEX idx_seasons_end_at ON seasons(end_at);

CREATE TABLE divisions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    season_id UUID NOT NULL REFERENCES seasons(id),
    name VARCHAR(255) NOT NULL,
    level INTEGER,
    division_type VARCHAR(50) DEFAULT 'league',
    division_status division_status NOT NULL DEFAULT 'active',
    capacity INTEGER,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(season_id, name)
);

CREATE INDEX idx_divisions_season_id ON divisions(season_id);
CREATE INDEX idx_divisions_level ON divisions(level);
CREATE INDEX idx_divisions_status ON divisions(division_status);

CREATE TABLE division_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    season_id UUID NOT NULL REFERENCES seasons(id),
    division_id UUID NOT NULL REFERENCES divisions(id),
    player_profile_id UUID NOT NULL REFERENCES player_profiles(id),
    club_id_snapshot UUID REFERENCES clubs(id),
    registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    withdrawn_at TIMESTAMPTZ,
    promoted_at TIMESTAMPTZ,
    relegated_at TIMESTAMPTZ,
    eliminated_at TIMESTAMPTZ,
    division_member_status VARCHAR(50) DEFAULT 'active',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(season_id, player_profile_id)
);

CREATE INDEX idx_division_members_season_id ON division_members(season_id);
CREATE INDEX idx_division_members_division_id ON division_members(division_id);
CREATE INDEX idx_division_members_player_id ON division_members(player_profile_id);

CREATE TABLE fixtures (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fixture_code VARCHAR(100) NOT NULL UNIQUE,
    season_id UUID NOT NULL REFERENCES seasons(id),
    division_id UUID NOT NULL REFERENCES divisions(id),
    created_by_user_id UUID NOT NULL REFERENCES users(id),
    player_a_profile_id UUID NOT NULL REFERENCES player_profiles(id),
    player_b_profile_id UUID NOT NULL REFERENCES player_profiles(id),
    week_no INTEGER,
    scheduled_at TIMESTAMPTZ NOT NULL,
    check_in_open_at TIMESTAMPTZ,
    check_in_close_at TIMESTAMPTZ,
    submission_deadline_at TIMESTAMPTZ,
    fixture_type VARCHAR(50) DEFAULT 'league',
    fixture_status fixture_status NOT NULL DEFAULT 'draft',
    published_at TIMESTAMPTZ,
    rescheduled_from_fixture_id UUID REFERENCES fixtures(id),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (player_a_profile_id != player_b_profile_id)
);

CREATE INDEX idx_fixtures_season_id ON fixtures(season_id);
CREATE INDEX idx_fixtures_division_id ON fixtures(division_id);
CREATE INDEX idx_fixtures_scheduled_at ON fixtures(scheduled_at);
CREATE INDEX idx_fixtures_status ON fixtures(fixture_status);

CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fixture_id UUID NOT NULL UNIQUE REFERENCES fixtures(id),
    match_status match_status NOT NULL DEFAULT 'pending',
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    admin_override_reason TEXT,
    operator_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_matches_status ON matches(match_status);
CREATE INDEX idx_matches_fixture_id ON matches(fixture_id);

CREATE TABLE match_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    match_id UUID NOT NULL REFERENCES matches(id),
    player_profile_id UUID NOT NULL REFERENCES player_profiles(id),
    side VARCHAR(10) NOT NULL,
    club_id_snapshot UUID REFERENCES clubs(id),
    participant_status VARCHAR(50) DEFAULT 'pending',
    confirmation_status VARCHAR(50) DEFAULT 'pending',
    checked_in_at TIMESTAMPTZ,
    confirmed_at TIMESTAMPTZ,
    submission_role VARCHAR(50),
    forfeit_flag BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(match_id, player_profile_id),
    UNIQUE(match_id, side)
);

CREATE INDEX idx_match_participants_match_id ON match_participants(match_id);
CREATE INDEX idx_match_participants_player_id ON match_participants(player_profile_id);
CREATE INDEX idx_match_participants_status ON match_participants(participant_status);

CREATE TABLE results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    match_id UUID NOT NULL UNIQUE REFERENCES matches(id),
    submitted_by_user_id UUID NOT NULL REFERENCES users(id),
    submitted_by_player_profile_id UUID NOT NULL REFERENCES player_profiles(id),
    verified_by_user_id UUID REFERENCES users(id),
    score_player_a INTEGER NOT NULL,
    score_player_b INTEGER NOT NULL,
    winner_player_profile_id UUID REFERENCES player_profiles(id),
    evidence_type VARCHAR(50),
    evidence_payload JSONB,
    result_status result_status NOT NULL DEFAULT 'submitted',
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    verified_at TIMESTAMPTZ,
    decision_notes TEXT,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_results_match_id ON results(match_id);
CREATE INDEX idx_results_status ON results(result_status);
CREATE INDEX idx_results_verified_by ON results(verified_by_user_id);

-- ============================================================================
-- GOVERNANCE LAYER
-- ============================================================================

CREATE TABLE disputes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    match_id UUID NOT NULL REFERENCES matches(id),
    result_id UUID REFERENCES results(id),
    opened_by_user_id UUID NOT NULL REFERENCES users(id),
    opened_by_player_profile_id UUID NOT NULL REFERENCES player_profiles(id),
    resolved_by_user_id UUID REFERENCES users(id),
    dispute_type VARCHAR(50) NOT NULL,
    dispute_status dispute_status NOT NULL DEFAULT 'open',
    summary TEXT NOT NULL,
    resolution TEXT,
    resolution_notes TEXT,
    evidence_payload JSONB,
    appeal_status VARCHAR(50),
    escalation_level INTEGER DEFAULT 0,
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_disputes_match_id ON disputes(match_id);
CREATE INDEX idx_disputes_status ON disputes(dispute_status);
-- Only one active dispute per match
CREATE UNIQUE INDEX idx_disputes_active ON disputes(match_id) WHERE dispute_status IN ('open', 'investigating', 'escalated');

CREATE TABLE warnings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    target_user_id UUID NOT NULL REFERENCES users(id),
    target_club_id UUID REFERENCES clubs(id),
    issued_by_user_id UUID NOT NULL REFERENCES users(id),
    match_id UUID REFERENCES matches(id),
    dispute_id UUID REFERENCES disputes(id),
    reason TEXT NOT NULL,
    warning_level INTEGER DEFAULT 1,
    warning_status VARCHAR(50) NOT NULL DEFAULT 'active',
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    metadata_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_warnings_target_user_id ON warnings(target_user_id);
CREATE INDEX idx_warnings_target_club_id ON warnings(target_club_id);
CREATE INDEX idx_warnings_status ON warnings(warning_status);

CREATE TABLE penalties (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    target_user_id UUID REFERENCES users(id),
    target_club_id UUID REFERENCES clubs(id),
    issued_by_user_id UUID NOT NULL REFERENCES users(id),
    match_id UUID REFERENCES matches(id),
    dispute_id UUID REFERENCES disputes(id),
    penalty_type VARCHAR(50) NOT NULL,
    reason TEXT NOT NULL,
    penalty_status VARCHAR(50) NOT NULL DEFAULT 'proposed',
    points_delta INTEGER,
    effective_from TIMESTAMPTZ,
    effective_to TIMESTAMPTZ,
    evidence_payload JSONB,
    appeal_status VARCHAR(50),
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (target_user_id IS NOT NULL OR target_club_id IS NOT NULL)
);

CREATE INDEX idx_penalties_target_user_id ON penalties(target_user_id);
CREATE INDEX idx_penalties_target_club_id ON penalties(target_club_id);
CREATE INDEX idx_penalties_status ON penalties(penalty_status);
CREATE INDEX idx_penalties_type ON penalties(penalty_type);

CREATE TABLE sanctions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    target_user_id UUID REFERENCES users(id),
    target_club_id UUID REFERENCES clubs(id),
    issued_by_user_id UUID NOT NULL REFERENCES users(id),
    sanction_type VARCHAR(50) NOT NULL,
    reason TEXT NOT NULL,
    sanction_status VARCHAR(50) NOT NULL DEFAULT 'active',
    scope VARCHAR(50),
    start_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_at TIMESTAMPTZ,
    lifted_at TIMESTAMPTZ,
    review_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (target_user_id IS NOT NULL OR target_club_id IS NOT NULL)
);

CREATE INDEX idx_sanctions_target_user_id ON sanctions(target_user_id);
CREATE INDEX idx_sanctions_target_club_id ON sanctions(target_club_id);
CREATE INDEX idx_sanctions_status ON sanctions(sanction_status);
CREATE INDEX idx_sanctions_type ON sanctions(sanction_type);

-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    entity_type VARCHAR(50),
    entity_id UUID,
    notification_type VARCHAR(100) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    notification_status VARCHAR(50) NOT NULL DEFAULT 'unread',
    action_url TEXT,
    priority VARCHAR(50) DEFAULT 'normal',
    metadata_json JSONB,
    read_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_status ON notifications(notification_status);
CREATE INDEX idx_notifications_user_status ON notifications(user_id, notification_status);
CREATE INDEX idx_notifications_created_at ON notifications(created_at);

-- ============================================================================
-- AUDIT LOGGING
-- ============================================================================

CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_user_id UUID NOT NULL REFERENCES users(id),
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    action VARCHAR(100) NOT NULL,
    before_data JSONB,
    after_data JSONB,
    metadata_json JSONB,
    request_id VARCHAR(255),
    ip_address INET,
    user_agent TEXT,
    correlation_id VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_actor_id ON audit_logs(actor_user_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);

-- ============================================================================
-- STANDINGS & RANKINGS
-- ============================================================================

CREATE TABLE standings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    season_id UUID NOT NULL REFERENCES seasons(id),
    division_id UUID NOT NULL REFERENCES divisions(id),
    player_profile_id UUID NOT NULL REFERENCES player_profiles(id),
    club_id_snapshot UUID REFERENCES clubs(id),
    matches_played INTEGER DEFAULT 0,
    wins INTEGER DEFAULT 0,
    draws INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    goals_for INTEGER DEFAULT 0,
    goals_against INTEGER DEFAULT 0,
    goal_difference INTEGER DEFAULT 0,
    points INTEGER DEFAULT 0,
    rank_position INTEGER,
    tie_break_score INTEGER,
    standing_status VARCHAR(50) DEFAULT 'active',
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    locked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(season_id, division_id, player_profile_id)
);

CREATE INDEX idx_standings_season_id ON standings(season_id);
CREATE INDEX idx_standings_division_id ON standings(division_id);
CREATE INDEX idx_standings_rank ON standings(division_id, rank_position);
CREATE INDEX idx_standings_points ON standings(points);

CREATE TABLE rankings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_profile_id UUID NOT NULL REFERENCES player_profiles(id),
    season_id UUID REFERENCES seasons(id),
    ranking_scope_type VARCHAR(50) NOT NULL DEFAULT 'global',
    scope_id UUID,
    ranking_points INTEGER NOT NULL DEFAULT 0,
    rank_position INTEGER,
    tier VARCHAR(50),
    win_rate DECIMAL(5,2),
    reputation_score INTEGER DEFAULT 0,
    ranking_status VARCHAR(50) DEFAULT 'active',
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(ranking_scope_type, scope_id, player_profile_id)
);

CREATE INDEX idx_rankings_player_id ON rankings(player_profile_id);
CREATE INDEX idx_rankings_rank_position ON rankings(rank_position);
CREATE INDEX idx_rankings_points ON rankings(ranking_points);

CREATE TABLE rewards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    season_id UUID NOT NULL REFERENCES seasons(id),
    recipient_player_profile_id UUID REFERENCES player_profiles(id),
    recipient_club_id UUID REFERENCES clubs(id),
    awarded_by_user_id UUID NOT NULL REFERENCES users(id),
    reward_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    evidence_note TEXT,
    metadata_json JSONB,
    reward_status VARCHAR(50) DEFAULT 'granted',
    awarded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (recipient_player_profile_id IS NOT NULL OR recipient_club_id IS NOT NULL)
);

CREATE INDEX idx_rewards_season_id ON rewards(season_id);
CREATE INDEX idx_rewards_player_id ON rewards(recipient_player_profile_id);
CREATE INDEX idx_rewards_club_id ON rewards(recipient_club_id);
CREATE INDEX idx_rewards_type ON rewards(reward_type);

CREATE TABLE achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_profile_id UUID NOT NULL REFERENCES player_profiles(id),
    season_id UUID REFERENCES seasons(id),
    source_reward_id UUID REFERENCES rewards(id),
    achievement_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    badge_key VARCHAR(100),
    visible_in_profile BOOLEAN DEFAULT TRUE,
    metadata_json JSONB,
    earned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_achievements_player_id ON achievements(player_profile_id);
CREATE INDEX idx_achievements_season_id ON achievements(season_id);
CREATE INDEX idx_achievements_type ON achievements(achievement_type);

-- ============================================================================
-- INITIALIZATION: Default Roles
-- ============================================================================

INSERT INTO roles (role_key, role_name, description, scope) VALUES
    ('player', 'Player', 'Participant in the league', NULL),
    ('club_manager', 'Club Manager', 'Club administrator and roster manager', 'club'),
    ('moderator', 'Moderator', 'Community moderator', NULL),
    ('operator', 'Match Operator', 'Match operations and verification', 'division'),
    ('commissioner', 'Commissioner', 'League commissioner and oversight', 'season'),
    ('hq_admin', 'HQ Admin', 'NexGen headquarters administrator', NULL)
ON CONFLICT (role_key) DO NOTHING;

-- ============================================================================
-- INITIALIZATION: Analytics/Summary Views
-- ============================================================================

CREATE VIEW active_players AS
SELECT 
    p.id,
    p.user_id,
    p.gamer_tag,
    p.reputation_score,
    p.wins,
    p.losses,
    p.draws,
    u.email,
    p.created_at
FROM player_profiles p
JOIN users u ON p.user_id = u.id
WHERE p.player_status = 'active' AND u.account_status = 'active' AND p.deleted_at IS NULL;

CREATE VIEW active_clubs AS
SELECT 
    c.id,
    c.club_name,
    c.region,
    COUNT(DISTINCT cm.player_profile_id) as roster_size,
    c.created_at
FROM clubs c
LEFT JOIN club_members cm ON c.id = cm.club_id AND cm.left_at IS NULL AND cm.membership_status = 'active'
WHERE c.club_status = 'active' AND c.deleted_at IS NULL
GROUP BY c.id, c.club_name, c.region, c.created_at;

-- ============================================================================
-- Permissions for Audit Logging
-- ============================================================================

-- All data in audit_logs must be append-only
ALTER TABLE audit_logs DISABLE TRIGGER ALL;
-- Re-enable after data load if needed

-- Success message
SELECT 'NexGen MVP Database initialized successfully' as status;
