--
-- PostgreSQL database dump
--

-- Dumped from database version 11.1
-- Dumped by pg_dump version 11.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: t155376; Type: DATABASE; Schema: -; Owner: t155376
--

CREATE DATABASE t155376 WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'et_EE.utf8' LC_CTYPE = 'et_EE.utf8';


ALTER DATABASE t155376 OWNER TO t155376;

\connect t155376

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: postgres_fdw; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS postgres_fdw WITH SCHEMA public;


--
-- Name: EXTENSION postgres_fdw; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgres_fdw IS 'foreign-data wrapper for remote PostgreSQL servers';


--
-- Name: d_reg_aeg; Type: DOMAIN; Schema: public; Owner: t155376
--

CREATE DOMAIN public.d_reg_aeg AS timestamp without time zone NOT NULL DEFAULT LOCALTIMESTAMP(0)
	CONSTRAINT d_check_reg_aeg CHECK (((VALUE >= '2010-01-01 00:00:00'::timestamp without time zone) AND (VALUE <= '2100-12-31 23:59:59'::timestamp without time zone)));


ALTER DOMAIN public.d_reg_aeg OWNER TO t155376;

--
-- Name: f_eemalda_kauba_kategooriast(character varying, character varying); Type: FUNCTION; Schema: public; Owner: t155376
--

CREATE FUNCTION public.f_eemalda_kauba_kategooriast(p_kauba_kood character varying, p_kauba_kategooria_kood character varying) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DELETE FROM kauba_kategooria_omamine WHERE kauba_kood=p_kauba_kood AND kauba_kategooria_kood=p_kauba_kategooria_kood;
$$;


ALTER FUNCTION public.f_eemalda_kauba_kategooriast(p_kauba_kood character varying, p_kauba_kategooria_kood character varying) OWNER TO t155376;

--
-- Name: FUNCTION f_eemalda_kauba_kategooriast(p_kauba_kood character varying, p_kauba_kategooria_kood character varying); Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON FUNCTION public.f_eemalda_kauba_kategooriast(p_kauba_kood character varying, p_kauba_kategooria_kood character varying) IS 'Selle funktsiooni abil eemaldatakse ühendus kauba ja selle kategooria vahelt. See funktsioon realiseerib andmebaasioperatsiooni OP8. Parameetri p_kauba_kood oodatav väärtus on kauba kood, p_kauba_kategooria_kood oodatav väärtus on kauba kategooria kood.';


--
-- Name: f_kustuta_kaup(character varying); Type: FUNCTION; Schema: public; Owner: t155376
--

CREATE FUNCTION public.f_kustuta_kaup(p_kauba_kood character varying) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DELETE FROM Kaup WHERE kauba_kood=p_kauba_kood;
$$;


ALTER FUNCTION public.f_kustuta_kaup(p_kauba_kood character varying) OWNER TO t155376;

--
-- Name: FUNCTION f_kustuta_kaup(p_kauba_kood character varying); Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON FUNCTION public.f_kustuta_kaup(p_kauba_kood character varying) IS 'Selle funktsiooni abile saab kaupa kustutada. See funktsioon realiseerib anemdbaasioperatsiooni OP2. Parameetri p_kauba_kood oodatav väärtus on kustutatava kauba kood.';


--
-- Name: f_lisa_kauba_kategooriasse(character varying, character varying); Type: FUNCTION; Schema: public; Owner: t155376
--

CREATE FUNCTION public.f_lisa_kauba_kategooriasse(p_kauba_kood character varying, p_kauba_kategooria_kood character varying) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
INSERT INTO kauba_kategooria_omamine(kauba_kood, kauba_kategooria_kood)
VALUES (p_kauba_kood, p_kauba_kategooria_kood);
$$;


ALTER FUNCTION public.f_lisa_kauba_kategooriasse(p_kauba_kood character varying, p_kauba_kategooria_kood character varying) OWNER TO t155376;

--
-- Name: FUNCTION f_lisa_kauba_kategooriasse(p_kauba_kood character varying, p_kauba_kategooria_kood character varying); Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON FUNCTION public.f_lisa_kauba_kategooriasse(p_kauba_kood character varying, p_kauba_kategooria_kood character varying) IS 'Selle funktsiooni abil lisatakse ühendus kauba ja selle kategooria vahele. See funktsioon realiseerib andmebaasioperatsiooni OP7. Parameetri p_kauba_kood oodatav väärtus on kauba kood, p_kauba_kategooria_kood oodatav väärtus on kauba kategooria kood.';


--
-- Name: f_lisa_kaup(character varying, character varying, character varying, integer, character varying, character varying, character varying, character varying, numeric); Type: FUNCTION; Schema: public; Owner: t155376
--

CREATE FUNCTION public.f_lisa_kaup(p_kauba_kood character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_registreerija_id integer, p_palli_materjali_kood character varying, p_palli_varvi_kood character varying, p_palli_tyybi_kood character varying, p_palli_suuruse_kood character varying, p_hind numeric) RETURNS character varying
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
INSERT INTO Kaup(kauba_kood, kauba_nimetus, kauba_kirjeldus, registreerija_id,
palli_materjali_kood, palli_varvi_kood, palli_tyybi_kood, palli_suuruse_kood, hind)
VALUES (p_kauba_kood, p_kauba_nimetus, p_kauba_kirjeldus, p_registreerija_id,
p_palli_materjali_kood, p_palli_varvi_kood, p_palli_tyybi_kood, p_palli_suuruse_kood, p_hind)
ON CONFLICT DO NOTHING RETURNING kauba_kood;
$$;


ALTER FUNCTION public.f_lisa_kaup(p_kauba_kood character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_registreerija_id integer, p_palli_materjali_kood character varying, p_palli_varvi_kood character varying, p_palli_tyybi_kood character varying, p_palli_suuruse_kood character varying, p_hind numeric) OWNER TO t155376;

--
-- Name: FUNCTION f_lisa_kaup(p_kauba_kood character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_registreerija_id integer, p_palli_materjali_kood character varying, p_palli_varvi_kood character varying, p_palli_tyybi_kood character varying, p_palli_suuruse_kood character varying, p_hind numeric); Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON FUNCTION public.f_lisa_kaup(p_kauba_kood character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_registreerija_id integer, p_palli_materjali_kood character varying, p_palli_varvi_kood character varying, p_palli_tyybi_kood character varying, p_palli_suuruse_kood character varying, p_hind numeric) IS 'See funktsioon lisab uue kauba andmebaasi süsteemi operatsiooniga OP1';


--
-- Name: f_lopeta_isik(); Type: FUNCTION; Schema: public; Owner: t155376
--

CREATE FUNCTION public.f_lopeta_isik() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
RAISE EXCEPTION 'Ei saa lõpetada isikut, kes on ooteseisundis!';
RETURN NULL;
END;
$$;


ALTER FUNCTION public.f_lopeta_isik() OWNER TO t155376;

--
-- Name: FUNCTION f_lopeta_isik(); Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON FUNCTION public.f_lopeta_isik() IS 'See trigeri funktsioon aitab jõustada ärireegli: Ei saa lõpetada isikut, kes on ooteseisundis';


--
-- Name: f_lopeta_kaup(); Type: FUNCTION; Schema: public; Owner: t155376
--

CREATE FUNCTION public.f_lopeta_kaup() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
RAISE EXCEPTION 'Ei saa lõpetada kaupa, mis on aktiivne! Muuda kõigepealt kaup mitteaktiivseks!';
RETURN NULL;
END;
$$;


ALTER FUNCTION public.f_lopeta_kaup() OWNER TO t155376;

--
-- Name: FUNCTION f_lopeta_kaup(); Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON FUNCTION public.f_lopeta_kaup() IS 'See trigeri funktsioon aitab jõustada ärireegli:
Ei saa lopetada kaupa, mis on ootel või aktiivne';


--
-- Name: f_lopeta_kaup(character varying); Type: FUNCTION; Schema: public; Owner: t155376
--

CREATE FUNCTION public.f_lopeta_kaup(p_kauba_kood character varying) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
UPDATE Kaup SET kauba_seisundi_liigi_kood=4 
WHERE kauba_kood=p_kauba_kood;
$$;


ALTER FUNCTION public.f_lopeta_kaup(p_kauba_kood character varying) OWNER TO t155376;

--
-- Name: FUNCTION f_lopeta_kaup(p_kauba_kood character varying); Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON FUNCTION public.f_lopeta_kaup(p_kauba_kood character varying) IS 'Selle funktsiooni abil lõpetatakse kaup. See funktsioon realiseerib andmebaasioperatsiooni OP5. Parameetri p_kauba_kood oodatav väärtus on lõpetatava kauba kood.';


--
-- Name: f_muuda_kaup(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, numeric); Type: FUNCTION; Schema: public; Owner: t155376
--

CREATE FUNCTION public.f_muuda_kaup(p_kauba_kood_vana character varying, p_kauba_kood_uus character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_palli_materjali_kood character varying, p_palli_varvi_kood character varying, p_palli_tyybi_kood character varying, p_palli_suuruse_kood character varying, p_hind numeric) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
UPDATE Kaup SET kauba_kood=p_kauba_kood_uus,
kauba_nimetus=p_kauba_nimetus, hind=p_hind, kauba_kirjeldus=p_kauba_kirjeldus,
palli_materjali_kood=p_palli_materjali_kood, palli_varvi_kood=p_palli_varvi_kood,
palli_tyybi_kood=p_palli_tyybi_kood, palli_suuruse_kood=p_palli_suuruse_kood
WHERE kauba_kood=p_kauba_kood_vana;
$$;


ALTER FUNCTION public.f_muuda_kaup(p_kauba_kood_vana character varying, p_kauba_kood_uus character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_palli_materjali_kood character varying, p_palli_varvi_kood character varying, p_palli_tyybi_kood character varying, p_palli_suuruse_kood character varying, p_hind numeric) OWNER TO t155376;

--
-- Name: FUNCTION f_muuda_kaup(p_kauba_kood_vana character varying, p_kauba_kood_uus character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_palli_materjali_kood character varying, p_palli_varvi_kood character varying, p_palli_tyybi_kood character varying, p_palli_suuruse_kood character varying, p_hind numeric); Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON FUNCTION public.f_muuda_kaup(p_kauba_kood_vana character varying, p_kauba_kood_uus character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_palli_materjali_kood character varying, p_palli_varvi_kood character varying, p_palli_tyybi_kood character varying, p_palli_suuruse_kood character varying, p_hind numeric) IS 'See funktsioon muudab kauba andmeid andmebaasis operatsiooniga OP6';


--
-- Name: f_muuda_kaup_aktiivseks(character varying); Type: FUNCTION; Schema: public; Owner: t155376
--

CREATE FUNCTION public.f_muuda_kaup_aktiivseks(p_kauba_kood character varying) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
UPDATE Kaup SET kauba_seisundi_liigi_kood=2
WHERE kauba_kood=p_kauba_kood;
$$;


ALTER FUNCTION public.f_muuda_kaup_aktiivseks(p_kauba_kood character varying) OWNER TO t155376;

--
-- Name: FUNCTION f_muuda_kaup_aktiivseks(p_kauba_kood character varying); Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON FUNCTION public.f_muuda_kaup_aktiivseks(p_kauba_kood character varying) IS 'See funktsioon muudab antud kauba seisundi aktiivseks operatsiooniga OP3';


--
-- Name: f_muuda_kaup_mitteaktiivseks(character varying); Type: FUNCTION; Schema: public; Owner: t155376
--

CREATE FUNCTION public.f_muuda_kaup_mitteaktiivseks(p_kauba_kood character varying) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
UPDATE Kaup SET kauba_seisundi_liigi_kood=3 WHERE kauba_kood=p_kauba_kood;
$$;


ALTER FUNCTION public.f_muuda_kaup_mitteaktiivseks(p_kauba_kood character varying) OWNER TO t155376;

--
-- Name: FUNCTION f_muuda_kaup_mitteaktiivseks(p_kauba_kood character varying); Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON FUNCTION public.f_muuda_kaup_mitteaktiivseks(p_kauba_kood character varying) IS 'See funktsioon muudab antud kauba seisundi mitteaktiivseks operatsiooniga OP4';


--
-- Name: f_registreeri_kaup(character varying, character varying, character varying, numeric, integer, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: t155376
--

CREATE FUNCTION public.f_registreeri_kaup(p_kauba_kood character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_hind numeric, p_tootaja_id integer, p_varvi_kood character varying, p_tyybi_kood character varying, p_suuruse_kood character varying, p_materjali_kood character varying) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$ INSERT INTO Kaup(kauba_kood, kauba_nimetus, kauba_kirjeldus, hind, registreerija_id, palli_varvi_kood, palli_tyybi_koOd, palli_suuruse_kood, palli_materjali_kood) VALUES (p_kauba_kood, p_kauba_nimetus, p_kauba_kirjeldus, p_hind, p_tootaja_id, p_varvi_kood, p_tyybi_kood, p_suuruse_kood, p_materjali_kood); $$;


ALTER FUNCTION public.f_registreeri_kaup(p_kauba_kood character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_hind numeric, p_tootaja_id integer, p_varvi_kood character varying, p_tyybi_kood character varying, p_suuruse_kood character varying, p_materjali_kood character varying) OWNER TO t155376;

--
-- Name: f_uuenda_kauba_andmeid(character varying, character varying, character varying, character varying, numeric, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: t155376
--

CREATE FUNCTION public.f_uuenda_kauba_andmeid(p_kauba_kood_vana character varying, p_kauba_kood_uus character varying, p_nimetus character varying, p_kirjeldus character varying, p_hind numeric, p_varvi_kood character varying, p_tyybi_kood character varying, p_suuruse_kood character varying, p_materjali_kood character varying) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
UPDATE Kaup SET kauba_kood=p_kauba_kood_uus, kauba_nimetus=p_nimetus, kauba_kirjeldus=p_kirjeldus, hind=p_hind, palli_varvi_kood=p_varvi_kood, palli_tyybi_kood=p_tyybi_kood, palli_suuruse_kood=p_suuruse_kood, palli_materjali_kood=p_materjali_kood
WHERE kauba_kood=p_kauba_kood_vana;
$$;


ALTER FUNCTION public.f_uuenda_kauba_andmeid(p_kauba_kood_vana character varying, p_kauba_kood_uus character varying, p_nimetus character varying, p_kirjeldus character varying, p_hind numeric, p_varvi_kood character varying, p_tyybi_kood character varying, p_suuruse_kood character varying, p_materjali_kood character varying) OWNER TO t155376;

--
-- Name: FUNCTION f_uuenda_kauba_andmeid(p_kauba_kood_vana character varying, p_kauba_kood_uus character varying, p_nimetus character varying, p_kirjeldus character varying, p_hind numeric, p_varvi_kood character varying, p_tyybi_kood character varying, p_suuruse_kood character varying, p_materjali_kood character varying); Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON FUNCTION public.f_uuenda_kauba_andmeid(p_kauba_kood_vana character varying, p_kauba_kood_uus character varying, p_nimetus character varying, p_kirjeldus character varying, p_hind numeric, p_varvi_kood character varying, p_tyybi_kood character varying, p_suuruse_kood character varying, p_materjali_kood character varying) IS 'Selle funktsiooni abil muudetakse vana kauba andmeid. See funktsioon realiseerib andmebaasioperatsiooni OP6. Parameetri p_kauba_kood_vana oodatav väärtus on muudetava kauba kood, p_kauba_kood_uus oodatav väärtus on kauba uus kood, p_kauba_nimetus oodatav väärtus on kaupa kirjeldav lühisõnaline pealkiri, p_kauba_kirjeldus oodatav väärtus on kauba detaile kirlejdus, p_hind oodatav väärtus on muudetava toote hind, p_palli_materjali_kood oodatav väärtus on muudetava toote materjali kood, p_palli_varvi oodatav väärtus on muudetava toote värvi kood, p_palli_tyybi_kood oodatav väärtus on muudetava toote tüübi kood, p_palli_suuruse_kood oodatav väärtus on muudetava toote suuruse kood.';


--
-- Name: t155376_testandmed_apex; Type: SERVER; Schema: -; Owner: t155376
--

CREATE SERVER t155376_testandmed_apex FOREIGN DATA WRAPPER postgres_fdw OPTIONS (
    dbname 'testandmed',
    host 'apex.ttu.ee',
    port '5432'
);


ALTER SERVER t155376_testandmed_apex OWNER TO t155376;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: kauba_seisundi_liik; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.kauba_seisundi_liik (
    kauba_seisundi_liigi_kood character varying(12) NOT NULL,
    kauba_seisundi_liigi_nimetus character varying(255) NOT NULL,
    CONSTRAINT check_kauba_seisundi_liik_kauba_seisundi_liigi_kood_mts CHECK (((kauba_seisundi_liigi_kood)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_kauba_seisundi_liik_kauba_seisundi_liigi_nimetus_mts CHECK (((kauba_seisundi_liigi_nimetus)::text !~ '^[[:space:]]*$'::text))
);


ALTER TABLE public.kauba_seisundi_liik OWNER TO t155376;

--
-- Name: kauba_tyyp; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.kauba_tyyp (
    palli_tyybi_kood character varying(12) NOT NULL,
    tyybi_nimetus character varying(255) NOT NULL,
    CONSTRAINT check_kauba_tyyp_palli_tyybi_kood_mts CHECK (((palli_tyybi_kood)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_kauba_tyyp_tyybi_nimetus_mts CHECK (((tyybi_nimetus)::text !~ '^[[:space:]]*$'::text))
);


ALTER TABLE public.kauba_tyyp OWNER TO t155376;

--
-- Name: kaup; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.kaup (
    kauba_kood character varying(12) NOT NULL,
    kauba_nimetus character varying(50) NOT NULL,
    kauba_kirjeldus character varying(1000) NOT NULL,
    hind numeric(6,2) NOT NULL,
    kauba_kategooria_kood character varying(12) NOT NULL,
    kauba_seisundi_liigi_kood character varying(12) DEFAULT 'o'::character varying NOT NULL,
    registreerija_id integer NOT NULL,
    kauba_reg_aeg public.d_reg_aeg,
    palli_materjali_kood character varying(12) NOT NULL,
    palli_varvi_kood character varying(12) NOT NULL,
    palli_tyybi_kood character varying(12) NOT NULL,
    palli_suuruse_kood character varying(12) NOT NULL,
    CONSTRAINT check_kaup_hind_nullist_suurem CHECK ((hind > (0)::numeric)),
    CONSTRAINT check_kaup_kauba_kirjeldus_mts CHECK (((kauba_kirjeldus)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_kaup_kauba_kood_mts CHECK (((kauba_kood)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_kaup_kauba_nimetus_mts CHECK (((kauba_nimetus)::text !~ '^[[:space:]]*$'::text))
)
WITH (fillfactor='50');


ALTER TABLE public.kaup OWNER TO t155376;

--
-- Name: aktiivsed_mitteaktivsed_kaubad; Type: VIEW; Schema: public; Owner: t155376
--

CREATE VIEW public.aktiivsed_mitteaktivsed_kaubad WITH (security_barrier='true') AS
 SELECT kaup.kauba_kood,
    kaup.kauba_nimetus,
    kauba_tyyp.tyybi_nimetus AS kauba_tyyp,
    kauba_seisundi_liik.kauba_seisundi_liigi_nimetus AS seisund,
    kaup.hind
   FROM (public.kauba_seisundi_liik
     JOIN (public.kaup
     JOIN public.kauba_tyyp ON (((kauba_tyyp.palli_tyybi_kood)::text = (kaup.palli_tyybi_kood)::text))) ON (((kauba_seisundi_liik.kauba_seisundi_liigi_kood)::text = (kaup.kauba_seisundi_liigi_kood)::text)))
  WHERE ((kauba_seisundi_liik.kauba_seisundi_liigi_nimetus)::text = ANY (ARRAY[('aktiivne'::character varying)::text, ('mitteaktiivne'::character varying)::text]));


ALTER TABLE public.aktiivsed_mitteaktivsed_kaubad OWNER TO t155376;

--
-- Name: VIEW aktiivsed_mitteaktivsed_kaubad; Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON VIEW public.aktiivsed_mitteaktivsed_kaubad IS 'See vaade leiab kõik kaubad, mis on märgitud seisundiga aktiivne või mitteaktiivne';


--
-- Name: amet; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.amet (
    ameti_kood character varying(12) NOT NULL,
    ameti_nimetus character varying(80) NOT NULL,
    ameti_kirjeldus text,
    CONSTRAINT check_amet_ameti_kirjeldus_mts CHECK ((ameti_kirjeldus !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_amet_ameti_kood_mts CHECK (((ameti_kood)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_amet_ameti_nimetus_mts CHECK (((ameti_nimetus)::text !~ '^[[:space:]]*$'::text))
)
WITH (fillfactor='50');


ALTER TABLE public.amet OWNER TO t155376;

--
-- Name: isik; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.isik (
    isiku_id integer NOT NULL,
    isiku_seisundi_liigi_kood character varying(12) DEFAULT 'o'::character varying NOT NULL,
    riigi_kood character varying(3) NOT NULL,
    isikukood character varying(50) NOT NULL,
    eesnimi character varying(1200) NOT NULL,
    parool character varying(60) NOT NULL,
    e_mail character varying(254) NOT NULL,
    synni_kp date NOT NULL,
    perenimi character varying(1200),
    elukoht character varying(1000),
    reg_aeg public.d_reg_aeg,
    CONSTRAINT check_isik_e_mail_on_korrektselt_vormistatud CHECK (((e_mail)::text ~ '^(.*@.*[.].*)$'::text)),
    CONSTRAINT check_isik_eesnimi_mts CHECK (((eesnimi)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_isik_elukoht_ei_sisalda_ainult_numbreid CHECK (((elukoht)::text !~ '^([[:digit:]])*$'::text)),
    CONSTRAINT check_isik_elukoht_mts CHECK (((elukoht)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_isik_isikukood_eesti CHECK (((NOT ((riigi_kood)::text = 'EST'::text)) OR ((isikukood)::text ~ '^([3-6]{1}[[:digit:]]{2}[0-1]{1}[[:digit:]]{1}[0-3]{1}[[:digit:]]{5})$'::text))),
    CONSTRAINT check_isik_isikukood_mts CHECK (((isikukood)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_isik_parool_mts CHECK (((parool)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_isik_perenimi_mts CHECK (((perenimi)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_isik_reg_aeg CHECK (((reg_aeg)::date >= synni_kp)),
    CONSTRAINT check_isik_synni_kp_vahemikus_1900_ja_2100 CHECK (((synni_kp >= '1900-01-01'::date) AND (synni_kp <= '2100-12-31'::date)))
)
WITH (fillfactor='50');


ALTER TABLE public.isik OWNER TO t155376;

--
-- Name: isik_isik_id_seq; Type: SEQUENCE; Schema: public; Owner: t155376
--

CREATE SEQUENCE public.isik_isik_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.isik_isik_id_seq OWNER TO t155376;

--
-- Name: isik_isik_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: t155376
--

ALTER SEQUENCE public.isik_isik_id_seq OWNED BY public.isik.isiku_id;


--
-- Name: isiku_seisundi_liik; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.isiku_seisundi_liik (
    isiku_seisundi_liigi_kood character varying(12) NOT NULL,
    isiku_seisundi_liigi_nimetus character varying(80) NOT NULL,
    CONSTRAINT check_isiku_seisundi_liik_isiku_seisundi_liigi_kood_mts CHECK (((isiku_seisundi_liigi_kood)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_isiku_seisundi_liik_isiku_seisundi_liigi_nimetus_mts CHECK (((isiku_seisundi_liigi_nimetus)::text !~ '^[[:space:]]*$'::text))
);


ALTER TABLE public.isiku_seisundi_liik OWNER TO t155376;

--
-- Name: kauba_kategooria; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.kauba_kategooria (
    kauba_kategooria_kood character varying(12) NOT NULL,
    kauba_kategooria_nimetus character varying(80) NOT NULL,
    kauba_kategooria_tyybi_kood character varying(12) NOT NULL,
    CONSTRAINT check_kauba_kategooria_kauba_kategooria_kood_mts CHECK (((kauba_kategooria_kood)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_kauba_kategooria_kauba_kategooria_nimetus_mts CHECK (((kauba_kategooria_nimetus)::text !~ '^[[:space:]]*$'::text))
);


ALTER TABLE public.kauba_kategooria OWNER TO t155376;

--
-- Name: kauba_kategooria_omamine; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.kauba_kategooria_omamine (
    kauba_kood character varying(12) NOT NULL,
    kauba_kategooria_kood character varying(12) NOT NULL,
    CONSTRAINT check_kauba_kategooria_omamine_kauba_kategooria_kood_mts CHECK (((kauba_kategooria_kood)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_kauba_kategooria_omamine_kauba_kood_mts CHECK (((kauba_kood)::text !~ '^[[:space:]]*$'::text))
);


ALTER TABLE public.kauba_kategooria_omamine OWNER TO t155376;

--
-- Name: kauba_kategooria_tyyp; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.kauba_kategooria_tyyp (
    kauba_kategooria_tyybi_kood character varying(12) NOT NULL,
    kategooria_tyybi_nimetus character varying(80) NOT NULL,
    CONSTRAINT check_kauba_kategooria_tyyp_kategooria_tyybi_nimetus_mts CHECK (((kategooria_tyybi_nimetus)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_kauba_kategooria_tyyp_kauba_kategooria_tyybi_kood_mts CHECK (((kauba_kategooria_tyybi_kood)::text !~ '^[[:space:]]*$'::text))
);


ALTER TABLE public.kauba_kategooria_tyyp OWNER TO t155376;

--
-- Name: kaubad; Type: VIEW; Schema: public; Owner: t155376
--

CREATE VIEW public.kaubad WITH (security_barrier='true') AS
 SELECT kaup.kauba_kood,
    kaup.kauba_nimetus,
    kauba_tyyp.tyybi_nimetus AS kauba_tyyp,
    kauba_seisundi_liik.kauba_seisundi_liigi_nimetus AS seisund,
    kaup.hind
   FROM (public.kauba_seisundi_liik
     JOIN (public.kaup
     JOIN public.kauba_tyyp ON (((kauba_tyyp.palli_tyybi_kood)::text = (kaup.palli_tyybi_kood)::text))) ON (((kauba_seisundi_liik.kauba_seisundi_liigi_kood)::text = (kaup.kauba_seisundi_liigi_kood)::text)));


ALTER TABLE public.kaubad OWNER TO t155376;

--
-- Name: VIEW kaubad; Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON VIEW public.kaubad IS 'See vaade leiad andmed kõigi kaupade kõige tähtsamate veergude kohta';


--
-- Name: materjal; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.materjal (
    palli_materjali_kood character varying(12) NOT NULL,
    materjali_nimetus character varying(255) NOT NULL,
    CONSTRAINT check_materjal_materjali_nimetus_mts CHECK (((materjali_nimetus)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_materjal_palli_materjali_kood_mts CHECK (((palli_materjali_kood)::text !~ '^[[:space:]]*$'::text))
);


ALTER TABLE public.materjal OWNER TO t155376;

--
-- Name: suurus; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.suurus (
    palli_suuruse_kood character varying(12) NOT NULL,
    suuruse_nimetus character varying(255) NOT NULL,
    CONSTRAINT check_suurus_palli_suuruse_kood_mts CHECK (((palli_suuruse_kood)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_suurus_suuruse_nimetus_mts CHECK (((suuruse_nimetus)::text !~ '^[[:space:]]*$'::text))
);


ALTER TABLE public.suurus OWNER TO t155376;

--
-- Name: varv; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.varv (
    palli_varvi_kood character varying(12) NOT NULL,
    varvi_nimetus character varying(255) NOT NULL,
    CONSTRAINT check_varv_palli_varvi_kood_mts CHECK (((palli_varvi_kood)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_varv_varvi_nimetus_mts CHECK (((varvi_nimetus)::text !~ '^[[:space:]]*$'::text))
);


ALTER TABLE public.varv OWNER TO t155376;

--
-- Name: kaubad_detailselt; Type: VIEW; Schema: public; Owner: t155376
--

CREATE VIEW public.kaubad_detailselt WITH (security_barrier='true') AS
 SELECT kaup.kauba_kood,
    kaup.kauba_nimetus,
    kaup.kauba_reg_aeg AS registreerimisaeg,
    concat_ws(' '::text, isik.eesnimi, isik.perenimi, isik.e_mail) AS registreerija,
    kaup.hind,
    kaup.kauba_kirjeldus AS kirjeldus,
    varv.varvi_nimetus AS varv,
    kauba_tyyp.tyybi_nimetus AS kauba_tyyp,
    suurus.suuruse_nimetus AS suurus,
    materjal.materjali_nimetus AS materjal
   FROM (public.isik
     JOIN (public.varv
     JOIN (public.kauba_tyyp
     JOIN (public.suurus
     JOIN (public.materjal
     JOIN public.kaup ON (((materjal.palli_materjali_kood)::text = (kaup.palli_materjali_kood)::text))) ON (((suurus.palli_suuruse_kood)::text = (kaup.palli_suuruse_kood)::text))) ON (((kauba_tyyp.palli_tyybi_kood)::text = (kaup.palli_tyybi_kood)::text))) ON (((varv.palli_varvi_kood)::text = (kaup.palli_varvi_kood)::text))) ON ((isik.isiku_id = kaup.registreerija_id)));


ALTER TABLE public.kaubad_detailselt OWNER TO t155376;

--
-- Name: VIEW kaubad_detailselt; Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON VIEW public.kaubad_detailselt IS 'See vaade leiad andmed kõigi kaupade andmete kohta, mis võivad kliendile tähtsad olla';


--
-- Name: kaupade_koondaruanne; Type: VIEW; Schema: public; Owner: t155376
--

CREATE VIEW public.kaupade_koondaruanne WITH (security_barrier='true') AS
 SELECT kauba_seisundi_liik.kauba_seisundi_liigi_kood AS seisundi_kood,
    upper((kauba_seisundi_liik.kauba_seisundi_liigi_nimetus)::text) AS seisundi_nimetus,
    count(kaup.kauba_kood) AS arv
   FROM (public.kauba_seisundi_liik
     LEFT JOIN public.kaup ON (((kauba_seisundi_liik.kauba_seisundi_liigi_kood)::text = (kaup.kauba_seisundi_liigi_kood)::text)))
  GROUP BY kauba_seisundi_liik.kauba_seisundi_liigi_kood, (upper((kauba_seisundi_liik.kauba_seisundi_liigi_nimetus)::text))
  ORDER BY (count(kaup.kauba_kood)) DESC, (upper((kauba_seisundi_liik.kauba_seisundi_liigi_nimetus)::text));


ALTER TABLE public.kaupade_koondaruanne OWNER TO t155376;

--
-- Name: VIEW kaupade_koondaruanne; Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON VIEW public.kaupade_koondaruanne IS 'See vaade leiab andmed kaupade seisundite kohta, mis on koondatud, et näha, kui palju on erinevaid kaupu mingis seisundis.';


--
-- Name: kliendi_seisundi_liik; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.kliendi_seisundi_liik (
    kliendi_seisundi_liigi_kood character varying(12) NOT NULL,
    kliendi_seisundi_liigi_nimetus character varying(80) NOT NULL,
    CONSTRAINT check_kliendi_seisundi_liik_kliendi_seisundi_liigi_kood_mts CHECK (((kliendi_seisundi_liigi_kood)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_kliendi_seisundi_liik_kliendi_seisundi_liigi_nimetus_mts CHECK (((kliendi_seisundi_liigi_nimetus)::text !~ '^[[:space:]]*$'::text))
);


ALTER TABLE public.kliendi_seisundi_liik OWNER TO t155376;

--
-- Name: klient; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.klient (
    isiku_id integer NOT NULL,
    kliendi_seisundi_liigi_kood character varying(12) DEFAULT 'o'::character varying NOT NULL,
    on_nous_tylitamisega boolean DEFAULT false NOT NULL
)
WITH (fillfactor='50');


ALTER TABLE public.klient OWNER TO t155376;

--
-- Name: mv_aktiivsed_mitteaktiivsed_kaubad; Type: MATERIALIZED VIEW; Schema: public; Owner: t155376
--

CREATE MATERIALIZED VIEW public.mv_aktiivsed_mitteaktiivsed_kaubad AS
 SELECT kaup.kauba_kood,
    kaup.kauba_nimetus,
    kauba_tyyp.tyybi_nimetus AS kauba_tyyp,
    kauba_seisundi_liik.kauba_seisundi_liigi_nimetus AS seisund,
    kaup.hind
   FROM (public.kauba_seisundi_liik
     JOIN (public.kaup
     JOIN public.kauba_tyyp ON (((kauba_tyyp.palli_tyybi_kood)::text = (kaup.palli_tyybi_kood)::text))) ON (((kauba_seisundi_liik.kauba_seisundi_liigi_kood)::text = (kaup.kauba_seisundi_liigi_kood)::text)))
  WHERE ((kauba_seisundi_liik.kauba_seisundi_liigi_nimetus)::text = ANY (ARRAY[('aktiivne'::character varying)::text, ('mitteaktiivne'::character varying)::text]))
  WITH NO DATA;


ALTER TABLE public.mv_aktiivsed_mitteaktiivsed_kaubad OWNER TO t155376;

--
-- Name: MATERIALIZED VIEW mv_aktiivsed_mitteaktiivsed_kaubad; Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON MATERIALIZED VIEW public.mv_aktiivsed_mitteaktiivsed_kaubad IS 'See vaade leiab kõik kaubad, mis on märgitud seisundiga aktiivne või mitteaktiivne';


--
-- Name: mv_kaubad; Type: MATERIALIZED VIEW; Schema: public; Owner: t155376
--

CREATE MATERIALIZED VIEW public.mv_kaubad AS
 SELECT kaup.kauba_kood,
    kaup.kauba_nimetus AS kaubanimetus,
    kauba_tyyp.tyybi_nimetus AS kauba_tyyp,
    kauba_seisundi_liik.kauba_seisundi_liigi_nimetus AS seisund,
    kaup.hind
   FROM (public.kauba_seisundi_liik
     JOIN (public.kaup
     JOIN public.kauba_tyyp ON (((kauba_tyyp.palli_tyybi_kood)::text = (kaup.palli_tyybi_kood)::text))) ON (((kauba_seisundi_liik.kauba_seisundi_liigi_kood)::text = (kaup.kauba_seisundi_liigi_kood)::text)))
  WITH NO DATA;


ALTER TABLE public.mv_kaubad OWNER TO t155376;

--
-- Name: MATERIALIZED VIEW mv_kaubad; Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON MATERIALIZED VIEW public.mv_kaubad IS 'See vaade leiad andmed kõigi kaupade kõige tähtsamate veergude kohta';


--
-- Name: mv_kaubad_detailselt; Type: MATERIALIZED VIEW; Schema: public; Owner: t155376
--

CREATE MATERIALIZED VIEW public.mv_kaubad_detailselt AS
 SELECT kaup.kauba_kood,
    kaup.kauba_nimetus,
    kaup.kauba_reg_aeg AS registreerimisaeg,
    concat_ws(' '::text, isik.eesnimi, isik.perenimi, isik.e_mail) AS registreerija,
    kaup.hind,
    kaup.kauba_kirjeldus AS kirjeldus,
    varv.varvi_nimetus AS varv,
    kauba_tyyp.tyybi_nimetus AS kauba_tyyp,
    suurus.suuruse_nimetus AS suurus,
    materjal.materjali_nimetus AS materjal
   FROM (public.isik
     JOIN (public.varv
     JOIN (public.kauba_tyyp
     JOIN (public.suurus
     JOIN (public.materjal
     JOIN public.kaup ON (((materjal.palli_materjali_kood)::text = (kaup.palli_materjali_kood)::text))) ON (((suurus.palli_suuruse_kood)::text = (kaup.palli_suuruse_kood)::text))) ON (((kauba_tyyp.palli_tyybi_kood)::text = (kaup.palli_tyybi_kood)::text))) ON (((varv.palli_varvi_kood)::text = (kaup.palli_varvi_kood)::text))) ON ((isik.isiku_id = kaup.registreerija_id)))
  WITH NO DATA;


ALTER TABLE public.mv_kaubad_detailselt OWNER TO t155376;

--
-- Name: MATERIALIZED VIEW mv_kaubad_detailselt; Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON MATERIALIZED VIEW public.mv_kaubad_detailselt IS 'See vaade leiad andmed kõigi kaupade andmete kohta, mis võivad kliendile tähtsad olla';


--
-- Name: mv_kaupade_koondaruanne; Type: MATERIALIZED VIEW; Schema: public; Owner: t155376
--

CREATE MATERIALIZED VIEW public.mv_kaupade_koondaruanne AS
 SELECT kauba_seisundi_liik.kauba_seisundi_liigi_kood AS seisundi_kood,
    upper((kauba_seisundi_liik.kauba_seisundi_liigi_nimetus)::text) AS seisundi_nimetus,
    count(kaup.kauba_kood) AS arv
   FROM (public.kauba_seisundi_liik
     LEFT JOIN public.kaup ON (((kauba_seisundi_liik.kauba_seisundi_liigi_kood)::text = (kaup.kauba_seisundi_liigi_kood)::text)))
  GROUP BY kauba_seisundi_liik.kauba_seisundi_liigi_kood, (upper((kauba_seisundi_liik.kauba_seisundi_liigi_nimetus)::text))
  ORDER BY (count(kaup.kauba_kood)) DESC, (upper((kauba_seisundi_liik.kauba_seisundi_liigi_nimetus)::text))
  WITH NO DATA;


ALTER TABLE public.mv_kaupade_koondaruanne OWNER TO t155376;

--
-- Name: MATERIALIZED VIEW mv_kaupade_koondaruanne; Type: COMMENT; Schema: public; Owner: t155376
--

COMMENT ON MATERIALIZED VIEW public.mv_kaupade_koondaruanne IS 'See vaade leiab andmed kaupade seisundite kohta, mis on koondatud, et näha, kui palju on erinevaid kaupu mingis seisundis.';


--
-- Name: riik; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.riik (
    riigi_kood character varying(3) NOT NULL,
    riigi_nimetus character varying(60) NOT NULL,
    CONSTRAINT check_riik_riigi_kood_koosneb_kolmest_tahest CHECK (((riigi_kood)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT check_riik_riigi_nimetus_mts CHECK (((riigi_nimetus)::text !~ '^[[:space:]]*$'::text))
);


ALTER TABLE public.riik OWNER TO t155376;

--
-- Name: tootaja; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.tootaja (
    isiku_id integer NOT NULL,
    seisundi_liigi_kood character varying(12) DEFAULT 'o'::character varying NOT NULL,
    ameti_kood character varying(12) NOT NULL,
    CONSTRAINT check_tootaja_seisundi_liigi_kood_mts CHECK (((seisundi_liigi_kood)::text !~ '^[[:space:]]*$'::text))
)
WITH (fillfactor='50');


ALTER TABLE public.tootaja OWNER TO t155376;

--
-- Name: tootaja_seisundi_liik; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.tootaja_seisundi_liik (
    tootaja_seisund_liigi_kood character varying(12) NOT NULL,
    tootaja_seisundi_nimetus character varying(60) NOT NULL,
    CONSTRAINT check_tootaja_seisundi_liik_tootaja_seisund_liigi_kood_mts CHECK (((tootaja_seisund_liigi_kood)::text !~ '^[[:space:]]*$'::text)),
    CONSTRAINT check_tootaja_seisundi_liik_tootaja_seisundi_nimetus_mts CHECK (((tootaja_seisundi_nimetus)::text !~ '^[[:space:]]*$'::text))
);


ALTER TABLE public.tootaja_seisundi_liik OWNER TO t155376;

--
-- Name: unsuspected_secret; Type: FOREIGN TABLE; Schema: public; Owner: t155376
--

CREATE FOREIGN TABLE public.unsuspected_secret (
    test_value character(5)
)
SERVER t155376_testandmed_apex;


ALTER FOREIGN TABLE public.unsuspected_secret OWNER TO t155376;

--
-- Name: varv_kaup; Type: TABLE; Schema: public; Owner: t155376
--

CREATE TABLE public.varv_kaup (
    palli_varvi_kood character varying(12) NOT NULL,
    kauba_kood character varying(12) NOT NULL,
    CONSTRAINT check_varv_kaup_kauba_kood_mts CHECK (((kauba_kood)::text !~ '^[[:space:]]*$'::text))
);


ALTER TABLE public.varv_kaup OWNER TO t155376;

--
-- Name: isik isiku_id; Type: DEFAULT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.isik ALTER COLUMN isiku_id SET DEFAULT nextval('public.isik_isik_id_seq'::regclass);


--
-- Data for Name: amet; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.amet (ameti_kood, ameti_nimetus, ameti_kirjeldus) FROM stdin;
2	Admin	Süsteemi administraator
1	Klienditeenindaja	Teenindab kliente
\.


--
-- Data for Name: isik; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.isik (isiku_id, isiku_seisundi_liigi_kood, riigi_kood, isikukood, eesnimi, parool, e_mail, synni_kp, perenimi, elukoht, reg_aeg) FROM stdin;
40	l	CAN	90467859363205270000	Karin	$2a$11$8Cqvx2M1uhKMSpit5TgArOa.2SuhVC3OFuAirhdN.RiYuS9RDSxf2	karin.wynn@qualitern.tv	1995-05-05	Wynn	502 Lamont Court, Highland, Nebraska, 9391	2018-01-21 19:35:45
29	o	USA	47066086861941710000	Penny	$2a$11$X7T905VwH5H1hAlgk1WHw.sY/Z8s/tFs3AQ0Rrml9y9PRnNGFa8Oq	penny.williams@deviltoe.me	1988-02-06	Williams	696 Fair Street, Dennard, Colorado, 2702	2018-01-21 19:35:45
33	o	USA	32584045717715034000	Sybil	$2a$11$NeKvk6TL.mBvy7e3G.GCmusvDoQr7B2lv9ozgh6lnXeWl8beMtrXO	sybil.castaneda@jamnation.tv	1993-03-02	Castaneda	305 Rutherford Place, Dawn, Rhode Island, 6080	2018-01-21 19:35:45
34	o	CAN	55305706714092765000	Humphrey	$2a$11$649f2KjrJUT7xzM9OLULzu0EhS1IKvxHhsea1DLuTQhHgiCvzIiEm	humphrey.villarreal@organica.co.uk	1986-05-19	Villarreal	621 Seagate Terrace, Bayview, Wyoming, 823	2018-01-21 19:35:45
36	o	CAN	26907995024554610000	Flynn	$2a$11$.HvLSkP04upU9rTndzoetuMP5YIrPkKnuntgLxQ/ypUMte0TC/on6	flynn.combs@neteria.io	1983-04-15	Combs	977 Coles Street, Gilgo, Pennsylvania, 7787	2018-01-21 19:35:45
38	o	CAN	53575005875886270000	Warner	$2a$11$9ZHkdn4cRnc.4E7ynMju4.J5KKzuS5.Pe75zxF.BigMhTXmk2pX92	warner.hull@automon.ca	1998-07-08	Hull	434 Seeley Street, Hollins, Maryland, 1653	2018-01-21 19:35:45
37	o	CAN	66366267417195620000	Fox	$2a$11$nlVGbmkEybIfXhp7dobhJuPhrXQB6VfXEZb3HAWM9ELVmnZu.zGru	fox.aguirre@farmex.org	1951-08-03	Aguirre	829 Applegate Court, Goochland, Guam, 8320	2018-01-21 18:29:28
27	o	USA	70038558336176980000	Louella	$2a$11$I3.UEKIhJ8HR7ic1J9ua1.uKF9eLW/8LBjzuRqjZMiLsIU39TQ20a	louella.henson@colaire.com	1966-08-15	Henson	578 Wyckoff Street, Starks, District Of Columbia, 7644	2018-02-21 19:36:42
35	a	CAN	48655957920023260000	Sheena	$2a$11$rcycGlAtz8YRbQeSkTn/kePSZNfQDpwPBhnV4tES/LxUJ2jTjWoty	sheena.whitney@comveyor.tv	1991-07-27	Whitney	669 Dean Street, Albrightsville, Nevada, 4912	2018-01-21 19:35:45
42	a	RUS	3472842348192986421	Petryakovf	$2a$11$2m.mA9qiYCnsETigJFq8geRi7nvZ.4Xd4R.xGdJlxE9nC1Pmruyx6	minu.mees@ruulib.ok	1994-03-29	\N	293 Stukovski Street, Russia	2018-01-21 19:35:45
41	a	CAN	60923665020797200000	Carmella	$2a$11$yHfDdp7GBx4JitleAlNFdugoRSjbtj4AAQMudBqPbmyt1hgNPi3Pa	carmella.russo@geekosis.io	1998-09-17	Russo	902 Orange Street, Greensburg, District Of Columbia, 5540	2018-01-21 19:35:45
26	a	USA	15341433215970306000	Lucile	$2a$11$J1joV0HT7PxGxgkbRxhAQekzpXGx2zem/XJrDlt9zPFXd0/q3EtTe	lucile.burgess@frolix.net	1977-08-11	Burgess	470 Lincoln Place, Bethpage, Oregon, 5017	2018-01-21 19:35:45
25	a	USA	27515832667968168000	Ward	$2a$11$/axvc.z0LjeLjRAWF.XNXegEzWrdMfQgfp1/U2izKrBInGp19k3tC	ward.richard@comvoy.co.uk	1989-04-28	Richard	207 Doughty Street, Staples, Indiana, 9524	2018-01-21 19:35:45
28	a	USA	80634337199925790000	Joy	$2a$11$EbpYZgB8iYchfgXI0XVTxeG9eUc1kzuZJWavDIU1afaSXSl4BbY8e	joy.hawkins@geekosis.name	1997-10-23	Hawkins	328 Lacon Court, Sehili, Florida, 4913	2018-01-21 19:35:45
30	a	USA	44858842069209300000	Cole	$2a$11$RUV8aaQZ.YSYzjgcsxbkWOZKwDupHNK3JrVRj..MDwGGSyfDo4JOm	cole.nichols@ezent.biz	1980-09-27	Nichols	180 Branton Street, Orick, Mississippi, 1966	2018-01-21 19:35:45
31	a	USA	5187095594760457000	Love	$2a$11$8FYJoBJ/Flaq2bFy9I1fg.t.LpVxLqUNPqb76Yq0Ud3m3vn910sD6	love.curry@zentility.org	1993-02-10	Curry	138 Shale Street, Groveville, Hawaii, 2806	2018-01-21 19:35:45
32	a	USA	14486824729649263000	Maritza	$2a$11$.b8hgSm0dA.PH6Ms9sbv2.TLmL59GDyuOBRX4Rf0IZ3ANWH1H/rnW	maritza.alexander@franscene.io	1997-05-25	Alexander	780 Brighton Court, Lindcove, Ohio, 4290	2017-01-22 13:35:45
80	a	USA	19374827482758698274	Test	$2a$11$YEX6Ssa80drjWbXhhrLvTOs7O/7.HXroKMU7t1AjrLyLc2SzRS6N2	testuser@email.com	1992-03-03	User	735 Main Street, Michigan, Cattle, 1284	2018-11-27 13:14:45
39	m	CAN	1606250517596442600	Kristin	$2a$11$XS5nOVLcx15W7gkvefUrIO26h1ldOZvkvZK7ck0K3NtqhktsVBXzy	kristin.rollins@eweville.co.uk	1981-04-07	Rollins	951 Marconi Place, Sedley, Hawaii, 9635	2018-11-04 05:39:33
\.


--
-- Data for Name: isiku_seisundi_liik; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.isiku_seisundi_liik (isiku_seisundi_liigi_kood, isiku_seisundi_liigi_nimetus) FROM stdin;
o	ootel
a	aktiivne
m	mitteaktiivne
l	lõpetatud
\.


--
-- Data for Name: kauba_kategooria; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.kauba_kategooria (kauba_kategooria_kood, kauba_kategooria_nimetus, kauba_kategooria_tyybi_kood) FROM stdin;
1	Mitmevärviline	1
2	Suur	1
3	Kerge	1
4	Mängimiseks	2
6	Vabaajakasutamieks	2
5	Sportimiseks	2
\.


--
-- Data for Name: kauba_kategooria_omamine; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.kauba_kategooria_omamine (kauba_kood, kauba_kategooria_kood) FROM stdin;
2	4
1	2
3	6
\.


--
-- Data for Name: kauba_kategooria_tyyp; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.kauba_kategooria_tyyp (kauba_kategooria_tyybi_kood, kategooria_tyybi_nimetus) FROM stdin;
2	kasutusotstarve
1	omadussõna
\.


--
-- Data for Name: kauba_seisundi_liik; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.kauba_seisundi_liik (kauba_seisundi_liigi_kood, kauba_seisundi_liigi_nimetus) FROM stdin;
o	ootel
a	aktiivne
ma	mitteaktiivne
l	lõpetatud
\.


--
-- Data for Name: kauba_tyyp; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.kauba_tyyp (palli_tyybi_kood, tyybi_nimetus) FROM stdin;
2	Korvpall
1	Jalgpall
3	Võrkpall
\.


--
-- Data for Name: kaup; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.kaup (kauba_kood, kauba_nimetus, kauba_kirjeldus, hind, kauba_kategooria_kood, kauba_seisundi_liigi_kood, registreerija_id, kauba_reg_aeg, palli_materjali_kood, palli_varvi_kood, palli_tyybi_kood, palli_suuruse_kood) FROM stdin;
1	Spalding sport	korvpall	19.99	1	a	25	2018-01-12 15:03:20	1	1	2	3
2	Mikasa indoors 	võrkpall	14.99	2	ma	30	2018-01-12 15:31:32	2	2	3	2
3	Adidas predator	jalgpall	19.99	1	l	30	2018-01-12 15:33:46	2	3	1	2
\.


--
-- Data for Name: kliendi_seisundi_liik; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.kliendi_seisundi_liik (kliendi_seisundi_liigi_kood, kliendi_seisundi_liigi_nimetus) FROM stdin;
l	lõpetatud
o	ootel
a	aktiivne
ma	mitteaktiivne
\.


--
-- Data for Name: klient; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.klient (isiku_id, kliendi_seisundi_liigi_kood, on_nous_tylitamisega) FROM stdin;
37	l	f
42	o	f
31	o	t
25	a	f
36	a	f
40	a	f
28	a	f
30	a	f
29	a	f
32	a	f
33	a	f
38	a	t
39	a	t
27	a	t
34	a	t
26	ma	f
41	ma	f
35	ma	t
\.


--
-- Data for Name: materjal; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.materjal (palli_materjali_kood, materjali_nimetus) FROM stdin;
2	nahk
1	kumm
3	puit
\.


--
-- Data for Name: riik; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.riik (riigi_kood, riigi_nimetus) FROM stdin;
AFG	Afghanistan
ALA	Åland Islands
ALB	Albania
DZA	Algeria
ASM	American Samoa
AND	Andorra
AGO	Angola
AIA	Anguilla
ATA	Antarctica
ATG	Antigua and Barbuda
ARG	Argentina
ARM	Armenia
ABW	Aruba
AUS	Australia
AUT	Austria
AZE	Azerbaijan
BHS	Bahamas
BHR	Bahrain
BGD	Bangladesh
BRB	Barbados
BLR	Belarus
BEL	Belgium
BLZ	Belize
BEN	Benin
BMU	Bermuda
BTN	Bhutan
BOL	Bolivia, Plurinational State of
BIH	Bosnia and Herzegovina
BWA	Botswana
BVT	Bouvet Island
BRA	Brazil
IOT	British Indian Ocean Territory
BRN	Brunei Darussalam
BGR	Bulgaria
BFA	Burkina Faso
BDI	Burundi
KHM	Cambodia
CMR	Cameroon
CAN	Canada
CPV	Cape Verde
CYM	Cayman Islands
CAF	Central African Republic
TCD	Chad
CHL	Chile
CHN	China
CXR	Christmas Island
CCK	Cocos (Keeling) Islands
COL	Colombia
COM	Comoros
COG	Congo
COD	Congo, the Democratic Republic of the
COK	Cook Islands
CRI	Costa Rica
CIV	Côte d'Ivoire
HRV	Croatia
CUB	Cuba
CYP	Cyprus
CZE	Czech Republic
DNK	Denmark
DJI	Djibouti
DMA	Dominica
DOM	Dominican Republic
ECU	Ecuador
EGY	Egypt
SLV	El Salvador
GNQ	Equatorial Guinea
ERI	Eritrea
EST	Estonia
ETH	Ethiopia
FLK	Falkland Islands (Malvinas)
FRO	Faroe Islands
FJI	Fiji
FIN	Finland
FRA	France
GUF	French Guiana
PYF	French Polynesia
ATF	French Southern Territories
GAB	Gabon
GMB	Gambia
GEO	Georgia
DEU	Germany
GHA	Ghana
GIB	Gibraltar
GRC	Greece
GRL	Greenland
GRD	Grenada
GLP	Guadeloupe
GUM	Guam
GTM	Guatemala
GGY	Guernsey
GIN	Guinea
GNB	Guinea-Bissau
GUY	Guyana
HTI	Haiti
HMD	Heard Island and McDonald Islands
VAT	Holy See (Vatican City State)
HND	Honduras
HKG	Hong Kong
HUN	Hungary
ISL	Iceland
IND	India
IDN	Indonesia
IRN	Iran, Islamic Republic of
IRQ	Iraq
IRL	Ireland
IMN	Isle of Man
ISR	Israel
ITA	Italy
JAM	Jamaica
JPN	Japan
JEY	Jersey
JOR	Jordan
KAZ	Kazakhstan
KEN	Kenya
KIR	Kiribati
PRK	Korea, Democratic People's Republic of
KOR	Korea, Republic of
KWT	Kuwait
KGZ	Kyrgyzstan
LAO	Lao People's Democratic Republic
LVA	Latvia
LBN	Lebanon
LSO	Lesotho
LBR	Liberia
LBY	Libyan Arab Jamahiriya
LIE	Liechtenstein
LTU	Lithuania
LUX	Luxembourg
MAC	Macao
MKD	Macedonia, the former Yugoslav Republic of
MDG	Madagascar
MWI	Malawi
MYS	Malaysia
MDV	Maldives
MLI	Mali
MLT	Malta
MHL	Marshall Islands
MTQ	Martinique
MRT	Mauritania
MUS	Mauritius
MYT	Mayotte
MEX	Mexico
FSM	Micronesia, Federated States of
MDA	Moldova, Republic of
MCO	Monaco
MNG	Mongolia
MNE	Montenegro
MSR	Montserrat
MAR	Morocco
MOZ	Mozambique
MMR	Myanmar
NAM	Namibia
NRU	Nauru
NPL	Nepal
NLD	Netherlands
ANT	Netherlands Antilles
NCL	New Caledonia
NZL	New Zealand
NIC	Nicaragua
NER	Niger
NGA	Nigeria
NIU	Niue
NFK	Norfolk Island
MNP	Northern Mariana Islands
NOR	Norway
OMN	Oman
PAK	Pakistan
PLW	Palau
PSE	Palestinian Territory, Occupied
PAN	Panama
PNG	Papua New Guinea
PRY	Paraguay
PER	Peru
PHL	Philippines
PCN	Pitcairn
POL	Poland
PRT	Portugal
PRI	Puerto Rico
QAT	Qatar
REU	Réunion
ROU	Romania
RUS	Russian Federation
RWA	Rwanda
BLM	Saint Barthélemy
SHN	Saint Helena, Ascension and Tristan da Cunha
KNA	Saint Kitts and Nevis
LCA	Saint Lucia
MAF	Saint Martin (French part)
SPM	Saint Pierre and Miquelon
VCT	Saint Vincent and the Grenadines
WSM	Samoa
SMR	San Marino
STP	Sao Tome and Principe
SAU	Saudi Arabia
SEN	Senegal
SRB	Serbia
SYC	Seychelles
SLE	Sierra Leone
SGP	Singapore
SVK	Slovakia
SVN	Slovenia
SLB	Solomon Islands
SOM	Somalia
ZAF	South Africa
SGS	South Georgia and the South Sandwich Islands
ESP	Spain
LKA	Sri Lanka
SDN	Sudan
SUR	Suriname
SJM	Svalbard and Jan Mayen
SWZ	Swaziland
SWE	Sweden
CHE	Switzerland
SYR	Syrian Arab Republic
TWN	Taiwan, Province of China
TJK	Tajikistan
TZA	Tanzania, United Republic of
THA	Thailand
TLS	Timor-Leste
TGO	Togo
TKL	Tokelau
TON	Tonga
TTO	Trinidad and Tobago
TUN	Tunisia
TUR	Turkey
TKM	Turkmenistan
TCA	Turks and Caicos Islands
TUV	Tuvalu
UGA	Uganda
UKR	Ukraine
ARE	United Arab Emirates
GBR	United Kingdom
USA	United States
UMI	United States Minor Outlying Islands
URY	Uruguay
UZB	Uzbekistan
VUT	Vanuatu
VEN	Venezuela, Bolivarian Republic of
VNM	Viet Nam
VGB	Virgin Islands, British
VIR	Virgin Islands, U.S.
WLF	Wallis and Futuna
ESH	Western Sahara
YEM	Yemen
ZMB	Zambia
ZWE	Zimbabwe
\.


--
-- Data for Name: suurus; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.suurus (palli_suuruse_kood, suuruse_nimetus) FROM stdin;
2	5
1	3
4	9
3	7
\.


--
-- Data for Name: tootaja; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.tootaja (isiku_id, seisundi_liigi_kood, ameti_kood) FROM stdin;
30	o	2
25	a	1
\.


--
-- Data for Name: tootaja_seisundi_liik; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.tootaja_seisundi_liik (tootaja_seisund_liigi_kood, tootaja_seisundi_nimetus) FROM stdin;
ma	mitteaktiivne
a	aktiivne
o	ootel
l	lõpetatud
\.


--
-- Data for Name: varv; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.varv (palli_varvi_kood, varvi_nimetus) FROM stdin;
2	roheline
1	punane
3	mustvalge
\.


--
-- Data for Name: varv_kaup; Type: TABLE DATA; Schema: public; Owner: t155376
--

COPY public.varv_kaup (palli_varvi_kood, kauba_kood) FROM stdin;
2	3
1	2
3	1
\.


--
-- Name: isik_isik_id_seq; Type: SEQUENCE SET; Schema: public; Owner: t155376
--

SELECT pg_catalog.setval('public.isik_isik_id_seq', 42, true);


--
-- Name: amet pk_amet; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.amet
    ADD CONSTRAINT pk_amet PRIMARY KEY (ameti_kood);


--
-- Name: isik pk_isik; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.isik
    ADD CONSTRAINT pk_isik PRIMARY KEY (isiku_id);


--
-- Name: isiku_seisundi_liik pk_isiku_seisundi_liik; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.isiku_seisundi_liik
    ADD CONSTRAINT pk_isiku_seisundi_liik PRIMARY KEY (isiku_seisundi_liigi_kood);


--
-- Name: kauba_kategooria pk_kauba_kategooria; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kauba_kategooria
    ADD CONSTRAINT pk_kauba_kategooria PRIMARY KEY (kauba_kategooria_kood);


--
-- Name: kauba_kategooria_omamine pk_kauba_kategooria_omamine; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kauba_kategooria_omamine
    ADD CONSTRAINT pk_kauba_kategooria_omamine PRIMARY KEY (kauba_kood);


--
-- Name: kauba_kategooria_tyyp pk_kauba_kategooria_tyyp; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kauba_kategooria_tyyp
    ADD CONSTRAINT pk_kauba_kategooria_tyyp PRIMARY KEY (kauba_kategooria_tyybi_kood);


--
-- Name: kauba_seisundi_liik pk_kauba_seisundi_liik; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kauba_seisundi_liik
    ADD CONSTRAINT pk_kauba_seisundi_liik PRIMARY KEY (kauba_seisundi_liigi_kood);


--
-- Name: kauba_tyyp pk_kauba_tyyp; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kauba_tyyp
    ADD CONSTRAINT pk_kauba_tyyp PRIMARY KEY (palli_tyybi_kood);


--
-- Name: kaup pk_kaup; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kaup
    ADD CONSTRAINT pk_kaup PRIMARY KEY (kauba_kood);


--
-- Name: kliendi_seisundi_liik pk_kliendi_seisundi_liik; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kliendi_seisundi_liik
    ADD CONSTRAINT pk_kliendi_seisundi_liik PRIMARY KEY (kliendi_seisundi_liigi_kood);


--
-- Name: klient pk_klient; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.klient
    ADD CONSTRAINT pk_klient PRIMARY KEY (isiku_id);


--
-- Name: materjal pk_materjal; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.materjal
    ADD CONSTRAINT pk_materjal PRIMARY KEY (palli_materjali_kood);


--
-- Name: riik pk_riik; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.riik
    ADD CONSTRAINT pk_riik PRIMARY KEY (riigi_kood);


--
-- Name: suurus pk_suurus; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.suurus
    ADD CONSTRAINT pk_suurus PRIMARY KEY (palli_suuruse_kood);


--
-- Name: tootaja pk_tootaja; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.tootaja
    ADD CONSTRAINT pk_tootaja PRIMARY KEY (isiku_id);


--
-- Name: tootaja_seisundi_liik pk_tootaja_seisundi_liik; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.tootaja_seisundi_liik
    ADD CONSTRAINT pk_tootaja_seisundi_liik PRIMARY KEY (tootaja_seisund_liigi_kood);


--
-- Name: varv pk_varv; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.varv
    ADD CONSTRAINT pk_varv PRIMARY KEY (palli_varvi_kood);


--
-- Name: varv_kaup pk_varv_kaup; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.varv_kaup
    ADD CONSTRAINT pk_varv_kaup PRIMARY KEY (palli_varvi_kood, kauba_kood);


--
-- Name: amet unique_amet_nimetus; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.amet
    ADD CONSTRAINT unique_amet_nimetus UNIQUE (ameti_nimetus);


--
-- Name: isik unique_isik_isikukood; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.isik
    ADD CONSTRAINT unique_isik_isikukood UNIQUE (isikukood, riigi_kood);


--
-- Name: isiku_seisundi_liik unique_isiku_seisundi_liik_nimetus; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.isiku_seisundi_liik
    ADD CONSTRAINT unique_isiku_seisundi_liik_nimetus UNIQUE (isiku_seisundi_liigi_nimetus);


--
-- Name: kauba_kategooria unique_kauba_kategooria_nimetus; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kauba_kategooria
    ADD CONSTRAINT unique_kauba_kategooria_nimetus UNIQUE (kauba_kategooria_nimetus);


--
-- Name: kauba_kategooria_tyyp unique_kauba_kategooria_tyyp_nimetus; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kauba_kategooria_tyyp
    ADD CONSTRAINT unique_kauba_kategooria_tyyp_nimetus UNIQUE (kategooria_tyybi_nimetus);


--
-- Name: kauba_seisundi_liik unique_kauba_seisundi_liik_nimetus; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kauba_seisundi_liik
    ADD CONSTRAINT unique_kauba_seisundi_liik_nimetus UNIQUE (kauba_seisundi_liigi_nimetus);


--
-- Name: kauba_tyyp unique_kauba_tyyp_nimetus; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kauba_tyyp
    ADD CONSTRAINT unique_kauba_tyyp_nimetus UNIQUE (tyybi_nimetus);


--
-- Name: kaup unique_kaup_nimetus; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kaup
    ADD CONSTRAINT unique_kaup_nimetus UNIQUE (kauba_nimetus);


--
-- Name: kliendi_seisundi_liik unique_kliendi_seisundi_liik_nimetus; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kliendi_seisundi_liik
    ADD CONSTRAINT unique_kliendi_seisundi_liik_nimetus UNIQUE (kliendi_seisundi_liigi_nimetus);


--
-- Name: materjal unique_materjal_nimetus; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.materjal
    ADD CONSTRAINT unique_materjal_nimetus UNIQUE (materjali_nimetus);


--
-- Name: riik unique_riik_nimetus; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.riik
    ADD CONSTRAINT unique_riik_nimetus UNIQUE (riigi_nimetus);


--
-- Name: suurus unique_suurus_nimetus; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.suurus
    ADD CONSTRAINT unique_suurus_nimetus UNIQUE (suuruse_nimetus);


--
-- Name: tootaja_seisundi_liik unique_tootaja_seisundi_liik_nimetus; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.tootaja_seisundi_liik
    ADD CONSTRAINT unique_tootaja_seisundi_liik_nimetus UNIQUE (tootaja_seisundi_nimetus);


--
-- Name: varv unique_varv_nimetus; Type: CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.varv
    ADD CONSTRAINT unique_varv_nimetus UNIQUE (varvi_nimetus);


--
-- Name: fki_fk_isik_isiku_seisundi_liigi_kood; Type: INDEX; Schema: public; Owner: t155376
--

CREATE INDEX fki_fk_isik_isiku_seisundi_liigi_kood ON public.isik USING btree (isiku_seisundi_liigi_kood);


--
-- Name: fki_fk_isik_isikukood; Type: INDEX; Schema: public; Owner: t155376
--

CREATE INDEX fki_fk_isik_isikukood ON public.isik USING btree (riigi_kood);


--
-- Name: fki_fk_kauba_kategooria_kauba_kategooria_tyybi_kood; Type: INDEX; Schema: public; Owner: t155376
--

CREATE INDEX fki_fk_kauba_kategooria_kauba_kategooria_tyybi_kood ON public.kauba_kategooria USING btree (kauba_kategooria_tyybi_kood);


--
-- Name: fki_fk_kaup_kauba_kategooria_kood; Type: INDEX; Schema: public; Owner: t155376
--

CREATE INDEX fki_fk_kaup_kauba_kategooria_kood ON public.kaup USING btree (kauba_kategooria_kood);


--
-- Name: fki_fk_kaup_kauba_seisundi_liik; Type: INDEX; Schema: public; Owner: t155376
--

CREATE INDEX fki_fk_kaup_kauba_seisundi_liik ON public.kaup USING btree (kauba_seisundi_liigi_kood);


--
-- Name: fki_fk_kaup_palli_materjali_kood; Type: INDEX; Schema: public; Owner: t155376
--

CREATE INDEX fki_fk_kaup_palli_materjali_kood ON public.kaup USING btree (palli_materjali_kood);


--
-- Name: fki_fk_kaup_palli_suuruse_kood; Type: INDEX; Schema: public; Owner: t155376
--

CREATE INDEX fki_fk_kaup_palli_suuruse_kood ON public.kaup USING btree (palli_suuruse_kood);


--
-- Name: fki_fk_kaup_palli_tyybi_kood; Type: INDEX; Schema: public; Owner: t155376
--

CREATE INDEX fki_fk_kaup_palli_tyybi_kood ON public.kaup USING btree (palli_tyybi_kood);


--
-- Name: fki_fk_kaup_palli_varvi_kood; Type: INDEX; Schema: public; Owner: t155376
--

CREATE INDEX fki_fk_kaup_palli_varvi_kood ON public.kaup USING btree (palli_varvi_kood);


--
-- Name: fki_fk_kaup_tootaja; Type: INDEX; Schema: public; Owner: t155376
--

CREATE INDEX fki_fk_kaup_tootaja ON public.kaup USING btree (registreerija_id);


--
-- Name: fki_fk_klient_kliendi_seisundi_liik; Type: INDEX; Schema: public; Owner: t155376
--

CREATE INDEX fki_fk_klient_kliendi_seisundi_liik ON public.klient USING btree (kliendi_seisundi_liigi_kood);


--
-- Name: fki_fk_tootaja_amet; Type: INDEX; Schema: public; Owner: t155376
--

CREATE INDEX fki_fk_tootaja_amet ON public.tootaja USING btree (ameti_kood);


--
-- Name: fki_fk_tootaja_seisundi_liik; Type: INDEX; Schema: public; Owner: t155376
--

CREATE INDEX fki_fk_tootaja_seisundi_liik ON public.tootaja USING btree (seisundi_liigi_kood);


--
-- Name: fki_fk_varv_kaup; Type: INDEX; Schema: public; Owner: t155376
--

CREATE INDEX fki_fk_varv_kaup ON public.varv_kaup USING btree (palli_varvi_kood);


--
-- Name: idx_isik_email_lower; Type: INDEX; Schema: public; Owner: t155376
--

CREATE UNIQUE INDEX idx_isik_email_lower ON public.isik USING btree (lower((e_mail)::text));


--
-- Name: isik trig_lopeta_isik; Type: TRIGGER; Schema: public; Owner: t155376
--

CREATE TRIGGER trig_lopeta_isik BEFORE UPDATE OF isiku_seisundi_liigi_kood ON public.isik FOR EACH ROW WHEN (((old.isiku_seisundi_liigi_kood)::text = 'o'::text)) EXECUTE PROCEDURE public.f_lopeta_isik();


--
-- Name: kaup trig_lopeta_kaup; Type: TRIGGER; Schema: public; Owner: t155376
--

CREATE TRIGGER trig_lopeta_kaup BEFORE UPDATE OF kauba_seisundi_liigi_kood ON public.kaup FOR EACH ROW WHEN ((((old.kauba_seisundi_liigi_kood)::text = 'o'::text) OR ((old.kauba_seisundi_liigi_kood)::text = 'a'::text))) EXECUTE PROCEDURE public.f_lopeta_kaup();


--
-- Name: isik fk_isik_isiku_seisundi_liigi_kood; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.isik
    ADD CONSTRAINT fk_isik_isiku_seisundi_liigi_kood FOREIGN KEY (isiku_seisundi_liigi_kood) REFERENCES public.isiku_seisundi_liik(isiku_seisundi_liigi_kood) ON UPDATE CASCADE;


--
-- Name: isik fk_isik_isikukood; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.isik
    ADD CONSTRAINT fk_isik_isikukood FOREIGN KEY (riigi_kood) REFERENCES public.riik(riigi_kood) ON UPDATE CASCADE;


--
-- Name: kauba_kategooria fk_kauba_kategooria_kauba_kategooria_tyybi_kood; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kauba_kategooria
    ADD CONSTRAINT fk_kauba_kategooria_kauba_kategooria_tyybi_kood FOREIGN KEY (kauba_kategooria_tyybi_kood) REFERENCES public.kauba_kategooria_tyyp(kauba_kategooria_tyybi_kood) ON UPDATE CASCADE;


--
-- Name: kaup fk_kauba_kategooria_omamine; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kaup
    ADD CONSTRAINT fk_kauba_kategooria_omamine FOREIGN KEY (kauba_kood) REFERENCES public.kauba_kategooria_omamine(kauba_kood) ON UPDATE CASCADE;


--
-- Name: kaup fk_kaup_kauba_kategooria_kood; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kaup
    ADD CONSTRAINT fk_kaup_kauba_kategooria_kood FOREIGN KEY (kauba_kategooria_kood) REFERENCES public.kauba_kategooria(kauba_kategooria_kood) ON UPDATE CASCADE;


--
-- Name: kaup fk_kaup_kauba_seisundi_liik; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kaup
    ADD CONSTRAINT fk_kaup_kauba_seisundi_liik FOREIGN KEY (kauba_seisundi_liigi_kood) REFERENCES public.kauba_seisundi_liik(kauba_seisundi_liigi_kood) ON UPDATE CASCADE;


--
-- Name: kaup fk_kaup_palli_materjali_kood; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kaup
    ADD CONSTRAINT fk_kaup_palli_materjali_kood FOREIGN KEY (palli_materjali_kood) REFERENCES public.materjal(palli_materjali_kood) ON UPDATE CASCADE;


--
-- Name: kaup fk_kaup_palli_suuruse_kood; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kaup
    ADD CONSTRAINT fk_kaup_palli_suuruse_kood FOREIGN KEY (palli_suuruse_kood) REFERENCES public.suurus(palli_suuruse_kood) ON UPDATE CASCADE;


--
-- Name: kaup fk_kaup_palli_tyybi_kood; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kaup
    ADD CONSTRAINT fk_kaup_palli_tyybi_kood FOREIGN KEY (palli_tyybi_kood) REFERENCES public.kauba_tyyp(palli_tyybi_kood) ON UPDATE CASCADE;


--
-- Name: kaup fk_kaup_palli_varvi_kood; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kaup
    ADD CONSTRAINT fk_kaup_palli_varvi_kood FOREIGN KEY (palli_varvi_kood) REFERENCES public.varv(palli_varvi_kood) ON UPDATE CASCADE;


--
-- Name: kaup fk_kaup_tootaja; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.kaup
    ADD CONSTRAINT fk_kaup_tootaja FOREIGN KEY (registreerija_id) REFERENCES public.tootaja(isiku_id);


--
-- Name: klient fk_klient_isik; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.klient
    ADD CONSTRAINT fk_klient_isik FOREIGN KEY (isiku_id) REFERENCES public.isik(isiku_id) ON DELETE CASCADE;


--
-- Name: klient fk_klient_kliendi_seisundi_liik; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.klient
    ADD CONSTRAINT fk_klient_kliendi_seisundi_liik FOREIGN KEY (kliendi_seisundi_liigi_kood) REFERENCES public.kliendi_seisundi_liik(kliendi_seisundi_liigi_kood) ON UPDATE CASCADE;


--
-- Name: tootaja fk_tootaja_amet; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.tootaja
    ADD CONSTRAINT fk_tootaja_amet FOREIGN KEY (ameti_kood) REFERENCES public.amet(ameti_kood) ON UPDATE CASCADE;


--
-- Name: tootaja fk_tootaja_isik; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.tootaja
    ADD CONSTRAINT fk_tootaja_isik FOREIGN KEY (isiku_id) REFERENCES public.isik(isiku_id) ON DELETE CASCADE;


--
-- Name: tootaja fk_tootaja_seisundi_liik; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.tootaja
    ADD CONSTRAINT fk_tootaja_seisundi_liik FOREIGN KEY (seisundi_liigi_kood) REFERENCES public.tootaja_seisundi_liik(tootaja_seisund_liigi_kood) ON UPDATE CASCADE;


--
-- Name: varv_kaup fk_varv_kaup; Type: FK CONSTRAINT; Schema: public; Owner: t155376
--

ALTER TABLE ONLY public.varv_kaup
    ADD CONSTRAINT fk_varv_kaup FOREIGN KEY (palli_varvi_kood) REFERENCES public.varv(palli_varvi_kood) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: DATABASE t155376; Type: ACL; Schema: -; Owner: t155376
--

REVOKE CONNECT,TEMPORARY ON DATABASE t155376 FROM PUBLIC;
GRANT ALL ON DATABASE t155376 TO t154874;
GRANT ALL ON DATABASE t155376 TO t155390;
GRANT CONNECT ON DATABASE t155376 TO username;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO username;


--
-- Name: LANGUAGE plpgsql; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON LANGUAGE plpgsql FROM PUBLIC;


--
-- Name: FUNCTION armor(bytea); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.armor(bytea) FROM PUBLIC;


--
-- Name: FUNCTION armor(bytea, text[], text[]); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.armor(bytea, text[], text[]) FROM PUBLIC;


--
-- Name: FUNCTION crypt(text, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.crypt(text, text) FROM PUBLIC;


--
-- Name: FUNCTION dearmor(text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.dearmor(text) FROM PUBLIC;


--
-- Name: FUNCTION decrypt(bytea, bytea, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.decrypt(bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION decrypt_iv(bytea, bytea, bytea, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.decrypt_iv(bytea, bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION digest(bytea, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.digest(bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION digest(text, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.digest(text, text) FROM PUBLIC;


--
-- Name: FUNCTION encrypt(bytea, bytea, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.encrypt(bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION encrypt_iv(bytea, bytea, bytea, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.encrypt_iv(bytea, bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION f_eemalda_kauba_kategooriast(p_kauba_kood character varying, p_kauba_kategooria_kood character varying); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.f_eemalda_kauba_kategooriast(p_kauba_kood character varying, p_kauba_kategooria_kood character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_kustuta_kaup(p_kauba_kood character varying); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.f_kustuta_kaup(p_kauba_kood character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_lisa_kauba_kategooriasse(p_kauba_kood character varying, p_kauba_kategooria_kood character varying); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.f_lisa_kauba_kategooriasse(p_kauba_kood character varying, p_kauba_kategooria_kood character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_lisa_kaup(p_kauba_kood character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_registreerija_id integer, p_palli_materjali_kood character varying, p_palli_varvi_kood character varying, p_palli_tyybi_kood character varying, p_palli_suuruse_kood character varying, p_hind numeric); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.f_lisa_kaup(p_kauba_kood character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_registreerija_id integer, p_palli_materjali_kood character varying, p_palli_varvi_kood character varying, p_palli_tyybi_kood character varying, p_palli_suuruse_kood character varying, p_hind numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION public.f_lisa_kaup(p_kauba_kood character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_registreerija_id integer, p_palli_materjali_kood character varying, p_palli_varvi_kood character varying, p_palli_tyybi_kood character varying, p_palli_suuruse_kood character varying, p_hind numeric) TO username;


--
-- Name: FUNCTION f_lopeta_isik(); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.f_lopeta_isik() FROM PUBLIC;


--
-- Name: FUNCTION f_lopeta_kaup(); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.f_lopeta_kaup() FROM PUBLIC;


--
-- Name: FUNCTION f_lopeta_kaup(p_kauba_kood character varying); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.f_lopeta_kaup(p_kauba_kood character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION public.f_lopeta_kaup(p_kauba_kood character varying) TO t154874;


--
-- Name: FUNCTION f_muuda_kaup(p_kauba_kood_vana character varying, p_kauba_kood_uus character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_palli_materjali_kood character varying, p_palli_varvi_kood character varying, p_palli_tyybi_kood character varying, p_palli_suuruse_kood character varying, p_hind numeric); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.f_muuda_kaup(p_kauba_kood_vana character varying, p_kauba_kood_uus character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_palli_materjali_kood character varying, p_palli_varvi_kood character varying, p_palli_tyybi_kood character varying, p_palli_suuruse_kood character varying, p_hind numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION public.f_muuda_kaup(p_kauba_kood_vana character varying, p_kauba_kood_uus character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_palli_materjali_kood character varying, p_palli_varvi_kood character varying, p_palli_tyybi_kood character varying, p_palli_suuruse_kood character varying, p_hind numeric) TO username;


--
-- Name: FUNCTION f_muuda_kaup_aktiivseks(p_kauba_kood character varying); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.f_muuda_kaup_aktiivseks(p_kauba_kood character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION public.f_muuda_kaup_aktiivseks(p_kauba_kood character varying) TO username;


--
-- Name: FUNCTION f_muuda_kaup_mitteaktiivseks(p_kauba_kood character varying); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.f_muuda_kaup_mitteaktiivseks(p_kauba_kood character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION public.f_muuda_kaup_mitteaktiivseks(p_kauba_kood character varying) TO username;


--
-- Name: FUNCTION f_registreeri_kaup(p_kauba_kood character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_hind numeric, p_tootaja_id integer, p_varvi_kood character varying, p_tyybi_kood character varying, p_suuruse_kood character varying, p_materjali_kood character varying); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.f_registreeri_kaup(p_kauba_kood character varying, p_kauba_nimetus character varying, p_kauba_kirjeldus character varying, p_hind numeric, p_tootaja_id integer, p_varvi_kood character varying, p_tyybi_kood character varying, p_suuruse_kood character varying, p_materjali_kood character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_uuenda_kauba_andmeid(p_kauba_kood_vana character varying, p_kauba_kood_uus character varying, p_nimetus character varying, p_kirjeldus character varying, p_hind numeric, p_varvi_kood character varying, p_tyybi_kood character varying, p_suuruse_kood character varying, p_materjali_kood character varying); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.f_uuenda_kauba_andmeid(p_kauba_kood_vana character varying, p_kauba_kood_uus character varying, p_nimetus character varying, p_kirjeldus character varying, p_hind numeric, p_varvi_kood character varying, p_tyybi_kood character varying, p_suuruse_kood character varying, p_materjali_kood character varying) FROM PUBLIC;


--
-- Name: FUNCTION gen_random_bytes(integer); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.gen_random_bytes(integer) FROM PUBLIC;


--
-- Name: FUNCTION gen_random_uuid(); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.gen_random_uuid() FROM PUBLIC;


--
-- Name: FUNCTION gen_salt(text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.gen_salt(text) FROM PUBLIC;


--
-- Name: FUNCTION gen_salt(text, integer); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.gen_salt(text, integer) FROM PUBLIC;


--
-- Name: FUNCTION hmac(bytea, bytea, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.hmac(bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION hmac(text, text, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.hmac(text, text, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_armor_headers(text, OUT key text, OUT value text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_armor_headers(text, OUT key text, OUT value text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_key_id(bytea); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_key_id(bytea) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea, text, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea, text, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea, text, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_encrypt(text, bytea); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_pub_encrypt(text, bytea) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_encrypt(text, bytea, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_pub_encrypt(text, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_encrypt_bytea(bytea, bytea); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea) FROM PUBLIC;


--
-- Name: FUNCTION pgp_pub_encrypt_bytea(bytea, bytea, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_decrypt(bytea, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_sym_decrypt(bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_decrypt(bytea, text, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_sym_decrypt(bytea, text, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_decrypt_bytea(bytea, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_sym_decrypt_bytea(bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_decrypt_bytea(bytea, text, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_sym_decrypt_bytea(bytea, text, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_encrypt(text, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_sym_encrypt(text, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_encrypt(text, text, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_sym_encrypt(text, text, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_encrypt_bytea(bytea, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_sym_encrypt_bytea(bytea, text) FROM PUBLIC;


--
-- Name: FUNCTION pgp_sym_encrypt_bytea(bytea, text, text); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.pgp_sym_encrypt_bytea(bytea, text, text) FROM PUBLIC;


--
-- Name: FUNCTION postgres_fdw_handler(); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.postgres_fdw_handler() FROM PUBLIC;


--
-- Name: FUNCTION postgres_fdw_validator(text[], oid); Type: ACL; Schema: public; Owner: t155376
--

REVOKE ALL ON FUNCTION public.postgres_fdw_validator(text[], oid) FROM PUBLIC;


--
-- Name: TABLE aktiivsed_mitteaktivsed_kaubad; Type: ACL; Schema: public; Owner: t155376
--

GRANT SELECT ON TABLE public.aktiivsed_mitteaktivsed_kaubad TO username;


--
-- Name: TABLE kaubad; Type: ACL; Schema: public; Owner: t155376
--

GRANT SELECT ON TABLE public.kaubad TO username;


--
-- Name: TABLE kaubad_detailselt; Type: ACL; Schema: public; Owner: t155376
--

GRANT SELECT ON TABLE public.kaubad_detailselt TO username;


--
-- Name: TABLE kaupade_koondaruanne; Type: ACL; Schema: public; Owner: t155376
--

GRANT SELECT ON TABLE public.kaupade_koondaruanne TO username;


--
-- Name: TABLE mv_aktiivsed_mitteaktiivsed_kaubad; Type: ACL; Schema: public; Owner: t155376
--

GRANT SELECT ON TABLE public.mv_aktiivsed_mitteaktiivsed_kaubad TO username;


--
-- Name: TABLE mv_kaubad; Type: ACL; Schema: public; Owner: t155376
--

GRANT SELECT ON TABLE public.mv_kaubad TO username;


--
-- Name: TABLE mv_kaubad_detailselt; Type: ACL; Schema: public; Owner: t155376
--

GRANT SELECT ON TABLE public.mv_kaubad_detailselt TO username;


--
-- Name: TABLE mv_kaupade_koondaruanne; Type: ACL; Schema: public; Owner: t155376
--

GRANT SELECT ON TABLE public.mv_kaupade_koondaruanne TO username;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: t155376
--

ALTER DEFAULT PRIVILEGES FOR ROLE t155376 REVOKE ALL ON FUNCTIONS  FROM PUBLIC;


--
-- Name: mv_aktiivsed_mitteaktiivsed_kaubad; Type: MATERIALIZED VIEW DATA; Schema: public; Owner: t155376
--

REFRESH MATERIALIZED VIEW public.mv_aktiivsed_mitteaktiivsed_kaubad;


--
-- Name: mv_kaubad; Type: MATERIALIZED VIEW DATA; Schema: public; Owner: t155376
--

REFRESH MATERIALIZED VIEW public.mv_kaubad;


--
-- Name: mv_kaubad_detailselt; Type: MATERIALIZED VIEW DATA; Schema: public; Owner: t155376
--

REFRESH MATERIALIZED VIEW public.mv_kaubad_detailselt;


--
-- Name: mv_kaupade_koondaruanne; Type: MATERIALIZED VIEW DATA; Schema: public; Owner: t155376
--

REFRESH MATERIALIZED VIEW public.mv_kaupade_koondaruanne;


--
-- PostgreSQL database dump complete
--

