BEGIN;

-- Deterministic randomness so seeded proportions stay stable across runs.
SELECT setseed(0.4242);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM plan WHERE plan_name = 'Free') THEN
        RAISE EXCEPTION 'Missing reference data in plan table. Run seeding/plans.sql first.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM plan_price pp
        JOIN plan p ON p.plan_id = pp.plan_id
        WHERE p.plan_name = 'Free'
          AND pp.billing_interval = 'monthly'
          AND pp.is_enabled = TRUE
    ) THEN
        RAISE EXCEPTION 'Missing Free monthly plan_price. Run seeding/plans.sql first.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM plan_price pp
        JOIN plan p ON p.plan_id = pp.plan_id
        WHERE p.plan_name = 'Pro'
          AND pp.billing_interval = 'monthly'
          AND pp.is_enabled = TRUE
    ) THEN
        RAISE EXCEPTION 'Missing Pro monthly plan_price. Run seeding/plans.sql first.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM plan_price pp
        JOIN plan p ON p.plan_id = pp.plan_id
        WHERE p.plan_name = 'Pro'
          AND pp.billing_interval = 'yearly'
          AND pp.is_enabled = TRUE
    ) THEN
        RAISE EXCEPTION 'Missing Pro yearly plan_price. Run seeding/plans.sql first.';
    END IF;
END $$;

-- Keep plan and feature dimensions, rebuild user/activity data from scratch.
TRUNCATE TABLE
    ad_impression,
    ai_request,
    payment,
    subscription,
    document_metadata,
    document_setting,
    user_account
RESTART IDENTITY;

INSERT INTO document_setting (document_type, target_audience, tone)
VALUES
    ('general', 'general_public', 'neutral'),
    ('general', 'students', 'formal'),
    ('social_media_post', 'followers', 'informal'),
    ('social_media_post', 'brand_customers', 'friendly'),
    ('creative_writing', 'fiction_readers', 'informal'),
    ('creative_writing', 'young_adults', 'friendly'),
    ('article', 'professionals', 'professional'),
    ('article', 'blog_readers', 'friendly'),
    ('report', 'executives', 'formal'),
    ('report', 'team_members', 'neutral'),
    ('email', 'clients', 'professional'),
    ('email', 'internal_team', 'friendly');

WITH generated_users AS (
    SELECT
        gs AS seq,
        ('user_' || LPAD(gs::text, 5, '0'))::varchar(50) AS username,
        ('user_' || LPAD(gs::text, 5, '0') || '@example.com')::varchar(50) AS email,
        ('hash_' || md5(gs::text))::varchar(255) AS password_hash,
        CASE
            WHEN random() < 0.70 THEN ('+1555' || LPAD(gs::text, 7, '0'))::varchar(20)
            ELSE NULL
        END AS telephone,
        CURRENT_TIMESTAMP - ((20 + floor(random() * 520))::text || ' days')::interval AS created_date
    FROM generate_series(1, 10000) AS gs
)
INSERT INTO user_account (
    username,
    email,
    password_hash,
    telephone,
    created_date,
    last_login_date
)
SELECT
    gu.username,
    gu.email,
    gu.password_hash,
    gu.telephone,
    gu.created_date,
    gu.created_date + (random() * EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - gu.created_date))) * interval '1 second'
FROM generated_users gu;

CREATE TEMP TABLE tmp_user_profile AS
SELECT
    ua.user_account_id,
    CASE
        WHEN ua.user_account_id <= 5000 THEN 'light'
        WHEN ua.user_account_id <= 8500 THEN 'moderate'
        ELSE 'heavy'
    END AS usage_segment,
    CASE
        WHEN ua.user_account_id <= 8000 THEN 'free'
        WHEN ua.user_account_id <= 9500 THEN 'pro_monthly'
        ELSE 'pro_yearly'
    END AS plan_tier
FROM user_account ua;

WITH price_lookup AS (
    SELECT p.plan_name, pp.billing_interval, pp.plan_price_id
    FROM plan_price pp
    JOIN plan p ON p.plan_id = pp.plan_id
    WHERE pp.is_enabled = TRUE
),
subscription_base AS (
    SELECT
        up.user_account_id,
        up.plan_tier,
        CASE
            WHEN up.plan_tier = 'free' AND random() < 0.97 THEN 'active'::plan_status_t
            WHEN up.plan_tier = 'free' THEN 'canceled'::plan_status_t
            WHEN random() < 0.85 THEN 'active'::plan_status_t
            WHEN random() < 0.93 THEN 'canceled'::plan_status_t
            ELSE 'past_due'::plan_status_t
        END AS plan_status
    FROM tmp_user_profile up
)
INSERT INTO subscription (
    user_account_id,
    plan_price_id,
    plan_start_date,
    plan_end_date,
    next_renewal,
    plan_status
)
SELECT
    sb.user_account_id,
    CASE
        WHEN sb.plan_tier = 'free' THEN pf.plan_price_id
        WHEN sb.plan_tier = 'pro_monthly' THEN pm.plan_price_id
        ELSE py.plan_price_id
    END AS plan_price_id,
    ps.plan_start_date,
    ps.plan_start_date
        + CASE
            WHEN sb.plan_tier = 'pro_yearly' THEN interval '1 year'
            ELSE interval '1 month'
          END AS plan_end_date,
    ps.plan_start_date
        + CASE
            WHEN sb.plan_tier = 'pro_yearly' THEN interval '1 year'
            ELSE interval '1 month'
          END AS next_renewal,
    sb.plan_status
FROM subscription_base sb
CROSS JOIN LATERAL (
    SELECT CASE
        WHEN sb.plan_tier = 'pro_yearly' THEN
            CURRENT_TIMESTAMP - ((10 + floor(random() * 355))::text || ' days')::interval
        ELSE
            CURRENT_TIMESTAMP - ((1 + floor(random() * 25))::text || ' days')::interval
    END AS plan_start_date
) ps
CROSS JOIN LATERAL (
    SELECT plan_price_id
    FROM price_lookup
    WHERE plan_name = 'Free' AND billing_interval = 'monthly'
) pf
CROSS JOIN LATERAL (
    SELECT plan_price_id
    FROM price_lookup
    WHERE plan_name = 'Pro' AND billing_interval = 'monthly'
) pm
CROSS JOIN LATERAL (
    SELECT plan_price_id
    FROM price_lookup
    WHERE plan_name = 'Pro' AND billing_interval = 'yearly'
) py;

WITH paid_subscriptions AS (
    SELECT
        s.subscription_id,
        s.plan_start_date,
        s.plan_status,
        pp.price,
        pp.currency_code,
        pp.billing_interval
    FROM subscription s
    JOIN plan_price pp ON pp.plan_price_id = s.plan_price_id
    JOIN plan p ON p.plan_id = pp.plan_id
    WHERE p.plan_name = 'Pro'
),
payment_counts AS (
    SELECT
        ps.*,
        1 AS payment_rows
    FROM paid_subscriptions ps
)
INSERT INTO payment (
    subscription_id,
    amount,
    currency_code,
    payment_date,
    payment_status
)
SELECT
    pc.subscription_id,
    pc.price,
    pc.currency_code,
    pc.plan_start_date
        + (g.idx - 1)
          * CASE
                WHEN pc.billing_interval = 'monthly' THEN interval '1 month'
                ELSE interval '1 year'
            END AS payment_date,
    CASE
        WHEN pc.plan_status = 'past_due' AND random() < 0.40 THEN 'failed'::payment_status_t
        WHEN random() < 0.92 THEN 'succeeded'::payment_status_t
        ELSE 'pending'::payment_status_t
    END AS payment_status
FROM payment_counts pc
JOIN LATERAL generate_series(1, pc.payment_rows) AS g(idx) ON TRUE
WHERE pc.plan_start_date
        + (g.idx - 1)
          * CASE
                WHEN pc.billing_interval = 'monthly' THEN interval '1 month'
                ELSE interval '1 year'
            END <= CURRENT_TIMESTAMP;

DROP TABLE tmp_user_profile;

COMMIT;

-- Quick sanity summary for this users/billing seed dataset.
SELECT 'user_account' AS table_name, COUNT(*) AS row_count FROM user_account
UNION ALL
SELECT 'subscription', COUNT(*) FROM subscription
UNION ALL
SELECT 'payment', COUNT(*) FROM payment
UNION ALL
SELECT 'document_setting', COUNT(*) FROM document_setting
ORDER BY table_name;
