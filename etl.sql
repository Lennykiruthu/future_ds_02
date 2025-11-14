-- ============================================
-- STEP 1: CREATE STAGING TABLE
-- ===========================================

DROP TABLE IF EXISTS staging_raw_data;

CREATE TABLE staging_raw_data (
    ad_id INT,
    reporting_start TEXT,
    reporting_end TEXT,
    campaign_id INT,
    fb_campaign_id INT,
    age VARCHAR(10),
    gender VARCHAR(10),
    interest_1 INT,
    interest_2 INT,
    interest_3 INT,
    impressions INT,
    clicks INT,
    spent DECIMAL(10,2),
    total_conversion INT,
    approved_conversion INT
);

-- ============================================
-- LOAD YOUR CSV DATA HERE
-- ============================================
COPY staging_raw_data FROM '/windows/local-git-repos/future_ds_02/data-fixed.csv'
WITH (FORMAT CSV, HEADER true, DELIMITER ',', NULL '');

-- alter reporting_start and reporting_end to match postgres data/time standards
ALTER TABLE staging_raw_data
ALTER COLUMN reporting_start TYPE DATE USING TO_DATE(reporting_start, 'DD/MM/YYYY'),
ALTER COLUMN reporting_end TYPE DATE USING TO_DATE(reporting_end, 'DD/MM/YYYY');

-- ============================================
-- STEP 2: DATA QUALITY CHECKS
-- ============================================
-- Check for nulls and data issues

-- SELECT
--     COUNT(*) as total_rows,
--     COUNT(DISTINCT ad_id) as unique_ids,
--     COUNT(DISTINCT campaign_id) as unique_campaigns,
--     COUNT(DISTINCT fb_campaign_id) as unique_fb_campaigns,
--     SUM(CASE WHEN ad_id IS NULL THEN 1 ELSE 0 END) as null_ad_ids,
--     SUM(CASE WHEN campaign_id IS NULL THEN 1 ELSE 0 END) as null_campaign_ids,
--     SUM(CASE WHEN impressions < 0 THEN 1 ELSE 0 END) as negative_impressions,
--     SUM(CASE WHEN clicks > impressions THEN 1 ELSE 0 END) as clicks_exceed_impressions    
-- FROM staging_raw_data;


-- View sample data
-- SELECT * FROM staging_raw_data LIMIT 10;

-- ============================================
-- STEP 3: POPULATE CAMPAIGNS TABLE
-- ============================================
INSERT INTO campaigns(campaign_id, fb_campaign_id)
SELECT DISTINCT
    campaign_id,
    MIN(fb_campaign_id) as fb_campaign_id
FROM staging_raw_data
WHERE campaign_id IS NOT NULL
GROUP BY campaign_id
ON CONFLICT (campaign_id) DO NOTHING;

--verify
-- SELECT 
--     COUNT(*) as total_campaigns,
--     MIN(campaign_id) as min_campaign_id,
--     MAX(campaign_id) as max_campaign_id
-- FROM campaigns;

-- ============================================
-- STEP 4: POPULATE ADS TABLE
-- ============================================
INSERT INTO ads(ad_id, campaign_id, fb_campaign_id)
SELECT
    ad_id,
    campaign_id,
    fb_campaign_id
FROM staging_raw_data
WHERE ad_id IS NOT NULL 
ON CONFLICT (ad_id) DO NOTHING;

-- -- verify
-- SELECT 
--     COUNT(*) as total_ads,
--     COUNT(DISTINCT campaign_id) as campaigns_with_ads,
--     COUNT(DISTINCT fb_campaign_id) as unique_fb_campaigns_ads,
--     MIN(ad_id) as min_ad_id,
--     MAX(ad_id) as max_ad_id
-- FROM ads;

-- -- check ad distribution per campaign
-- SELECT
--     campaign_id,
--     COUNT(*) as total_ads,
--     COUNT(DISTINCT fb_campaign_id) as fb_campaign_count
-- FROM ads
-- GROUP BY campaign_id
-- ORDER BY campaign_id;

-- ============================================
-- STEP 5: POPULATE AUDIENCE_SEGMENTS TABLE
-- ============================================
INSERT INTO audience_segments (age_range, gender, interest_1, interest_2, interest_3)
SELECT DISTINCT 
    age,
    gender,
    interest_1,
    interest_2,
    interest_3
FROM staging_raw_data
WHERE age IS NOT NULL 
  AND gender IS NOT NULL
ON CONFLICT (age_range, gender, interest_1, interest_2, interest_3) DO NOTHING;

-- -- Verify
-- SELECT 
--     COUNT(*) as total_segments,
--     COUNT(DISTINCT age_range) as unique_ages,
--     COUNT(DISTINCT gender) as unique_genders,
--     COUNT(DISTINCT interest_1) as unique_interest1,
--     COUNT(DISTINCT interest_2) as unique_interest2,
--     COUNT(DISTINCT interest_3) as unique_interest3
-- FROM audience_segments;

-- -- View sample segments
-- SELECT * FROM audience_segments LIMIT 20;

-- -- Check interest distribution
-- SELECT

--     'interest_1' as interest_type,
--     COUNT(DISTINCT interest_1) as unique_values,
--     COUNT(*) as total_segments
-- FROM audience_segments
-- UNION ALL
-- SELECT
--     'interest_2',
--     COUNT(DISTINCT interest_2),
--     COUNT(*)
-- FROM audience_segments
-- UNION ALL
-- SELECT
--     'interest_3',
--     COUNT(DISTINCT interest_3),
--     COUNT(*)
-- FROM audience_segments;

-- ============================================
-- STEP 6: POPULATE AD_PERFORMANCE TABLE
-- ============================================
INSERT INTO ad_performance (
    ad_id,
    segment_id,
    reporting_start,
    reporting_end,
    impressions,
    clicks,
    spent,
    total_conversion,
    approved_conversion
)
SELECT 
    s.ad_id,
    auc.segment_id,
    s.reporting_start,
    s.reporting_end,
    s.impressions,
    s.clicks,
    s.spent,
    s.total_conversion,
    s.approved_conversion
FROM staging_raw_data as s
JOIN audience_segments as auc ON
    s.age = auc.age_range 
    AND s.gender = auc.gender
    AND s.interest_1 = auc.interest_1
    AND s.interest_2 = auc.interest_2
    AND s.interest_3 = auc.interest_3
WHERE s.ad_id IS NOT NULL
ON CONFLICT (ad_id, segment_id, reporting_start, reporting_end) DO NOTHING;


-- -- Verify
-- SELECT 
--     COUNT(*) as total_performance_records,
--     COUNT(DISTINCT ad_id) as unique_ads,
--     COUNT(DISTINCT segment_id) as unique_segments,
--     COUNT(DISTINCT reporting_start) as unique_start_dates,
--     COUNT(DISTINCT reporting_end) as unique_end_dates,
--     SUM(impressions) as total_impressions,
--     SUM(clicks) as total_clicks,
--     SUM(spent) as total_spent,
--     SUM(approved_conversion) as total_conversions
-- FROM ad_performance;

-- -- Check date range
-- SELECT 
--     MIN(reporting_start) as earliest_date,
--     MAX(reporting_end) as latest_date,
--     COUNT(DISTINCT reporting_start) as unique_reporting_days
-- FROM ad_performance;

-- ============================================
-- STEP 8: DATA VALIDATION QUERIES
-- ============================================
-- validate referential integrity
-- SELECT 
--     'Orphan ads (no campaign)' as check_type,
--     COUNT(*) as issue_count
-- FROM ads a
-- LEFT JOIN campaigns c ON a.campaign_id = c.campaign_id
-- WHERE c.campaign_id IS NULL
-- UNION ALL
-- SELECT 
--     'Orphan performance (no ad)',
--     COUNT(*)
-- FROM ad_performance ap
-- LEFT JOIN ads a ON ap.ad_id = a.ad_id
-- WHERE a.ad_id IS NULL
-- UNION ALL
-- SELECT 
--     'Orphan performance (no segment)',
--     COUNT(*)
-- FROM ad_performance ap
-- LEFT JOIN audience_segments aus ON ap.segment_id = aus.segment_id
-- WHERE aus.segment_id IS NULL;

-- -- Compare staging vs final tables
-- SELECT 
--     'Staging Table' as source,
--     COUNT(*) as row_count,
--     SUM(impressions) as total_impressions,
--     SUM(clicks) as total_clicks,
--     SUM(spent) as total_spent,
--     SUM(approved_conversion) as total_conversions
-- FROM staging_raw_data
-- UNION ALL
-- SELECT 
--     'Ad Performance Table',
--     COUNT(*),
--     SUM(impressions),
--     SUM(clicks),
--     SUM(spent),
--     SUM(approved_conversion)
-- FROM ad_performance;
