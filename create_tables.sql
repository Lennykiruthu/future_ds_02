-- Table 1: CAMPAIGNS
-- 7 unique campaigns (from campaign_id)
CREATE TABLE campaigns (
    campaign_id INTEGER PRIMARY KEY,
    fb_campaign_id INTEGER NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table 2: ADS
-- 1,143 unique ads (from ad_id)
-- Multiple ads can belong to one campaign
-- 490 unique fb_campaign_ids means ads are grouped differently on Facebook
CREATE TABLE ads (
    ad_id INTEGER PRIMARY KEY,
    campaign_id INTEGER,
    fb_campaign_id INTEGER,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ads_campaign FOREIGN KEY (campaign_id) 
        REFERENCES campaigns(campaign_id) ON DELETE CASCADE
);

-- Create indexes for ads table
CREATE INDEX idx_ads_campaign ON ads(campaign_id);
CREATE INDEX idx_ads_fb_campaign ON ads(fb_campaign_id);

-- Table 3: AUDIENCE_SEGMENTS
-- Stores unique demographic + interest targeting combinations
-- With 44 ages × 63 genders × interest combinations, 
-- we'll have multiple unique segments
CREATE TABLE audience_segments (
    segment_id SERIAL PRIMARY KEY,
    age_range VARCHAR(10) NOT NULL,
    gender VARCHAR(10) NOT NULL,
    interest_1 INTEGER,
    interest_2 INTEGER,
    interest_3 INTEGER,
    CONSTRAINT unique_segment UNIQUE (age_range, gender, interest_1, interest_2, interest_3)
);

-- Create indexes for audience_segments table
CREATE INDEX idx_audience_age ON audience_segments(age_range);
CREATE INDEX idx_audience_gender ON audience_segments(gender);
CREATE INDEX idx_audience_interest1 ON audience_segments(interest_1);

-- Table 4: AD_PERFORMANCE
-- Fact table - the main transactional data
-- Each row represents one ad's performance for one audience segment 
-- over one reporting period
CREATE TABLE ad_performance (
    performance_id SERIAL PRIMARY KEY,
    ad_id INTEGER NOT NULL,
    segment_id INTEGER NOT NULL,
    reporting_start DATE NOT NULL,
    reporting_end DATE NOT NULL,
    impressions INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    spent NUMERIC(10, 2) DEFAULT 0.00,
    total_conversion INTEGER DEFAULT 0,
    approved_conversion INTEGER DEFAULT 0,
    CONSTRAINT fk_performance_ad FOREIGN KEY (ad_id) 
        REFERENCES ads(ad_id) ON DELETE CASCADE,
    CONSTRAINT fk_performance_segment FOREIGN KEY (segment_id) 
        REFERENCES audience_segments(segment_id) ON DELETE CASCADE,
    CONSTRAINT unique_performance UNIQUE (ad_id, segment_id, reporting_start, reporting_end)
);

-- Create indexes for ad_performance table
CREATE INDEX idx_performance_ad ON ad_performance(ad_id);
CREATE INDEX idx_performance_segment ON ad_performance(segment_id);
CREATE INDEX idx_performance_dates ON ad_performance(reporting_start, reporting_end);
CREATE INDEX idx_performance_ad_date ON ad_performance(ad_id, reporting_start);
CREATE INDEX idx_performance_conversions ON ad_performance(approved_conversion);
CREATE INDEX idx_performance_spent ON ad_performance(spent);