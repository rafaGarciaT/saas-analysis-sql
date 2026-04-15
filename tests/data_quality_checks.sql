-- Data quality checks for the schema.
-- Convention: each check returns a non-zero count only when there is a problem.
-- Final output returns only failing checks.

WITH checks AS (
	-- Foreign key orphan checks (defensive validation)
	SELECT -- Plan prices must reference an existing plan
		'orphan_plan_price_plan_id' AS check_name,
		COUNT(*)::bigint AS offending_rows
	FROM plan_price pp
	LEFT JOIN plan p ON p.plan_id = pp.plan_id
	WHERE p.plan_id IS NULL
	UNION ALL

	SELECT -- Subscriptions must reference an existing user
		'orphan_subscription_user_account_id',
		COUNT(*)::bigint
	FROM subscription s
	LEFT JOIN user_account ua ON ua.user_account_id = s.user_account_id
	WHERE ua.user_account_id IS NULL
	UNION ALL

	SELECT -- Subscriptions must reference an existing plan price
		'orphan_subscription_plan_price_id',
		COUNT(*)::bigint
	FROM subscription s
	LEFT JOIN plan_price pp ON pp.plan_price_id = s.plan_price_id
	WHERE pp.plan_price_id IS NULL
	UNION ALL

	SELECT -- Payments must reference an existing subscription
		'orphan_payment_subscription_id',
		COUNT(*)::bigint
	FROM payment py
	LEFT JOIN subscription s ON s.subscription_id = py.subscription_id
	WHERE s.subscription_id IS NULL
	UNION ALL

	SELECT -- Documents must reference an existing user
		'orphan_document_metadata_user_account_id',
		COUNT(*)::bigint
	FROM document_metadata dm
	LEFT JOIN user_account ua ON ua.user_account_id = dm.user_account_id
	WHERE ua.user_account_id IS NULL
	UNION ALL

	SELECT -- Documents must reference an existing document setting
		'orphan_document_metadata_document_setting_id',
		COUNT(*)::bigint
	FROM document_metadata dm
	LEFT JOIN document_setting ds ON ds.document_setting_id = dm.document_setting_id
	WHERE ds.document_setting_id IS NULL
	UNION ALL

	SELECT -- AI requests must reference an existing user
		'orphan_ai_request_user_account_id',
		COUNT(*)::bigint
	FROM ai_request ar
	LEFT JOIN user_account ua ON ua.user_account_id = ar.user_account_id
	WHERE ua.user_account_id IS NULL
	UNION ALL

	SELECT -- AI requests must reference an existing document
		'orphan_ai_request_document_metadata_id',
		COUNT(*)::bigint
	FROM ai_request ar
	LEFT JOIN document_metadata dm ON dm.document_metadata_id = ar.document_metadata_id
	WHERE dm.document_metadata_id IS NULL
	UNION ALL

	SELECT -- Ad events must reference an existing user
		'orphan_ad_impression_user_account_id',
		COUNT(*)::bigint
	FROM ad_impression ai
	LEFT JOIN user_account ua ON ua.user_account_id = ai.user_account_id
	WHERE ua.user_account_id IS NULL
	UNION ALL



	-- Null checks for required relationship columns
	SELECT -- Plan prices must have plan_id populated
		'null_plan_price_plan_id',
		COUNT(*)::bigint
	FROM plan_price
	WHERE plan_id IS NULL
	UNION ALL

	SELECT -- Subscriptions require user and plan price keys
		'null_subscription_required_columns',
		COUNT(*)::bigint
	FROM subscription
	WHERE user_account_id IS NULL OR plan_price_id IS NULL
	UNION ALL

	SELECT -- Payments require subscription_id
		'null_payment_subscription_id',
		COUNT(*)::bigint
	FROM payment
	WHERE subscription_id IS NULL
	UNION ALL

	SELECT -- Documents require user and setting keys
		'null_document_metadata_required_columns',
		COUNT(*)::bigint
	FROM document_metadata
	WHERE user_account_id IS NULL OR document_setting_id IS NULL
	UNION ALL

	SELECT -- AI requests require user and document keys
		'null_ai_request_required_columns',
		COUNT(*)::bigint
	FROM ai_request
	WHERE user_account_id IS NULL OR document_metadata_id IS NULL
	UNION ALL

	SELECT -- Ad events require user_account_id
		'null_ad_impression_user_account_id',
		COUNT(*)::bigint
	FROM ad_impression
	WHERE user_account_id IS NULL
	UNION ALL


	-- Numeric sanity checks
	SELECT -- Plan prices cannot be negative
		'negative_plan_price',
		COUNT(*)::bigint
	FROM plan_price
	WHERE price < 0
	UNION ALL

	SELECT -- Payment amounts cannot be negative
		'negative_payment_amount',
		COUNT(*)::bigint
	FROM payment
	WHERE amount < 0
	UNION ALL

	SELECT -- AI context length cannot be negative
		'negative_ai_context_length',
		COUNT(*)::bigint
	FROM ai_request
	WHERE context_length < 0
	UNION ALL

	SELECT -- Document word count cannot be negative
		'negative_document_word_count',
		COUNT(*)::bigint
	FROM document_metadata
	WHERE word_count < 0
	UNION ALL


	-- Time ordering checks
	SELECT -- User login must not predate account creation
		'user_last_login_before_created',
		COUNT(*)::bigint
	FROM user_account
	WHERE last_login_date < created_date
	UNION ALL

	SELECT -- Document modification must not predate creation
		'document_last_modified_before_created',
		COUNT(*)::bigint
	FROM document_metadata
	WHERE last_modified_date < created_date
	UNION ALL

	SELECT -- Subscription end date must be after start date
		'subscription_end_not_after_start',
		COUNT(*)::bigint
	FROM subscription
	WHERE plan_end_date <= plan_start_date
	UNION ALL

	SELECT -- Renewal date must not predate subscription start
		'subscription_renewal_before_start',
		COUNT(*)::bigint
	FROM subscription
	WHERE next_renewal < plan_start_date
	UNION ALL

	SELECT -- Renewal date should not already be in the past
		'subscription_renewal_in_the_past',
		COUNT(*)::bigint
	FROM subscription
	WHERE next_renewal < CURRENT_DATE
	UNION ALL

	SELECT
        'user_has_multiple_subscriptions',
        COUNT(*)::bigint
	FROM (
        SELECT user_account_id
        FROM subscription
        GROUP BY user_account_id
        HAVING COUNT(*) > 1
	) t
	UNION ALL

	-- Format checks
	SELECT -- Plan price currency must be 3-letter uppercase code
		'invalid_plan_price_currency_code',
		COUNT(*)::bigint
	FROM plan_price
	WHERE currency_code !~ '^[A-Z]{3}$'
	UNION ALL

	SELECT -- Payment currency must be 3-letter uppercase code
		'invalid_payment_currency_code',
		COUNT(*)::bigint
	FROM payment
	WHERE currency_code !~ '^[A-Z]{3}$'
	UNION ALL


	-- Plan feature consistency checks
	SELECT -- Feature limits must not be negative
		'plan_feature_negative_limits',
		COUNT(*)::bigint
	FROM plan_feature
	WHERE (daily_limit IS NOT NULL AND daily_limit < 0)
	   OR (monthly_limit IS NOT NULL AND monthly_limit < 0)
	UNION ALL

	SELECT -- Disabled features must not carry usage limits
		'plan_feature_disabled_with_limits',
		COUNT(*)::bigint
	FROM plan_feature
	WHERE is_enabled = FALSE
	  AND (daily_limit IS NOT NULL OR monthly_limit IS NOT NULL)
	UNION ALL


	SELECT -- At most one enabled price per plan and interval
		'multiple_enabled_plan_price_per_interval',
		COUNT(*)::bigint
	FROM (
		SELECT plan_id, billing_interval
		FROM plan_price
		WHERE is_enabled = TRUE
		GROUP BY plan_id, billing_interval
		HAVING COUNT(*) > 1
	) t
	UNION ALL

	SELECT -- Active subscriptions for the same user must not overlap
			'overlapping_active_subscriptions_per_user',
			COUNT(*)::bigint
	FROM subscription s1
	JOIN subscription s2
	ON s1.user_account_id = s2.user_account_id
	AND s1.subscription_id < s2.subscription_id
	AND s1.plan_status IN ('active', 'past_due')
	AND s2.plan_status IN ('active', 'past_due')
	AND s1.plan_start_date < s2.plan_end_date
	AND s2.plan_start_date < s1.plan_end_date
	UNION ALL

	SELECT -- Subscriptions must not use disabled plan prices
			'subscription_on_disabled_plan_price',
			COUNT(*)::bigint
	FROM subscription s
	JOIN plan_price pp ON pp.plan_price_id = s.plan_price_id
	WHERE pp.is_enabled = FALSE
	UNION ALL

	SELECT -- Subscriptions must not use inactive plans
			'subscription_on_inactive_plan',
			COUNT(*)::bigint
	FROM subscription s
	JOIN plan_price pp ON pp.plan_price_id = s.plan_price_id
	JOIN plan p ON p.plan_id = pp.plan_id
	WHERE p.is_active = FALSE
	UNION ALL

	SELECT -- Payment timestamps must fall within subscription dates
			'payment_outside_subscription_period',
			COUNT(*)::bigint
	FROM payment py
	JOIN subscription s ON s.subscription_id = py.subscription_id
	WHERE py.payment_date < s.plan_start_date
	OR py.payment_date > s.plan_end_date
	UNION ALL

	SELECT -- Payment currency must match the subscribed plan price currency
			'payment_currency_mismatch_plan_currency',
			COUNT(*)::bigint
	FROM payment py
	JOIN subscription s ON s.subscription_id = py.subscription_id
	JOIN plan_price pp ON pp.plan_price_id = s.plan_price_id
	WHERE py.currency_code <> pp.currency_code
	UNION ALL

	SELECT -- AI request user must be the owner of the referenced document
			'ai_request_user_document_owner_mismatch',
			COUNT(*)::bigint
	FROM ai_request ar
	JOIN document_metadata dm ON dm.document_metadata_id = ar.document_metadata_id
	WHERE ar.user_account_id <> dm.user_account_id
	UNION ALL

	SELECT -- AI requests must happen after document creation
			'ai_request_before_document_created',
			COUNT(*)::bigint
	FROM ai_request ar
	JOIN document_metadata dm ON dm.document_metadata_id = ar.document_metadata_id
	WHERE ar.request_time < dm.created_date
	UNION ALL

	SELECT -- Paid users should not generate ad events during active subscriptions
			'ad_events_for_paid_users',
			COUNT(*)::bigint
	FROM ad_impression ai
	JOIN subscription s ON s.user_account_id = ai.user_account_id
	JOIN plan_price pp ON pp.plan_price_id = s.plan_price_id
	JOIN plan p ON p.plan_id = pp.plan_id
	WHERE ai.impression_date BETWEEN s.plan_start_date AND s.plan_end_date
	AND LOWER(p.plan_name) <> 'free'
	UNION ALL

	SELECT -- Free-plan users should not generate AI requests
			'ai_requests_for_free_users',
			COUNT(*)::bigint
	FROM ai_request ar
	JOIN subscription s ON s.user_account_id = ar.user_account_id
	JOIN plan_price pp ON pp.plan_price_id = s.plan_price_id
	JOIN plan p ON p.plan_id = pp.plan_id
	WHERE ar.request_time BETWEEN s.plan_start_date AND s.plan_end_date
	AND LOWER(p.plan_name) = 'free'
	UNION ALL

	-- View completeness: all monthly source keys should appear in profitability view
	SELECT
			'vw_monthly_user_profitability_missing_source_keys',
			COUNT(*)::bigint
	FROM (
			SELECT user_account_id, month_ref FROM vw_monthly_ai_cost_by_user
			UNION
			SELECT user_account_id, month_ref FROM vw_monthly_ad_revenue_by_user
			UNION
			SELECT s.user_account_id, date_trunc('month', py.payment_date) AS month_ref
			FROM payment py
			JOIN subscription s ON s.subscription_id = py.subscription_id
			WHERE py.payment_status = 'succeeded'
	) src
	LEFT JOIN vw_monthly_user_profitability v
	ON v.user_account_id = src.user_account_id
	AND v.month_ref = src.month_ref
	WHERE v.user_account_id IS NULL
	UNION ALL


	-- View grain checks
	SELECT
		'vw_monthly_revenue_by_plan_duplicate_grain',
		COUNT(*)::bigint
	FROM (
		SELECT month_ref, plan_name, billing_interval, currency_code
		FROM vw_monthly_revenue_by_plan
		GROUP BY month_ref, plan_name, billing_interval, currency_code
		HAVING COUNT(*) > 1
	) t
	UNION ALL

	SELECT
		'vw_monthly_ai_cost_by_user_duplicate_grain',
		COUNT(*)::bigint
	FROM (
		SELECT user_account_id, month_ref
		FROM vw_monthly_ai_cost_by_user
		GROUP BY user_account_id, month_ref
		HAVING COUNT(*) > 1
	) t
	UNION ALL

	SELECT
		'vw_monthly_user_profitability_duplicate_grain',
		COUNT(*)::bigint
	FROM (
		SELECT user_account_id, month_ref
		FROM vw_monthly_user_profitability
		GROUP BY user_account_id, month_ref
		HAVING COUNT(*) > 1
	) t
	UNION ALL

	SELECT -- Profitability view arithmetic must equal revenue minus costs
		'vw_monthly_user_profitability_math_mismatch',
		COUNT(*)::bigint
	FROM vw_monthly_user_profitability v
	WHERE ROUND(v.estimated_profit::numeric, 4) != ROUND(
		(
			v.subscription_revenue
			+ v.estimated_ad_revenue
			- v.estimated_ai_cost
			- v.baseline_cost
		)::numeric,
		4
	)
)
SELECT check_name, offending_rows
FROM checks
WHERE offending_rows > 0
ORDER BY check_name;
