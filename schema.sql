--
-- PostgreSQL database dump
--

\restrict 6a9zmXOO2dnyDjRMRngoEZGGp5uJIpujuCqNgXqOaf7LxuxeJbysrJGTCWntTMP

-- Dumped from database version 18.0
-- Dumped by pg_dump version 18.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ad_performance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_performance (
    performance_id integer NOT NULL,
    ad_id integer NOT NULL,
    segment_id integer NOT NULL,
    reporting_start date NOT NULL,
    reporting_end date NOT NULL,
    impressions integer DEFAULT 0,
    clicks integer DEFAULT 0,
    spent numeric(10,2) DEFAULT 0.00,
    total_conversion integer DEFAULT 0,
    approved_conversion integer DEFAULT 0
);


--
-- Name: ad_performance_performance_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ad_performance_performance_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ad_performance_performance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ad_performance_performance_id_seq OWNED BY public.ad_performance.performance_id;


--
-- Name: ads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ads (
    ad_id integer NOT NULL,
    campaign_id integer,
    fb_campaign_id integer,
    created_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: audience_segments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audience_segments (
    segment_id integer NOT NULL,
    age_range character varying(10) NOT NULL,
    gender character varying(10) NOT NULL,
    interest_1 integer,
    interest_2 integer,
    interest_3 integer
);


--
-- Name: audience_segments_segment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audience_segments_segment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audience_segments_segment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audience_segments_segment_id_seq OWNED BY public.audience_segments.segment_id;


--
-- Name: campaigns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaigns (
    campaign_id integer NOT NULL,
    fb_campaign_id integer NOT NULL,
    created_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: staging_raw_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staging_raw_data (
    ad_id integer,
    reporting_start date,
    reporting_end date,
    campaign_id integer,
    fb_campaign_id integer,
    age character varying(10),
    gender character varying(10),
    interest_1 integer,
    interest_2 integer,
    interest_3 integer,
    impressions integer,
    clicks integer,
    spent numeric(10,2),
    total_conversion integer,
    approved_conversion integer
);


--
-- Name: ad_performance performance_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_performance ALTER COLUMN performance_id SET DEFAULT nextval('public.ad_performance_performance_id_seq'::regclass);


--
-- Name: audience_segments segment_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audience_segments ALTER COLUMN segment_id SET DEFAULT nextval('public.audience_segments_segment_id_seq'::regclass);


--
-- Name: ad_performance ad_performance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_performance
    ADD CONSTRAINT ad_performance_pkey PRIMARY KEY (performance_id);


--
-- Name: ads ads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ads
    ADD CONSTRAINT ads_pkey PRIMARY KEY (ad_id);


--
-- Name: audience_segments audience_segments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audience_segments
    ADD CONSTRAINT audience_segments_pkey PRIMARY KEY (segment_id);


--
-- Name: campaigns campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_pkey PRIMARY KEY (campaign_id);


--
-- Name: ad_performance unique_performance; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_performance
    ADD CONSTRAINT unique_performance UNIQUE (ad_id, segment_id, reporting_start, reporting_end);


--
-- Name: audience_segments unique_segment; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audience_segments
    ADD CONSTRAINT unique_segment UNIQUE (age_range, gender, interest_1, interest_2, interest_3);


--
-- Name: idx_ads_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_campaign ON public.ads USING btree (campaign_id);


--
-- Name: idx_ads_fb_campaign; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ads_fb_campaign ON public.ads USING btree (fb_campaign_id);


--
-- Name: idx_audience_age; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audience_age ON public.audience_segments USING btree (age_range);


--
-- Name: idx_audience_gender; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audience_gender ON public.audience_segments USING btree (gender);


--
-- Name: idx_audience_interest1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audience_interest1 ON public.audience_segments USING btree (interest_1);


--
-- Name: idx_performance_ad; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_performance_ad ON public.ad_performance USING btree (ad_id);


--
-- Name: idx_performance_ad_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_performance_ad_date ON public.ad_performance USING btree (ad_id, reporting_start);


--
-- Name: idx_performance_conversions; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_performance_conversions ON public.ad_performance USING btree (approved_conversion);


--
-- Name: idx_performance_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_performance_dates ON public.ad_performance USING btree (reporting_start, reporting_end);


--
-- Name: idx_performance_segment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_performance_segment ON public.ad_performance USING btree (segment_id);


--
-- Name: idx_performance_spent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_performance_spent ON public.ad_performance USING btree (spent);


--
-- Name: ads fk_ads_campaign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ads
    ADD CONSTRAINT fk_ads_campaign FOREIGN KEY (campaign_id) REFERENCES public.campaigns(campaign_id) ON DELETE CASCADE;


--
-- Name: ad_performance fk_performance_ad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_performance
    ADD CONSTRAINT fk_performance_ad FOREIGN KEY (ad_id) REFERENCES public.ads(ad_id) ON DELETE CASCADE;


--
-- Name: ad_performance fk_performance_segment; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_performance
    ADD CONSTRAINT fk_performance_segment FOREIGN KEY (segment_id) REFERENCES public.audience_segments(segment_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict 6a9zmXOO2dnyDjRMRngoEZGGp5uJIpujuCqNgXqOaf7LxuxeJbysrJGTCWntTMP

