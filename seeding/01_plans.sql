INSERT INTO plan (plan_name, is_active) VALUES
('Free', TRUE),
('Pro', TRUE);

INSERT INTO plan_price (plan_id, price, billing_interval, currency_code, effective_date, is_enabled) VALUES
(1, 0.00, 'monthly', 'USD', '2024-01-01', TRUE),
(2, 13.99, 'monthly', 'USD', '2024-01-01', TRUE),
(2, 129.99, 'yearly', 'USD', '2024-01-01', TRUE);

INSERT INTO feature (feature_name, feature_description) VALUES
('spelling_and_grammar_checking', 'Provides real-time spelling and grammar checking'),
('limited_grading_suggestion_system', 'Offers grading suggestions based on predefined criteria, limited to 5 a day'),
('unlimited_grading_suggestion_system', 'Offers grading suggestions based on predefined criteria, unlimited usage'),
('document_setup', 'Provides tools for setting up the other tools based on the document type, target audience, and tone'),
('ad_free_experience', 'Removes all advertisements from the user interface'),
('priority_customer_support', 'Provides priority access to customer support for faster issue resolution'),
('ai_feedback', 'Provides AI-generated feedback on writing quality and style'),
('ai_suggestions', 'Offers AI-generated suggestions for what to write next');

INSERT INTO plan_feature (plan_id, feature_id, is_enabled, daily_limit, monthly_limit) VALUES
(1, 1, TRUE, NULL, NULL),
(1, 2, TRUE, 5, NULL),
(1, 3, FALSE, NULL, NULL),
(1, 4, FALSE, NULL, NULL),
(1, 5, FALSE, NULL, NULL),
(1, 6, FALSE, NULL, NULL),
(1, 7, FALSE, NULL, NULL),
(1, 8, FALSE, NULL, NULL),
(2, 1, TRUE, NULL, NULL),
(2, 2, TRUE, NULL, NULL),
(2, 3, TRUE, NULL, NULL),
(2, 4, TRUE, NULL, NULL),
(2, 5, TRUE, NULL, NULL),
(2, 6, TRUE, NULL,NULL),
(2 ,7 ,TRUE ,NULL ,NULL ),
(2 ,8 ,TRUE ,NULL ,NULL );
