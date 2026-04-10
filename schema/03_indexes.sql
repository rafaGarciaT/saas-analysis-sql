-- Foreign key indexes
CREATE INDEX idx_plan_price_plan_id
ON plan_price(plan_id);

CREATE INDEX idx_subscription_user_account_id
ON subscription(user_account_id);

CREATE INDEX idx_subscription_plan_price_id
ON subscription(plan_price_id);

CREATE INDEX idx_payment_subscription_id
ON payment(subscription_id);

CREATE INDEX idx_document_metadata_user_account_id
ON document_metadata(user_account_id);

CREATE INDEX idx_document_metadata_document_setting_id
ON document_metadata(document_setting_id);

CREATE INDEX idx_ai_request_user_account_id
ON ai_request(user_account_id);

CREATE INDEX idx_ai_request_document_metadata_id
ON ai_request(document_metadata_id);

CREATE INDEX idx_ad_impression_user_account_id
ON ad_impression(user_account_id);

-- Time related indexes
CREATE INDEX idx_payment_payment_date
ON payment(payment_date);

CREATE INDEX idx_ai_request_request_time
ON ai_request(request_time);

CREATE INDEX idx_ad_impression_impression_date
ON ad_impression(impression_date);

-- Common query indexes
CREATE INDEX idx_subscription_user_status_renewal
ON subscription(user_account_id, plan_status, next_renewal);

CREATE INDEX idx_plan_price_lookup_current
ON plan_price(plan_id, billing_interval, effective_date DESC)
WHERE is_enabled = true;

CREATE INDEX idx_payment_sub_date
ON payment(subscription_id, payment_date DESC);

CREATE INDEX idx_ai_request_user_time
ON ai_request(user_account_id, request_time DESC);

CREATE INDEX idx_ai_request_type_time
ON ai_request(request_type, request_time);

CREATE INDEX idx_ad_impression_user_event_date
ON ad_impression(user_account_id, event_type, impression_date DESC);

CREATE INDEX idx_subscription_active_only
ON subscription(user_account_id, next_renewal)
WHERE plan_status = 'active';

CREATE INDEX idx_payment_succeeded_date
ON payment(payment_date)
WHERE payment_status = 'succeeded';
