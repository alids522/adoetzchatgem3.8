-- =============================================================================
-- ADOETZ CHAT 2 (com.adoetzchat2.chat) — PostgreSQL 15+ DDL, RLS, & Triggers
-- Blueprint Engineering v2.0 (Section 9)
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS private;
CREATE SCHEMA IF NOT EXISTS "waclonegem3.8";

-- 1. Enums
DO $$ BEGIN
    CREATE TYPE public.app_role AS ENUM ('user', 'admin');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE public.user_account_status AS ENUM ('active', 'suspended', 'soft_deleted');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE public.device_status AS ENUM ('active', 'revoked');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE public.receipt_status AS ENUM ('delivered', 'read');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE public.call_state AS ENUM ('ringing', 'connected', 'ended', 'declined', 'missed', 'busy', 'failed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. Profiles (1-to-1 with auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    username_normalized TEXT GENERATED ALWAYS AS (LOWER(TRIM(username))) STORED UNIQUE,
    display_name TEXT NOT NULL,
    bio TEXT DEFAULT '' NOT NULL CHECK (CHAR_LENGTH(bio) <= 160),
    avatar_path TEXT,
    discoverable BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT username_format_chk CHECK (username_normalized ~ '^[a-z0-9_]{3,24}$')
);

-- 3. Roles, Account Status, & User Preferences
CREATE TABLE IF NOT EXISTS public.user_roles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role public.app_role DEFAULT 'user'::public.app_role NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.account_status (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    status public.user_account_status DEFAULT 'active'::public.user_account_status NOT NULL,
    suspended_reason TEXT,
    suspended_until TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.user_preferences (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    read_receipts_enabled BOOLEAN DEFAULT TRUE NOT NULL,
    typing_indicators_enabled BOOLEAN DEFAULT TRUE NOT NULL,
    theme_mode TEXT DEFAULT 'dark' NOT NULL CHECK (theme_mode IN ('system', 'dark', 'light')),
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 4. E2EE Devices (Strict Single-Active-Device via Partial Unique Index)
CREATE TABLE IF NOT EXISTS public.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_name TEXT NOT NULL,
    registration_id INTEGER NOT NULL,
    identity_public_key TEXT NOT NULL,
    signed_prekey_id INTEGER NOT NULL,
    signed_prekey_public TEXT NOT NULL,
    signed_prekey_signature TEXT NOT NULL,
    status public.device_status DEFAULT 'active'::public.device_status NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    last_seen_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_single_active_device_per_user
    ON public.devices(user_id)
    WHERE status = 'active'::public.device_status;

CREATE TABLE IF NOT EXISTS public.device_one_time_prekeys (
    id BIGSERIAL PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    key_id INTEGER NOT NULL,
    public_key TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE (device_id, key_id)
);

-- 5. Conversations & Ciphertext Messages
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    direct_pair_key TEXT UNIQUE NOT NULL, -- LEAST(uid1,uid2) || ':' || GREATEST(uid1,uid2)
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    last_event_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.conversation_members (
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    last_read_server_ts TIMESTAMPTZ,
    is_muted BOOLEAN DEFAULT FALSE NOT NULL,
    is_pinned BOOLEAN DEFAULT FALSE NOT NULL,
    PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id),
    sender_device_id UUID NOT NULL REFERENCES public.devices(id),
    recipient_device_id UUID NOT NULL REFERENCES public.devices(id),
    client_message_id UUID NOT NULL,
    protocol_version SMALLINT DEFAULT 2 NOT NULL,
    message_kind TEXT NOT NULL CHECK (message_kind IN ('ciphertext', 'control_edit', 'control_revoke', 'key_change')),
    ciphertext_b64 TEXT NOT NULL,
    attachment_object_id UUID,
    server_created_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL,
    UNIQUE (sender_id, client_message_id)
);

CREATE INDEX IF NOT EXISTS idx_messages_conv_cursor
    ON public.messages (conversation_id, server_created_at ASC, id ASC);

CREATE TABLE IF NOT EXISTS public.message_receipts (
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    recipient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status public.receipt_status NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    PRIMARY KEY (message_id, recipient_id)
);

-- 6. Calls & Block List
CREATE TABLE IF NOT EXISTS public.calls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    caller_id UUID NOT NULL REFERENCES auth.users(id),
    callee_id UUID NOT NULL REFERENCES auth.users(id),
    is_video BOOLEAN DEFAULT FALSE NOT NULL,
    state public.call_state DEFAULT 'ringing'::public.call_state NOT NULL,
    started_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    ended_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '40 seconds') NOT NULL
);

CREATE TABLE IF NOT EXISTS public.blocked_users (
    blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    PRIMARY KEY (blocker_id, blocked_id),
    CONSTRAINT no_self_block CHECK (blocker_id <> blocked_id)
);

-- 7. Private Internal Tables (Not exposed to PostgREST Data API)
CREATE TABLE IF NOT EXISTS private.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id TEXT NOT NULL,
    actor_user_id UUID NOT NULL REFERENCES auth.users(id),
    target_user_id UUID REFERENCES auth.users(id),
    action TEXT NOT NULL,
    reason TEXT NOT NULL CHECK (CHAR_LENGTH(TRIM(reason)) >= 5),
    metadata JSONB DEFAULT '{}'::jsonb NOT NULL,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL
);

CREATE TABLE IF NOT EXISTS private.push_queue (
    id BIGSERIAL PRIMARY KEY,
    recipient_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN ('new_message', 'incoming_call')),
    conversation_id UUID,
    server_message_id UUID,
    call_id UUID,
    expires_at_ms BIGINT,
    processed BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL
);

-- 8. Atomic Registration Trigger (Section 9.2: Eliminates ERR-38 Split-State)
CREATE OR REPLACE FUNCTION private.handle_new_user_signup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_username TEXT;
    v_display_name TEXT;
BEGIN
    v_username := LOWER(TRIM(COALESCE(NEW.raw_user_meta_data->>'username', '')));
    v_display_name := TRIM(COALESCE(NEW.raw_user_meta_data->>'display_name', v_username));

    IF v_username !~ '^[a-z0-9_]{3,24}$' OR v_username IN ('admin', 'system', 'support', 'root', 'adoetz') THEN
        RAISE EXCEPTION 'INVALID_OR_RESERVED_USERNAME';
    END IF;

    INSERT INTO public.profiles (user_id, username, display_name)
    VALUES (NEW.id, v_username, v_display_name);

    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'user'::public.app_role);

    INSERT INTO public.account_status (user_id, status)
    VALUES (NEW.id, 'active'::public.user_account_status);

    INSERT INTO public.user_preferences (user_id)
    VALUES (NEW.id);

    -- Sync app_metadata so JWT always carries server-enforced role='user'
    UPDATE auth.users
    SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', 'user', 'status', 'active')
    WHERE id = NEW.id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION private.handle_new_user_signup();

-- 9. RLS Authorization Helper Functions (Section 9.3)
CREATE OR REPLACE FUNCTION public.is_caller_active()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.account_status
        WHERE user_id = auth.uid()
          AND status = 'active'::public.user_account_status
    );
$$;

CREATE OR REPLACE FUNCTION public.is_caller_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.user_roles r
        JOIN public.account_status s ON s.user_id = r.user_id
        WHERE r.user_id = auth.uid()
          AND r.role = 'admin'::public.app_role
          AND s.status = 'active'::public.user_account_status
    );
$$;

-- 10. Enable Row Level Security (RLS) on All Public Tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_one_time_prekeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

-- Profiles RLS
CREATE POLICY profiles_select_active ON public.profiles
    FOR SELECT USING (public.is_caller_active() AND (discoverable = TRUE OR user_id = auth.uid() OR public.is_caller_admin()));

CREATE POLICY profiles_update_self ON public.profiles
    FOR UPDATE USING (public.is_caller_active() AND user_id = auth.uid())
    WITH CHECK (public.is_caller_active() AND user_id = auth.uid());

-- Roles & Status RLS (Read own or Admin; never directly writable by client)
CREATE POLICY user_roles_select ON public.user_roles
    FOR SELECT USING (user_id = auth.uid() OR public.is_caller_admin());

CREATE POLICY account_status_select ON public.account_status
    FOR SELECT USING (user_id = auth.uid() OR public.is_caller_admin());

-- Devices RLS
CREATE POLICY devices_select_active ON public.devices
    FOR SELECT USING (public.is_caller_active());

CREATE POLICY devices_modify_self ON public.devices
    FOR ALL USING (public.is_caller_active() AND user_id = auth.uid());

-- Conversations & Messages RLS (Strictly active participants only)
CREATE POLICY conversations_select_member ON public.conversations
    FOR SELECT USING (
        public.is_caller_active() AND EXISTS (
            SELECT 1 FROM public.conversation_members cm
            WHERE cm.conversation_id = id AND cm.user_id = auth.uid()
        )
    );

CREATE POLICY conversation_members_select ON public.conversation_members
    FOR SELECT USING (
        public.is_caller_active() AND (
            user_id = auth.uid() OR EXISTS (
                SELECT 1 FROM public.conversation_members cm2
                WHERE cm2.conversation_id = conversation_id AND cm2.user_id = auth.uid()
            )
        )
    );

CREATE POLICY messages_select_participant ON public.messages
    FOR SELECT USING (
        public.is_caller_active() AND EXISTS (
            SELECT 1 FROM public.conversation_members cm
            WHERE cm.conversation_id = conversation_id AND cm.user_id = auth.uid()
        )
    );

CREATE POLICY messages_insert_participant ON public.messages
    FOR INSERT WITH CHECK (
        public.is_caller_active()
        AND sender_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.conversation_members cm
            WHERE cm.conversation_id = conversation_id AND cm.user_id = auth.uid()
        )
    );
