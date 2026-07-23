SET search_path TO notification, public;

-- ---------------------------------------------------------
-- Helper: keep updated_at fresh
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------
-- ENUMS
-- ---------------------------------------------------------

CREATE TYPE channel_type AS ENUM (
    'whatsapp', 'sms', 'email', 'android_pn', 'apple_pn'
);

CREATE TYPE notification_priority AS ENUM ('high', 'normal', 'low');

CREATE TYPE notification_status AS ENUM (
    'pending',            -- accepted, not yet fanned out to channels
    'processing',         -- fan-out in progress
    'sent',                -- all channels succeeded
    'failed'               -- all channels exhausted retries
);

CREATE TYPE delivery_status AS ENUM (
    'queued',       -- pushed to Kafka, waiting for worker
    'sent',         -- worker got 2xx from provider, awaiting confirmation
    'delivered',    -- provider confirmed delivery (via webhook)
    'failed',       -- current attempt failed, will retry if attempts remain
    'dead_letter'   -- exhausted max_attempts, needs manual intervention
);


-- ---------------------------------------------------------
-- 1. notification_templates
-- ---------------------------------------------------------
CREATE TABLE notification_templates (
    id              UUID PRIMARY KEY DEFAULT uuidv7(),
    name            VARCHAR(150) NOT NULL,       -- e.g. 'order_confirmed'
    channel         channel_type NOT NULL,
    subject         TEXT,                         -- used for email only
    body_template   TEXT NOT NULL,                -- e.g. 'Hi {{name}}, your order {{order_id}} is confirmed'
    version         INT NOT NULL DEFAULT 1,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (name, channel, version)
);

CREATE TRIGGER set_updated_at_notification_templates
    BEFORE UPDATE ON notification_templates
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_templates_lookup
    ON notification_templates (name, channel, locale)
    WHERE is_active = TRUE;



-- ---------------------------------------------------------
-- 2. notifications
--    The logical request - "notify user X about event Y"
--    before it's split into per-channel deliveries.
-- ---------------------------------------------------------
CREATE TABLE notifications (
    id                UUID PRIMARY KEY DEFAULT uuidv7(),
    idempotency_key   VARCHAR(255),               -- client-supplied or hash(payload+user+template)
    client_id         VARCHAR(100) NOT NULL,      -- e.g. 'flipkart', 'zomato'
    user_id           UUID NOT NULL,               -- FK conceptually to user service (different DB)
    template_name     VARCHAR(150) NOT NULL,
    payload           JSONB NOT NULL DEFAULT '{}', -- template variables: {"name": "Ravi", "order_id": "123"}
    requested_channels channel_type[],             -- NULL = resolve via user preference
    priority          notification_priority NOT NULL DEFAULT 'normal',
    status            notification_status NOT NULL DEFAULT 'pending',
    scheduled_at      TIMESTAMPTZ,                 -- NULL = send immediately
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE TRIGGER set_updated_at_notifications
    BEFORE UPDATE ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();


-- idempotency: prevent duplicate notification creation on client retries
CREATE UNIQUE INDEX uq_notifications_idempotency_key
    ON notifications (client_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE INDEX idx_notifications_user_id   ON notifications (user_id);
CREATE INDEX idx_notifications_status    ON notifications (status);
CREATE INDEX idx_notifications_created   ON notifications (created_at);
CREATE INDEX idx_notifications_scheduled ON notifications (scheduled_at)
    WHERE scheduled_at IS NOT NULL AND status = 'pending';


-- ---------------------------------------------------------
-- 3. notification_deliveries
--    One row per channel per notification. This is the row
--    workers claim, attempt, and update. Maps 1:1 with a
--    message on a Kafka channel topic.
-- ---------------------------------------------------------
CREATE TABLE notification_deliveries (
    id                  UUID PRIMARY KEY DEFAULT uuidv7(),
    notification_id     UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    channel             channel_type NOT NULL,
    provider            VARCHAR(50),                 -- 'twilio', 'fcm', 'ses', 'apns'
    recipient           VARCHAR(255) NOT NULL,       -- phone/email/device token (snapshot at send time)
    rendered_body        TEXT,                        -- template rendered with payload (optional, for audit)
    status               delivery_status NOT NULL DEFAULT 'queued',
    attempt_count        INT NOT NULL DEFAULT 0,
    max_attempts         INT NOT NULL DEFAULT 3,
    next_retry_at        TIMESTAMPTZ,
    provider_message_id  VARCHAR(255),                -- id returned by provider, used to match webhooks
    error_code            VARCHAR(50),
    error_message         TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);


CREATE TRIGGER set_updated_at_notification_deliveries
    BEFORE UPDATE ON notification_deliveries
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();


CREATE INDEX idx_deliveries_notification_id ON notification_deliveries (notification_id);

-- used by the retry scheduler: "give me everything due for retry"
CREATE INDEX idx_deliveries_retry_due
    ON notification_deliveries (next_retry_at)
    WHERE status = 'failed' AND next_retry_at IS NOT NULL;

-- used to match inbound provider webhooks back to a delivery
CREATE INDEX idx_deliveries_provider_message_id
    ON notification_deliveries (provider, provider_message_id)
    WHERE provider_message_id IS NOT NULL;

CREATE INDEX idx_deliveries_status ON notification_deliveries (status);



-- ---------------------------------------------------------
-- 4. delivery_attempts
--    Audit trail: every time a worker tries a delivery,
--    write a row here. Keeps notification_deliveries lean
--    (just current state) while preserving full history.
-- ---------------------------------------------------------
CREATE TABLE delivery_attempts (
    id                UUID PRIMARY KEY DEFAULT uuidv7(),
    delivery_id       UUID NOT NULL REFERENCES notification_deliveries(id) ON DELETE CASCADE,
    attempt_number    INT NOT NULL,
    worker_id         VARCHAR(100),               -- hostname/pod id, useful for debugging
    outcome           VARCHAR(20) NOT NULL,        -- 'success' | 'failure'
    provider_response JSONB,
    error_message     TEXT,
    attempted_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER set_updated_at_delivery_attempts
    BEFORE UPDATE ON delivery_attempts
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_attempts_delivery_id ON delivery_attempts (delivery_id);


-- ---------------------------------------------------------
-- 5. provider_webhook_events
--    Raw inbound events from providers (Twilio status
--    callbacks, SES bounce notifications, FCM delivery
--    receipts). Processed async to update deliveries.
-- ---------------------------------------------------------
CREATE TABLE provider_webhook_events (
    id                   UUID PRIMARY KEY DEFAULT uuidv7(),
    delivery_id          UUID REFERENCES notification_deliveries(id),  -- nullable until matched
    provider              VARCHAR(50) NOT NULL,
    provider_message_id   VARCHAR(255),
    event_type             VARCHAR(50) NOT NULL,   -- 'delivered', 'bounced', 'opened', 'clicked', 'failed'
    raw_payload             JSONB NOT NULL,
    processed                BOOLEAN NOT NULL DEFAULT FALSE,
    received_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER set_updated_at_provider_webhook_events
    BEFORE UPDATE ON provider_webhook_events
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_webhook_events_unprocessed
    ON provider_webhook_events (received_at)
    WHERE processed = FALSE;

CREATE INDEX idx_webhook_events_provider_msg_id
    ON provider_webhook_events (provider, provider_message_id);
