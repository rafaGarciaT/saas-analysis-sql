-- Timestamp/order sanity
ALTER TABLE user_account
  ADD CONSTRAINT ck_user_account_last_login_after_created
  CHECK (last_login_date >= created_date);

ALTER TABLE document_metadata
  ADD CONSTRAINT ck_document_metadata_modified_after_created
  CHECK (last_modified_date >= created_date);

ALTER TABLE subscription
  ADD CONSTRAINT ck_subscription_dates_order
  CHECK (plan_end_date > plan_start_date),
  ADD CONSTRAINT ck_subscription_renewal_after_start
  CHECK (next_renewal >= plan_start_date);

-- Currency format sanity (ISO-like shape)
ALTER TABLE plan_price
  ADD CONSTRAINT ck_plan_price_currency_code_format
  CHECK (currency_code ~ '^[A-Z]{3}$');

ALTER TABLE payment
  ADD CONSTRAINT ck_payment_currency_code_format
  CHECK (currency_code ~ '^[A-Z]{3}$');

-- Feature limits consistency
ALTER TABLE plan_feature
  ADD CONSTRAINT ck_plan_feature_limits_nonnegative
  CHECK (
    (daily_limit IS NULL OR daily_limit >= 0) AND
    (monthly_limit IS NULL OR monthly_limit >= 0)
  ),
  ADD CONSTRAINT ck_plan_feature_disabled_has_no_limits
  CHECK (is_enabled OR (daily_limit IS NULL AND monthly_limit IS NULL));

-- Only one active plan price per plan+interval (partial unique index)
CREATE UNIQUE INDEX ux_plan_price_one_active_per_interval
ON plan_price (plan_id, billing_interval)
WHERE is_enabled = true;