-- Denormalize tables for faster querying and create important feature columns.
CREATE OR REPLACE VIEW vw_performance_complete as
SELECT
    ap.performance_id,
    ap.reporting_start,
    ap.reporting_end,
    c.campaign_id,
    a.ad_id,
    a.fb_campaign_id as ad_fb_campaign_id,
    aus.age_range,
    aus.gender,
    aus.interest_1,
    aus.interest_2,
    aus.interest_3,
    ap.impressions,
    ap.clicks,
    ap.spent,
    ap.total_conversion,
    ap.approved_conversion,

    -- Calculated Columns
    -- Cick-through Rate (ctr)           : (Clicks ÷ Impressions) × 100
    -- Cost per Click (cpc)              : Total Spend ÷ Clicks
    -- Conversion Rate                   : (Approved Conversions ÷ Clicks) × 100
    -- Cost per Acquisition (cpa)        : Total Spend ÷ Approved Conversions
    -- Approval Rate                     : (Approved Conversions ÷ Total Conversions) × 100
    -- Cost Per Mille / 1000 Impressions : (Total Spend ÷ Impressions) × 1000
    ROUND(100.0 * ap.clicks / NULLIF(ap.impressions, 0), 4) as ctr,
    ROUND(ap.spent / NULLIF(ap.clicks, 0), 4) as cpc,
    ROUND(100.0 * ap.approved_conversion / NULLIF(ap.clicks, 0), 4) as conversion_rate,
    ROUND(ap.spent / NULLIF(ap.approved_conversion, 0), 4) as cpa,
    ROUND(100.0 * ap.approved_conversion / NULLIF(ap.total_conversion, 0), 4) as approval_rate,
    ROUND(ap.spent / NULLIF(ap.impressions, 0) * 1000, 4) as cpm
FROM ad_performance as ap
LEFT JOIN ads as a ON ap.ad_id = a.ad_id
LEFT JOIN campaigns as c ON a.campaign_id = c.campaign_id
LEFT JOIN audience_segments as aus ON ap.segment_id = aus.segment_id;

-- View 2: Campaign Summary
CREATE OR REPLACE VIEW vw_campaign_summary AS
SELECT 
    a.campaign_id,
    COUNT(DISTINCT a.ad_id) as total_ads,
    COUNT(DISTINCT a.fb_campaign_id) as unique_fb_campaigns,
    COUNT(DISTINCT ap.segment_id) as unique_segments_targeted,
    MIN(ap.reporting_start) as campaign_start_date,
    MAX(ap.reporting_end) as campaign_end_date,
    SUM(ap.impressions) as total_impressions,
    SUM(ap.clicks) as total_clicks,
    SUM(ap.spent) as total_spent,
    SUM(ap.total_conversion) as total_conversions,
    SUM(ap.approved_conversion) as approved_conversions,
    ROUND(100.0 * SUM(ap.clicks) / NULLIF(SUM(ap.impressions), 0), 2) as overall_ctr,
    ROUND(SUM(ap.spent) / NULLIF(SUM(ap.clicks), 0), 2) as avg_cpc,
    ROUND(100.0 * SUM(ap.approved_conversion) / NULLIF(SUM(ap.clicks), 0), 2) as overall_conversion_rate,
    ROUND(SUM(ap.spent) / NULLIF(SUM(ap.approved_conversion), 0), 2) as overall_cpa
FROM ads as a
LEFT JOIN campaigns as c ON c.campaign_id = a.campaign_id
LEFT JOIN ad_performance as ap ON a.ad_id = ap.ad_id
GROUP BY a.campaign_id;

-- View 3: Ad-Level Performance
CREATE OR REPLACE VIEW vw_ad_summary AS
SELECT 
    a.ad_id,
    a.campaign_id,
    a.fb_campaign_id,
    COUNT(DISTINCT ap.segment_id) as segments_targeted,
    COUNT(DISTINCT ap.reporting_start) as days_active,
    SUM(ap.impressions) as total_impressions,
    SUM(ap.clicks) as total_clicks,
    SUM(ap.spent) as total_spent,
    SUM(ap.approved_conversion) as total_conversions,
    ROUND(100.0 * SUM(ap.clicks) / NULLIF(SUM(ap.impressions), 0), 2) as ctr,
    ROUND(SUM(ap.spent) / NULLIF(SUM(ap.approved_conversion), 0), 2) as cpa,
    ROUND(AVG(ap.spent), 2) as avg_daily_spend
FROM ads as a
LEFT JOIN ad_performance as ap ON a.ad_id = ap.ad_id
GROUP BY a.ad_id, a.campaign_id, a.fb_campaign_id;

-- View 4: Audience Segment Performance
CREATE OR REPLACE VIEW vw_audience_performance AS
SELECT 
    aus.segment_id,
    aus.age_range,
    aus.gender,
    aus.interest_1,
    aus.interest_2,
    aus.interest_3,
    COUNT(DISTINCT ap.ad_id) as ads_shown_to_segment,
    COUNT(DISTINCT a.campaign_id) as campaigns_reached,
    SUM(ap.impressions) as total_impressions,
    SUM(ap.clicks) as total_clicks,
    SUM(ap.spent) as total_spent,
    SUM(ap.approved_conversion) as total_conversions,
    ROUND(AVG(100.0 * ap.clicks / NULLIF(ap.impressions, 0)), 2) as avg_ctr,
    ROUND(AVG(100.0 * ap.approved_conversion / NULLIF(ap.clicks, 0)), 2) as avg_conversion_rate,
    ROUND(AVG(ap.spent / NULLIF(ap.approved_conversion, 0)), 2) as avg_cpa
FROM audience_segments as aus
JOIN ad_performance as ap ON aus.segment_id = ap.segment_id
JOIN ads as a ON ap.ad_id = a.ad_id
GROUP BY aus.segment_id, aus.age_range, aus.gender, 
         aus.interest_1, aus.interest_2, aus.interest_3;

-- View 5: Daily Performance Trends
CREATE OR REPLACE VIEW vw_daily_trends AS
SELECT 
    ap.reporting_start as date,
    COUNT(DISTINCT ap.ad_id) as active_ads,
    COUNT(DISTINCT a.campaign_id) as active_campaigns,
    SUM(ap.impressions) as daily_impressions,
    SUM(ap.clicks) as daily_clicks,
    SUM(ap.spent) as daily_spend,
    SUM(ap.approved_conversion) as daily_conversions,
    ROUND(100.0 * SUM(ap.clicks) / NULLIF(SUM(ap.impressions), 0), 2) as daily_ctr,
    ROUND(SUM(ap.spent) / NULLIF(SUM(ap.approved_conversion), 0), 2) as daily_cpa
FROM ad_performance as ap
JOIN ads as a ON ap.ad_id = a.ad_id
GROUP BY ap.reporting_start
ORDER BY ap.reporting_start;


-- ============================================
-- View: Top/Bottom Performing Ads by Campaign
-- Purpose: Rank ads within each campaign by multiple performance metrics
-- Stakeholders: Media Buyers, Campaign Managers, Marketing Leadership
-- ============================================
CREATE OR REPLACE VIEW vw_ad_performance_ranking AS
WITH ad_metrics AS (
    SELECT 
        a.ad_id,
        a.campaign_id,

        -- Aggregated performance
        SUM(ap.impressions) as total_impressions,
        SUM(ap.clicks) as total_clicks,
        SUM(ap.spent) as total_spent,
        SUM(ap.approved_conversion) as total_approved_conversions,
        
        -- Calculated KPIs
        ROUND(100.0 * SUM(ap.clicks) / NULLIF(SUM(ap.impressions), 0), 2) as ctr,
        ROUND(SUM(ap.spent) / NULLIF(SUM(ap.clicks), 0), 2) as cpc,
        ROUND(100.0 * SUM(ap.approved_conversion) / NULLIF(SUM(ap.clicks), 0), 2) as conversion_rate,
        ROUND(SUM(ap.spent) / NULLIF(SUM(ap.approved_conversion), 0), 2) as cpa,
        
        -- Activity Metrics
        COUNT(DISTINCT ap.segment_id) as segments_targeted,
        COUNT(DISTINCT ap.reporting_start) as days_active                

    FROM ads as a
    LEFT JOIN ad_performance as ap ON a.ad_id = ap.ad_id
    LEFT JOIN campaigns as c ON c.campaign_id = a.campaign_id
    GROUP BY a.ad_id, a.campaign_id
)
SELECT 
    ad_id,
    campaign_id,
    total_impressions,
    total_clicks,
    total_spent,
    total_approved_conversions,
    ctr,
    cpc,
    conversion_rate,
    cpa,
    segments_targeted,
    days_active,
    
    -- Rankings by different metrics (1 = best performer)
    ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY cpa ASC NULLS LAST) as rank_by_cpa,
    ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY conversion_rate DESC NULLS LAST) as rank_by_conversion_rate,
    ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY ctr DESC NULLS LAST) as rank_by_ctr,
    ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY total_approved_conversions DESC NULLS LAST) as rank_by_total_conversions,

    -- Percentile rankings (shows relative position: 1-100)
    ROUND((PERCENT_RANK() OVER (PARTITION BY campaign_id ORDER BY cpa ASC NULLS LAST) * 100)::numeric, 1) as cpa_percentile,
    ROUND((PERCENT_RANK() OVER (PARTITION BY campaign_id ORDER BY conversion_rate DESC NULLS LAST) * 100)::numeric, 1) as conversion_percentile,

    CASE 
        WHEN NTILE(4) OVER (PARTITION BY campaign_id ORDER BY cpa ASC NULLS LAST) = 1 THEN 'Top 25%'
        WHEN NTILE(4) OVER (PARTITION BY campaign_id ORDER BY cpa ASC NULLS LAST) = 4 THEN 'Bottom 25%'
        ELSE 'Middle 50%'
    END as cpa_performance_tier,
    
    -- Campaign-level context
    COUNT(*) OVER (PARTITION BY campaign_id) as total_ads_in_campaign,
    
    -- Compare to campaign average
    ROUND((COALESCE(cpa, 0) - COALESCE(AVG(cpa) OVER (PARTITION BY campaign_id), 0))::numeric, 2) as cpa_vs_campaign_avg,
    ROUND((COALESCE(conversion_rate, 0) - COALESCE(AVG(conversion_rate) OVER (PARTITION BY campaign_id), 0))::numeric, 2) as conversion_rate_vs_campaign_avg,

    
    -- Efficiency flags
    CASE 
        WHEN cpa IS NOT NULL AND cpa < COALESCE(AVG(cpa) OVER (PARTITION BY campaign_id), 0) * 0.8 THEN 'High Performer'
        WHEN cpa IS NOT NULL AND cpa > COALESCE(AVG(cpa) OVER (PARTITION BY campaign_id), 0) * 1.2 THEN 'Underperformer'
        ELSE 'Average'
    END as efficiency_status

FROM ad_metrics
WHERE total_spent > 0    -- Only include ads with actual spend
ORDER BY campaign_id, rank_by_cpa;


-- SELECT *
-- FROM vw_ad_performance_ranking;

-- ============================================
-- Companion View: Quick Top/Bottom Summary
-- Purpose: Show just the best and worst performers per campaign
-- ============================================
CREATE OR REPLACE VIEW vw_campaign_top_bottom_ads AS 
WITH ranked_ads AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY cpa ASC NULLs LAST) as best_rank,
        ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY cpa DESC NULLs LAST) as worst_rank
    FROM vw_ad_performance_ranking
)
SELECT
    campaign_id,
    ad_id,
    cpa,  
    CASE 
        WHEN best_rank <= 5 THEN 'Top ' || best_rank
        WHEN worst_rank <= 5 THEN 'Bottom ' || worst_rank        
        ELSE NULL
    END as performance_position,
    total_spent,
    total_approved_conversions,
    conversion_rate,
    ctr,      
    total_ads_in_campaign
FROM ranked_ads
WHERE best_rank <=5 OR worst_rank <=5
ORDER BY campaign_id, best_rank;

-- ============================================
-- Interest View: Show count of each interest
-- ============================================
CREATE OR REPLACE VIEW vw_interest_analysis AS
SELECT
    interest,
    COUNT(*) AS occurrence
FROM (
    SELECT auc.interest_1 as interest
    FROM ad_performance as ap
    LEFT JOIN audience_segments as auc ON ap.segment_id = auc.segment_id

    UNION ALL

    SELECT auc.interest_2 as interest
    FROM ad_performance as ap
    LEFT JOIN audience_segments as auc ON ap.segment_id = auc.segment_id    

    UNION ALL

    SELECT auc.interest_3 as interest
    FROM ad_performance as ap
    LEFT JOIN audience_segments as auc ON ap.segment_id = auc.segment_id    

) AS all_interests
WHERE interest IS NOT NULL
GROUP BY interest
ORDER BY occurrence DESC;



-- SELECT *
-- FROM vw_campaign_top_bottom_ads;

-- SELECT * FROM vw_performance_complete;
-- SELECT * FROM vw_campaign_summary;
-- SELECT * FROM vw_ad_summary WHERE segments_targeted = 1;
-- SELECT * FROM ad_performance;
-- SELECT 
--     *,
--     SUM(daily_spend) OVER(ORDER BY date) as cumulative_spend
-- FROM vw_daily_trends;
-- SELECT * FROM vw_interest_analysis;

-- SELECT
--     (SELECT COUNT(DISTINCT pc.ad_id) FROM vw_performance_complete as pc),
--     (SELECT COUNT(DISTINCT campaign_id) FROM vw_campaign_summary) as campaign_summary_count,
--     (SELECT COUNT(DISTINCT ad_id) FROM vw_ad_summary) as ad_summary_count,
--     (SELECT COUNT(DISTINCT segment_id) FROM vw_audience_performance) as segments_count,
--     (SELECT COUNT(DISTINCT date) FROM vw_daily_trends) as daily_trends_count,
--     (SELECT COUNT(*) FROM vw_interest_analysis) as interests_count;   