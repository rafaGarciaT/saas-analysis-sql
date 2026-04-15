BEGIN;

-- Deterministic randomness so seeded proportions stay stable across runs.
SELECT setseed(0.4242);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_account) THEN
        RAISE EXCEPTION 'Missing users. Run seeding/02_users.sql first.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM document_setting) THEN
        RAISE EXCEPTION 'Missing document settings. Run seeding/02_users.sql first.';
    END IF;
END $$;

-- Rebuild only activity/event data.
TRUNCATE TABLE
    ad_impression,
    ai_request,
    document_metadata
RESTART IDENTITY;

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

WITH docs_per_user AS (
    SELECT
        up.user_account_id,
        up.usage_segment,
        CASE
            WHEN up.usage_segment = 'light' THEN 1 + floor(random() * 2)::int
            WHEN up.usage_segment = 'moderate' THEN 3 + floor(random() * 3)::int
            ELSE 6 + floor(random() * 5)::int
        END AS doc_count
    FROM tmp_user_profile up
)
INSERT INTO document_metadata (
    user_account_id,
    document_setting_id,
    created_date,
    last_modified_date,
    word_count
)
SELECT
    dpu.user_account_id,
    ds.document_setting_id,
    doc_created.created_ts,
    doc_created.created_ts + ((1 + floor(random() * 12))::text || ' days')::interval,
    CASE
        WHEN dpu.usage_segment = 'light' THEN 200 + floor(random() * 1300)::int
        WHEN dpu.usage_segment = 'moderate' THEN 800 + floor(random() * 3200)::int
        ELSE 2000 + floor(random() * 9000)::int
    END AS word_count
FROM docs_per_user dpu
JOIN LATERAL generate_series(1, dpu.doc_count) AS g(idx) ON TRUE
JOIN LATERAL (
    SELECT document_setting_id
    FROM document_setting
    ORDER BY random()
    LIMIT 1
) ds ON TRUE
JOIN LATERAL (
    SELECT CURRENT_TIMESTAMP - ((1 + floor(random() * 180))::text || ' days')::interval AS created_ts
) doc_created ON TRUE;

WITH requests_per_document AS (
    SELECT
        dm.document_metadata_id,
        dm.user_account_id,
        dm.created_date,
        up.usage_segment,
        CASE
            WHEN up.plan_tier = 'free' THEN 0
            WHEN up.usage_segment = 'light' THEN floor(random() * 3)::int
            WHEN up.usage_segment = 'moderate' THEN 1 + floor(random() * 4)::int
            ELSE 3 + floor(random() * 6)::int
        END AS req_count
    FROM document_metadata dm
    JOIN tmp_user_profile up ON up.user_account_id = dm.user_account_id
)
INSERT INTO ai_request (
    user_account_id,
    document_metadata_id,
    request_type,
    context_length,
    request_time
)
SELECT
    rpd.user_account_id,
    rpd.document_metadata_id,
    CASE
        WHEN random() < 0.34 THEN 'feedback'::ai_request_type_t
        WHEN random() < 0.67 THEN 'suggestion'::ai_request_type_t
        ELSE 'rewrite'::ai_request_type_t
    END AS request_type,
    CASE
        WHEN rpd.usage_segment = 'light' THEN 300 + floor(random() * 1700)::int
        WHEN rpd.usage_segment = 'moderate' THEN 1000 + floor(random() * 9000)::int
        ELSE 6000 + floor(random() * 18000)::int
    END AS context_length,
    rpd.created_date
        + (random() * EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - rpd.created_date))) * interval '1 second' AS request_time
FROM requests_per_document rpd
JOIN LATERAL generate_series(1, rpd.req_count) AS g(idx) ON TRUE;

WITH eligible_free_users AS (
    SELECT
        up.user_account_id,
        40 + floor(random() * 21)::int AS event_count
    FROM tmp_user_profile up
    WHERE up.plan_tier = 'free'
      AND random() >= 0.35
)
INSERT INTO ad_impression (
    user_account_id,
    event_type,
    impression_date
)
SELECT
    efu.user_account_id,
    CASE
        WHEN random() < 0.96 THEN 'impression'::ad_event_type_t
        ELSE 'click'::ad_event_type_t
    END AS event_type,
    CURRENT_TIMESTAMP - (random() * interval '30 days') AS impression_date
FROM eligible_free_users efu
JOIN LATERAL generate_series(1, efu.event_count) AS g(idx) ON TRUE;

DROP TABLE tmp_user_profile;

COMMIT;

-- Quick sanity summary for this activity seed dataset.
SELECT 'document_metadata' AS table_name, COUNT(*) AS row_count FROM document_metadata
UNION ALL
SELECT 'ai_request', COUNT(*) FROM ai_request
UNION ALL
SELECT 'ad_impression', COUNT(*) FROM ad_impression
ORDER BY table_name;
