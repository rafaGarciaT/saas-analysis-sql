CREATE OR REPLACE VIEW vw_subscription_enriched AS
SELECT
    s.subscription_id,
    s.user_account_id,
    ua.username,
    ua.email,
    s.plan_status,
    s.plan_start_date,
    s.plan_end_date,
    s.next_renewal,
    pp.plan_price_id,
    pp.price,
    pp.currency_code,
    pp.billing_interval,
    p.plan_id,
    p.plan_name
FROM subscription s
JOIN user_account ua ON ua.user_account_id = s.user_account_id
JOIN plan_price pp ON pp.plan_price_id = s.plan_price_id
JOIN plan p ON p.plan_id = pp.plan_id;

CREATE OR REPLACE VIEW vw_monthly_revenue_by_plan AS
SELECT
    date_trunc('month', py.payment_date) AS month_ref,
    p.plan_name,
    pp.billing_interval,
    py.currency_code,
    SUM(py.amount) AS gross_revenue,
    COUNT(*) AS payment_count
FROM payment py
JOIN subscription s ON s.subscription_id = py.subscription_id
JOIN plan_price pp ON pp.plan_price_id = s.plan_price_id
JOIN plan p ON p.plan_id = pp.plan_id
WHERE py.payment_status = 'succeeded'
GROUP BY 1, 2, 3, 4;

CREATE OR REPLACE VIEW vw_monthly_ai_cost_by_user AS
SELECT
    ar.user_account_id,
    date_trunc('month', ar.request_time) AS month_ref,
    COUNT(*) AS total_requests,
    SUM(ar.context_length) AS total_context_length,
    SUM(0.01 + (ar.context_length * 0.00001))::numeric(12, 4) AS estimated_ai_cost
FROM ai_request ar
GROUP BY 1, 2;

CREATE OR REPLACE VIEW vw_monthly_ad_revenue_by_user AS
SELECT
    ai.user_account_id,
    date_trunc('month', ai.impression_date) AS month_ref,
    COUNT(*) FILTER (WHERE ai.event_type = 'impression') AS impressions,
    (
      COUNT(*) FILTER (WHERE ai.event_type = 'impression') / 1000.0
    ) * 4.0 AS estimated_ad_revenue
FROM ad_impression ai
GROUP BY 1, 2;

CREATE OR REPLACE VIEW vw_monthly_user_profitability AS
WITH sub_revenue AS (
    SELECT
        s.user_account_id,
        date_trunc('month', py.payment_date) AS month_ref,
        SUM(py.amount) AS subscription_revenue
    FROM payment py
    JOIN subscription s ON s.subscription_id = py.subscription_id
    WHERE py.payment_status = 'succeeded'
    GROUP BY 1, 2
),
ad_revenue AS (
    SELECT
        m.user_account_id,
        m.month_ref,
        m.estimated_ad_revenue
    FROM vw_monthly_ad_revenue_by_user m
),
ai_cost AS (
    SELECT
        c.user_account_id,
        c.month_ref,
        c.estimated_ai_cost
    FROM vw_monthly_ai_cost_by_user c
),
all_user_months AS (
    SELECT user_account_id, month_ref FROM sub_revenue
    UNION
    SELECT user_account_id, month_ref FROM ad_revenue
    UNION
    SELECT user_account_id, month_ref FROM ai_cost
)
SELECT
    a.user_account_id,
    a.month_ref,
    COALESCE(sr.subscription_revenue, 0) AS subscription_revenue,
    COALESCE(ar.estimated_ad_revenue, 0) AS estimated_ad_revenue,
    COALESCE(ac.estimated_ai_cost, 0) AS estimated_ai_cost,
    0.10::numeric AS baseline_cost,
    (
        COALESCE(sr.subscription_revenue, 0)
        + COALESCE(ar.estimated_ad_revenue, 0)
        - COALESCE(ac.estimated_ai_cost, 0)
        - 0.10
    )::numeric(12, 4) AS estimated_profit
FROM all_user_months a
LEFT JOIN sub_revenue sr
    ON sr.user_account_id = a.user_account_id
   AND sr.month_ref = a.month_ref
LEFT JOIN ad_revenue ar
    ON ar.user_account_id = a.user_account_id
   AND ar.month_ref = a.month_ref
LEFT JOIN ai_cost ac
    ON ac.user_account_id = a.user_account_id
   AND ac.month_ref = a.month_ref;
