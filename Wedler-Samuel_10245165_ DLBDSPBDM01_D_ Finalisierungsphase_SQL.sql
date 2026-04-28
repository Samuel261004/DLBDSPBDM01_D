--
-- PostgreSQL database dump
--

\restrict RWz46LDrYVgi64SRxiW3lURCDfnf05oMXJIP9QykwcA1v2XejmIfbchWGgHQR4j

-- Dumped from database version 18.2
-- Dumped by pg_dump version 18.2

-- Started on 2026-04-28 17:24:15

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

--
-- TOC entry 245 (class 1255 OID 16697)
-- Name: buch_suchvektor_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.buch_suchvektor_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.suchvektor :=
  to_tsvector('german', NEW.titel);
  RETURN NEW;
END
$$;


ALTER FUNCTION public.buch_suchvektor_update() OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 16709)
-- Name: check_benutzer_aktiv(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_benutzer_aktiv() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM benutzer 
    WHERE benutzer_id = NEW.benutzer_id 
      AND aktiv = true
  ) THEN
    RAISE EXCEPTION 'Inaktiver Benutzer';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_benutzer_aktiv() OWNER TO postgres;

--
-- TOC entry 246 (class 1255 OID 16701)
-- Name: check_bewertung_nach_ausleihe(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_bewertung_nach_ausleihe() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM ausleihe
    WHERE benutzer_id = NEW.benutzer_id
      AND buch_id = NEW.buch_id
      AND status = 'zurueckgegeben'
  ) THEN
    RAISE EXCEPTION 'Bewertung nur nach abgeschlossener Ausleihe erlaubt.';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_bewertung_nach_ausleihe() OWNER TO postgres;

--
-- TOC entry 248 (class 1255 OID 16704)
-- Name: check_eigenes_buch(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_eigenes_buch() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.benutzer_id = (
    SELECT besitzer_id 
    FROM buch 
    WHERE buch_id = NEW.buch_id
  ) THEN
    RAISE EXCEPTION 'Eigenes Buch kann nicht ausgeliehen werden';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_eigenes_buch() OWNER TO postgres;

--
-- TOC entry 249 (class 1255 OID 16707)
-- Name: sende_ausleih_nachricht(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sende_ausleih_nachricht() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO nachricht (absender_id, empfaenger_id, inhalt)
  SELECT NEW.benutzer_id, b.besitzer_id, 'Dein Buch wurde ausgeliehen'
  FROM buch b
  WHERE b.buch_id = NEW.buch_id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.sende_ausleih_nachricht() OWNER TO postgres;

--
-- TOC entry 251 (class 1255 OID 16711)
-- Name: setze_gelesen_am(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.setze_gelesen_am() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.gelesen = true AND OLD.gelesen = false THEN
    NEW.gelesen_am := CURRENT_TIMESTAMP;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.setze_gelesen_am() OWNER TO postgres;

--
-- TOC entry 247 (class 1255 OID 16703)
-- Name: update_ausleihe_status(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_ausleihe_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ 
BEGIN 
  IF NEW.rueckgabedatum IS NOT NULL THEN 
    NEW.status := 'zurueckgegeben'; 
  ELSIF NEW.ausleihdatum < CURRENT_DATE - INTERVAL '14 days' THEN 
    NEW.status := 'ueberfaellig'; 
  ELSE 
    NEW.status := 'offen'; 
  END IF; 
  RETURN NEW; 
END; 
$$;


ALTER FUNCTION public.update_ausleihe_status() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 234 (class 1259 OID 16539)
-- Name: ausleihe; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ausleihe (
    ausleihe_id integer NOT NULL,
    benutzer_id integer NOT NULL,
    buch_id integer NOT NULL,
    ausleihdatum date DEFAULT CURRENT_DATE NOT NULL,
    rueckgabedatum date,
    status character varying(20) NOT NULL,
    erstellt_am timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ausleihe_check CHECK (((rueckgabedatum IS NULL) OR (rueckgabedatum >= ausleihdatum))),
    CONSTRAINT ausleihe_status_check CHECK (((status)::text = ANY ((ARRAY['offen'::character varying, 'zurueckgegeben'::character varying, 'ueberfaellig'::character varying])::text[]))),
    CONSTRAINT rueckgabe_nach_start CHECK (((rueckgabedatum IS NULL) OR (rueckgabedatum >= ausleihdatum)))
);


ALTER TABLE public.ausleihe OWNER TO postgres;

--
-- TOC entry 5208 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE ausleihe; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.ausleihe IS 'Verknüpft Benutzer und Buch mit Zeitraum';


--
-- TOC entry 5209 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN ausleihe.status; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.ausleihe.status IS 'offen | zurueckgegeben | verspaetet';


--
-- TOC entry 233 (class 1259 OID 16538)
-- Name: ausleihe_ausleihe_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ausleihe_ausleihe_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ausleihe_ausleihe_id_seq OWNER TO postgres;

--
-- TOC entry 5210 (class 0 OID 0)
-- Dependencies: 233
-- Name: ausleihe_ausleihe_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ausleihe_ausleihe_id_seq OWNED BY public.ausleihe.ausleihe_id;


--
-- TOC entry 226 (class 1259 OID 16463)
-- Name: autor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.autor (
    autor_id integer NOT NULL,
    name character varying(255) NOT NULL
);


ALTER TABLE public.autor OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16462)
-- Name: autor_autor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.autor_autor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.autor_autor_id_seq OWNER TO postgres;

--
-- TOC entry 5211 (class 0 OID 0)
-- Dependencies: 225
-- Name: autor_autor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.autor_autor_id_seq OWNED BY public.autor.autor_id;


--
-- TOC entry 224 (class 1259 OID 16435)
-- Name: benutzer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.benutzer (
    benutzer_id integer NOT NULL,
    name character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    rolle_id integer NOT NULL,
    standort_id integer,
    erstellt_am timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    aktiv boolean DEFAULT true
);


ALTER TABLE public.benutzer OWNER TO postgres;

--
-- TOC entry 5212 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE benutzer; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.benutzer IS 'Registrierte Personen der Plattform';


--
-- TOC entry 223 (class 1259 OID 16434)
-- Name: benutzer_benutzer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.benutzer_benutzer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.benutzer_benutzer_id_seq OWNER TO postgres;

--
-- TOC entry 5213 (class 0 OID 0)
-- Dependencies: 223
-- Name: benutzer_benutzer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.benutzer_benutzer_id_seq OWNED BY public.benutzer.benutzer_id;


--
-- TOC entry 236 (class 1259 OID 16564)
-- Name: bewertung; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bewertung (
    bewertung_id integer NOT NULL,
    benutzer_id integer NOT NULL,
    buch_id integer NOT NULL,
    sterne integer NOT NULL,
    bewertungstext text,
    datum timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT bewertung_sterne_check CHECK (((sterne >= 1) AND (sterne <= 5)))
);


ALTER TABLE public.bewertung OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 16563)
-- Name: bewertung_bewertung_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bewertung_bewertung_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bewertung_bewertung_id_seq OWNER TO postgres;

--
-- TOC entry 5214 (class 0 OID 0)
-- Dependencies: 235
-- Name: bewertung_bewertung_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bewertung_bewertung_id_seq OWNED BY public.bewertung.bewertung_id;


--
-- TOC entry 230 (class 1259 OID 16483)
-- Name: buch; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.buch (
    buch_id integer NOT NULL,
    titel character varying(255) NOT NULL,
    isbn character varying(13),
    zustand character varying(50),
    besitzer_id integer NOT NULL,
    standort_id integer,
    erstellt_am timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    suchvektor tsvector,
    CONSTRAINT buch_zustand_check CHECK (((zustand)::text = ANY ((ARRAY['neu'::character varying, 'sehr gut'::character varying, 'gut'::character varying, 'akzeptabel'::character varying])::text[])))
);


ALTER TABLE public.buch OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 16504)
-- Name: buch_autor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.buch_autor (
    buch_id integer NOT NULL,
    autor_id integer NOT NULL
);


ALTER TABLE public.buch_autor OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16482)
-- Name: buch_buch_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.buch_buch_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.buch_buch_id_seq OWNER TO postgres;

--
-- TOC entry 5215 (class 0 OID 0)
-- Dependencies: 229
-- Name: buch_buch_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.buch_buch_id_seq OWNED BY public.buch.buch_id;


--
-- TOC entry 244 (class 1259 OID 16686)
-- Name: buch_durchschnittsbewertung; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.buch_durchschnittsbewertung AS
 SELECT buch_id,
    round(avg(sterne), 2) AS durchschnitt
   FROM public.bewertung
  GROUP BY buch_id;


ALTER VIEW public.buch_durchschnittsbewertung OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 16521)
-- Name: buch_kategorie; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.buch_kategorie (
    buch_id integer NOT NULL,
    kategorie_id integer NOT NULL
);


ALTER TABLE public.buch_kategorie OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 16472)
-- Name: kategorie; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.kategorie (
    kategorie_id integer NOT NULL,
    name character varying(100) NOT NULL
);


ALTER TABLE public.kategorie OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 16471)
-- Name: kategorie_kategorie_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.kategorie_kategorie_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.kategorie_kategorie_id_seq OWNER TO postgres;

--
-- TOC entry 5216 (class 0 OID 0)
-- Dependencies: 227
-- Name: kategorie_kategorie_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.kategorie_kategorie_id_seq OWNED BY public.kategorie.kategorie_id;


--
-- TOC entry 238 (class 1259 OID 16591)
-- Name: kommentar; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.kommentar (
    kommentar_id integer NOT NULL,
    benutzer_id integer NOT NULL,
    buch_id integer NOT NULL,
    text text NOT NULL,
    erstellt_am timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.kommentar OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 16590)
-- Name: kommentar_kommentar_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.kommentar_kommentar_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.kommentar_kommentar_id_seq OWNER TO postgres;

--
-- TOC entry 5217 (class 0 OID 0)
-- Dependencies: 237
-- Name: kommentar_kommentar_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.kommentar_kommentar_id_seq OWNED BY public.kommentar.kommentar_id;


--
-- TOC entry 243 (class 1259 OID 16659)
-- Name: meldung; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.meldung (
    meldung_id integer NOT NULL,
    melder_id integer,
    buch_id integer,
    grund text NOT NULL,
    status character varying(20) DEFAULT 'offen'::character varying,
    erstellt_am timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT meldung_status_check CHECK (((status)::text = ANY ((ARRAY['offen'::character varying, 'in_bearbeitung'::character varying, 'geschlossen'::character varying])::text[])))
);


ALTER TABLE public.meldung OWNER TO postgres;

--
-- TOC entry 242 (class 1259 OID 16658)
-- Name: meldung_meldung_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.meldung_meldung_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.meldung_meldung_id_seq OWNER TO postgres;

--
-- TOC entry 5218 (class 0 OID 0)
-- Dependencies: 242
-- Name: meldung_meldung_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.meldung_meldung_id_seq OWNED BY public.meldung.meldung_id;


--
-- TOC entry 241 (class 1259 OID 16634)
-- Name: nachricht; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nachricht (
    nachricht_id integer NOT NULL,
    absender_id integer NOT NULL,
    empfaenger_id integer NOT NULL,
    betreff character varying(255),
    inhalt text NOT NULL,
    gesendet_am timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    gelesen boolean DEFAULT false
);


ALTER TABLE public.nachricht OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 16633)
-- Name: nachricht_nachricht_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.nachricht_nachricht_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.nachricht_nachricht_id_seq OWNER TO postgres;

--
-- TOC entry 5219 (class 0 OID 0)
-- Dependencies: 240
-- Name: nachricht_nachricht_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.nachricht_nachricht_id_seq OWNED BY public.nachricht.nachricht_id;


--
-- TOC entry 220 (class 1259 OID 16390)
-- Name: rolle; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rolle (
    rolle_id integer NOT NULL,
    name character varying(50) NOT NULL
);


ALTER TABLE public.rolle OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16389)
-- Name: rolle_rolle_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rolle_rolle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rolle_rolle_id_seq OWNER TO postgres;

--
-- TOC entry 5220 (class 0 OID 0)
-- Dependencies: 219
-- Name: rolle_rolle_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rolle_rolle_id_seq OWNED BY public.rolle.rolle_id;


--
-- TOC entry 222 (class 1259 OID 16425)
-- Name: standort; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.standort (
    standort_id integer NOT NULL,
    stadt character varying(100) NOT NULL,
    plz character varying(20),
    land character varying(100) NOT NULL
);


ALTER TABLE public.standort OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16424)
-- Name: standort_standort_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.standort_standort_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.standort_standort_id_seq OWNER TO postgres;

--
-- TOC entry 5221 (class 0 OID 0)
-- Dependencies: 221
-- Name: standort_standort_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.standort_standort_id_seq OWNED BY public.standort.standort_id;


--
-- TOC entry 239 (class 1259 OID 16614)
-- Name: wunschliste; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.wunschliste (
    benutzer_id integer NOT NULL,
    buch_id integer NOT NULL,
    prioritaet integer,
    hinzugefuegt_am timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT wunschliste_prioritaet_check CHECK (((prioritaet >= 1) AND (prioritaet <= 5)))
);


ALTER TABLE public.wunschliste OWNER TO postgres;

--
-- TOC entry 4938 (class 2604 OID 16542)
-- Name: ausleihe ausleihe_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ausleihe ALTER COLUMN ausleihe_id SET DEFAULT nextval('public.ausleihe_ausleihe_id_seq'::regclass);


--
-- TOC entry 4934 (class 2604 OID 16466)
-- Name: autor autor_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.autor ALTER COLUMN autor_id SET DEFAULT nextval('public.autor_autor_id_seq'::regclass);


--
-- TOC entry 4931 (class 2604 OID 16438)
-- Name: benutzer benutzer_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.benutzer ALTER COLUMN benutzer_id SET DEFAULT nextval('public.benutzer_benutzer_id_seq'::regclass);


--
-- TOC entry 4941 (class 2604 OID 16567)
-- Name: bewertung bewertung_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bewertung ALTER COLUMN bewertung_id SET DEFAULT nextval('public.bewertung_bewertung_id_seq'::regclass);


--
-- TOC entry 4936 (class 2604 OID 16486)
-- Name: buch buch_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buch ALTER COLUMN buch_id SET DEFAULT nextval('public.buch_buch_id_seq'::regclass);


--
-- TOC entry 4935 (class 2604 OID 16475)
-- Name: kategorie kategorie_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kategorie ALTER COLUMN kategorie_id SET DEFAULT nextval('public.kategorie_kategorie_id_seq'::regclass);


--
-- TOC entry 4943 (class 2604 OID 16594)
-- Name: kommentar kommentar_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kommentar ALTER COLUMN kommentar_id SET DEFAULT nextval('public.kommentar_kommentar_id_seq'::regclass);


--
-- TOC entry 4949 (class 2604 OID 16662)
-- Name: meldung meldung_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meldung ALTER COLUMN meldung_id SET DEFAULT nextval('public.meldung_meldung_id_seq'::regclass);


--
-- TOC entry 4946 (class 2604 OID 16637)
-- Name: nachricht nachricht_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nachricht ALTER COLUMN nachricht_id SET DEFAULT nextval('public.nachricht_nachricht_id_seq'::regclass);


--
-- TOC entry 4929 (class 2604 OID 16393)
-- Name: rolle rolle_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rolle ALTER COLUMN rolle_id SET DEFAULT nextval('public.rolle_rolle_id_seq'::regclass);


--
-- TOC entry 4930 (class 2604 OID 16428)
-- Name: standort standort_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.standort ALTER COLUMN standort_id SET DEFAULT nextval('public.standort_standort_id_seq'::regclass);


--
-- TOC entry 5193 (class 0 OID 16539)
-- Dependencies: 234
-- Data for Name: ausleihe; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ausleihe (ausleihe_id, benutzer_id, buch_id, ausleihdatum, rueckgabedatum, status, erstellt_am) FROM stdin;
1	2	1	2026-03-03	\N	zurueckgegeben	2026-03-03 10:56:03.31417
2	3	2	2026-03-03	\N	zurueckgegeben	2026-03-03 10:56:03.31417
3	4	3	2026-03-03	\N	zurueckgegeben	2026-03-03 10:56:03.31417
4	5	4	2026-03-03	\N	zurueckgegeben	2026-03-03 10:56:03.31417
5	6	5	2026-03-03	\N	zurueckgegeben	2026-03-03 10:56:03.31417
6	7	6	2026-03-03	\N	zurueckgegeben	2026-03-03 10:56:03.31417
7	8	7	2026-03-03	\N	zurueckgegeben	2026-03-03 10:56:03.31417
8	9	8	2026-03-03	\N	zurueckgegeben	2026-03-03 10:56:03.31417
9	10	9	2026-03-03	\N	zurueckgegeben	2026-03-03 10:56:03.31417
10	1	10	2026-03-03	2026-03-03	zurueckgegeben	2026-03-03 10:56:03.31417
\.


--
-- TOC entry 5185 (class 0 OID 16463)
-- Dependencies: 226
-- Data for Name: autor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.autor (autor_id, name) FROM stdin;
1	Autor A
2	Autor B
3	Autor C
4	Autor D
5	Autor E
6	Autor F
7	Autor G
8	Autor H
9	Autor I
10	Autor J
\.


--
-- TOC entry 5183 (class 0 OID 16435)
-- Dependencies: 224
-- Data for Name: benutzer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.benutzer (benutzer_id, name, email, password_hash, rolle_id, standort_id, erstellt_am, aktiv) FROM stdin;
1	Max Mustermann	max1@test.de	hash	2	1	2026-03-03 10:54:29.825374	t
2	Anna Schmidt	anna@test.de	hash	2	2	2026-03-03 10:54:29.825374	t
3	Tom Weber	tom@test.de	hash	2	3	2026-03-03 10:54:29.825374	t
4	Lisa Klein	lisa@test.de	hash	2	4	2026-03-03 10:54:29.825374	t
5	Paul Becker	paul@test.de	hash	2	5	2026-03-03 10:54:29.825374	t
6	Laura Wolf	laura@test.de	hash	2	6	2026-03-03 10:54:29.825374	t
7	Jan Koch	jan@test.de	hash	2	7	2026-03-03 10:54:29.825374	t
8	Nina Braun	nina@test.de	hash	2	8	2026-03-03 10:54:29.825374	t
9	Felix Roth	felix@test.de	hash	2	9	2026-03-03 10:54:29.825374	t
10	Mara Vogel	mara@test.de	hash	2	10	2026-03-03 10:54:29.825374	t
\.


--
-- TOC entry 5195 (class 0 OID 16564)
-- Dependencies: 236
-- Data for Name: bewertung; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bewertung (bewertung_id, benutzer_id, buch_id, sterne, bewertungstext, datum) FROM stdin;
21	2	1	5	\N	2026-03-03 11:03:29.856949
22	3	2	4	\N	2026-03-03 11:03:29.856949
23	4	3	3	\N	2026-03-03 11:03:29.856949
24	5	4	5	\N	2026-03-03 11:03:29.856949
25	6	5	4	\N	2026-03-03 11:03:29.856949
26	7	6	3	\N	2026-03-03 11:03:29.856949
27	8	7	5	\N	2026-03-03 11:03:29.856949
28	9	8	4	\N	2026-03-03 11:03:29.856949
29	10	9	5	\N	2026-03-03 11:03:29.856949
30	1	10	4	\N	2026-03-03 11:03:29.856949
\.


--
-- TOC entry 5189 (class 0 OID 16483)
-- Dependencies: 230
-- Data for Name: buch; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.buch (buch_id, titel, isbn, zustand, besitzer_id, standort_id, erstellt_am, suchvektor) FROM stdin;
1	Buch 1	1111111111111	gut	1	1	2026-03-03 10:55:18.707177	'1':2 'buch':1
2	Buch 2	2222222222222	neu	2	2	2026-03-03 10:55:18.707177	'2':2 'buch':1
3	Buch 3	3333333333333	sehr gut	3	3	2026-03-03 10:55:18.707177	'3':2 'buch':1
4	Buch 4	4444444444444	akzeptabel	4	4	2026-03-03 10:55:18.707177	'4':2 'buch':1
5	Buch 5	5555555555555	gut	5	5	2026-03-03 10:55:18.707177	'5':2 'buch':1
6	Buch 6	6666666666666	neu	6	6	2026-03-03 10:55:18.707177	'6':2 'buch':1
7	Buch 7	7777777777777	gut	7	7	2026-03-03 10:55:18.707177	'7':2 'buch':1
8	Buch 8	8888888888888	sehr gut	8	8	2026-03-03 10:55:18.707177	'8':2 'buch':1
9	Buch 9	9999999999999	gut	9	9	2026-03-03 10:55:18.707177	'9':2 'buch':1
10	Buch 10	1010101010101	neu	10	10	2026-03-03 10:55:18.707177	'10':2 'buch':1
\.


--
-- TOC entry 5190 (class 0 OID 16504)
-- Dependencies: 231
-- Data for Name: buch_autor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.buch_autor (buch_id, autor_id) FROM stdin;
1	1
2	2
3	3
4	4
5	5
6	6
7	7
8	8
9	9
10	10
\.


--
-- TOC entry 5191 (class 0 OID 16521)
-- Dependencies: 232
-- Data for Name: buch_kategorie; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.buch_kategorie (buch_id, kategorie_id) FROM stdin;
1	1
2	2
3	3
4	4
5	5
6	6
7	7
8	8
9	9
10	10
\.


--
-- TOC entry 5187 (class 0 OID 16472)
-- Dependencies: 228
-- Data for Name: kategorie; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.kategorie (kategorie_id, name) FROM stdin;
1	Roman
2	Thriller
3	Fantasy
4	Sachbuch
5	Biografie
6	Krimi
7	Kinderbuch
8	Science Fiction
9	Geschichte
10	Psychologie
\.


--
-- TOC entry 5197 (class 0 OID 16591)
-- Dependencies: 238
-- Data for Name: kommentar; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.kommentar (kommentar_id, benutzer_id, buch_id, text, erstellt_am) FROM stdin;
1	1	1	Tolles Buch!	2026-03-03 10:57:28.875091
2	2	2	Sehr spannend	2026-03-03 10:57:28.875091
3	3	3	Interessant	2026-03-03 10:57:28.875091
4	4	4	Empfehlenswert	2026-03-03 10:57:28.875091
5	5	5	Gut geschrieben	2026-03-03 10:57:28.875091
6	6	6	Super Story	2026-03-03 10:57:28.875091
7	7	7	Lese ich nochmal	2026-03-03 10:57:28.875091
8	8	8	Sehr gut	2026-03-03 10:57:28.875091
9	9	9	Fand ich klasse	2026-03-03 10:57:28.875091
10	10	10	Top!	2026-03-03 10:57:28.875091
\.


--
-- TOC entry 5202 (class 0 OID 16659)
-- Dependencies: 243
-- Data for Name: meldung; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.meldung (meldung_id, melder_id, buch_id, grund, status, erstellt_am) FROM stdin;
1	1	1	Falsche Beschreibung	offen	2026-03-03 10:58:05.86926
2	2	2	Beschädigt	offen	2026-03-03 10:58:05.86926
3	3	3	Spam	offen	2026-03-03 10:58:05.86926
4	4	4	Unangemessen	offen	2026-03-03 10:58:05.86926
5	5	5	Fehlerhafte Daten	offen	2026-03-03 10:58:05.86926
6	6	6	Veraltet	offen	2026-03-03 10:58:05.86926
7	7	7	Nicht vorhanden	offen	2026-03-03 10:58:05.86926
8	8	8	Doppelt	offen	2026-03-03 10:58:05.86926
9	9	9	Missbrauch	offen	2026-03-03 10:58:05.86926
10	10	10	Testmeldung	offen	2026-03-03 10:58:05.86926
\.


--
-- TOC entry 5200 (class 0 OID 16634)
-- Dependencies: 241
-- Data for Name: nachricht; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.nachricht (nachricht_id, absender_id, empfaenger_id, betreff, inhalt, gesendet_am, gelesen) FROM stdin;
1	1	2	\N	Hallo!	2026-03-03 10:57:51.99306	f
2	2	3	\N	Noch verfügbar?	2026-03-03 10:57:51.99306	f
3	3	4	\N	Danke!	2026-03-03 10:57:51.99306	f
4	4	5	\N	Bitte melden	2026-03-03 10:57:51.99306	f
5	5	6	\N	Wann Rückgabe?	2026-03-03 10:57:51.99306	f
6	6	7	\N	Alles klar	2026-03-03 10:57:51.99306	f
7	7	8	\N	Super	2026-03-03 10:57:51.99306	f
8	8	9	\N	Perfekt	2026-03-03 10:57:51.99306	f
9	9	10	\N	Okay	2026-03-03 10:57:51.99306	f
10	10	1	\N	Vielen Dank	2026-03-03 10:57:51.99306	f
\.


--
-- TOC entry 5179 (class 0 OID 16390)
-- Dependencies: 220
-- Data for Name: rolle; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rolle (rolle_id, name) FROM stdin;
1	Gast
2	Benutzer
3	Administrator
4	Moderator
5	Premium
6	Verifiziert
7	Support
8	Tester
9	Archiviert
10	Demo
\.


--
-- TOC entry 5181 (class 0 OID 16425)
-- Dependencies: 222
-- Data for Name: standort; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.standort (standort_id, stadt, plz, land) FROM stdin;
1	Berlin	10115	Deutschland
2	Hamburg	20095	Deutschland
3	München	80331	Deutschland
4	Köln	50667	Deutschland
5	Frankfurt	60311	Deutschland
6	Stuttgart	70173	Deutschland
7	Düsseldorf	40213	Deutschland
8	Leipzig	04109	Deutschland
9	Dresden	01067	Deutschland
10	Bremen	28195	Deutschland
\.


--
-- TOC entry 5198 (class 0 OID 16614)
-- Dependencies: 239
-- Data for Name: wunschliste; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.wunschliste (benutzer_id, buch_id, prioritaet, hinzugefuegt_am) FROM stdin;
1	2	3	2026-03-03 10:57:42.452342
2	3	4	2026-03-03 10:57:42.452342
3	4	5	2026-03-03 10:57:42.452342
4	5	2	2026-03-03 10:57:42.452342
5	6	1	2026-03-03 10:57:42.452342
6	7	3	2026-03-03 10:57:42.452342
7	8	4	2026-03-03 10:57:42.452342
8	9	2	2026-03-03 10:57:42.452342
9	10	5	2026-03-03 10:57:42.452342
10	1	4	2026-03-03 10:57:42.452342
\.


--
-- TOC entry 5222 (class 0 OID 0)
-- Dependencies: 233
-- Name: ausleihe_ausleihe_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ausleihe_ausleihe_id_seq', 10, true);


--
-- TOC entry 5223 (class 0 OID 0)
-- Dependencies: 225
-- Name: autor_autor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.autor_autor_id_seq', 10, true);


--
-- TOC entry 5224 (class 0 OID 0)
-- Dependencies: 223
-- Name: benutzer_benutzer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.benutzer_benutzer_id_seq', 10, true);


--
-- TOC entry 5225 (class 0 OID 0)
-- Dependencies: 235
-- Name: bewertung_bewertung_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.bewertung_bewertung_id_seq', 30, true);


--
-- TOC entry 5226 (class 0 OID 0)
-- Dependencies: 229
-- Name: buch_buch_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.buch_buch_id_seq', 10, true);


--
-- TOC entry 5227 (class 0 OID 0)
-- Dependencies: 227
-- Name: kategorie_kategorie_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.kategorie_kategorie_id_seq', 10, true);


--
-- TOC entry 5228 (class 0 OID 0)
-- Dependencies: 237
-- Name: kommentar_kommentar_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.kommentar_kommentar_id_seq', 10, true);


--
-- TOC entry 5229 (class 0 OID 0)
-- Dependencies: 242
-- Name: meldung_meldung_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.meldung_meldung_id_seq', 10, true);


--
-- TOC entry 5230 (class 0 OID 0)
-- Dependencies: 240
-- Name: nachricht_nachricht_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.nachricht_nachricht_id_seq', 10, true);


--
-- TOC entry 5231 (class 0 OID 0)
-- Dependencies: 219
-- Name: rolle_rolle_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rolle_rolle_id_seq', 10, true);


--
-- TOC entry 5232 (class 0 OID 0)
-- Dependencies: 221
-- Name: standort_standort_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.standort_standort_id_seq', 10, true);


--
-- TOC entry 4988 (class 2606 OID 16552)
-- Name: ausleihe ausleihe_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ausleihe
    ADD CONSTRAINT ausleihe_pkey PRIMARY KEY (ausleihe_id);


--
-- TOC entry 4973 (class 2606 OID 16470)
-- Name: autor autor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.autor
    ADD CONSTRAINT autor_pkey PRIMARY KEY (autor_id);


--
-- TOC entry 4968 (class 2606 OID 16451)
-- Name: benutzer benutzer_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.benutzer
    ADD CONSTRAINT benutzer_email_key UNIQUE (email);


--
-- TOC entry 4970 (class 2606 OID 16449)
-- Name: benutzer benutzer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.benutzer
    ADD CONSTRAINT benutzer_pkey PRIMARY KEY (benutzer_id);


--
-- TOC entry 4992 (class 2606 OID 16579)
-- Name: bewertung bewertung_benutzer_id_buch_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bewertung
    ADD CONSTRAINT bewertung_benutzer_id_buch_id_key UNIQUE (benutzer_id, buch_id);


--
-- TOC entry 4994 (class 2606 OID 16577)
-- Name: bewertung bewertung_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bewertung
    ADD CONSTRAINT bewertung_pkey PRIMARY KEY (bewertung_id);


--
-- TOC entry 4984 (class 2606 OID 16510)
-- Name: buch_autor buch_autor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buch_autor
    ADD CONSTRAINT buch_autor_pkey PRIMARY KEY (buch_id, autor_id);


--
-- TOC entry 4986 (class 2606 OID 16527)
-- Name: buch_kategorie buch_kategorie_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buch_kategorie
    ADD CONSTRAINT buch_kategorie_pkey PRIMARY KEY (buch_id, kategorie_id);


--
-- TOC entry 4979 (class 2606 OID 16493)
-- Name: buch buch_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buch
    ADD CONSTRAINT buch_pkey PRIMARY KEY (buch_id);


--
-- TOC entry 4975 (class 2606 OID 16481)
-- Name: kategorie kategorie_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kategorie
    ADD CONSTRAINT kategorie_name_key UNIQUE (name);


--
-- TOC entry 4977 (class 2606 OID 16479)
-- Name: kategorie kategorie_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kategorie
    ADD CONSTRAINT kategorie_pkey PRIMARY KEY (kategorie_id);


--
-- TOC entry 4996 (class 2606 OID 16603)
-- Name: kommentar kommentar_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kommentar
    ADD CONSTRAINT kommentar_pkey PRIMARY KEY (kommentar_id);


--
-- TOC entry 5002 (class 2606 OID 16671)
-- Name: meldung meldung_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meldung
    ADD CONSTRAINT meldung_pkey PRIMARY KEY (meldung_id);


--
-- TOC entry 5000 (class 2606 OID 16647)
-- Name: nachricht nachricht_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nachricht
    ADD CONSTRAINT nachricht_pkey PRIMARY KEY (nachricht_id);


--
-- TOC entry 4960 (class 2606 OID 16399)
-- Name: rolle rolle_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rolle
    ADD CONSTRAINT rolle_name_key UNIQUE (name);


--
-- TOC entry 4962 (class 2606 OID 16684)
-- Name: rolle rolle_name_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rolle
    ADD CONSTRAINT rolle_name_unique UNIQUE (name);


--
-- TOC entry 4964 (class 2606 OID 16397)
-- Name: rolle rolle_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rolle
    ADD CONSTRAINT rolle_pkey PRIMARY KEY (rolle_id);


--
-- TOC entry 4966 (class 2606 OID 16433)
-- Name: standort standort_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.standort
    ADD CONSTRAINT standort_pkey PRIMARY KEY (standort_id);


--
-- TOC entry 4998 (class 2606 OID 16622)
-- Name: wunschliste wunschliste_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wunschliste
    ADD CONSTRAINT wunschliste_pkey PRIMARY KEY (benutzer_id, buch_id);


--
-- TOC entry 4989 (class 1259 OID 16693)
-- Name: idx_ausleihe_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ausleihe_status ON public.ausleihe USING btree (status);


--
-- TOC entry 4971 (class 1259 OID 16692)
-- Name: idx_benutzer_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_benutzer_email ON public.benutzer USING btree (email);


--
-- TOC entry 4980 (class 1259 OID 16691)
-- Name: idx_buch_isbn; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_buch_isbn ON public.buch USING btree (isbn);


--
-- TOC entry 4981 (class 1259 OID 16696)
-- Name: idx_buch_suche; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_buch_suche ON public.buch USING gin (suchvektor);


--
-- TOC entry 4982 (class 1259 OID 16690)
-- Name: idx_buch_titel; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_buch_titel ON public.buch USING btree (titel);


--
-- TOC entry 4990 (class 1259 OID 16685)
-- Name: unique_offene_ausleihe; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX unique_offene_ausleihe ON public.ausleihe USING btree (buch_id) WHERE ((status)::text = 'offen'::text);


--
-- TOC entry 5028 (class 2620 OID 16702)
-- Name: bewertung trg_bewertung_check; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_bewertung_check BEFORE INSERT ON public.bewertung FOR EACH ROW EXECUTE FUNCTION public.check_bewertung_nach_ausleihe();


--
-- TOC entry 5023 (class 2620 OID 16698)
-- Name: buch trg_buch_suche; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_buch_suche BEFORE INSERT OR UPDATE ON public.buch FOR EACH ROW EXECUTE FUNCTION public.buch_suchvektor_update();


--
-- TOC entry 5024 (class 2620 OID 16710)
-- Name: ausleihe trg_check_benutzer_aktiv; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_benutzer_aktiv BEFORE INSERT OR UPDATE ON public.ausleihe FOR EACH ROW EXECUTE FUNCTION public.check_benutzer_aktiv();


--
-- TOC entry 5025 (class 2620 OID 16708)
-- Name: ausleihe trg_sende_ausleih_nachricht; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_sende_ausleih_nachricht AFTER INSERT ON public.ausleihe FOR EACH ROW EXECUTE FUNCTION public.sende_ausleih_nachricht();


--
-- TOC entry 5029 (class 2620 OID 16712)
-- Name: nachricht trg_setze_gelesen_am; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_setze_gelesen_am BEFORE UPDATE ON public.nachricht FOR EACH ROW EXECUTE FUNCTION public.setze_gelesen_am();


--
-- TOC entry 5026 (class 2620 OID 16705)
-- Name: ausleihe trigger_check_eigenes_buch; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_check_eigenes_buch BEFORE INSERT OR UPDATE ON public.ausleihe FOR EACH ROW EXECUTE FUNCTION public.check_eigenes_buch();


--
-- TOC entry 5027 (class 2620 OID 16706)
-- Name: ausleihe trigger_update_ausleihe_status; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_ausleihe_status BEFORE INSERT OR UPDATE ON public.ausleihe FOR EACH ROW EXECUTE FUNCTION public.update_ausleihe_status();


--
-- TOC entry 5011 (class 2606 OID 16553)
-- Name: ausleihe ausleihe_benutzer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ausleihe
    ADD CONSTRAINT ausleihe_benutzer_id_fkey FOREIGN KEY (benutzer_id) REFERENCES public.benutzer(benutzer_id);


--
-- TOC entry 5012 (class 2606 OID 16558)
-- Name: ausleihe ausleihe_buch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ausleihe
    ADD CONSTRAINT ausleihe_buch_id_fkey FOREIGN KEY (buch_id) REFERENCES public.buch(buch_id);


--
-- TOC entry 5003 (class 2606 OID 16452)
-- Name: benutzer benutzer_rolle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.benutzer
    ADD CONSTRAINT benutzer_rolle_id_fkey FOREIGN KEY (rolle_id) REFERENCES public.rolle(rolle_id);


--
-- TOC entry 5004 (class 2606 OID 16457)
-- Name: benutzer benutzer_standort_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.benutzer
    ADD CONSTRAINT benutzer_standort_id_fkey FOREIGN KEY (standort_id) REFERENCES public.standort(standort_id);


--
-- TOC entry 5013 (class 2606 OID 16580)
-- Name: bewertung bewertung_benutzer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bewertung
    ADD CONSTRAINT bewertung_benutzer_id_fkey FOREIGN KEY (benutzer_id) REFERENCES public.benutzer(benutzer_id);


--
-- TOC entry 5014 (class 2606 OID 16585)
-- Name: bewertung bewertung_buch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bewertung
    ADD CONSTRAINT bewertung_buch_id_fkey FOREIGN KEY (buch_id) REFERENCES public.buch(buch_id);


--
-- TOC entry 5007 (class 2606 OID 16516)
-- Name: buch_autor buch_autor_autor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buch_autor
    ADD CONSTRAINT buch_autor_autor_id_fkey FOREIGN KEY (autor_id) REFERENCES public.autor(autor_id) ON DELETE CASCADE;


--
-- TOC entry 5008 (class 2606 OID 16511)
-- Name: buch_autor buch_autor_buch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buch_autor
    ADD CONSTRAINT buch_autor_buch_id_fkey FOREIGN KEY (buch_id) REFERENCES public.buch(buch_id) ON DELETE CASCADE;


--
-- TOC entry 5005 (class 2606 OID 16494)
-- Name: buch buch_besitzer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buch
    ADD CONSTRAINT buch_besitzer_id_fkey FOREIGN KEY (besitzer_id) REFERENCES public.benutzer(benutzer_id);


--
-- TOC entry 5009 (class 2606 OID 16528)
-- Name: buch_kategorie buch_kategorie_buch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buch_kategorie
    ADD CONSTRAINT buch_kategorie_buch_id_fkey FOREIGN KEY (buch_id) REFERENCES public.buch(buch_id) ON DELETE CASCADE;


--
-- TOC entry 5010 (class 2606 OID 16533)
-- Name: buch_kategorie buch_kategorie_kategorie_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buch_kategorie
    ADD CONSTRAINT buch_kategorie_kategorie_id_fkey FOREIGN KEY (kategorie_id) REFERENCES public.kategorie(kategorie_id) ON DELETE CASCADE;


--
-- TOC entry 5006 (class 2606 OID 16499)
-- Name: buch buch_standort_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buch
    ADD CONSTRAINT buch_standort_id_fkey FOREIGN KEY (standort_id) REFERENCES public.standort(standort_id);


--
-- TOC entry 5015 (class 2606 OID 16604)
-- Name: kommentar kommentar_benutzer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kommentar
    ADD CONSTRAINT kommentar_benutzer_id_fkey FOREIGN KEY (benutzer_id) REFERENCES public.benutzer(benutzer_id);


--
-- TOC entry 5016 (class 2606 OID 16609)
-- Name: kommentar kommentar_buch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kommentar
    ADD CONSTRAINT kommentar_buch_id_fkey FOREIGN KEY (buch_id) REFERENCES public.buch(buch_id);


--
-- TOC entry 5021 (class 2606 OID 16677)
-- Name: meldung meldung_buch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meldung
    ADD CONSTRAINT meldung_buch_id_fkey FOREIGN KEY (buch_id) REFERENCES public.buch(buch_id);


--
-- TOC entry 5022 (class 2606 OID 16672)
-- Name: meldung meldung_melder_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.meldung
    ADD CONSTRAINT meldung_melder_id_fkey FOREIGN KEY (melder_id) REFERENCES public.benutzer(benutzer_id);


--
-- TOC entry 5019 (class 2606 OID 16648)
-- Name: nachricht nachricht_absender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nachricht
    ADD CONSTRAINT nachricht_absender_id_fkey FOREIGN KEY (absender_id) REFERENCES public.benutzer(benutzer_id);


--
-- TOC entry 5020 (class 2606 OID 16653)
-- Name: nachricht nachricht_empfaenger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nachricht
    ADD CONSTRAINT nachricht_empfaenger_id_fkey FOREIGN KEY (empfaenger_id) REFERENCES public.benutzer(benutzer_id);


--
-- TOC entry 5017 (class 2606 OID 16623)
-- Name: wunschliste wunschliste_benutzer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wunschliste
    ADD CONSTRAINT wunschliste_benutzer_id_fkey FOREIGN KEY (benutzer_id) REFERENCES public.benutzer(benutzer_id) ON DELETE CASCADE;


--
-- TOC entry 5018 (class 2606 OID 16628)
-- Name: wunschliste wunschliste_buch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.wunschliste
    ADD CONSTRAINT wunschliste_buch_id_fkey FOREIGN KEY (buch_id) REFERENCES public.buch(buch_id) ON DELETE CASCADE;


-- Completed on 2026-04-28 17:24:15

--
-- PostgreSQL database dump complete
--

\unrestrict RWz46LDrYVgi64SRxiW3lURCDfnf05oMXJIP9QykwcA1v2XejmIfbchWGgHQR4j

