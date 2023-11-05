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
-- Name: pgapex; Type: DATABASE; Schema: -; Owner: pgapex_live_user
--

CREATE DATABASE pgapex WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'et_EE.utf8' LC_CTYPE = 'et_EE.utf8';


ALTER DATABASE pgapex OWNER TO pgapex_live_user;

\connect pgapex

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
-- Name: pgapex; Type: SCHEMA; Schema: -; Owner: t143682
--

CREATE SCHEMA pgapex;


ALTER SCHEMA pgapex OWNER TO t143682;

--
-- Name: dblink; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA pgapex;


--
-- Name: EXTENSION dblink; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION dblink IS 'connect to other PostgreSQL databases from within a database';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA pgapex;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: t_navigation_item_with_level; Type: TYPE; Schema: pgapex; Owner: t143682
--

CREATE TYPE pgapex.t_navigation_item_with_level AS (
	navigation_item_id integer,
	parent_navigation_item_id integer,
	sequence integer,
	name character varying,
	page_id integer,
	url character varying,
	level integer
);


ALTER TYPE pgapex.t_navigation_item_with_level OWNER TO t143682;

--
-- Name: t_report_column_with_link; Type: TYPE; Schema: pgapex; Owner: t143682
--

CREATE TYPE pgapex.t_report_column_with_link AS (
	view_column_name character varying,
	heading character varying,
	sequence integer,
	is_text_escaped boolean,
	url character varying,
	link_text character varying,
	attributes character varying
);


ALTER TYPE pgapex.t_report_column_with_link OWNER TO t143682;

--
-- Name: f_app_add_error_message(text); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_add_error_message(t_message text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  INSERT INTO temp_messages(transaction_id, type, message) VALUES (txid_current(), 'ERROR', t_message);
END
$$;


ALTER FUNCTION pgapex.f_app_add_error_message(t_message text) OWNER TO t143682;

--
-- Name: f_app_add_region(character varying, integer, text); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_add_region(v_display_point character varying, i_sequence integer, t_content text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  INSERT INTO temp_regions (transaction_id , display_point, sequence, content) VALUES (txid_current(), v_display_point, i_sequence, COALESCE(t_content, ''));
END
$$;


ALTER FUNCTION pgapex.f_app_add_region(v_display_point character varying, i_sequence integer, t_content text) OWNER TO t143682;

--
-- Name: f_app_add_setting(character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_add_setting(v_key character varying, v_value character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  DELETE FROM temp_settings WHERE transaction_id = txid_current() AND key = lower(v_key);
  INSERT INTO temp_settings(transaction_id, key, value) VALUES (txid_current(), lower(v_key), v_value);
END
$$;


ALTER FUNCTION pgapex.f_app_add_setting(v_key character varying, v_value character varying) OWNER TO t143682;

--
-- Name: f_app_add_success_message(text); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_add_success_message(t_message text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  INSERT INTO temp_messages(transaction_id, type, message) VALUES (txid_current(), 'SUCCESS', t_message);
END
$$;


ALTER FUNCTION pgapex.f_app_add_success_message(t_message text) OWNER TO t143682;

--
-- Name: f_app_create_page(integer, integer, jsonb, jsonb); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_create_page(i_application_id integer, i_page_id integer, j_get_params jsonb, j_post_params jsonb) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  b_is_app_auth_required  BOOLEAN;
  b_is_page_auth_required BOOLEAN;
  t_response              TEXT;
  t_success_message       TEXT;
  t_error_message         TEXT;
  r_region                RECORD;
  v_display_point         VARCHAR;
  t_region_template       TEXT;
  t_region_content        TEXT;
BEGIN
  SELECT authentication_scheme_id <> 'NO_AUTHENTICATION' INTO b_is_app_auth_required FROM pgapex.application WHERE application_id = i_application_id;
  SELECT is_authentication_required INTO b_is_page_auth_required FROM pgapex.page WHERE page_id = i_page_id;

  IF b_is_app_auth_required AND b_is_page_auth_required AND pgapex.f_app_is_authenticated() = FALSE THEN
    SELECT pt.header || pt.body || pt.footer, pt.success_message, pt.error_message
    INTO t_response, t_success_message, t_error_message
    FROM pgapex.page_template pt
    WHERE pt.template_id = (SELECT a.login_page_template_id
                            FROM pgapex.application a
                            WHERE a.application_id = i_application_id);
  ELSE
    FOR r_region IN (SELECT * FROM pgapex.f_app_get_page_regions(i_page_id)) LOOP

      SELECT template INTO t_region_template FROM pgapex.region_template WHERE template_id = r_region.template_id;

      IF r_region.region_type = 'HTML' THEN
        SELECT pgapex.f_app_get_html_region(r_region.region_id) INTO t_region_content;
      ELSIF r_region.region_type = 'NAVIGATION' THEN
        SELECT pgapex.f_app_get_navigation_region(r_region.region_id) INTO t_region_content;
      ELSIF r_region.region_type = 'REPORT' THEN
        SELECT pgapex.f_app_get_report_region(r_region.region_id, j_get_params) INTO t_region_content;
      ELSIF r_region.region_type = 'FORM' THEN
        SELECT pgapex.f_app_get_form_region(r_region.region_id, j_get_params) INTO t_region_content;
      END IF;
      t_region_template := replace(t_region_template, '#NAME#', r_region.name);
      t_region_template := replace(t_region_template, '#BODY#', t_region_content);
      PERFORM pgapex.f_app_add_region(r_region.display_point, r_region.sequence, t_region_template);
    END LOOP;

    SELECT pt.header || pt.body || pt.footer, pt.success_message, pt.error_message
    INTO t_response, t_success_message, t_error_message
    FROM pgapex.page_template pt
    WHERE pt.template_id = (SELECT template_id FROM pgapex.page WHERE page_id = i_page_id);

    FOR v_display_point IN (SELECT distinct ptdp.display_point_id
                            FROM pgapex.page p
                            LEFT JOIN pgapex.page_template pt ON p.template_id = pt.template_id
                            LEFT JOIN pgapex.page_template_display_point ptdp ON pt.template_id = ptdp.page_template_id
                            WHERE p.page_id = i_page_id
    ) LOOP
      t_response := replace(t_response, '#' || v_display_point || '#', COALESCE(pgapex.f_app_get_display_point_content(v_display_point), ''));
    END LOOP;
  END IF;

  t_response := replace(t_response, '#APPLICATION_NAME#', (SELECT name FROM pgapex.application WHERE application_id = i_application_id));
  t_response := replace(t_response, '#TITLE#', (SELECT title FROM pgapex.page WHERE page_id = i_page_id));
  t_response := replace(t_response, '#LOGOUT_LINK#', pgapex.f_app_get_logout_link());
  t_response := replace(t_response, '#ERROR_MESSAGE#', pgapex.f_app_get_error_message(t_error_message));
  t_response := replace(t_response, '#SUCCESS_MESSAGE#', pgapex.f_app_get_success_message(t_success_message));
  t_response := pgapex.f_app_replace_system_variables(t_response);

  RETURN t_response;
END
$$;


ALTER FUNCTION pgapex.f_app_create_page(i_application_id integer, i_page_id integer, j_get_params jsonb, j_post_params jsonb) OWNER TO t143682;

--
-- Name: f_app_create_response(text); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_create_response(t_response_body text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  j_response JSON;
BEGIN
  SELECT json_build_object(
    'headers', coalesce(json_object(array_agg(h.field_name), array_agg(h.value)), '{}'::json)
  , 'body', t_response_body
  )
  INTO j_response
  FROM temp_headers h
  WHERE h.transaction_id = txid_current();

  RETURN j_response;
END
$$;


ALTER FUNCTION pgapex.f_app_create_response(t_response_body text) OWNER TO t143682;

--
-- Name: f_app_create_temp_tables(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_create_temp_tables() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS temp_headers (
      transaction_id INT          NOT NULL
    , field_name     VARCHAR(100) NOT NULL
    , value          TEXT         NOT NULL
  );
  CREATE TEMP TABLE IF NOT EXISTS temp_settings (
      transaction_id INT          NOT NULL
    , key            VARCHAR(100) NOT NULL
    , value          TEXT         NOT NULL
  );
  CREATE TEMP TABLE IF NOT EXISTS temp_messages (
      transaction_id INT          NOT NULL
    , type           VARCHAR(10)  NOT NULL CHECK (type IN ('ERROR', 'SUCCESS'))
    , message        TEXT         NOT NULL
  );
  CREATE TEMP TABLE IF NOT EXISTS temp_regions (
      transaction_id INT          NOT NULL
    , display_point  VARCHAR      NOT NULL
    , sequence       INT          NOT NULL
    , content        TEXT         NOT NULL
  );
END
$$;


ALTER FUNCTION pgapex.f_app_create_temp_tables() OWNER TO t143682;

--
-- Name: f_app_dblink_connect(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_dblink_connect(i_application_id integer) RETURNS text
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT dblink_connect(pgapex.f_app_get_dblink_connection_name(),
                       'dbname=' || database_name || ' user=' || database_username || ' password=' || database_password)
  FROM pgapex.application WHERE application_id = i_application_id;
$$;


ALTER FUNCTION pgapex.f_app_dblink_connect(i_application_id integer) OWNER TO t143682;

--
-- Name: f_app_dblink_disconnect(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_dblink_disconnect() RETURNS text
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT dblink_disconnect(pgapex.f_app_get_dblink_connection_name());
$$;


ALTER FUNCTION pgapex.f_app_dblink_disconnect() OWNER TO t143682;

--
-- Name: f_app_error(character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_error(v_error_message character varying) RETURNS text
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT '<html>
  <head>
    <title>Error</title>
  </head>
  <body>
    <strong>Error!</strong>
    <p>' || v_error_message || '</p>
  </body>
</html>';
$$;


ALTER FUNCTION pgapex.f_app_error(v_error_message character varying) OWNER TO t143682;

--
-- Name: f_app_form_region_submit(integer, integer, jsonb); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_form_region_submit(i_page_id integer, i_region_id integer, j_post_params jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  v_schema_name       VARCHAR;
  v_function_name     VARCHAR;
  v_success_message   VARCHAR;
  v_error_message     VARCHAR;
  v_redirect_url      VARCHAR;
  t_function_call     TEXT;
  i_function_response INT;
BEGIN
  IF (SELECT NOT EXISTS(SELECT 1
                        FROM pgapex.region r
                        LEFT JOIN pgapex.form_region fr ON fr.region_id = r.region_id
                        WHERE r.page_id = i_page_id AND r.region_id = i_region_id AND fr.region_id IS NOT NULL)) THEN
    PERFORM pgapex.f_app_add_error_message('Region does not exist');
  END IF;

  SELECT schema_name, function_name, success_message, error_message, redirect_url
  INTO v_schema_name, v_function_name, v_success_message, v_error_message, v_redirect_url
  FROM pgapex.form_region WHERE region_id = i_region_id;

  t_function_call := 'SELECT 1 FROM ' || v_schema_name || '.' || v_function_name || ' ( ';
  t_function_call := t_function_call || (SELECT string_agg(a.param, ', ')
                      FROM (
                             SELECT ff.function_parameter_ordinal_position, quote_nullable(url_params.value) AS param
                             FROM pgapex.form_field ff
                               LEFT JOIN pgapex.page_item pi ON pi.form_field_id = ff.form_field_id
                               LEFT JOIN json_each_text(j_post_params::json) url_params ON url_params.key = pi.name
                             WHERE ff.region_id = i_region_id
                             ORDER BY ff.function_parameter_ordinal_position ASC
                           ) a);
  t_function_call := t_function_call || ' );';

  BEGIN
    SELECT res_func INTO i_function_response FROM dblink(pgapex.f_app_get_dblink_connection_name(), t_function_call, TRUE) AS ( res_func int );
    IF v_success_message IS NOT NULL THEN
      PERFORM pgapex.f_app_add_success_message(v_success_message);
    END IF;
    IF v_redirect_url IS NOT NULL THEN
      PERFORM pgapex.f_app_set_header('location', pgapex.f_app_replace_system_variables(v_redirect_url));
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      PERFORM pgapex.f_app_add_error_message(coalesce(v_error_message, SQLERRM));
  END;
END
$$;


ALTER FUNCTION pgapex.f_app_form_region_submit(i_page_id integer, i_region_id integer, j_post_params jsonb) OWNER TO t143682;

--
-- Name: f_app_get_application_id(character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_application_id(v_application_id character varying) RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $_$
  SELECT (
    CASE
      WHEN v_application_id ~ '^[0-9]+$' AND
          (SELECT EXISTS(SELECT 1 FROM pgapex.application WHERE application_id = v_application_id::int)) THEN
            v_application_id::int
      WHEN (SELECT EXISTS(SELECT 1 FROM pgapex.application WHERE alias = v_application_id)) THEN
        (SELECT application_id FROM pgapex.application WHERE alias = v_application_id)
      ELSE
        NULL
    END
  );
$_$;


ALTER FUNCTION pgapex.f_app_get_application_id(v_application_id character varying) OWNER TO t143682;

--
-- Name: f_app_get_cookie(character varying, jsonb); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_cookie(v_cookie_name character varying, j_headers jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  v_cookie_value VARCHAR;
  v_cookies VARCHAR;
  v_cookie TEXT[];
BEGIN
  IF j_headers IS NULL THEN
    RETURN NULL;
  END IF;
  IF j_headers ? 'HTTP_COOKIE' THEN
  SELECT j_headers->'HTTP_COOKIE'->>0 INTO v_cookies;
  FOR v_cookie IN SELECT regexp_split_to_array(trim(c), E'=') FROM regexp_split_to_table(v_cookies, E';') AS c LOOP
    IF v_cookie[1] = v_cookie_name THEN
      RETURN v_cookie[2];
    END IF;
  END LOOP;
END IF;
RETURN NULL;
END
$$;


ALTER FUNCTION pgapex.f_app_get_cookie(v_cookie_name character varying, j_headers jsonb) OWNER TO t143682;

--
-- Name: f_app_get_dblink_connection_name(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_dblink_connection_name() RETURNS character varying
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT 'dblink_connection_' || txid_current()::varchar;
$$;


ALTER FUNCTION pgapex.f_app_get_dblink_connection_name() OWNER TO t143682;

--
-- Name: f_app_get_display_point_content(character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_display_point_content(v_display_point character varying) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  t_response TEXT;
BEGIN
  WITH display_point_content AS (
    SELECT content FROM temp_regions
    WHERE transaction_id = txid_current()
      AND display_point = v_display_point
    ORDER BY sequence
  ) SELECT COALESCE(string_agg(content, ''), '') INTO t_response FROM display_point_content;
  RETURN t_response;
END
$$;


ALTER FUNCTION pgapex.f_app_get_display_point_content(v_display_point character varying) OWNER TO t143682;

--
-- Name: f_app_get_error_message(text); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_error_message(t_error_message_template text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  RETURN pgapex.f_app_get_message('ERROR', t_error_message_template);
END
$$;


ALTER FUNCTION pgapex.f_app_get_error_message(t_error_message_template text) OWNER TO t143682;

--
-- Name: f_app_get_form_region(integer, jsonb); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_form_region(i_region_id integer, j_get_params jsonb) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  t_region_template              TEXT;
  i_form_pre_fill_id             INT;
  v_button_label                 VARCHAR;
  t_form_begin_template          TEXT;
  t_form_end_template            TEXT;
  t_row_begin_template           TEXT;
  t_row_end_template             TEXT;
  t_row_template                 TEXT;
  t_mandatory_row_begin_template TEXT;
  t_mandatory_row_end_template   TEXT;
  t_mandatory_row_template       TEXT;
  t_button_template              TEXT;
  v_pre_fill_schema              VARCHAR;
  v_pre_fill_view                VARCHAR;
  r_form_row                     RECORD;
  t_current_row_begin_template   TEXT     := '';
  t_current_row_end_template     TEXT     := '';
  t_current_row_template         TEXT     := '';
  t_form_element                 TEXT     := '';
  j_lov_rows                     JSON;
  v_query                        VARCHAR;
  t_option                       TEXT;
  t_options                      TEXT;
  t_pre_fill_url_params          TEXT[];
  j_pre_fetched_values           JSONB   := '{}';
  j_option                       JSON;
BEGIN
  SELECT fr.form_pre_fill_id, fr.button_label, ft.form_begin, ft.form_end, ft.row_begin, ft.row_end, ft.row,
         ft.mandatory_row_begin, ft.mandatory_row_end, ft.mandatory_row, bt.template, fpf.schema_name, fpf.view_name
  INTO i_form_pre_fill_id, v_button_label, t_form_begin_template, t_form_end_template, t_row_begin_template, t_row_end_template, t_row_template,
       t_mandatory_row_begin_template, t_mandatory_row_end_template, t_mandatory_row_template, t_button_template, v_pre_fill_schema, v_pre_fill_view
  FROM pgapex.form_region fr
  LEFT JOIN pgapex.form_template ft ON ft.template_id = fr.template_id
  LEFT JOIN pgapex.button_template bt ON bt.template_id = fr.button_template_id
  LEFT JOIN pgapex.form_pre_fill fpf ON fpf.form_pre_fill_id = fr.form_pre_fill_id
  WHERE fr.region_id = i_region_id;

  IF i_form_pre_fill_id IS NOT NULL THEN
    SELECT ARRAY( SELECT pi.name
    FROM pgapex.fetch_row_condition frc
    RIGHT JOIN pgapex.page_item pi ON pi.page_item_id = frc.url_parameter_id
    WHERE frc.form_pre_fill_id = i_form_pre_fill_id) INTO t_pre_fill_url_params;

    IF (j_get_params ?& t_pre_fill_url_params) = FALSE THEN
      PERFORM pgapex.f_app_add_error_message('All url params must exist to prefetch form data: ' || array_to_string(t_pre_fill_url_params, ', '));
      RETURN '';
    END IF;

    SELECT string_agg(params.param, ' AND ') INTO v_query
    FROM ( SELECT (frc.view_column_name || '=' || quote_nullable(url_params.value)) param
           FROM pgapex.fetch_row_condition frc
           LEFT JOIN pgapex.page_item pi ON pi.page_item_id = frc.url_parameter_id
           LEFT JOIN (SELECT key, value FROM json_each_text(j_get_params::json)) url_params ON url_params.key = pi.name
           WHERE frc.form_pre_fill_id = i_form_pre_fill_id
         ) params;

    v_query := 'SELECT to_json(a) FROM ' || v_pre_fill_schema || '.' || v_pre_fill_view || ' a WHERE ' || v_query || ' LIMIT 1';
    SELECT res_pre_fetch_values INTO j_pre_fetched_values FROM dblink(pgapex.f_app_get_dblink_connection_name(), v_query, FALSE) AS ( res_pre_fetch_values JSONB );

  END IF;

  t_button_template := replace(replace(t_button_template, '#NAME#', 'PGAPEX_BUTTON'), '#LABEL#', v_button_label);

  t_region_template := replace(t_form_begin_template, '#SUBMIT_BUTTON#', t_button_template);
  t_region_template := t_region_template || '<input type="hidden" name="PGAPEX_REGION" value="' || i_region_id || '">';

  FOR r_form_row IN (
    SELECT
      ff.field_type_id, ff.label, ff.is_mandatory, ff.is_visible, ff.default_value, ff.help_text, ff.field_pre_fill_view_column_name,
      pi.name AS form_element_name, lov.schema_name, lov.view_name, lov.label_view_column_name, lov.value_view_column_name,
      it.template AS input_template, tt.template AS textarea_template,
      ddt.drop_down_begin, ddt.drop_down_end, ddt.option_begin, ddt.option_end
    FROM pgapex.form_field ff
      LEFT JOIN pgapex.list_of_values lov ON lov.list_of_values_id = ff.list_of_values_id
      LEFT JOIN pgapex.page_item pi ON pi.form_field_id = ff.form_field_id
      LEFT JOIN pgapex.input_template it ON it.template_id = ff.input_template_id
      LEFT JOIN pgapex.drop_down_template ddt ON ddt.template_id = ff.drop_down_template_id
      LEFT JOIN pgapex.textarea_template tt ON tt.template_id = ff.textarea_template_id
    WHERE ff.region_id = i_region_id
    ORDER BY ff.sequence ASC
  )
  LOOP
    t_form_element := '';
    r_form_row.default_value := pgapex.f_app_replace_system_variables(r_form_row.default_value);

    IF r_form_row.field_pre_fill_view_column_name IS NOT NULL AND j_pre_fetched_values ? r_form_row.field_pre_fill_view_column_name THEN
      r_form_row.default_value := j_pre_fetched_values->>r_form_row.field_pre_fill_view_column_name;
    END IF;

    IF r_form_row.is_visible THEN
      IF r_form_row.is_mandatory THEN
        t_current_row_begin_template := t_mandatory_row_begin_template;
        t_current_row_end_template := t_mandatory_row_end_template;
        t_current_row_template := t_mandatory_row_template;
      ELSE
        t_current_row_begin_template := t_row_begin_template;
        t_current_row_end_template := t_row_end_template;
        t_current_row_template := t_row_template;
      END IF;
      t_region_template := t_region_template || t_current_row_begin_template;

      IF r_form_row.field_type_id IN ('TEXT', 'PASSWORD', 'CHECKBOX') THEN
        t_form_element := r_form_row.input_template;
        t_form_element := replace(t_form_element, '#VALUE#', pgapex.f_app_html_special_chars(coalesce(r_form_row.default_value, '')));
        t_form_element := replace(t_form_element, '#CHECKED#', '');

      ELSIF r_form_row.field_type_id = 'RADIO' THEN
        v_query := 'SELECT json_build_object(''value'', ' || r_form_row.value_view_column_name || ', ''label'', ' || r_form_row.label_view_column_name || ') ' ||
                   ' FROM '  || r_form_row.schema_name || '.' || r_form_row.view_name;
        t_options := '';
        FOR j_option IN (SELECT res_options FROM dblink(pgapex.f_app_get_dblink_connection_name(), v_query, FALSE) AS ( res_options JSON ))
        LOOP
          t_option := r_form_row.input_template;
          t_option := replace(t_option, '#VALUE#', pgapex.f_app_html_special_chars(j_option->>'value'));
          t_option := replace(t_option, '#INPUT_LABEL#', pgapex.f_app_html_special_chars(j_option->>'label'));
          IF j_option->>'value' = r_form_row.default_value THEN
            t_option := replace(t_option, '#CHECKED#', ' checked="checked" ');
          END IF;
          t_option := replace(t_option, '#CHECKED#', '');
          t_options := t_options || t_option;
        END LOOP;
        t_form_element := t_form_element || t_options;

      ELSIF r_form_row.field_type_id = 'TEXTAREA' THEN
        t_form_element := r_form_row.textarea_template;
        t_form_element := replace(t_form_element, '#VALUE#', pgapex.f_app_html_special_chars(coalesce(r_form_row.default_value, '')));

      ELSIF r_form_row.field_type_id = 'DROP_DOWN' THEN
        t_form_element := r_form_row.drop_down_begin;
        v_query := 'SELECT json_build_object(''value'', ' || r_form_row.value_view_column_name || ', ''label'', ' || r_form_row.label_view_column_name || ') ' ||
                   ' FROM '  || r_form_row.schema_name || '.' || r_form_row.view_name;
        t_options := '';
        FOR j_option IN (SELECT res_options FROM dblink(pgapex.f_app_get_dblink_connection_name(), v_query, FALSE) AS ( res_options JSON ))
        LOOP
          t_option := r_form_row.option_begin;
          t_option := replace(t_option, '#VALUE#', pgapex.f_app_html_special_chars(j_option->>'value'));
          IF j_option->>'value' = r_form_row.default_value THEN
            t_option := replace(t_option, '#SELECTED#', ' selected="selected" ');
          END IF;
          t_option := replace(t_option, '#SELECTED#', '');
          t_option := t_option || pgapex.f_app_html_special_chars(j_option->>'label') || r_form_row.option_end;
          t_options := t_options || t_option;
        END LOOP;

        t_form_element := t_form_element || t_options;
        t_form_element := t_form_element || r_form_row.drop_down_end;
      END IF;
    ELSE
      t_current_row_begin_template := '';
      t_current_row_end_template := '';
      t_current_row_template := '#FORM_ELEMENT#';
      t_form_element := '<input type="hidden" name="#NAME#" value="#VALUE#">';
      t_form_element :=  replace(t_form_element, '#VALUE#', pgapex.f_app_html_special_chars(coalesce(r_form_row.default_value, '')));
    END IF;

    t_form_element := replace(t_form_element, '#NAME#',      pgapex.f_app_html_special_chars(r_form_row.form_element_name));
    t_form_element := replace(t_form_element, '#ROW_LABEL#', pgapex.f_app_html_special_chars(r_form_row.label));

    t_current_row_template := replace(t_current_row_template, '#FORM_ELEMENT#', t_form_element);
    t_current_row_template := replace(t_current_row_template, '#HELP_TEXT#',    pgapex.f_app_html_special_chars(coalesce(r_form_row.help_text, '')));
    t_current_row_template := replace(t_current_row_template, '#LABEL#',        r_form_row.label);
    t_region_template := t_region_template || t_current_row_template;
    t_region_template := t_region_template || t_current_row_end_template;
  END LOOP;

  t_region_template := t_region_template || replace(t_form_end_template, '#SUBMIT_BUTTON#', t_button_template);

  RETURN t_region_template;
END
$$;


ALTER FUNCTION pgapex.f_app_get_form_region(i_region_id integer, j_get_params jsonb) OWNER TO t143682;

--
-- Name: f_app_get_html_region(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_html_region(i_region_id integer) RETURNS text
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT content FROM pgapex.html_region WHERE region_id = i_region_id;
$$;


ALTER FUNCTION pgapex.f_app_get_html_region(i_region_id integer) OWNER TO t143682;

--
-- Name: f_app_get_logout_link(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_logout_link() RETURNS character varying
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT pgapex.f_app_get_setting('application_root') || '/logout/' ||  pgapex.f_app_get_setting('application_id');
$$;


ALTER FUNCTION pgapex.f_app_get_logout_link() OWNER TO t143682;

--
-- Name: f_app_get_message(character varying, text); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_message(v_type character varying, t_message_template text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  t_response TEXT;
  t_message TEXT;
BEGIN
  SELECT string_agg(message, '<br />') INTO t_message FROM temp_messages WHERE type = v_type AND transaction_id = txid_current();
  IF t_message <> '' THEN
    RETURN replace(t_message_template, '#MESSAGE#', t_message);
  END IF;
  RETURN '';
END
$$;


ALTER FUNCTION pgapex.f_app_get_message(v_type character varying, t_message_template text) OWNER TO t143682;

--
-- Name: f_app_get_navigation_breadcrumb(integer, integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_navigation_breadcrumb(i_navigation_id integer, i_page_id integer) RETURNS SETOF pgapex.t_navigation_item_with_level
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  WITH RECURSIVE breadcrumb(navigation_item_id, parent_navigation_item_id, sequence, name, page_id, url, level) AS (
    SELECT * FROM pgapex.f_app_get_navigation_items_with_levels(i_navigation_id)
    WHERE page_id = i_page_id
    UNION ALL
    SELECT niwl.* FROM pgapex.f_app_get_navigation_items_with_levels(i_navigation_id) niwl, breadcrumb b
    WHERE niwl.navigation_item_id = b.parent_navigation_item_id
  )
  SELECT * FROM breadcrumb
  ORDER BY level
$$;


ALTER FUNCTION pgapex.f_app_get_navigation_breadcrumb(i_navigation_id integer, i_page_id integer) OWNER TO t143682;

--
-- Name: f_app_get_navigation_in_order(integer, integer, integer[]); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_navigation_in_order(i_navigation_id integer, i_parent_navigation_item_id integer, i_parent_ids integer[]) RETURNS SETOF pgapex.t_navigation_item_with_level
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  r pgapex.t_navigation_item_with_level;
BEGIN
  FOR r IN SELECT * FROM pgapex.f_app_get_navigation_items_with_levels(i_navigation_id)
  WHERE (
    CASE
      WHEN i_parent_navigation_item_id IS NULL THEN (parent_navigation_item_id IS NULL)
      ELSE (parent_navigation_item_id = i_parent_navigation_item_id)
    END
  ) AND (
    CASE
      WHEN i_parent_ids IS NULL THEN (TRUE)
      WHEN parent_navigation_item_id IS NULL THEN (TRUE)
      ELSE (parent_navigation_item_id = ANY(i_parent_ids))
    END
  )
  ORDER BY sequence
  LOOP
    RETURN NEXT r;
    RETURN QUERY SELECT * FROM pgapex.f_app_get_navigation_in_order(i_navigation_id, r.navigation_item_id, i_parent_ids);
  END LOOP;
  RETURN;
END
$$;


ALTER FUNCTION pgapex.f_app_get_navigation_in_order(i_navigation_id integer, i_parent_navigation_item_id integer, i_parent_ids integer[]) OWNER TO t143682;

--
-- Name: f_app_get_navigation_items_with_levels(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_navigation_items_with_levels(i_navigation_id integer) RETURNS SETOF pgapex.t_navigation_item_with_level
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  WITH RECURSIVE navigation_tree (navigation_item_id, parent_navigation_item_id, sequence, name, page_id, url, level)
  AS (
    SELECT
      navigation_item_id
      , parent_navigation_item_id
      , sequence
      , name
      , page_id
      , url
      , 1
    FROM pgapex.navigation_item
    WHERE navigation_id = i_navigation_id
      AND parent_navigation_item_id is NULL
    UNION ALL
    SELECT
      ni.navigation_item_id,
      nt.navigation_item_id,
      ni.sequence,
      ni.name,
      ni.page_id,
      ni.url,
      nt.level + 1
    FROM pgapex.navigation_item ni, navigation_tree nt
    WHERE ni.parent_navigation_item_id = nt.navigation_item_id
      AND ni.navigation_id = i_navigation_id
  )
  SELECT navigation_item_id, parent_navigation_item_id, sequence, name, page_id, url, level
  FROM navigation_tree
  ORDER BY level, parent_navigation_item_id NULLS FIRST, sequence;
$$;


ALTER FUNCTION pgapex.f_app_get_navigation_items_with_levels(i_navigation_id integer) OWNER TO t143682;

--
-- Name: f_app_get_navigation_of_type(integer, integer, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_navigation_of_type(i_navigation_id integer, i_page_id integer, v_navigation_type character varying) RETURNS SETOF pgapex.t_navigation_item_with_level
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  IF v_navigation_type = 'BREADCRUMB' THEN
    RETURN QUERY SELECT * FROM pgapex.f_app_get_navigation_breadcrumb(i_navigation_id, i_page_id);
  ELSIF v_navigation_type = 'SITEMAP' THEN
    RETURN QUERY SELECT * FROM pgapex.f_app_get_navigation_in_order(i_navigation_id, NULL, NULL);
  ELSE
    RETURN QUERY SELECT * FROM pgapex.f_app_get_navigation_in_order(i_navigation_id, NULL, (
      SELECT ARRAY (SELECT navigation_item_id FROM  pgapex.f_app_get_navigation_breadcrumb(i_navigation_id, i_page_id))
    ));
  END IF;
  RETURN;
END
$$;


ALTER FUNCTION pgapex.f_app_get_navigation_of_type(i_navigation_id integer, i_page_id integer, v_navigation_type character varying) OWNER TO t143682;

--
-- Name: f_app_get_navigation_region(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_navigation_region(i_region_id integer) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  v_url_prefix                         VARCHAR;
  v_navigation_type                    VARCHAR;
  i_navigation_id                      INT;
  i_template_id                        INT;
  i_page_id                            INT;
  b_repeat_last_level                  BOOLEAN;
  t_region_template                    TEXT;
  t_navigation_begin_template          TEXT;
  t_navigation_end_template            TEXT;
  i_navigation_template_id             INT;
  i_navigation_item_template_max_level INT;
BEGIN
  SELECT nr.navigation_type_id, nr.navigation_id, nr.template_id, nr.repeat_last_level, r.page_id, nt.navigation_begin, nt.navigation_end, nt.template_id
  INTO v_navigation_type, i_navigation_id, i_template_id, b_repeat_last_level, i_page_id, t_navigation_begin_template, t_navigation_end_template, i_navigation_template_id
  FROM pgapex.navigation_region nr
  LEFT JOIN pgapex.region r ON nr.region_id = r.region_id
  LEFT JOIN pgapex.navigation_template nt ON nr.template_id = nt.template_id
  WHERE nr.region_id = i_region_id;

  SELECT max(level) INTO i_navigation_item_template_max_level FROM pgapex.navigation_item_template WHERE navigation_template_id = i_navigation_template_id;
  SELECT pgapex.f_app_get_setting('application_root') || '/app/' || pgapex.f_app_get_setting('application_id') || '/' INTO v_url_prefix;

  SELECT string_agg(
      CASE
      WHEN n.page_id = i_page_id THEN replace(replace(replace(nit.active_template, '#NAME#', n.name), '#URL#', (
        CASE
          WHEN n.page_id IS NULL THEN n.url
          ELSE v_url_prefix || n.page_id
        END
      )), '#LEVEL#', n.level::varchar)
      ELSE replace(replace(replace(nit.inactive_template, '#NAME#', n.name), '#URL#', (
        CASE
          WHEN n.page_id IS NULL THEN n.url
          ELSE v_url_prefix || n.page_id
        END
      )), '#LEVEL#', n.level::varchar)
      END
      , '') INTO t_region_template
  FROM pgapex.f_app_get_navigation_of_type(i_navigation_id, i_page_id, v_navigation_type) n
    LEFT JOIN pgapex.navigation_item_template nit ON (
      CASE
        WHEN n.level > i_navigation_item_template_max_level AND b_repeat_last_level THEN
          nit.level = i_navigation_item_template_max_level AND nit.navigation_template_id = i_navigation_template_id
        ELSE
          n.level = nit.level AND nit.navigation_template_id = i_navigation_template_id
      END
      )
  WHERE nit.navigation_item_template_id IS NOT NULL;

  RETURN t_navigation_begin_template || t_region_template || t_navigation_end_template;
END
$$;


ALTER FUNCTION pgapex.f_app_get_navigation_region(i_region_id integer) OWNER TO t143682;

--
-- Name: f_app_get_page_id(integer, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_page_id(i_application_id integer, v_page_id character varying) RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $_$
  SELECT (
    CASE
      WHEN v_page_id ~ '^[0-9]+$' AND
          (SELECT EXISTS(SELECT 1 FROM pgapex.page WHERE page_id = v_page_id::int AND application_id = i_application_id)) THEN
            v_page_id::int
      WHEN (SELECT EXISTS(SELECT 1 FROM pgapex.page WHERE application_id = i_application_id AND alias = v_page_id)) THEN
        (SELECT page_id FROM pgapex.page WHERE application_id = i_application_id AND alias = v_page_id)
      ELSE
        NULL
    END
  );
$_$;


ALTER FUNCTION pgapex.f_app_get_page_id(i_application_id integer, v_page_id character varying) OWNER TO t143682;

--
-- Name: f_app_get_page_regions(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_page_regions(i_page_id integer) RETURNS TABLE(region_id integer, region_type character varying, display_point character varying, sequence integer, template_id integer, name character varying)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT
    r.region_id
    , (CASE
       WHEN hr.region_id IS NOT NULL THEN 'HTML'
       WHEN nr.region_id IS NOT NULL THEN 'NAVIGATION'
       WHEN rr.region_id IS NOT NULL THEN 'REPORT'
       WHEN fr.region_id IS NOT NULL THEN 'FORM'
       END) AS region_type
    , ptdp.display_point_id AS display_point
    , r.sequence
    , r.template_id
    , r.name
  FROM pgapex.region r
    LEFT JOIN pgapex.html_region hr ON hr.region_id = r.region_id
    LEFT JOIN pgapex.navigation_region nr ON nr.region_id = r.region_id
    LEFT JOIN pgapex.report_region rr ON rr.region_id = r.region_id
    LEFT JOIN pgapex.form_region fr ON fr.region_id = r.region_id
    LEFT JOIN pgapex.page_template_display_point ptdp ON ptdp.page_template_display_point_id = r.page_template_display_point_id
  WHERE r.page_id = i_page_id AND r.is_visible = TRUE
  ORDER BY r.sequence;
$$;


ALTER FUNCTION pgapex.f_app_get_page_regions(i_page_id integer) OWNER TO t143682;

--
-- Name: f_app_get_report_region(integer, jsonb); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_report_region(i_region_id integer, j_get_params jsonb) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  t_region_template        TEXT;
  v_schema_name            VARCHAR;
  v_view_name              VARCHAR;
  i_items_per_page         INT;
  b_show_header            BOOLEAN;
  v_pagination_query_param VARCHAR;
  i_current_page           INT      := 1;
  i_row_count              INT;
  i_page_count             INT;
  i_offset                 INT      := 0;
  j_rows                   JSON;
  v_query                  VARCHAR;
BEGIN
  SELECT rr.schema_name, rr.view_name, rr.items_per_page, rr.show_header, pi.name
  INTO v_schema_name, v_view_name, i_items_per_page, b_show_header, v_pagination_query_param
  FROM pgapex.report_region rr
  LEFT JOIN pgapex.page_item pi ON rr.region_id = pi.region_id
  WHERE rr.region_id = i_region_id;

  IF j_get_params IS NOT NULL AND j_get_params ? v_pagination_query_param THEN
    i_current_page := (j_get_params->>v_pagination_query_param)::INT;
  END IF;

  i_row_count := pgapex.f_app_get_row_count(v_schema_name, v_view_name);
  i_page_count := ceil(i_row_count::float/i_items_per_page::float);

  IF (i_page_count < i_current_page) OR (i_current_page < 1) THEN
    i_current_page := 1;
  END IF;

  i_offset := (i_current_page - 1) * i_items_per_page;

  v_query := 'SELECT json_agg(a) FROM (SELECT * FROM ' || v_schema_name || '.' || v_view_name || ' LIMIT ' || i_items_per_page || ' OFFSET ' || i_offset || ') AS a';

  SELECT res_rows INTO j_rows FROM dblink(pgapex.f_app_get_dblink_connection_name(), v_query, FALSE) AS ( res_rows JSON );

  RETURN pgapex.f_app_get_report_region_with_template(i_region_id, j_rows, v_pagination_query_param, i_page_count, i_current_page, b_show_header);
END
$$;


ALTER FUNCTION pgapex.f_app_get_report_region(i_region_id integer, j_get_params jsonb) OWNER TO t143682;

--
-- Name: f_app_get_report_region_with_template(integer, json, character varying, integer, integer, boolean); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_report_region_with_template(i_region_id integer, j_data json, v_pagination_query_param character varying, i_page_count integer, i_current_page integer, b_show_header boolean) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  t_response         TEXT;
  t_pagination       TEXT     := '';
  v_url_prefix       VARCHAR;
  t_report_begin     TEXT;
  t_report_end       TEXT;
  t_header_begin     TEXT;
  t_header_row_begin TEXT;
  t_header_cell      TEXT;
  t_header_row_end   TEXT;
  t_header_end       TEXT;
  t_body_begin       TEXT;
  t_body_row_begin   TEXT;
  t_body_row_cell    TEXT;
  t_body_row_end     TEXT;
  t_body_end         TEXT;
  t_pagination_begin TEXT;
  t_pagination_end   TEXT;
  t_previous_page    TEXT;
  t_next_page        TEXT;
  t_active_page      TEXT;
  t_inactive_page    TEXT;
  r_report_column    pgapex.t_report_column_with_link;
  r_report_columns   pgapex.t_report_column_with_link[];
  j_row              JSON;
  r_column           RECORD;
  t_cell_content     TEXT;
BEGIN
  SELECT rt.report_begin, rt.report_end, rt.header_begin, rt.header_row_begin, rt.header_cell, rt.header_row_end, rt.header_end,
         rt.body_begin, rt.body_row_begin, rt.body_row_cell, rt.body_row_end, rt.body_end,
         rt.pagination_begin, rt.pagination_end, rt.previous_page, rt.next_page, rt.active_page, rt.inactive_page
  INTO t_report_begin, t_report_end, t_header_begin, t_header_row_begin, t_header_cell, t_header_row_end, t_header_end,
       t_body_begin, t_body_row_begin, t_body_row_cell, t_body_row_end, t_body_end,
       t_pagination_begin, t_pagination_end, t_previous_page, t_next_page, t_active_page, t_inactive_page
  FROM pgapex.report_region rr
  LEFT JOIN pgapex.report_template rt ON rt.template_id = rr.template_id
  WHERE rr.region_id = i_region_id;

  SELECT ARRAY(
      SELECT ROW(rc.view_column_name, rc.heading, rc.sequence, rc.is_text_escaped, rcl.url, rcl.link_text, rcl.attributes)
      FROM pgapex.report_column rc
      LEFT JOIN pgapex.report_column_link rcl ON rcl.report_column_id = rc.report_column_id
      WHERE rc.region_id = i_region_id
      ORDER BY rc.sequence
  ) INTO r_report_columns;

  t_response := t_report_begin;

  IF b_show_header THEN
    t_response := t_response || t_header_begin || t_header_row_begin;

    FOREACH r_report_column IN ARRAY r_report_columns
    LOOP
      t_response := t_response || replace(t_header_cell, '#CELL_CONTENT#', r_report_column.heading);
    END LOOP;

    t_response := t_response || t_header_row_end || t_header_end;
  END IF;

  t_response := t_response || t_body_begin;

  IF j_data IS NOT NULL THEN
    FOR j_row IN SELECT * FROM json_array_elements(j_data)
    LOOP
      t_response := t_response || t_body_row_begin;
        FOREACH r_report_column IN ARRAY r_report_columns
        LOOP
          IF r_report_column.view_column_name IS NOT NULL THEN
            t_cell_content := COALESCE(j_row->>r_report_column.view_column_name, '');
            IF r_report_column.is_text_escaped THEN
              t_cell_content := pgapex.f_app_html_special_chars(t_cell_content);
            END IF;
            t_response := t_response || replace(t_body_row_cell, '#CELL_CONTENT#', t_cell_content);
          ELSE
            FOR r_column IN SELECT * FROM json_each_text(j_row)
            LOOP
              r_report_column.link_text := replace(r_report_column.link_text, '%' || r_column.key || '%', coalesce(r_column.value, ''));
              r_report_column.url := replace(r_report_column.url, '%' || r_column.key || '%', coalesce(r_column.value, ''));
            END LOOP;
            IF r_report_column.is_text_escaped THEN
              r_report_column.link_text := pgapex.f_app_html_special_chars(r_report_column.link_text);
            END IF;
            t_response := t_response || replace(t_body_row_cell, '#CELL_CONTENT#', '<a href="' || r_report_column.url || '" ' || COALESCE(r_report_column.attributes, '') || '>' || r_report_column.link_text || '</a>');
          END IF;
        END LOOP;
      t_response := t_response || t_body_row_end;
    END LOOP;
  END IF;

  t_response := t_response || t_body_end || t_report_end;

  v_url_prefix := pgapex.f_app_get_setting('application_root') || '/app/' || pgapex.f_app_get_setting('application_id') || '/' || pgapex.f_app_get_setting('page_id') || '?' || v_pagination_query_param || '=';

  IF i_page_count > 1 THEN
    t_pagination := t_pagination_begin;

    IF i_current_page > 1 THEN
      t_pagination := t_pagination || replace(t_previous_page, '#LINK#', v_url_prefix || 1);
    END IF;

    FOR p in 1 .. i_page_count
    LOOP
      IF p = i_current_page THEN
        t_pagination := t_pagination || replace(replace(t_active_page, '#LINK#', v_url_prefix || p), '#NUMBER#', p::varchar);
      ELSE
        t_pagination := t_pagination || replace(replace(t_inactive_page, '#LINK#', v_url_prefix || p), '#NUMBER#', p::varchar);
      END IF;
    END LOOP;

    IF i_current_page < i_page_count THEN
      t_pagination := t_pagination || replace(t_next_page, '#LINK#', v_url_prefix || i_page_count);
    END IF;

    t_pagination := t_pagination || t_pagination_end;
  END IF;

  RETURN replace(t_response, '#PAGINATION#', t_pagination);
END
$$;


ALTER FUNCTION pgapex.f_app_get_report_region_with_template(i_region_id integer, j_data json, v_pagination_query_param character varying, i_page_count integer, i_current_page integer, b_show_header boolean) OWNER TO t143682;

--
-- Name: f_app_get_row_count(character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_row_count(v_schema_name character varying, v_view_name character varying) RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT res_row_count
  FROM dblink(pgapex.f_app_get_dblink_connection_name()
  , 'SELECT COUNT(1) FROM ' || v_schema_name || '.' || v_view_name
  , FALSE) AS ( res_row_count INT)
$$;


ALTER FUNCTION pgapex.f_app_get_row_count(v_schema_name character varying, v_view_name character varying) OWNER TO t143682;

--
-- Name: f_app_get_session_id(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_session_id() RETURNS character varying
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT pgapex.f_app_get_setting('session_id');
$$;


ALTER FUNCTION pgapex.f_app_get_session_id() OWNER TO t143682;

--
-- Name: f_app_get_setting(character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_setting(v_key character varying) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  v_value VARCHAR;
BEGIN
  SELECT value INTO v_value FROM temp_settings WHERE transaction_id = txid_current() AND key = lower(v_key);
  RETURN v_value;
END
$$;


ALTER FUNCTION pgapex.f_app_get_setting(v_key character varying) OWNER TO t143682;

--
-- Name: f_app_get_success_message(text); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_get_success_message(t_success_message_template text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  RETURN pgapex.f_app_get_message('SUCCESS', t_success_message_template);
END
$$;


ALTER FUNCTION pgapex.f_app_get_success_message(t_success_message_template text) OWNER TO t143682;

--
-- Name: f_app_html_special_chars(text); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_html_special_chars(t_text text) RETURNS text
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT replace(replace(replace(replace(replace(t_text, '&', '&amp;'), '"', '&quot;'), '''', '&apos;'), '>', '&gt;'), '<', '&lt;');
$$;


ALTER FUNCTION pgapex.f_app_html_special_chars(t_text text) OWNER TO t143682;

--
-- Name: f_app_is_authenticated(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_is_authenticated() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  b_is_authenticated BOOLEAN;
BEGIN
  SELECT pgapex.f_app_session_read('is_authenticated')::BOOLEAN INTO b_is_authenticated;
  IF b_is_authenticated IS NOT NULL AND b_is_authenticated = TRUE THEN
    RETURN TRUE;
  END IF;
  RETURN FALSE;
END
$$;


ALTER FUNCTION pgapex.f_app_is_authenticated() OWNER TO t143682;

--
-- Name: f_app_logout(character varying, character varying, jsonb); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_logout(v_application_root character varying, v_application_id character varying, j_headers jsonb) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  j_response       JSON;
  t_response_body  TEXT;
  i_application_id INT;
BEGIN
  PERFORM pgapex.f_app_create_temp_tables();
  SELECT pgapex.f_app_get_application_id(v_application_id) INTO i_application_id;

  IF i_application_id IS NULL THEN
    SELECT pgapex.f_app_error('Application does not exist: ' || v_application_id) INTO t_response_body;
    SELECT pgapex.f_app_create_response(t_response_body) INTO j_response;
    RETURN j_response;
  END IF;

  PERFORM pgapex.f_app_open_session(v_application_root, i_application_id, j_headers);
  DELETE FROM pgapex.session WHERE session_id = f_app_get_session_id();

  PERFORM pgapex.f_app_set_header('location', v_application_root || '/app/' || v_application_id);
  SELECT pgapex.f_app_create_response('') INTO j_response;
  RETURN j_response;
END
$$;


ALTER FUNCTION pgapex.f_app_logout(v_application_root character varying, v_application_id character varying, j_headers jsonb) OWNER TO t143682;

--
-- Name: f_app_open_session(character varying, integer, jsonb); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_open_session(v_application_root character varying, i_application_id integer, j_headers jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  v_session_id      VARCHAR;
  t_expiration_time TIMESTAMP;
  j_data            JSONB;
BEGIN
  SELECT pgapex.f_app_get_cookie('PGAPEX_SESSION_' || i_application_id::VARCHAR, j_headers) INTO v_session_id;
  IF v_session_id IS NOT NULL THEN
    SELECT expiration_time, data INTO t_expiration_time, j_data FROM pgapex.session WHERE session_id = v_session_id;
    IF t_expiration_time > current_timestamp THEN
      UPDATE pgapex.session SET expiration_time = (current_timestamp + interval '1 hour') WHERE session_id = v_session_id;
      PERFORM pgapex.f_app_add_setting('session_id', v_session_id);
      IF j_data IS NOT NULL AND j_data ? 'username' THEN
        PERFORM pgapex.f_app_add_setting('username', j_data->>'username');
      END IF;
      RETURN;
    ELSE
      DELETE FROM pgapex.session WHERE session_id = v_session_id;
    END IF;
  END IF;

  SELECT encode(pgapex.digest(current_timestamp::text || random()::text || txid_current()::text || i_application_id::text, 'sha512'), 'hex') INTO v_session_id;
  PERFORM pgapex.f_app_set_cookie('PGAPEX_SESSION_' || i_application_id::VARCHAR, v_session_id || '; Path=' || v_application_root);
  PERFORM pgapex.f_app_add_setting('session_id', v_session_id);
  INSERT INTO pgapex.session (session_id, application_id, data, expiration_time)
  VALUES (v_session_id, i_application_id, '{}'::jsonb, (current_timestamp + interval '1 hour'));
END
$$;


ALTER FUNCTION pgapex.f_app_open_session(v_application_root character varying, i_application_id integer, j_headers jsonb) OWNER TO t143682;

--
-- Name: f_app_parse_operation(integer, integer, character varying, jsonb, jsonb, jsonb); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_parse_operation(i_application_id integer, i_page_id integer, v_method character varying, j_headers jsonb, j_get_params jsonb, j_post_params jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  b_is_permitted BOOLEAN;
BEGIN
  IF upper(v_method) <> 'POST' THEN
    RETURN;
  END IF;

  IF j_post_params ? 'PGAPEX_OP' AND j_post_params ? 'USERNAME' AND j_post_params ? 'PASSWORD' AND j_post_params->>'PGAPEX_OP' = 'LOGIN' THEN
    SELECT is_permitted INTO b_is_permitted
    FROM pgapex.application a,
        dblink(
          pgapex.f_app_get_dblink_connection_name()
        , 'select ' || a.authentication_function_schema_name || '.' || a.authentication_function_name || '(' || quote_nullable(j_post_params->>'USERNAME') || ',' || quote_nullable(j_post_params->>'PASSWORD') || ')'
        , false
        ) AS ( is_permitted BOOLEAN )
    WHERE application_id = i_application_id;

    IF b_is_permitted THEN
      PERFORM pgapex.f_app_session_write('is_authenticated', TRUE::VARCHAR);
      PERFORM pgapex.f_app_session_write('username', j_post_params->>'USERNAME');
      PERFORM pgapex.f_app_add_setting('username', j_post_params->>'USERNAME');
    ELSE
      PERFORM pgapex.f_app_add_error_message('Permission denied!');
    END IF;
  ELSIF j_post_params ? 'PGAPEX_REGION' THEN
    PERFORM pgapex.f_app_form_region_submit(i_page_id, (j_post_params->>'PGAPEX_REGION')::int, j_post_params);
  END IF;
END
$$;


ALTER FUNCTION pgapex.f_app_parse_operation(i_application_id integer, i_page_id integer, v_method character varying, j_headers jsonb, j_get_params jsonb, j_post_params jsonb) OWNER TO t143682;

--
-- Name: f_app_query_page(character varying, character varying, character varying, character varying, jsonb, jsonb, jsonb); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_query_page(v_application_root character varying, v_application_id character varying, v_page_id character varying, v_method character varying, j_headers jsonb, j_get_params jsonb, j_post_params jsonb) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  j_response       JSON;
  t_response_body  TEXT;
  i_application_id INT;
  i_page_id        INT;
BEGIN
  PERFORM pgapex.f_app_create_temp_tables();
  SELECT pgapex.f_app_get_application_id(v_application_id) INTO i_application_id;

  IF i_application_id IS NULL THEN
    SELECT pgapex.f_app_error('Application does not exist: ' || v_application_id) INTO t_response_body;
    SELECT pgapex.f_app_create_response(t_response_body) INTO j_response;
    RETURN j_response;
  END IF;

  PERFORM pgapex.f_app_open_session(v_application_root, i_application_id, j_headers);

  SELECT pgapex.f_app_get_page_id(i_application_id, v_page_id) INTO i_page_id;

  IF i_page_id IS NULL THEN
    SELECT page_id INTO i_page_id FROM pgapex.page WHERE application_id = i_application_id AND is_homepage = true;
    IF i_page_id IS NULL THEN
      SELECT pgapex.f_app_error('Application does not have any pages') INTO t_response_body;
      SELECT pgapex.f_app_create_response(t_response_body) INTO j_response;
      RETURN j_response;
    ELSE
      PERFORM pgapex.f_app_set_header('location', v_application_root || '/app/' || v_application_id || '/' || i_page_id);
      SELECT pgapex.f_app_create_response('') INTO j_response;
      RETURN j_response;
    END IF;
  END IF;

  PERFORM pgapex.f_app_add_setting('application_root', v_application_root);
  PERFORM pgapex.f_app_add_setting('application_id', i_application_id::varchar);
  PERFORM pgapex.f_app_add_setting('page_id', i_page_id::varchar);
  BEGIN
    PERFORM pgapex.f_app_dblink_connect(i_application_id);
    PERFORM pgapex.f_app_parse_operation(i_application_id, i_page_id, v_method, j_headers, j_get_params, j_post_params);
    SELECT pgapex.f_app_create_page(i_application_id, i_page_id, j_get_params, j_post_params) INTO t_response_body;
  EXCEPTION
    WHEN OTHERS THEN
      SELECT pgapex.f_app_error('System error: ' || SQLERRM) INTO t_response_body;
  END;
  PERFORM pgapex.f_app_dblink_disconnect();
  SELECT pgapex.f_app_create_response(t_response_body) INTO j_response;
  RETURN j_response;
END
$$;


ALTER FUNCTION pgapex.f_app_query_page(v_application_root character varying, v_application_id character varying, v_page_id character varying, v_method character varying, j_headers jsonb, j_get_params jsonb, j_post_params jsonb) OWNER TO t143682;

--
-- Name: f_app_replace_system_variables(text); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_replace_system_variables(t_template text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  t_template := replace(t_template, '&SESSION_ID&', COALESCE(pgapex.f_app_get_session_id(), ''));
  t_template := replace(t_template, '&APPLICATION_ROOT&', COALESCE(pgapex.f_app_get_setting('application_root'), ''));
  t_template := replace(t_template, '&APPLICATION_ID&', COALESCE(pgapex.f_app_get_setting('application_id'), ''));
  t_template := replace(t_template, '&PAGE_ID&', COALESCE(pgapex.f_app_get_setting('page_id'), ''));
  t_template := replace(t_template, '&USERNAME&', COALESCE(pgapex.f_app_get_setting('username'), ''));
  t_template := replace(t_template, '&APPLICATION_NAME&', (SELECT COALESCE(name, '') FROM pgapex.application WHERE application_id = pgapex.f_app_get_setting('application_id')::int));
  t_template := replace(t_template, '&TITLE&', (SELECT COALESCE(title, '') FROM pgapex.page WHERE page_id = pgapex.f_app_get_setting('page_id')::int));
  t_template := replace(t_template, '&LOGOUT_LINK&', COALESCE(pgapex.f_app_get_logout_link(), ''));
  RETURN t_template;
END
$$;


ALTER FUNCTION pgapex.f_app_replace_system_variables(t_template text) OWNER TO t143682;

--
-- Name: f_app_session_read(character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_session_read(v_key character varying) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  j_session_data JSONB;
  j_value        VARCHAR;
BEGIN
  SELECT data INTO j_session_data FROM pgapex.session WHERE session_id = pgapex.f_app_get_session_id();
  IF j_session_data IS NOT NULL AND j_session_data ? lower(v_key) THEN
    SELECT j_session_data->>lower(v_key) INTO j_value;
    RETURN j_value;
  END IF;
  RETURN NULL;
END
$$;


ALTER FUNCTION pgapex.f_app_session_read(v_key character varying) OWNER TO t143682;

--
-- Name: f_app_session_write(character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_session_write(v_key character varying, v_value character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  j_new_session_data JSONB;
BEGIN
  WITH session_data AS (
    SELECT data FROM pgapex.session WHERE session_id = pgapex.f_app_get_session_id()
  ), concat_json AS (
    SELECT s1.key, s1.value FROM jsonb_each(json_build_object(lower(v_key), v_value)::jsonb) s1
    UNION ALL
    SELECT s2.key, s2.value FROM session_data, jsonb_each(session_data.data) s2
  ), with_unique_keys AS (
    SELECT DISTINCT ON (key) key, value FROM concat_json
  )
  SELECT json_object_agg(key, value) INTO j_new_session_data FROM with_unique_keys;

  UPDATE pgapex.session SET data = j_new_session_data
  WHERE session_id = pgapex.f_app_get_session_id();
END
$$;


ALTER FUNCTION pgapex.f_app_session_write(v_key character varying, v_value character varying) OWNER TO t143682;

--
-- Name: f_app_set_cookie(character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_set_cookie(v_cookie_name character varying, v_cookie_value character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  PERFORM pgapex.f_app_set_header('set-cookie', v_cookie_name || '=' || v_cookie_value);
END
$$;


ALTER FUNCTION pgapex.f_app_set_cookie(v_cookie_name character varying, v_cookie_value character varying) OWNER TO t143682;

--
-- Name: f_app_set_header(character varying, text); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_app_set_header(v_field_name character varying, t_value text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  DELETE FROM temp_headers WHERE transaction_id = txid_current() AND field_name = lower(v_field_name);
  INSERT INTO temp_headers(transaction_id, field_name, value) VALUES (txid_current(), lower(v_field_name), t_value);
END
$$;


ALTER FUNCTION pgapex.f_app_set_header(v_field_name character varying, t_value text) OWNER TO t143682;

--
-- Name: f_application_application_may_have_a_name(integer, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_application_application_may_have_a_name(i_id integer, v_name character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  b_name_already_exists BOOLEAN;
BEGIN
  IF i_id IS NULL THEN
    SELECT COUNT(1) = 0 INTO b_name_already_exists FROM pgapex.application WHERE name = v_name;
  ELSE
    SELECT COUNT(1) = 0 INTO b_name_already_exists FROM pgapex.application WHERE name = v_name AND application_id <> i_id;
  END IF;
  RETURN b_name_already_exists;
END
$$;


ALTER FUNCTION pgapex.f_application_application_may_have_a_name(i_id integer, v_name character varying) OWNER TO t143682;

--
-- Name: f_application_application_may_have_an_alias(integer, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_application_application_may_have_an_alias(i_id integer, v_alias character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  b_alias_already_exists BOOLEAN;
BEGIN
  IF i_id IS NULL THEN
    SELECT COUNT(1) = 0 INTO b_alias_already_exists FROM pgapex.application WHERE alias = v_alias;
  ELSE
    SELECT COUNT(1) = 0 INTO b_alias_already_exists FROM pgapex.application WHERE alias = v_alias AND application_id <> i_id;
  END IF;
  RETURN b_alias_already_exists;
END
$$;


ALTER FUNCTION pgapex.f_application_application_may_have_an_alias(i_id integer, v_alias character varying) OWNER TO t143682;

--
-- Name: f_application_delete_application(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_application_delete_application(i_id integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  DELETE FROM pgapex.application
  WHERE application_id = i_id;
  RETURN FOUND;
END
$$;


ALTER FUNCTION pgapex.f_application_delete_application(i_id integer) OWNER TO t143682;

--
-- Name: f_application_get_application(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_application_get_application(i_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
SELECT
  json_build_object(
      'id', application_id
      , 'type', 'application'
      , 'attributes', json_build_object(
          'name', name
          , 'alias', alias
          , 'database', database_name
          , 'databaseUsername', database_username
      )
  )
FROM pgapex.application
WHERE application_id = i_id
$$;


ALTER FUNCTION pgapex.f_application_get_application(i_id integer) OWNER TO t143682;

--
-- Name: f_application_get_application_authentication(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_application_get_application_authentication(i_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT
  json_build_object(
    'id', application_id
  , 'type', 'application-authentication'
  , 'attributes', json_build_object(
      'authenticationScheme', authentication_scheme_id
    , 'authenticationFunction', json_build_object(
        'database', database_name
      , 'schema', authentication_function_schema_name
      , 'function', authentication_function_name
      )
    , 'loginPageTemplate', login_page_template_id
    )
  )
  FROM pgapex.application
  WHERE application_id = i_id
$$;


ALTER FUNCTION pgapex.f_application_get_application_authentication(i_id integer) OWNER TO t143682;

--
-- Name: f_application_get_applications(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_application_get_applications() RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT COALESCE(JSON_AGG(a), '[]')
  FROM (
    SELECT
      application_id AS id
    , 'application' AS type
    , json_build_object(
        'alias', alias
      , 'name', name
    ) AS attributes
    FROM pgapex.application
    ORDER BY name
  ) a
$$;


ALTER FUNCTION pgapex.f_application_get_applications() OWNER TO t143682;

--
-- Name: f_application_save_application(integer, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_application_save_application(i_id integer, v_name character varying, v_alias character varying, v_database character varying, v_database_username character varying, v_database_password character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $_$
BEGIN
  IF pgapex.f_user_exists(v_database_username, v_database_password) = FALSE THEN
    RAISE EXCEPTION 'Application username and password do not match.';
  END IF;
  IF (v_alias ~* '.*[a-z].*') = FALSE OR (v_alias ~* '^\w*$') = FALSE THEN
    RAISE EXCEPTION 'Application alias must contain characters (included underscore) and may contain numbers.';
  END IF;
  IF pgapex.f_application_application_may_have_an_alias(i_id, v_alias) = FALSE THEN
    RAISE EXCEPTION 'Application alias is already taken.';
  END IF;
  IF i_id IS NULL THEN
    INSERT INTO pgapex.application (name, alias, database_name, database_username, database_password)
    VALUES (v_name, v_alias, v_database, v_database_username, v_database_password);
  ELSE
    UPDATE pgapex.application
    SET name = v_name
    ,   alias = v_alias
    ,   database_name = v_database
    ,   database_username = v_database_username
    ,   database_password = v_database_password
    WHERE application_id = i_id;
  END IF;
  RETURN FOUND;
END
$_$;


ALTER FUNCTION pgapex.f_application_save_application(i_id integer, v_name character varying, v_alias character varying, v_database character varying, v_database_username character varying, v_database_password character varying) OWNER TO t143682;

--
-- Name: f_application_save_application_authentication(integer, character varying, character varying, character varying, integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_application_save_application_authentication(i_id integer, v_authentication_scheme character varying, v_authentication_function_schema_name character varying, v_authentication_function_name character varying, i_login_page_template integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  IF v_authentication_scheme = 'NO_AUTHENTICATION' THEN
    UPDATE pgapex.application
    SET authentication_scheme_id = v_authentication_scheme
      ,   authentication_function_schema_name = NULL
      ,   authentication_function_name = NULL
      ,   login_page_template_id = NULL
    WHERE application_id = i_id;
  ELSE
    UPDATE pgapex.application
    SET authentication_scheme_id = v_authentication_scheme
    ,   authentication_function_schema_name = v_authentication_function_schema_name
    ,   authentication_function_name = v_authentication_function_name
    ,   login_page_template_id = i_login_page_template
    WHERE application_id = i_id;
  END IF;
  RETURN FOUND;
END
$$;


ALTER FUNCTION pgapex.f_application_save_application_authentication(i_id integer, v_authentication_scheme character varying, v_authentication_function_schema_name character varying, v_authentication_function_name character varying, i_login_page_template integer) OWNER TO t143682;

--
-- Name: f_database_object_get_authentication_functions(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_database_object_get_authentication_functions(i_application_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  WITH boolean_functions_with_two_parameters AS (
      SELECT f.database_name, f.schema_name, f.function_name, f.return_type, p.parameter_type
      FROM pgapex.application a
        LEFT JOIN pgapex.function f ON a.database_name = f.database_name
        LEFT JOIN pgapex.parameter p ON (a.database_name = p.database_name AND p.schema_name = f.schema_name AND p.function_name = f.function_name)
      WHERE f.return_type = 'bool'
        AND a.application_id = i_application_id
      GROUP BY f.database_name, f.schema_name, f.function_name, f.return_type, p.parameter_type
      HAVING MAX(p.ordinal_position) = 2
      ORDER BY f.database_name, f.schema_name, f.function_name
  )
  SELECT json_agg(
    json_build_object(
      'type', 'login-function'
    , 'attributes', json_build_object(
        'database', f.database_name
        , 'schema',   f.schema_name
        , 'function', f.function_name
      )
    )
  )
  FROM boolean_functions_with_two_parameters f
  WHERE f.parameter_type IN ('text', 'varchar')
$$;


ALTER FUNCTION pgapex.f_database_object_get_authentication_functions(i_application_id integer) OWNER TO t143682;

--
-- Name: f_database_object_get_databases(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_database_object_get_databases() RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
SELECT COALESCE(JSON_AGG(a), '[]')
FROM (
       SELECT
           database_name AS id
         , 'database' AS type
         , json_build_object(
               'name', database_name
           ) AS attributes
       FROM pgapex.database
       ORDER BY database_name
     ) a
$$;


ALTER FUNCTION pgapex.f_database_object_get_databases() OWNER TO t143682;

--
-- Name: f_database_object_get_functions_with_parameters(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_database_object_get_functions_with_parameters(i_application_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
WITH functions_with_parameters AS (
    SELECT
      json_build_object(
            'id', p.database_specific_name
          , 'type', 'function'
          , 'attributes', json_build_object(
                'schema', p.schema_name
              , 'name', p.function_name
              , 'parameters', json_agg(
                  json_build_object(
                        'id', p.database_name || '.' || p.schema_name || '.' || p.function_name || '.' || p.ordinal_position
                      , 'type', 'parameter'
                      , 'attributes', json_build_object(
                          'name', p.parameter_name
                        , 'argumentType', p.parameter_type
                        , 'ordinalPosition', p.ordinal_position
                      )
                  )
              )
          )
      ) AS fwp
    FROM pgapex.application a
    LEFT JOIN pgapex.parameter p ON a.database_name = p.database_name
    WHERE a.application_id = i_application_id
    GROUP BY p.database_specific_name, p.database_name, p.schema_name, p.function_name
    ORDER BY p.database_name, p.schema_name, p.function_name
)
SELECT
  COALESCE(json_agg(functions_with_parameters.fwp), '[]')
FROM functions_with_parameters;
$$;


ALTER FUNCTION pgapex.f_database_object_get_functions_with_parameters(i_application_id integer) OWNER TO t143682;

--
-- Name: f_database_object_get_views_with_columns(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_database_object_get_views_with_columns(i_application_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
WITH views_with_columns AS (
    SELECT
      json_build_object(
            'id', vc.database_name || '.' || vc.schema_name || '.' || vc.view_name
          , 'type', 'view'
          , 'attributes', json_build_object(
                'schema', vc.schema_name
              , 'name', vc.view_name
              , 'columns', json_agg(
                  json_build_object(
                        'id', vc.database_name || '.' || vc.schema_name || '.' || vc.view_name || '.' || vc.column_name
                      , 'type', 'column'
                      , 'attributes', json_build_object(
                          'name', vc.column_name
                      )
                  )
              )
          )
      ) AS vwc
    FROM pgapex.application a
      LEFT JOIN pgapex.view_column vc ON a.database_name = vc.database_name
    WHERE a.application_id = i_application_id
    GROUP BY vc.database_name, vc.schema_name, vc.view_name
)
SELECT
  COALESCE(json_agg(views_with_columns.vwc), '[]')
FROM views_with_columns;
$$;


ALTER FUNCTION pgapex.f_database_object_get_views_with_columns(i_application_id integer) OWNER TO t143682;

--
-- Name: f_get_function_meta_info(character varying, character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_get_function_meta_info(database character varying, username character varying, password character varying) RETURNS TABLE(schema_name character varying, function_name character varying, return_type character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    res_schema_name
  , res_function_name
  , res_return_type
  FROM
  dblink(
    'dbname=' || database || ' user=' || username || ' password=' || password,
    'SELECT n.nspname, p.proname, t.typname ' ||
    'FROM pg_catalog.pg_proc p ' ||
    'LEFT JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid ' ||
    'LEFT JOIN pg_catalog.pg_type t ON p.prorettype = t.oid ' ||
    'WHERE ' ||
    '    n.nspname NOT IN (''information_schema'', ''pg_catalog'') ' ||
    'AND n.nspname NOT LIKE ''pg_toast%'' ' ||
    'AND n.nspname NOT LIKE ''pg_temp%'''
  ) AS (
    res_schema_name   VARCHAR
  , res_function_name VARCHAR
  , res_return_type   VARCHAR
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN;
END
$$;


ALTER FUNCTION pgapex.f_get_function_meta_info(database character varying, username character varying, password character varying) OWNER TO t143682;

--
-- Name: f_get_function_parameter_meta_info(character varying, character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_get_function_parameter_meta_info(database character varying, username character varying, password character varying) RETURNS TABLE(specific_name character varying, schema_name character varying, function_name character varying, parameter_name character varying, ordinal_position integer, parameter_type character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    res_specific_name
  , res_schema_name
  , res_function_name
  , res_parameter_name
  , res_ordinal_position
  , res_parameter_type
  FROM
  dblink(
    'dbname=' || database || ' user=' || username || ' password=' || password,
    'SELECT r.specific_name, r.routine_schema, r.routine_name, p.parameter_name, p.ordinal_position, p.udt_name ' ||
    'FROM information_schema.routines r ' ||
    'JOIN information_schema.parameters p ON r.specific_name = p.specific_name ' ||
    'WHERE r.routine_type = ''FUNCTION'' ' ||
    '  AND r.routine_schema NOT IN (''pg_catalog'', ''information_schema'') ' ||
    '  AND r.routine_schema NOT LIKE ''pg_toast%'' ' ||
    '  AND r.routine_schema NOT LIKE ''pg_temp%'''
  ) AS (
    res_specific_name    VARCHAR
  , res_schema_name      VARCHAR
  , res_function_name    VARCHAR
  , res_parameter_name   VARCHAR
  , res_ordinal_position INT
  , res_parameter_type   VARCHAR
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN;
END
$$;


ALTER FUNCTION pgapex.f_get_function_parameter_meta_info(database character varying, username character varying, password character varying) OWNER TO t143682;

--
-- Name: f_get_schema_meta_info(character varying, character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_get_schema_meta_info(database character varying, username character varying, password character varying) RETURNS TABLE(schema_name character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  RETURN QUERY
  SELECT res_schema_name
  FROM
  dblink(
    'dbname=' || database || ' user=' || username || ' password=' || password,
    'SELECT nspname FROM pg_catalog.pg_namespace ' ||
    'WHERE nspname NOT IN (''information_schema'', ''pg_catalog'') ' ||
    '  AND nspname NOT LIKE ''pg_toast%'' ' ||
    '  AND nspname NOT LIKE ''pg_temp%'''
  ) AS (
    res_schema_name VARCHAR
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN;
END
$$;


ALTER FUNCTION pgapex.f_get_schema_meta_info(database character varying, username character varying, password character varying) OWNER TO t143682;

--
-- Name: f_get_view_column_meta_info(character varying, character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_get_view_column_meta_info(database character varying, username character varying, password character varying) RETURNS TABLE(schema_name character varying, view_name character varying, column_name character varying, column_type character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    res_schema_name
  , res_view_name
  , res_column_name
  , res_column_type
  FROM
  dblink(
    'dbname=' || database || ' user=' || username || ' password=' || password,
    'SELECT n.nspname, c.relname, a.attname, t.typname ' ||
    'FROM pg_catalog.pg_class c ' ||
    'LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace ' ||
    'LEFT JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid ' ||
    'LEFT JOIN pg_catalog.pg_type t ON a.atttypid = t.oid ' ||
    'WHERE c.relkind IN (''v'', ''m'') ' ||
    '  AND n.nspname NOT IN (''information_schema'', ''pg_catalog'') ' ||
    '  AND n.nspname NOT LIKE ''pg_toast%'' ' ||
    '  AND n.nspname NOT LIKE ''pg_temp%'' ' ||
    '  AND a.attnum > 0 ' ||
    '  AND NOT a.attisdropped'
  ) AS (
    res_schema_name VARCHAR
  , res_view_name   VARCHAR
  , res_column_name VARCHAR
  , res_column_type VARCHAR
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN;
END
$$;


ALTER FUNCTION pgapex.f_get_view_column_meta_info(database character varying, username character varying, password character varying) OWNER TO t143682;

--
-- Name: f_get_view_meta_info(character varying, character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_get_view_meta_info(database character varying, username character varying, password character varying) RETURNS TABLE(schema_name character varying, view_name character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  RETURN QUERY
  SELECT
    res_schema_name
  , res_view_name
  FROM
  dblink(
    'dbname=' || database || ' user=' || username || ' password=' || password,
    'SELECT n.nspname, c.relname ' ||
    'FROM pg_class c ' ||
    'LEFT JOIN pg_namespace n ON n.oid = c.relnamespace ' ||
    'WHERE c.relkind IN (''v'', ''m'') ' ||
    '  AND n.nspname NOT IN (''information_schema'', ''pg_catalog'') ' ||
    '  AND n.nspname NOT LIKE ''pg_toast%'' ' ||
    '  AND n.nspname NOT LIKE ''pg_temp%'''
  ) AS (
    res_schema_name VARCHAR
  , res_view_name VARCHAR
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN;
END
$$;


ALTER FUNCTION pgapex.f_get_view_meta_info(database character varying, username character varying, password character varying) OWNER TO t143682;

--
-- Name: f_is_superuser(character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_is_superuser(username character varying, password character varying) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $_$
  SELECT EXISTS(
    SELECT 1
    FROM pg_catalog.pg_shadow
    WHERE usename = $1
      AND (passwd = 'md5' || md5($2 || $1)
        OR passwd IS NULL
      )
      AND usesuper = TRUE
      AND (valuntil IS NULL
        OR valuntil > current_timestamp
      )
  );
$_$;


ALTER FUNCTION pgapex.f_is_superuser(username character varying, password character varying) OWNER TO t143682;

--
-- Name: f_navigation_delete_navigation(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_navigation_delete_navigation(i_navigation_id integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  DELETE FROM pgapex.navigation WHERE navigation_id = i_navigation_id;
  RETURN FOUND;
END
$$;


ALTER FUNCTION pgapex.f_navigation_delete_navigation(i_navigation_id integer) OWNER TO t143682;

--
-- Name: f_navigation_delete_navigation_item(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_navigation_delete_navigation_item(i_navigation_item_id integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  DELETE FROM pgapex.navigation_item WHERE navigation_item_id = i_navigation_item_id;
  RETURN FOUND;
END
$$;


ALTER FUNCTION pgapex.f_navigation_delete_navigation_item(i_navigation_item_id integer) OWNER TO t143682;

--
-- Name: f_navigation_get_navigation(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_navigation_get_navigation(i_navigation_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT
  json_build_object(
    'id', navigation_id
  , 'type', 'navigation'
  , 'attributes', json_build_object(
      'name', name
    )
  )
  FROM pgapex.navigation
  WHERE navigation_id = i_navigation_id
$$;


ALTER FUNCTION pgapex.f_navigation_get_navigation(i_navigation_id integer) OWNER TO t143682;

--
-- Name: f_navigation_get_navigation_item(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_navigation_get_navigation_item(i_navigation_item_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT
  json_build_object(
    'id', navigation_id
  , 'type', 'navigation-item'
  , 'attributes', json_build_object(
      'name', name
    , 'parentNavigationItemId', parent_navigation_item_id
    , 'sequence', sequence
    , 'page', page_id
    , 'url', url
    )
  )
  FROM pgapex.navigation_item
  WHERE navigation_item_id = i_navigation_item_id
$$;


ALTER FUNCTION pgapex.f_navigation_get_navigation_item(i_navigation_item_id integer) OWNER TO t143682;

--
-- Name: f_navigation_get_navigation_items(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_navigation_get_navigation_items(i_navigation_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
SELECT COALESCE(JSON_AGG(a), '[]')
FROM (
  SELECT
    ni.navigation_item_id AS id
  , 'navigation-item' AS type
  , json_build_object(
      'name', ni.name
    , 'parentNavigationItemId', ni.parent_navigation_item_id
    , 'sequence', ni.sequence
    , 'url', ni.url
    , 'page', (
        CASE
          WHEN ni.page_id IS NULL THEN NULL
          ELSE json_build_object(
              'id', ni.page_id
            , 'title', p.title
          )
        END
      )
    ) AS attributes
  FROM pgapex.navigation_item AS ni
  LEFT JOIN pgapex.page AS p ON ni.page_id = p.page_id
  WHERE ni.navigation_id = i_navigation_id
  ORDER BY ni.sequence, ni.name
) a
$$;


ALTER FUNCTION pgapex.f_navigation_get_navigation_items(i_navigation_id integer) OWNER TO t143682;

--
-- Name: f_navigation_get_navigations(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_navigation_get_navigations(i_application_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT COALESCE(JSON_AGG(a), '[]')
  FROM (
    SELECT
      navigation_id AS id
    , 'navigation' AS type
    , json_build_object(
        'name', name
    ) AS attributes
    FROM pgapex.navigation
    WHERE application_id = i_application_id
    ORDER BY name
  ) a
$$;


ALTER FUNCTION pgapex.f_navigation_get_navigations(i_application_id integer) OWNER TO t143682;

--
-- Name: f_navigation_navigation_item_contains_cycle(integer, integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_navigation_navigation_item_contains_cycle(i_navigation_item_id integer, i_parent_navigation_item_id integer) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (
      WITH RECURSIVE navigation_item_search_graph(parent_id, path, has_cycle)
      AS (
        SELECT i_parent_navigation_item_id, ARRAY[i_navigation_item_id, i_parent_navigation_item_id], (i_navigation_item_id = i_parent_navigation_item_id)

        UNION ALL

        SELECT ni.parent_navigation_item_id, nisg.path || ni.parent_navigation_item_id, ni.parent_navigation_item_id = ANY(nisg.path)
        FROM navigation_item_search_graph nisg
        JOIN pgapex.navigation_item ni ON ni.navigation_item_id = nisg.parent_id
        WHERE NOT nisg.has_cycle
      )
      SELECT 1
      FROM navigation_item_search_graph
      WHERE has_cycle
      LIMIT 1
  );
$$;


ALTER FUNCTION pgapex.f_navigation_navigation_item_contains_cycle(i_navigation_item_id integer, i_parent_navigation_item_id integer) OWNER TO t143682;

--
-- Name: f_navigation_navigation_item_may_have_a_sequence(integer, integer, integer, integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_navigation_navigation_item_may_have_a_sequence(i_navigation_item_id integer, i_navigation_id integer, i_parent_navigation_item_id integer, i_sequence integer) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT NOT EXISTS(
    SELECT 1 FROM pgapex.navigation_item
    WHERE
      (CASE
        WHEN i_navigation_item_id IS NULL THEN TRUE
        ELSE navigation_item_id <> i_navigation_item_id
      END)
      AND navigation_id = i_navigation_id
      AND (
       CASE
         WHEN i_parent_navigation_item_id IS NULL THEN parent_navigation_item_id IS NULL
         ELSE parent_navigation_item_id = i_parent_navigation_item_id
       END)
      AND sequence = i_sequence
  );
$$;


ALTER FUNCTION pgapex.f_navigation_navigation_item_may_have_a_sequence(i_navigation_item_id integer, i_navigation_id integer, i_parent_navigation_item_id integer, i_sequence integer) OWNER TO t143682;

--
-- Name: f_navigation_navigation_item_may_refer_to_page(integer, integer, integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_navigation_navigation_item_may_refer_to_page(i_navigation_item_id integer, i_navigation_id integer, i_page_id integer) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT NOT EXISTS(
    SELECT 1 FROM pgapex.navigation_item
    WHERE
      navigation_id = i_navigation_id
      AND (
       CASE
         WHEN i_page_id IS NULL THEN FALSE
         ELSE page_id = i_page_id
       END)
      AND (
       CASE
         WHEN i_navigation_item_id IS NULL THEN TRUE
         ELSE navigation_item_id <> i_navigation_item_id
       END)
  );
$$;


ALTER FUNCTION pgapex.f_navigation_navigation_item_may_refer_to_page(i_navigation_item_id integer, i_navigation_id integer, i_page_id integer) OWNER TO t143682;

--
-- Name: f_navigation_navigation_may_have_a_name(integer, integer, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_navigation_navigation_may_have_a_name(i_navigation_id integer, i_application_id integer, v_name character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  b_name_already_exists BOOLEAN;
BEGIN
  IF i_navigation_id IS NULL THEN
    SELECT COUNT(1) = 0 INTO b_name_already_exists
    FROM pgapex.navigation WHERE name = v_name AND application_id = i_application_id;
  ELSE
    SELECT COUNT(1) = 0 INTO b_name_already_exists
    FROM pgapex.navigation WHERE name = v_name AND application_id = i_application_id AND navigation_id <> i_navigation_id;
  END IF;
  RETURN b_name_already_exists;
END
$$;


ALTER FUNCTION pgapex.f_navigation_navigation_may_have_a_name(i_navigation_id integer, i_application_id integer, v_name character varying) OWNER TO t143682;

--
-- Name: f_navigation_save_navigation(integer, integer, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_navigation_save_navigation(i_navigation_id integer, i_application_id integer, v_name character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  IF i_navigation_id IS NULL THEN
    INSERT INTO pgapex.navigation (application_id, name) VALUES (i_application_id, v_name);
  ELSE
    UPDATE pgapex.navigation
    SET application_id = i_application_id
    ,   name = v_name
    WHERE navigation_id = i_navigation_id;
  END IF;
  RETURN FOUND;
END
$$;


ALTER FUNCTION pgapex.f_navigation_save_navigation(i_navigation_id integer, i_application_id integer, v_name character varying) OWNER TO t143682;

--
-- Name: f_navigation_save_navigation_item(integer, integer, integer, character varying, integer, integer, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_navigation_save_navigation_item(i_navigation_item_id integer, i_parent_navigation_item_id integer, i_navigation_id integer, v_name character varying, i_sequence integer, i_page_id integer, v_url character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  IF i_navigation_item_id IS NULL THEN
    INSERT INTO pgapex.navigation_item (parent_navigation_item_id, navigation_id, name, sequence, page_id, url)
    VALUES (i_parent_navigation_item_id, i_navigation_id, v_name, i_sequence, i_page_id, v_url);
  ELSE
    UPDATE pgapex.navigation_item
    SET parent_navigation_item_id = i_parent_navigation_item_id
    ,   navigation_id = i_navigation_id
    ,   name = v_name
    ,   sequence = i_sequence
    ,   page_id = i_page_id
    ,   url = v_url
    WHERE navigation_item_id = i_navigation_item_id;
  END IF;
  RETURN FOUND;
END
$$;


ALTER FUNCTION pgapex.f_navigation_save_navigation_item(i_navigation_item_id integer, i_parent_navigation_item_id integer, i_navigation_id integer, v_name character varying, i_sequence integer, i_page_id integer, v_url character varying) OWNER TO t143682;

--
-- Name: f_page_delete_page(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_page_delete_page(i_page_id integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  b_homepage_exists BOOLEAN;
  i_application_id INT;
BEGIN
  SELECT application_id INTO i_application_id
  FROM pgapex.page WHERE page_id = i_page_id;

  DELETE FROM pgapex.page WHERE page_id = i_page_id;

  SELECT count(1) > 0 INTO b_homepage_exists
  FROM pgapex.page
  WHERE application_id = i_application_id
        AND is_homepage = TRUE;

  IF b_homepage_exists = FALSE THEN
    UPDATE pgapex.page
    SET is_homepage = TRUE
    WHERE page_id = (
      SELECT page_id FROM pgapex.page ORDER BY is_authentication_required ASC LIMIT 1
    );
  END IF;
  RETURN TRUE;
END
$$;


ALTER FUNCTION pgapex.f_page_delete_page(i_page_id integer) OWNER TO t143682;

--
-- Name: f_page_get_page(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_page_get_page(i_page_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT
  json_build_object(
    'id', application_id
  , 'type', 'page'
  , 'attributes', json_build_object(
      'title', title
    , 'alias', alias
    , 'template', template_id
    , 'isHomepage', is_homepage
    , 'isAuthenticationRequired', is_authentication_required
    )
  )
  FROM pgapex.page
  WHERE page_id = i_page_id
$$;


ALTER FUNCTION pgapex.f_page_get_page(i_page_id integer) OWNER TO t143682;

--
-- Name: f_page_get_pages(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_page_get_pages(i_application_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT COALESCE(JSON_AGG(a), '[]')
  FROM (
    SELECT
      page_id AS id
    , 'page' AS type
    , json_build_object(
        'title', title
      , 'alias', alias
      , 'isHomepage', is_homepage
      , 'isAuthenticationRequired', is_authentication_required
    ) AS attributes
    FROM pgapex.page
    WHERE application_id = i_application_id
    ORDER BY title, alias
  ) a
$$;


ALTER FUNCTION pgapex.f_page_get_pages(i_application_id integer) OWNER TO t143682;

--
-- Name: f_page_page_may_have_an_alias(integer, integer, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_page_page_may_have_an_alias(i_page_id integer, i_application_id integer, v_alias character varying) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM pgapex.page
    WHERE application_id = i_application_id
    AND alias = v_alias
    AND (
      CASE
        WHEN i_page_id IS NULL THEN TRUE
        ELSE page_id <> i_page_id
      END
    )
  );
$$;


ALTER FUNCTION pgapex.f_page_page_may_have_an_alias(i_page_id integer, i_application_id integer, v_alias character varying) OWNER TO t143682;

--
-- Name: f_page_save_page(integer, integer, integer, character varying, character varying, boolean, boolean); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_page_save_page(i_page_id integer, i_application_id integer, i_template_id integer, v_title character varying, v_alias character varying, b_is_homepage boolean, b_is_authentication_required boolean) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $_$
DECLARE
  b_homepage_exists BOOLEAN;
BEGIN
  IF (v_alias ~* '.*[a-z].*') = FALSE OR (v_alias ~* '^\w*$') = FALSE THEN
    RAISE EXCEPTION 'Page alias must contain characters (included underscore) and may contain numbers.';
  END IF;
  IF b_is_homepage THEN
    UPDATE pgapex.page
    SET is_homepage = FALSE
    WHERE application_id = i_application_id;
  ELSE
    SELECT count(1) > 0 INTO b_homepage_exists
    FROM pgapex.page
    WHERE application_id = i_application_id
      AND is_homepage = TRUE
      AND page_id <> COALESCE(i_page_id, -1);
    IF b_homepage_exists = FALSE THEN
      b_is_homepage = TRUE;
    END IF;
  END IF;
  IF i_page_id IS NULL THEN
    INSERT INTO pgapex.page (application_id, template_id, title, alias, is_homepage, is_authentication_required)
    VALUES (i_application_id, i_template_id, v_title, v_alias, b_is_homepage, b_is_authentication_required);
  ELSE
    UPDATE pgapex.page
    SET application_id = i_application_id
    ,   template_id = i_template_id
    ,   title = v_title
    ,   alias = v_alias
    ,   is_homepage = b_is_homepage
    ,   is_authentication_required = b_is_authentication_required
    WHERE page_id = i_page_id;
  END IF;
  RETURN FOUND;
END
$_$;


ALTER FUNCTION pgapex.f_page_save_page(i_page_id integer, i_application_id integer, i_template_id integer, v_title character varying, v_alias character varying, b_is_homepage boolean, b_is_authentication_required boolean) OWNER TO t143682;

--
-- Name: f_refresh_database_objects(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_refresh_database_objects() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  REFRESH MATERIALIZED VIEW pgapex.database;
  REFRESH MATERIALIZED VIEW pgapex.schema;
  REFRESH MATERIALIZED VIEW pgapex.function;
  REFRESH MATERIALIZED VIEW pgapex.parameter;
  REFRESH MATERIALIZED VIEW pgapex.view;
  REFRESH MATERIALIZED VIEW pgapex.view_column;
  REFRESH MATERIALIZED VIEW pgapex.data_type;
END
$$;


ALTER FUNCTION pgapex.f_refresh_database_objects() OWNER TO t143682;

--
-- Name: f_region_create_report_region_column(integer, character varying, character varying, integer, boolean); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_create_report_region_column(i_region_id integer, v_view_column_name character varying, v_heading character varying, i_sequence integer, b_is_text_escaped boolean) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  i_new_report_column_id INT;
BEGIN
  SELECT nextval('pgapex.report_column_report_column_id_seq') INTO i_new_report_column_id;
  INSERT INTO pgapex.report_column (report_column_id, region_id, report_column_type_id, view_column_name, heading, sequence, is_text_escaped)
    VALUES (i_new_report_column_id, i_region_id, 'COLUMN', v_view_column_name, v_heading, i_sequence, b_is_text_escaped);
  RETURN FOUND;
END
$$;


ALTER FUNCTION pgapex.f_region_create_report_region_column(i_region_id integer, v_view_column_name character varying, v_heading character varying, i_sequence integer, b_is_text_escaped boolean) OWNER TO t143682;

--
-- Name: f_region_create_report_region_link(integer, character varying, integer, boolean, character varying, character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_create_report_region_link(i_region_id integer, v_heading character varying, i_sequence integer, b_is_text_escaped boolean, v_url character varying, v_link_text character varying, v_attributes character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  i_new_report_column_id INT;
BEGIN
  SELECT nextval('pgapex.report_column_report_column_id_seq') INTO i_new_report_column_id;
  INSERT INTO pgapex.report_column (report_column_id, region_id, report_column_type_id, heading, sequence, is_text_escaped)
    VALUES (i_new_report_column_id, i_region_id, 'LINK', v_heading, i_sequence, b_is_text_escaped);
  INSERT INTO pgapex.report_column_link (report_column_id, url, link_text, attributes)
    VALUES (i_new_report_column_id, v_url, v_link_text, v_attributes);
  RETURN FOUND;
END
$$;


ALTER FUNCTION pgapex.f_region_create_report_region_link(i_region_id integer, v_heading character varying, i_sequence integer, b_is_text_escaped boolean, v_url character varying, v_link_text character varying, v_attributes character varying) OWNER TO t143682;

--
-- Name: f_region_delete_form_pre_fill_and_form_field(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_delete_form_pre_fill_and_form_field(i_region_id integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  i_form_pre_fill_id INT;
BEGIN
  SELECT form_pre_fill_id INTO i_form_pre_fill_id FROM pgapex.form_region WHERE region_id = i_region_id;
  IF i_form_pre_fill_id IS NOT NULL THEN
    DELETE FROM pgapex.form_pre_fill WHERE form_pre_fill_id = i_form_pre_fill_id;
  END IF;
  DELETE FROM pgapex.form_field WHERE region_id = i_region_id;
  RETURN FOUND;
END
$$;


ALTER FUNCTION pgapex.f_region_delete_form_pre_fill_and_form_field(i_region_id integer) OWNER TO t143682;

--
-- Name: f_region_delete_region(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_delete_region(i_region_id integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  DELETE FROM pgapex.region WHERE region_id = i_region_id;
  RETURN FOUND;
END
$$;


ALTER FUNCTION pgapex.f_region_delete_region(i_region_id integer) OWNER TO t143682;

--
-- Name: f_region_delete_report_region_columns(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_delete_report_region_columns(i_region_id integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
BEGIN
  DELETE FROM pgapex.report_column WHERE region_id = i_region_id;
  RETURN FOUND;
END
$$;


ALTER FUNCTION pgapex.f_region_delete_report_region_columns(i_region_id integer) OWNER TO t143682;

--
-- Name: f_region_get_display_points_with_regions(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_get_display_points_with_regions(i_page_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT json_agg(json_build_object(
      'id', ptdp.page_template_display_point_id
    , 'type', 'page-template-display-point'
    , 'attributes', json_build_object(
          'displayPointName', ptdp.display_point_id
        , 'description', ptdp.description
        , 'regions', (
          SELECT coalesce(json_agg(json_build_object(
               'id', r.region_id
             , 'type', 'region'
             , 'attributes', json_build_object(
                   'name', r.name
                 , 'sequence', r.sequence
                 , 'isVisible', r.is_visible
                 , 'type', (
                   CASE
                     WHEN hr.region_id IS NOT NULL THEN 'HTML'
                     WHEN nr.region_id IS NOT NULL THEN 'NAVIGATION'
                     WHEN fr.region_id IS NOT NULL THEN 'FORM'
                     WHEN rr.region_id IS NOT NULL THEN 'REPORT'
                     ELSE 'UNKNOWN'
                   END
                 )
             )
           )), '[]')
          FROM pgapex.region r
            LEFT JOIN pgapex.html_region hr ON r.region_id = hr.region_id
            LEFT JOIN pgapex.navigation_region nr ON r.region_id = nr.region_id
            LEFT JOIN pgapex.form_region fr ON r.region_id = fr.region_id
            LEFT JOIN pgapex.report_region rr ON r.region_id = rr.region_id
          WHERE r.page_template_display_point_id = ptdp.page_template_display_point_id
                AND r.page_id = p.page_id
        )
    )
  ))
  FROM pgapex.page p
    LEFT JOIN pgapex.page_template pt ON p.template_id = pt.template_id
    LEFT JOIN pgapex.page_template_display_point ptdp ON pt.template_id = ptdp.page_template_id
  WHERE p.page_id = i_page_id
$$;


ALTER FUNCTION pgapex.f_region_get_display_points_with_regions(i_page_id integer) OWNER TO t143682;

--
-- Name: f_region_get_form_region(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_get_form_region(i_region_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT
    json_build_object(
          'id', r.region_id
        , 'type', 'form-region'
        , 'attributes', json_build_object(
              'name', r.name
            , 'sequence', r.sequence
            , 'regionTemplate', r.template_id
            , 'isVisible', r.is_visible

            , 'formTemplate', fr.template_id
            , 'buttonTemplate', fr.button_template_id
            , 'buttonLabel', fr.button_label
            , 'successMessage', fr.success_message
            , 'errorMessage', fr.error_message
            , 'redirectUrl', fr.redirect_url
            , 'function', json_build_object(
                'type', 'function'
              , 'attributes', json_build_object(
                  'schema', fr.schema_name
                , 'name', fr.function_name
                )
              )
            , 'formPreFill', (fr.form_pre_fill_id IS NOT NULL)
            , 'formPreFillView', json_build_object(
                'id', fpf.form_pre_fill_id
              , 'type', 'form-pre-fill'
              , 'attributes', json_build_object(
                  'schema', fpf.schema_name
                , 'name', fpf.view_name
                )
              )
            , 'formPreFillColumns', (SELECT json_agg(json_build_object(
                                       'value', pi.name
                                     , 'column', json_build_object(
                                         'type', 'view-column'
                                       , 'attributes', json_build_object(
                                           'name', vc.column_name
                                         )
                                       )
                                     ))
                                     FROM pgapex.view_column vc
                                     LEFT JOIN pgapex.fetch_row_condition frc ON (vc.column_name = frc.view_column_name AND frc.form_pre_fill_id = fpf.form_pre_fill_id)
                                     LEFT JOIN pgapex.page_item pi ON pi.page_item_id = frc.url_parameter_id
                                     WHERE vc.database_name = a.database_name
                                           AND vc.schema_name = fpf.schema_name
                                           AND vc.view_name = fpf.view_name)
            , 'functionParameters', (SELECT json_agg(ff_agg.ff_obj) FROM (
                                    SELECT json_build_object(
                                      'fieldType', ff.field_type_id
                                    , 'fieldTemplate', COALESCE(ff.input_template_id, ff.drop_down_template_id, ff.textarea_template_id)
                                    , 'label', ff.label
                                    , 'inputName', pi.name
                                    , 'sequence', ff.sequence
                                    , 'isMandatory', ff.is_mandatory
                                    , 'isVisible', ff.is_visible
                                    , 'defaultValue', ff.default_value
                                    , 'helpText', ff.help_text
                                    , 'attributes', json_build_object(
                                        'name', par.parameter_name
                                      , 'argumentType', ff.function_parameter_type
                                      , 'ordinalPosition', ff.function_parameter_ordinal_position
                                      )
                                    , 'preFillColumn', ff.field_pre_fill_view_column_name
                                    , 'listOfValuesView', json_build_object(
                                        'attributes', json_build_object(
                                          'schema', lov.schema_name
                                        , 'name', lov.view_name
                                        , 'columns', (SELECT json_agg(lov_cols.c) FROM (SELECT json_build_object(
                                            'attributes', json_build_object(
                                              'name', lov_vc.column_name
                                            )
                                          ) c FROM pgapex.view_column lov_vc
                                            WHERE lov_vc.database_name = a.database_name
                                              AND lov_vc.schema_name = lov.schema_name
                                              AND lov_vc.view_name = lov.view_name
                                          ) lov_cols)
                                        )
                                      )
                                    , 'listOfValuesValue', json_build_object(
                                        'attributes', json_build_object(
                                          'name', lov.value_view_column_name
                                        )
                                      )
                                    , 'listOfValuesLabel', json_build_object(
                                        'attributes', json_build_object(
                                          'name', lov.label_view_column_name
                                        )
                                      )
                                    ) ff_obj
                                    FROM pgapex.form_field ff
                                    LEFT JOIN pgapex.page_item pi ON pi.form_field_id = ff.form_field_id
                                    LEFT JOIN pgapex.list_of_values lov ON lov.list_of_values_id = ff.list_of_values_id
                                    LEFT JOIN pgapex.parameter par ON (par.database_name = a.database_name AND par.schema_name = fr.schema_name AND par.function_name = fr.function_name AND par.parameter_type = ff.function_parameter_type AND par.ordinal_position = ff.function_parameter_ordinal_position)
                                    WHERE ff.region_id = r.region_id
                                    ORDER BY ff.function_parameter_ordinal_position) ff_agg
              )
        )
    )
  FROM pgapex.region r
    LEFT JOIN pgapex.form_region fr ON r.region_id = fr.region_id
    LEFT JOIN pgapex.form_pre_fill fpf ON fpf.form_pre_fill_id = fr.form_pre_fill_id
    LEFT JOIN pgapex.page p ON p.page_id = r.page_id
    LEFT JOIN pgapex.application a ON a.application_id = p.application_id
  WHERE r.region_id = i_region_id
$$;


ALTER FUNCTION pgapex.f_region_get_form_region(i_region_id integer) OWNER TO t143682;

--
-- Name: f_region_get_html_region(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_get_html_region(i_region_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT
  json_build_object(
    'id', r.region_id
  , 'type', 'html-region'
  , 'attributes', json_build_object(
      'name', r.name
    , 'sequence', r.sequence
    , 'regionTemplate', r.template_id
    , 'isVisible', r.is_visible
    , 'content', hr.content
    )
  )
  FROM pgapex.region r
  LEFT JOIN pgapex.html_region hr ON r.region_id = hr.region_id
  WHERE r.region_id = i_region_id
$$;


ALTER FUNCTION pgapex.f_region_get_html_region(i_region_id integer) OWNER TO t143682;

--
-- Name: f_region_get_navigation_region(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_get_navigation_region(i_region_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT
  json_build_object(
    'id', r.region_id
  , 'type', 'navigation-region'
  , 'attributes', json_build_object(
      'name', r.name
    , 'sequence', r.sequence
    , 'regionTemplate', r.template_id
    , 'isVisible', r.is_visible

    , 'navigationTemplate', nr.template_id
    , 'navigationType', nr.navigation_type_id
    , 'navigation', nr.navigation_id
    , 'repeatLastLevel', nr.repeat_last_level
    )
  )
  FROM pgapex.region r
  LEFT JOIN pgapex.navigation_region nr ON r.region_id = nr.region_id
  WHERE r.region_id = i_region_id
$$;


ALTER FUNCTION pgapex.f_region_get_navigation_region(i_region_id integer) OWNER TO t143682;

--
-- Name: f_region_get_region(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_get_region(i_region_id integer) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  j_result JSON;
BEGIN
  IF (SELECT EXISTS (SELECT 1 FROM pgapex.html_region WHERE region_id = i_region_id)) = TRUE THEN
    SELECT pgapex.f_region_get_html_region(i_region_id) INTO j_result;
  ELSIF (SELECT EXISTS (SELECT 1 FROM pgapex.navigation_region WHERE region_id = i_region_id)) = TRUE THEN
    SELECT pgapex.f_region_get_navigation_region(i_region_id) INTO j_result;
  ELSIF (SELECT EXISTS (SELECT 1 FROM pgapex.report_region WHERE region_id = i_region_id)) = TRUE THEN
    SELECT pgapex.f_region_get_report_region(i_region_id) INTO j_result;
  ELSIF (SELECT EXISTS (SELECT 1 FROM pgapex.form_region WHERE region_id = i_region_id)) = TRUE THEN
    SELECT pgapex.f_region_get_form_region(i_region_id) INTO j_result;
  END IF;
  RETURN j_result;
END
$$;


ALTER FUNCTION pgapex.f_region_get_region(i_region_id integer) OWNER TO t143682;

--
-- Name: f_region_get_report_region(integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_get_report_region(i_region_id integer) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT
    json_build_object(
          'id', r.region_id
        , 'type', 'report-region'
        , 'attributes', json_build_object(
              'name', r.name
            , 'sequence', r.sequence
            , 'regionTemplate', r.template_id
            , 'isVisible', r.is_visible

            , 'reportTemplate', rr.template_id
            , 'schemaName', rr.schema_name
            , 'viewName', rr.view_name
            , 'showHeader', rr.show_header
            , 'itemsPerPage', rr.items_per_page
            , 'paginationQueryParameter', pi.name
            , 'reportColumns', json_agg(
                CASE
                WHEN rcl.report_column_link_id IS NULL THEN
                  json_build_object(
                        'id', rc.report_column_id
                      , 'type', 'report-column'
                      , 'attributes', json_build_object(
                          'type', 'COLUMN'
                          , 'isTextEscaped', rc.is_text_escaped
                          , 'heading', rc.heading
                          , 'sequence', rc.sequence
                          , 'column', rc.view_column_name
                      )
                  )
                ELSE
                  json_build_object(
                        'id', rc.report_column_id
                      , 'type', 'report-link'
                      , 'attributes', json_build_object(
                            'type', 'LINK'
                          , 'isTextEscaped', rc.is_text_escaped
                          , 'heading', rc.heading
                          , 'sequence', rc.sequence
                          , 'linkUrl', rcl.url
                          , 'linkText', rcl.link_text
                          , 'linkAttributes', rcl.attributes
                      )
                  )
                END
            )
        )
    )
  FROM pgapex.region r
    LEFT JOIN pgapex.report_region rr ON r.region_id = rr.region_id
    LEFT JOIN pgapex.page_item pi ON pi.region_id = rr.region_id
    LEFT JOIN pgapex.report_column rc ON rc.region_id = rr.region_id
    LEFT JOIN pgapex.report_column_link rcl ON rcl.report_column_id = rc.report_column_id
  WHERE r.region_id = i_region_id
  GROUP BY r.region_id, r.name, r.sequence, r.template_id, r.is_visible,
    rr.template_id, rr.schema_name, rr.view_name, rr.show_header,
    rr.items_per_page, pi.name
$$;


ALTER FUNCTION pgapex.f_region_get_report_region(i_region_id integer) OWNER TO t143682;

--
-- Name: f_region_region_may_have_a_sequence(integer, integer, integer, integer); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_region_may_have_a_sequence(i_region_id integer, i_page_id integer, i_page_template_display_point_id integer, i_sequence integer) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT NOT EXISTS(
    SELECT 1 FROM pgapex.region
    WHERE page_id = i_page_id
      AND sequence = i_sequence
      AND page_template_display_point_id = i_page_template_display_point_id
      AND (
        CASE
          WHEN i_region_id IS NULL THEN TRUE
          ELSE region_id <> i_region_id
        END)
  );
$$;


ALTER FUNCTION pgapex.f_region_region_may_have_a_sequence(i_region_id integer, i_page_id integer, i_page_template_display_point_id integer, i_sequence integer) OWNER TO t143682;

--
-- Name: f_region_save_fetch_row_condition(integer, integer, character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_save_fetch_row_condition(i_form_pre_fill_id integer, i_region_id integer, v_url_parameter character varying, v_view_column_name character varying) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  INSERT INTO pgapex.fetch_row_condition (form_pre_fill_id, url_parameter_id, view_column_name)
  VALUES (i_form_pre_fill_id, (
    SELECT pi.page_item_id
    FROM pgapex.region r
    LEFT JOIN pgapex.page_item pi ON pi.page_id = r.page_id
    WHERE r.region_id = i_region_id
      AND pi.name = v_url_parameter
  ), v_view_column_name);
$$;


ALTER FUNCTION pgapex.f_region_save_fetch_row_condition(i_form_pre_fill_id integer, i_region_id integer, v_url_parameter character varying, v_view_column_name character varying) OWNER TO t143682;

--
-- Name: f_region_save_form_field(integer, character varying, integer, integer, character varying, character varying, character varying, integer, boolean, boolean, character varying, character varying, character varying, smallint); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_save_form_field(i_region_id integer, v_field_type_id character varying, i_list_of_values_id integer, i_form_field_template_id integer, v_field_pre_fill_view_column_name character varying, v_form_element_name character varying, v_label character varying, i_sequence integer, b_is_mandatory boolean, b_is_visible boolean, v_default_value character varying, v_help_text character varying, v_function_parameter_type character varying, v_function_parameter_ordinal_position smallint) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  i_new_form_field_id INT;
  i_page_id INT;
BEGIN
  SELECT nextval('pgapex.form_field_form_field_id_seq') INTO i_new_form_field_id;
  SELECT page_id INTO i_page_id FROM pgapex.region WHERE region_id = i_region_id;

  INSERT INTO pgapex.form_field (form_field_id, region_id, field_type_id, list_of_values_id, input_template_id, drop_down_template_id, textarea_template_id,
                                 field_pre_fill_view_column_name, label, sequence, is_mandatory, is_visible, default_value, help_text,
                                 function_parameter_type, function_parameter_ordinal_position
  )
  VALUES (i_new_form_field_id, i_region_id, v_field_type_id, i_list_of_values_id, (
    CASE
      WHEN v_field_type_id IN ('TEXT', 'PASSWORD', 'RADIO', 'CHECKBOX') THEN i_form_field_template_id
      ELSE NULL
    END
  ), (
    CASE
    WHEN v_field_type_id = 'DROP_DOWN' THEN i_form_field_template_id
    ELSE NULL
    END
  ), (
    CASE
    WHEN v_field_type_id = 'TEXTAREA' THEN i_form_field_template_id
    ELSE NULL
    END
  ),
  v_field_pre_fill_view_column_name, v_label, i_sequence, b_is_mandatory, b_is_visible, v_default_value, v_help_text,
  v_function_parameter_type, v_function_parameter_ordinal_position);

  INSERT INTO pgapex.page_item (page_id, form_field_id, name) VALUES (i_page_id, i_new_form_field_id, v_form_element_name);
END
$$;


ALTER FUNCTION pgapex.f_region_save_form_field(i_region_id integer, v_field_type_id character varying, i_list_of_values_id integer, i_form_field_template_id integer, v_field_pre_fill_view_column_name character varying, v_form_element_name character varying, v_label character varying, i_sequence integer, b_is_mandatory boolean, b_is_visible boolean, v_default_value character varying, v_help_text character varying, v_function_parameter_type character varying, v_function_parameter_ordinal_position smallint) OWNER TO t143682;

--
-- Name: f_region_save_form_pre_fill(character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_save_form_pre_fill(v_schema_name character varying, v_view_name character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  i_new_form_pre_fill_id INT;
BEGIN
  SELECT nextval('pgapex.form_pre_fill_form_pre_fill_id_seq') INTO i_new_form_pre_fill_id;
  INSERT INTO pgapex.form_pre_fill (form_pre_fill_id, schema_name, view_name)
  VALUES (i_new_form_pre_fill_id, v_schema_name, v_view_name);
  RETURN i_new_form_pre_fill_id;
END
$$;


ALTER FUNCTION pgapex.f_region_save_form_pre_fill(v_schema_name character varying, v_view_name character varying) OWNER TO t143682;

--
-- Name: f_region_save_form_region(integer, integer, integer, integer, character varying, integer, boolean, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_save_form_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_form_pre_fill_id integer, i_form_template_id integer, i_button_template_id integer, v_schema_name character varying, v_function_name character varying, v_button_label character varying, v_success_message character varying, v_error_message character varying, v_redirect_url character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  i_new_region_id INT;
BEGIN
  IF i_region_id IS NULL THEN
    SELECT nextval('pgapex.region_region_id_seq') INTO i_new_region_id;

    INSERT INTO pgapex.region (region_id, page_id, template_id, page_template_display_point_id, name, sequence, is_visible)
    VALUES (i_new_region_id, i_page_id, i_region_template_id, i_page_template_display_point_id, v_name, i_sequence, b_is_visible);

    INSERT INTO pgapex.form_region (region_id, form_pre_fill_id, template_id, button_template_id, schema_name, function_name, button_label, success_message, error_message, redirect_url)
    VALUES (i_new_region_id, i_form_pre_fill_id, i_form_template_id, i_button_template_id, v_schema_name, v_function_name, v_button_label, v_success_message, v_error_message, v_redirect_url);

    RETURN i_new_region_id;
  ELSE
    UPDATE pgapex.region
    SET page_id = i_page_id
    ,   template_id = i_region_template_id
    ,   page_template_display_point_id = i_page_template_display_point_id
    ,   name = v_name
    ,   sequence = i_sequence
    ,   is_visible = b_is_visible
    WHERE region_id = i_region_id;

    UPDATE pgapex.form_region
    SET form_pre_fill_id   = i_form_pre_fill_id
      , template_id        = i_form_template_id
      , button_template_id = i_button_template_id
      , schema_name        = v_schema_name
      , function_name      = v_function_name
      , button_label       = v_button_label
      , success_message    = v_success_message
      , error_message      = v_error_message
      , redirect_url       = v_redirect_url
    WHERE region_id = i_region_id;
    RETURN i_region_id;
  END IF;
END
$$;


ALTER FUNCTION pgapex.f_region_save_form_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_form_pre_fill_id integer, i_form_template_id integer, i_button_template_id integer, v_schema_name character varying, v_function_name character varying, v_button_label character varying, v_success_message character varying, v_error_message character varying, v_redirect_url character varying) OWNER TO t143682;

--
-- Name: f_region_save_html_region(integer, integer, integer, integer, character varying, integer, boolean, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_save_html_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, t_content character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  i_new_region_id INT;
BEGIN
  IF i_region_id IS NULL THEN
    SELECT nextval('pgapex.region_region_id_seq') INTO i_new_region_id;

    INSERT INTO pgapex.region (region_id, page_id, template_id, page_template_display_point_id, name, sequence, is_visible)
    VALUES (i_new_region_id, i_page_id, i_region_template_id, i_page_template_display_point_id, v_name, i_sequence, b_is_visible);

    INSERT INTO pgapex.html_region (region_id, content)
    VALUES (i_new_region_id, t_content);
  ELSE
    UPDATE pgapex.region
    SET page_id = i_page_id
    ,   template_id = i_region_template_id
    ,   page_template_display_point_id = i_page_template_display_point_id
    ,   name = v_name
    ,   sequence = i_sequence
    ,   is_visible = b_is_visible
    WHERE region_id = i_region_id;

    UPDATE pgapex.html_region
    SET content = t_content
    WHERE region_id = i_region_id;
  END IF;
  RETURN FOUND;
END
$$;


ALTER FUNCTION pgapex.f_region_save_html_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, t_content character varying) OWNER TO t143682;

--
-- Name: f_region_save_list_of_values(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_save_list_of_values(v_value_view_column_name character varying, v_label_view_column_name character varying, v_view_name character varying, v_schema_name character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  i_new_list_of_values_id INT;
BEGIN
  SELECT nextval('pgapex.list_of_values_list_of_values_id_seq') INTO i_new_list_of_values_id;
  INSERT INTO pgapex.list_of_values (list_of_values_id, value_view_column_name, label_view_column_name, view_name, schema_name)
  VALUES (i_new_list_of_values_id, v_value_view_column_name, v_label_view_column_name, v_view_name, v_schema_name);
  RETURN i_new_list_of_values_id;
END
$$;


ALTER FUNCTION pgapex.f_region_save_list_of_values(v_value_view_column_name character varying, v_label_view_column_name character varying, v_view_name character varying, v_schema_name character varying) OWNER TO t143682;

--
-- Name: f_region_save_navigation_region(integer, integer, integer, integer, character varying, integer, boolean, character varying, integer, integer, boolean); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_save_navigation_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_navigation_type_id character varying, i_navigation_id integer, i_navigation_template_id integer, b_repeat_last_level boolean) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  i_new_region_id INT;
BEGIN
  IF i_region_id IS NULL THEN
    SELECT nextval('pgapex.region_region_id_seq') INTO i_new_region_id;

    INSERT INTO pgapex.region (region_id, page_id, template_id, page_template_display_point_id, name, sequence, is_visible)
    VALUES (i_new_region_id, i_page_id, i_region_template_id, i_page_template_display_point_id, v_name, i_sequence, b_is_visible);

    INSERT INTO pgapex.navigation_region (region_id, navigation_type_id, navigation_id, template_id, repeat_last_level)
    VALUES (i_new_region_id, i_navigation_type_id, i_navigation_id, i_navigation_template_id, b_repeat_last_level);
  ELSE
    UPDATE pgapex.region
    SET page_id = i_page_id
    ,   template_id = i_region_template_id
    ,   page_template_display_point_id = i_page_template_display_point_id
    ,   name = v_name
    ,   sequence = i_sequence
    ,   is_visible = b_is_visible
    WHERE region_id = i_region_id;

    UPDATE pgapex.navigation_region
    SET navigation_type_id = i_navigation_type_id
      , navigation_id = i_navigation_id
      , template_id = i_navigation_template_id
      , repeat_last_level = b_repeat_last_level
    WHERE region_id = i_region_id;
  END IF;
  RETURN FOUND;
END
$$;


ALTER FUNCTION pgapex.f_region_save_navigation_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_navigation_type_id character varying, i_navigation_id integer, i_navigation_template_id integer, b_repeat_last_level boolean) OWNER TO t143682;

--
-- Name: f_region_save_report_region(integer, integer, integer, integer, character varying, integer, boolean, integer, character varying, character varying, integer, boolean, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_region_save_report_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_report_template_id integer, v_schema_name character varying, v_view_name character varying, i_items_per_page integer, b_show_header boolean, v_pagination_query_parameter character varying) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
DECLARE
  i_new_region_id INT;
BEGIN
  IF i_region_id IS NULL THEN
    SELECT nextval('pgapex.region_region_id_seq') INTO i_new_region_id;

    INSERT INTO pgapex.region (region_id, page_id, template_id, page_template_display_point_id, name, sequence, is_visible)
    VALUES (i_new_region_id, i_page_id, i_region_template_id, i_page_template_display_point_id, v_name, i_sequence, b_is_visible);

    INSERT INTO pgapex.report_region (region_id, template_id, schema_name, view_name, items_per_page, show_header)
    VALUES (i_new_region_id, i_report_template_id, v_schema_name, v_view_name, i_items_per_page, b_show_header);

    INSERT INTO pgapex.page_item (page_id, region_id, name) VALUES (i_page_id, i_new_region_id, v_pagination_query_parameter);
    RETURN i_new_region_id;
  ELSE
    UPDATE pgapex.region
    SET page_id = i_page_id
    ,   template_id = i_region_template_id
    ,   page_template_display_point_id = i_page_template_display_point_id
    ,   name = v_name
    ,   sequence = i_sequence
    ,   is_visible = b_is_visible
    WHERE region_id = i_region_id;

    UPDATE pgapex.report_region
    SET template_id = i_report_template_id
      , schema_name = v_schema_name
      , view_name = v_view_name
      , items_per_page = i_items_per_page
      , show_header = b_show_header
    WHERE region_id = i_region_id;

    UPDATE pgapex.page_item
    SET name = v_pagination_query_parameter
    WHERE page_id = i_page_id
      AND region_id = i_region_id;
    RETURN i_region_id;
  END IF;
END
$$;


ALTER FUNCTION pgapex.f_region_save_report_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_report_template_id integer, v_schema_name character varying, v_view_name character varying, i_items_per_page integer, b_show_header boolean, v_pagination_query_parameter character varying) OWNER TO t143682;

--
-- Name: f_template_get_button_templates(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_template_get_button_templates() RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
SELECT COALESCE(JSON_AGG(a), '[]')
  FROM (
    SELECT
      t.template_id AS id
    , 'button-template' AS type
    , json_build_object(
        'name', t.name
    ) AS attributes
    FROM pgapex.button_template bt
    LEFT JOIN pgapex.template t ON bt.template_id = t.template_id
    ORDER BY t.name
  ) a
$$;


ALTER FUNCTION pgapex.f_template_get_button_templates() OWNER TO t143682;

--
-- Name: f_template_get_drop_down_templates(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_template_get_drop_down_templates() RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
SELECT COALESCE(JSON_AGG(a), '[]')
  FROM (
    SELECT
      t.template_id AS id
    , 'drop-down-template' AS type
    , json_build_object(
        'name', t.name
    ) AS attributes
    FROM pgapex.drop_down_template ddt
    LEFT JOIN pgapex.template t ON ddt.template_id = t.template_id
    ORDER BY t.name
  ) a
$$;


ALTER FUNCTION pgapex.f_template_get_drop_down_templates() OWNER TO t143682;

--
-- Name: f_template_get_form_templates(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_template_get_form_templates() RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
SELECT COALESCE(JSON_AGG(a), '[]')
  FROM (
    SELECT
      t.template_id AS id
    , 'form-template' AS type
    , json_build_object(
        'name', t.name
    ) AS attributes
    FROM pgapex.form_template ft
    LEFT JOIN pgapex.template t ON ft.template_id = t.template_id
    ORDER BY t.name
  ) a
$$;


ALTER FUNCTION pgapex.f_template_get_form_templates() OWNER TO t143682;

--
-- Name: f_template_get_input_templates(character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_template_get_input_templates(v_input_template_type character varying) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
SELECT COALESCE(JSON_AGG(a), '[]')
  FROM (
    SELECT
      t.template_id AS id
    , lower(v_input_template_type) || '-input-template' AS type
    , json_build_object(
        'name', t.name
    ) AS attributes
    FROM pgapex.input_template it
    LEFT JOIN pgapex.template t ON it.template_id = t.template_id
    WHERE it.input_template_type_id = v_input_template_type
    ORDER BY t.name
  ) a
$$;


ALTER FUNCTION pgapex.f_template_get_input_templates(v_input_template_type character varying) OWNER TO t143682;

--
-- Name: f_template_get_navigation_templates(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_template_get_navigation_templates() RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
SELECT COALESCE(JSON_AGG(a), '[]')
  FROM (
    SELECT
      t.template_id AS id
    , 'navigation-template' AS type
    , json_build_object(
        'name', t.name
    ) AS attributes
    FROM pgapex.navigation_template nt
    LEFT JOIN pgapex.template t ON nt.template_id = t.template_id
    ORDER BY t.name
  ) a
$$;


ALTER FUNCTION pgapex.f_template_get_navigation_templates() OWNER TO t143682;

--
-- Name: f_template_get_page_templates(character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_template_get_page_templates(v_page_type character varying) RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
  SELECT COALESCE(JSON_AGG(a), '[]')
  FROM (
    SELECT
      t.template_id AS id
    , lower(v_page_type) || '-page-template' AS type
    , json_build_object(
        'name', t.name
    ) AS attributes
    FROM pgapex.page_template pt
    LEFT JOIN pgapex.template t ON pt.template_id = t.template_id
    WHERE pt.page_type_id = v_page_type
    ORDER BY t.name
  ) a
$$;


ALTER FUNCTION pgapex.f_template_get_page_templates(v_page_type character varying) OWNER TO t143682;

--
-- Name: f_template_get_region_templates(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_template_get_region_templates() RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
SELECT COALESCE(JSON_AGG(a), '[]')
FROM (
       SELECT
           t.template_id AS id
         , 'region-template' AS type
         , json_build_object(
               'name', t.name
           ) AS attributes
       FROM pgapex.region_template rt
         LEFT JOIN pgapex.template t ON rt.template_id = t.template_id
       ORDER BY t.name
     ) a
$$;


ALTER FUNCTION pgapex.f_template_get_region_templates() OWNER TO t143682;

--
-- Name: f_template_get_report_templates(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_template_get_report_templates() RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
SELECT COALESCE(JSON_AGG(a), '[]')
  FROM (
    SELECT
      t.template_id AS id
    , 'report-template' AS type
    , json_build_object(
        'name', t.name
    ) AS attributes
    FROM pgapex.report_template rt
    LEFT JOIN pgapex.template t ON rt.template_id = t.template_id
    ORDER BY t.name
  ) a
$$;


ALTER FUNCTION pgapex.f_template_get_report_templates() OWNER TO t143682;

--
-- Name: f_template_get_textarea_templates(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_template_get_textarea_templates() RETURNS json
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $$
SELECT COALESCE(JSON_AGG(a), '[]')
  FROM (
    SELECT
      t.template_id AS id
    , 'textarea-template' AS type
    , json_build_object(
        'name', t.name
    ) AS attributes
    FROM pgapex.textarea_template tt
    LEFT JOIN pgapex.template t ON tt.template_id = t.template_id
    ORDER BY t.name
  ) a
$$;


ALTER FUNCTION pgapex.f_template_get_textarea_templates() OWNER TO t143682;

--
-- Name: f_trig_application_authentication_function_exists(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_trig_application_authentication_function_exists() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
	b_authentication_function_exists BOOLEAN;
BEGIN
  IF NEW.authentication_scheme_id <> 'USER_FUNCTION' THEN
    RETURN NEW;
  END IF;

  WITH boolean_functions_with_two_parameters AS (
    SELECT f.database_name, f.schema_name, f.function_name, f.return_type, p.parameter_type
    FROM pgapex.function f
    LEFT JOIN pgapex.parameter p ON (f.database_name = p.database_name AND f.schema_name = p.schema_name AND f.function_name = p.function_name)
    WHERE f.database_name = NEW.database_name
      AND f.schema_name = NEW.authentication_function_schema_name
      AND f.function_name = NEW.authentication_function_name
      AND f.return_type = 'bool'
    GROUP BY f.database_name, f.schema_name, f.function_name, f.return_type, p.parameter_type
    HAVING max(p.ordinal_position) = 2
  )
  SELECT count(1) = 1 INTO b_authentication_function_exists FROM boolean_functions_with_two_parameters f
  WHERE f.parameter_type IN ('text', 'varchar');

	IF b_authentication_function_exists = FALSE THEN
		RAISE EXCEPTION 'Application authentication function does not exist';
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION pgapex.f_trig_application_authentication_function_exists() OWNER TO t143682;

--
-- Name: f_trig_form_pre_fill_must_be_deleted_with_form_region(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_trig_form_pre_fill_must_be_deleted_with_form_region() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
	IF OLD.form_pre_fill_id IS NOT NULL THEN
		DELETE FROM pgapex.form_pre_fill WHERE form_pre_fill_id = OLD.form_pre_fill_id;
	END IF;
	RETURN OLD;
END;
$$;


ALTER FUNCTION pgapex.f_trig_form_pre_fill_must_be_deleted_with_form_region() OWNER TO t143682;

--
-- Name: f_trig_list_of_values_must_be_deleted_with_form_field(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_trig_list_of_values_must_be_deleted_with_form_field() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
	IF OLD.list_of_values_id IS NOT NULL THEN
		DELETE FROM pgapex.list_of_values WHERE list_of_values_id = OLD.list_of_values_id;
	END IF;
	RETURN OLD;
END;
$$;


ALTER FUNCTION pgapex.f_trig_list_of_values_must_be_deleted_with_form_field() OWNER TO t143682;

--
-- Name: f_trig_navigation_item_may_not_contain_cycles(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_trig_navigation_item_may_not_contain_cycles() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF pgapex.f_navigation_navigation_item_contains_cycle(NEW.navigation_item_id, NEW.parent_navigation_item_id) THEN
    RAISE EXCEPTION 'Navigation may not contain cycles';
  END IF;
	RETURN NEW;
END;
$$;


ALTER FUNCTION pgapex.f_trig_navigation_item_may_not_contain_cycles() OWNER TO t143682;

--
-- Name: f_trig_page_only_one_homepage_per_application(); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_trig_page_only_one_homepage_per_application() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
	b_application_has_more_than_one_homepage BOOLEAN;
BEGIN
  SELECT count(1) > 0 INTO b_application_has_more_than_one_homepage
  FROM pgapex.page
  WHERE is_homepage = TRUE
  GROUP BY application_id
  HAVING COUNT(1) > 1;

	IF b_application_has_more_than_one_homepage THEN
		RAISE EXCEPTION 'Application may have only one homepage';
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION pgapex.f_trig_page_only_one_homepage_per_application() OWNER TO t143682;

--
-- Name: f_user_exists(character varying, character varying); Type: FUNCTION; Schema: pgapex; Owner: t143682
--

CREATE FUNCTION pgapex.f_user_exists(username character varying, password character varying) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pgapex', 'public', 'pg_temp'
    AS $_$
  SELECT EXISTS(
    SELECT 1
    FROM pg_catalog.pg_shadow
    WHERE usename = $1
      AND (passwd = 'md5' || md5($2 || $1)
        OR passwd IS NULL
      )
      AND (valuntil IS NULL
        OR valuntil > current_timestamp
      )
  );
$_$;


ALTER FUNCTION pgapex.f_user_exists(username character varying, password character varying) OWNER TO t143682;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: application; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.application (
    application_id integer NOT NULL,
    authentication_scheme_id character varying(30) DEFAULT 'NO_AUTHENTICATION'::character varying NOT NULL,
    login_page_template_id integer,
    database_name character varying(64) NOT NULL,
    authentication_function_name character varying(64),
    authentication_function_schema_name character varying(64),
    name character varying(60) NOT NULL,
    alias character varying(30),
    database_username character varying(64) NOT NULL,
    database_password character varying(64) NOT NULL,
    CONSTRAINT chk_application_alias_must_contain_char CHECK (((alias IS NULL) OR (((alias)::text ~* '.*[a-z].*'::text) AND ((alias)::text ~* '^\w*$'::text)))),
    CONSTRAINT chk_application_authentication_function_name_and_schema_coexist CHECK ((((authentication_function_name IS NULL) AND (authentication_function_schema_name IS NULL)) OR ((authentication_function_name IS NOT NULL) AND (authentication_function_schema_name IS NOT NULL)))),
    CONSTRAINT chk_application_authentication_function_requires_login_template CHECK (((((authentication_scheme_id)::text = 'NO_AUTHENTICATION'::text) AND (login_page_template_id IS NULL)) OR (((authentication_scheme_id)::text <> 'NO_AUTHENTICATION'::text) AND (login_page_template_id IS NOT NULL)))),
    CONSTRAINT chk_application_authentication_scheme_requires_function CHECK (((((authentication_scheme_id)::text = 'NO_AUTHENTICATION'::text) AND (authentication_function_name IS NULL)) OR (((authentication_scheme_id)::text <> 'NO_AUTHENTICATION'::text) AND (authentication_function_name IS NOT NULL))))
);


ALTER TABLE pgapex.application OWNER TO t143682;

--
-- Name: application_application_id_seq; Type: SEQUENCE; Schema: pgapex; Owner: t143682
--

CREATE SEQUENCE pgapex.application_application_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pgapex.application_application_id_seq OWNER TO t143682;

--
-- Name: application_application_id_seq; Type: SEQUENCE OWNED BY; Schema: pgapex; Owner: t143682
--

ALTER SEQUENCE pgapex.application_application_id_seq OWNED BY pgapex.application.application_id;


--
-- Name: authentication_scheme; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.authentication_scheme (
    authentication_scheme_id character varying(30) NOT NULL
);


ALTER TABLE pgapex.authentication_scheme OWNER TO t143682;

--
-- Name: button_template; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.button_template (
    template_id integer NOT NULL,
    template text NOT NULL
);


ALTER TABLE pgapex.button_template OWNER TO t143682;

--
-- Name: function; Type: MATERIALIZED VIEW; Schema: pgapex; Owner: t143682
--

CREATE MATERIALIZED VIEW pgapex.function AS
 SELECT DISTINCT a.database_name,
    i.schema_name,
    i.function_name,
    i.return_type
   FROM pgapex.application a,
    LATERAL pgapex.f_get_function_meta_info(a.database_name, a.database_username, a.database_password) i(schema_name, function_name, return_type)
  WITH NO DATA;


ALTER TABLE pgapex.function OWNER TO t143682;

--
-- Name: parameter; Type: MATERIALIZED VIEW; Schema: pgapex; Owner: t143682
--

CREATE MATERIALIZED VIEW pgapex.parameter AS
 SELECT DISTINCT (((a.database_name)::text || '.'::text) || (i.specific_name)::text) AS database_specific_name,
    a.database_name,
    i.schema_name,
    i.function_name,
    i.parameter_name,
    i.ordinal_position,
    i.parameter_type
   FROM pgapex.application a,
    LATERAL pgapex.f_get_function_parameter_meta_info(a.database_name, a.database_username, a.database_password) i(specific_name, schema_name, function_name, parameter_name, ordinal_position, parameter_type)
  WITH NO DATA;


ALTER TABLE pgapex.parameter OWNER TO t143682;

--
-- Name: view_column; Type: MATERIALIZED VIEW; Schema: pgapex; Owner: t143682
--

CREATE MATERIALIZED VIEW pgapex.view_column AS
 SELECT DISTINCT a.database_name,
    i.schema_name,
    i.view_name,
    i.column_name,
    i.column_type
   FROM pgapex.application a,
    LATERAL pgapex.f_get_view_column_meta_info(a.database_name, a.database_username, a.database_password) i(schema_name, view_name, column_name, column_type)
  WITH NO DATA;


ALTER TABLE pgapex.view_column OWNER TO t143682;

--
-- Name: data_type; Type: MATERIALIZED VIEW; Schema: pgapex; Owner: t143682
--

CREATE MATERIALIZED VIEW pgapex.data_type AS
 SELECT DISTINCT view_column.database_name,
    view_column.schema_name,
    view_column.column_type AS data_type
   FROM pgapex.view_column
UNION
 SELECT DISTINCT function.database_name,
    function.schema_name,
    function.return_type AS data_type
   FROM pgapex.function
UNION
 SELECT DISTINCT parameter.database_name,
    parameter.schema_name,
    parameter.parameter_type AS data_type
   FROM pgapex.parameter
  WITH NO DATA;


ALTER TABLE pgapex.data_type OWNER TO t143682;

--
-- Name: database; Type: MATERIALIZED VIEW; Schema: pgapex; Owner: t143682
--

CREATE MATERIALIZED VIEW pgapex.database AS
 SELECT pg_database.datname AS database_name
   FROM pg_database
  WHERE (pg_database.datname <> ALL (ARRAY['template0'::name, 'template1'::name]))
  WITH NO DATA;


ALTER TABLE pgapex.database OWNER TO t143682;

--
-- Name: display_point; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.display_point (
    display_point_id character varying(30) NOT NULL
);


ALTER TABLE pgapex.display_point OWNER TO t143682;

--
-- Name: drop_down_template; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.drop_down_template (
    template_id integer NOT NULL,
    drop_down_begin text NOT NULL,
    drop_down_end text NOT NULL,
    option_begin text NOT NULL,
    option_end text NOT NULL
);


ALTER TABLE pgapex.drop_down_template OWNER TO t143682;

--
-- Name: fetch_row_condition; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.fetch_row_condition (
    fetch_row_condition_id integer NOT NULL,
    form_pre_fill_id integer NOT NULL,
    url_parameter_id integer NOT NULL,
    view_column_name character varying(64) NOT NULL
);


ALTER TABLE pgapex.fetch_row_condition OWNER TO t143682;

--
-- Name: fetch_row_condition_fetch_row_condition_id_seq; Type: SEQUENCE; Schema: pgapex; Owner: t143682
--

CREATE SEQUENCE pgapex.fetch_row_condition_fetch_row_condition_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pgapex.fetch_row_condition_fetch_row_condition_id_seq OWNER TO t143682;

--
-- Name: fetch_row_condition_fetch_row_condition_id_seq; Type: SEQUENCE OWNED BY; Schema: pgapex; Owner: t143682
--

ALTER SEQUENCE pgapex.fetch_row_condition_fetch_row_condition_id_seq OWNED BY pgapex.fetch_row_condition.fetch_row_condition_id;


--
-- Name: field_type; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.field_type (
    field_type_id character varying(10) NOT NULL
);


ALTER TABLE pgapex.field_type OWNER TO t143682;

--
-- Name: form_field; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.form_field (
    form_field_id integer NOT NULL,
    region_id integer NOT NULL,
    field_type_id character varying(10) NOT NULL,
    list_of_values_id integer,
    input_template_id integer,
    drop_down_template_id integer,
    textarea_template_id integer,
    field_pre_fill_view_column_name character varying(64),
    label character varying(255) NOT NULL,
    sequence integer NOT NULL,
    is_mandatory boolean DEFAULT false NOT NULL,
    is_visible boolean DEFAULT true NOT NULL,
    default_value character varying(60),
    help_text character varying(255),
    function_parameter_type character varying(64) NOT NULL,
    function_parameter_ordinal_position smallint NOT NULL,
    CONSTRAINT chk_form_field_drop_down_template_must_match_field_type CHECK ((((drop_down_template_id IS NOT NULL) AND ((field_type_id)::text = 'DROP_DOWN'::text)) OR ((drop_down_template_id IS NULL) AND ((field_type_id)::text <> 'DROP_DOWN'::text)))),
    CONSTRAINT chk_form_field_extarea_template_must_match_field_type CHECK ((((textarea_template_id IS NOT NULL) AND ((field_type_id)::text = 'TEXTAREA'::text)) OR ((textarea_template_id IS NULL) AND ((field_type_id)::text <> 'TEXTAREA'::text)))),
    CONSTRAINT chk_form_field_function_parameter_ordinal_position_is_gt_0 CHECK ((function_parameter_ordinal_position > 0)),
    CONSTRAINT chk_form_field_input_template_must_match_field_type CHECK ((((input_template_id IS NOT NULL) AND ((field_type_id)::text = ANY (ARRAY[('TEXT'::character varying)::text, ('PASSWORD'::character varying)::text, ('RADIO'::character varying)::text, ('CHECKBOX'::character varying)::text]))) OR ((input_template_id IS NULL) AND ((field_type_id)::text <> ALL (ARRAY[('TEXT'::character varying)::text, ('PASSWORD'::character varying)::text, ('RADIO'::character varying)::text, ('CHECKBOX'::character varying)::text]))))),
    CONSTRAINT chk_form_field_list_of_values_requires_specific_field_type CHECK ((((list_of_values_id IS NULL) AND ((field_type_id)::text <> ALL (ARRAY[('DROP_DOWN'::character varying)::text, ('RADIO'::character varying)::text]))) OR ((list_of_values_id IS NOT NULL) AND ((field_type_id)::text = ANY (ARRAY[('DROP_DOWN'::character varying)::text, ('RADIO'::character varying)::text]))))),
    CONSTRAINT chk_form_field_only_one_template_can_be_chosen CHECK ((((input_template_id IS NOT NULL) AND (textarea_template_id IS NULL) AND (drop_down_template_id IS NULL)) OR ((input_template_id IS NULL) AND (textarea_template_id IS NOT NULL) AND (drop_down_template_id IS NULL)) OR ((input_template_id IS NULL) AND (textarea_template_id IS NULL) AND (drop_down_template_id IS NOT NULL)))),
    CONSTRAINT chk_form_field_sequence_must_be_not_negative CHECK ((sequence >= 0))
);


ALTER TABLE pgapex.form_field OWNER TO t143682;

--
-- Name: form_field_form_field_id_seq; Type: SEQUENCE; Schema: pgapex; Owner: t143682
--

CREATE SEQUENCE pgapex.form_field_form_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pgapex.form_field_form_field_id_seq OWNER TO t143682;

--
-- Name: form_field_form_field_id_seq; Type: SEQUENCE OWNED BY; Schema: pgapex; Owner: t143682
--

ALTER SEQUENCE pgapex.form_field_form_field_id_seq OWNED BY pgapex.form_field.form_field_id;


--
-- Name: form_pre_fill; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.form_pre_fill (
    form_pre_fill_id integer NOT NULL,
    schema_name character varying(64) NOT NULL,
    view_name character varying(64) NOT NULL
);


ALTER TABLE pgapex.form_pre_fill OWNER TO t143682;

--
-- Name: form_pre_fill_form_pre_fill_id_seq; Type: SEQUENCE; Schema: pgapex; Owner: t143682
--

CREATE SEQUENCE pgapex.form_pre_fill_form_pre_fill_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pgapex.form_pre_fill_form_pre_fill_id_seq OWNER TO t143682;

--
-- Name: form_pre_fill_form_pre_fill_id_seq; Type: SEQUENCE OWNED BY; Schema: pgapex; Owner: t143682
--

ALTER SEQUENCE pgapex.form_pre_fill_form_pre_fill_id_seq OWNED BY pgapex.form_pre_fill.form_pre_fill_id;


--
-- Name: form_region; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.form_region (
    region_id integer NOT NULL,
    form_pre_fill_id integer,
    template_id integer NOT NULL,
    button_template_id integer NOT NULL,
    schema_name character varying(64) NOT NULL,
    function_name character varying(64) NOT NULL,
    button_label character varying(255) NOT NULL,
    success_message character varying(255),
    error_message character varying(255),
    redirect_url character varying(255)
);


ALTER TABLE pgapex.form_region OWNER TO t143682;

--
-- Name: form_template; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.form_template (
    template_id integer NOT NULL,
    form_begin text NOT NULL,
    form_end text NOT NULL,
    row_begin text NOT NULL,
    row_end text NOT NULL,
    "row" text NOT NULL,
    mandatory_row_begin text NOT NULL,
    mandatory_row_end text NOT NULL,
    mandatory_row text NOT NULL
);


ALTER TABLE pgapex.form_template OWNER TO t143682;

--
-- Name: html_region; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.html_region (
    region_id integer NOT NULL,
    content text
);


ALTER TABLE pgapex.html_region OWNER TO t143682;

--
-- Name: input_template; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.input_template (
    template_id integer NOT NULL,
    template text NOT NULL,
    input_template_type_id character varying(10) NOT NULL
);


ALTER TABLE pgapex.input_template OWNER TO t143682;

--
-- Name: input_template_type; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.input_template_type (
    input_template_type_id character varying(10) NOT NULL
);


ALTER TABLE pgapex.input_template_type OWNER TO t143682;

--
-- Name: list_of_values; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.list_of_values (
    list_of_values_id integer NOT NULL,
    value_view_column_name character varying(64) NOT NULL,
    label_view_column_name character varying(64) NOT NULL,
    view_name character varying(64) NOT NULL,
    schema_name character varying(64) NOT NULL
);


ALTER TABLE pgapex.list_of_values OWNER TO t143682;

--
-- Name: list_of_values_list_of_values_id_seq; Type: SEQUENCE; Schema: pgapex; Owner: t143682
--

CREATE SEQUENCE pgapex.list_of_values_list_of_values_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pgapex.list_of_values_list_of_values_id_seq OWNER TO t143682;

--
-- Name: list_of_values_list_of_values_id_seq; Type: SEQUENCE OWNED BY; Schema: pgapex; Owner: t143682
--

ALTER SEQUENCE pgapex.list_of_values_list_of_values_id_seq OWNED BY pgapex.list_of_values.list_of_values_id;


--
-- Name: navigation; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.navigation (
    navigation_id integer NOT NULL,
    application_id integer NOT NULL,
    name character varying(60) NOT NULL,
    CONSTRAINT chk_navigation_name_must_be_longer_than_0 CHECK ((length(btrim((name)::text)) > 0))
);


ALTER TABLE pgapex.navigation OWNER TO t143682;

--
-- Name: navigation_item; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.navigation_item (
    navigation_item_id integer NOT NULL,
    parent_navigation_item_id integer,
    navigation_id integer NOT NULL,
    page_id integer,
    name character varying(60) NOT NULL,
    sequence integer NOT NULL,
    url character varying(255),
    CONSTRAINT chk_navigation_item_can_not_refer_back_to_itself CHECK (((parent_navigation_item_id IS NULL) OR (parent_navigation_item_id <> navigation_item_id))),
    CONSTRAINT chk_navigation_item_must_refer_to_page_xor_url CHECK ((((page_id IS NULL) AND (url IS NOT NULL)) OR ((page_id IS NOT NULL) AND (url IS NULL)))),
    CONSTRAINT chk_navigation_item_name_must_be_longer_than_0 CHECK ((length(btrim((name)::text)) > 0)),
    CONSTRAINT chk_navigation_item_sequence_is_not_negative CHECK ((sequence >= 0)),
    CONSTRAINT chk_navigation_item_url_must_be_longer_than_0 CHECK (((url IS NULL) OR (length(btrim((url)::text)) > 0)))
);


ALTER TABLE pgapex.navigation_item OWNER TO t143682;

--
-- Name: navigation_item_navigation_item_id_seq; Type: SEQUENCE; Schema: pgapex; Owner: t143682
--

CREATE SEQUENCE pgapex.navigation_item_navigation_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pgapex.navigation_item_navigation_item_id_seq OWNER TO t143682;

--
-- Name: navigation_item_navigation_item_id_seq; Type: SEQUENCE OWNED BY; Schema: pgapex; Owner: t143682
--

ALTER SEQUENCE pgapex.navigation_item_navigation_item_id_seq OWNED BY pgapex.navigation_item.navigation_item_id;


--
-- Name: navigation_item_template; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.navigation_item_template (
    navigation_item_template_id integer NOT NULL,
    navigation_template_id integer NOT NULL,
    active_template text NOT NULL,
    inactive_template text NOT NULL,
    level integer NOT NULL,
    CONSTRAINT chk_navigation_item_template_level_must_be_positive CHECK ((level > 0))
);


ALTER TABLE pgapex.navigation_item_template OWNER TO t143682;

--
-- Name: navigation_navigation_id_seq; Type: SEQUENCE; Schema: pgapex; Owner: t143682
--

CREATE SEQUENCE pgapex.navigation_navigation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pgapex.navigation_navigation_id_seq OWNER TO t143682;

--
-- Name: navigation_navigation_id_seq; Type: SEQUENCE OWNED BY; Schema: pgapex; Owner: t143682
--

ALTER SEQUENCE pgapex.navigation_navigation_id_seq OWNED BY pgapex.navigation.navigation_id;


--
-- Name: navigation_region; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.navigation_region (
    region_id integer NOT NULL,
    navigation_type_id character varying(10) NOT NULL,
    navigation_id integer NOT NULL,
    template_id integer NOT NULL,
    repeat_last_level boolean DEFAULT true NOT NULL
);


ALTER TABLE pgapex.navigation_region OWNER TO t143682;

--
-- Name: navigation_template; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.navigation_template (
    template_id integer NOT NULL,
    navigation_begin text NOT NULL,
    navigation_end text NOT NULL
);


ALTER TABLE pgapex.navigation_template OWNER TO t143682;

--
-- Name: navigation_type; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.navigation_type (
    navigation_type_id character varying(10) NOT NULL
);


ALTER TABLE pgapex.navigation_type OWNER TO t143682;

--
-- Name: page; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.page (
    page_id integer NOT NULL,
    application_id integer NOT NULL,
    template_id integer NOT NULL,
    title character varying(60) NOT NULL,
    alias character varying(60),
    is_homepage boolean DEFAULT false NOT NULL,
    is_authentication_required boolean DEFAULT false NOT NULL
);


ALTER TABLE pgapex.page OWNER TO t143682;

--
-- Name: page_item; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.page_item (
    page_item_id integer NOT NULL,
    page_id integer NOT NULL,
    form_field_id integer,
    region_id integer,
    name character varying(60) NOT NULL,
    CONSTRAINT chk_page_item_must_refer_to_region_xor_form_field CHECK ((((form_field_id IS NULL) AND (region_id IS NOT NULL)) OR ((form_field_id IS NOT NULL) AND (region_id IS NULL)))),
    CONSTRAINT chk_page_item_name_is_not_empty CHECK ((length(btrim((name)::text)) > 0)),
    CONSTRAINT chk_page_item_name_may_contain_alphabet_underscore_hypen CHECK (((name)::text ~ '^[a-zA-Z_-]+$'::text))
);


ALTER TABLE pgapex.page_item OWNER TO t143682;

--
-- Name: page_item_page_item_id_seq; Type: SEQUENCE; Schema: pgapex; Owner: t143682
--

CREATE SEQUENCE pgapex.page_item_page_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pgapex.page_item_page_item_id_seq OWNER TO t143682;

--
-- Name: page_item_page_item_id_seq; Type: SEQUENCE OWNED BY; Schema: pgapex; Owner: t143682
--

ALTER SEQUENCE pgapex.page_item_page_item_id_seq OWNED BY pgapex.page_item.page_item_id;


--
-- Name: page_page_id_seq; Type: SEQUENCE; Schema: pgapex; Owner: t143682
--

CREATE SEQUENCE pgapex.page_page_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pgapex.page_page_id_seq OWNER TO t143682;

--
-- Name: page_page_id_seq; Type: SEQUENCE OWNED BY; Schema: pgapex; Owner: t143682
--

ALTER SEQUENCE pgapex.page_page_id_seq OWNED BY pgapex.page.page_id;


--
-- Name: page_template; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.page_template (
    template_id integer NOT NULL,
    page_type_id character varying(10) NOT NULL,
    header text NOT NULL,
    body text NOT NULL,
    footer text NOT NULL,
    error_message text NOT NULL,
    success_message text NOT NULL
);


ALTER TABLE pgapex.page_template OWNER TO t143682;

--
-- Name: page_template_display_point; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.page_template_display_point (
    page_template_display_point_id integer NOT NULL,
    page_template_id integer NOT NULL,
    display_point_id character varying(30) NOT NULL,
    description character varying(60) NOT NULL
);


ALTER TABLE pgapex.page_template_display_point OWNER TO t143682;

--
-- Name: page_type; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.page_type (
    page_type_id character varying(10) NOT NULL
);


ALTER TABLE pgapex.page_type OWNER TO t143682;

--
-- Name: region; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.region (
    region_id integer NOT NULL,
    page_id integer NOT NULL,
    template_id integer NOT NULL,
    page_template_display_point_id integer NOT NULL,
    name character varying(60) NOT NULL,
    sequence integer NOT NULL,
    is_visible boolean DEFAULT true NOT NULL
);


ALTER TABLE pgapex.region OWNER TO t143682;

--
-- Name: region_region_id_seq; Type: SEQUENCE; Schema: pgapex; Owner: t143682
--

CREATE SEQUENCE pgapex.region_region_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pgapex.region_region_id_seq OWNER TO t143682;

--
-- Name: region_region_id_seq; Type: SEQUENCE OWNED BY; Schema: pgapex; Owner: t143682
--

ALTER SEQUENCE pgapex.region_region_id_seq OWNED BY pgapex.region.region_id;


--
-- Name: region_template; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.region_template (
    template_id integer NOT NULL,
    template text NOT NULL
);


ALTER TABLE pgapex.region_template OWNER TO t143682;

--
-- Name: report_column; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.report_column (
    report_column_id integer NOT NULL,
    report_column_type_id character varying(30) NOT NULL,
    region_id integer NOT NULL,
    view_column_name character varying(64),
    heading character varying(60) NOT NULL,
    sequence integer NOT NULL,
    is_text_escaped boolean DEFAULT true NOT NULL,
    CONSTRAINT chk_report_column_sequence_must_be_not_negative CHECK ((sequence >= 0))
);


ALTER TABLE pgapex.report_column OWNER TO t143682;

--
-- Name: report_column_link; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.report_column_link (
    report_column_link_id integer NOT NULL,
    report_column_id integer NOT NULL,
    url character varying(255) NOT NULL,
    link_text character varying(60) NOT NULL,
    attributes character varying(255)
);


ALTER TABLE pgapex.report_column_link OWNER TO t143682;

--
-- Name: report_column_link_report_column_link_id_seq; Type: SEQUENCE; Schema: pgapex; Owner: t143682
--

CREATE SEQUENCE pgapex.report_column_link_report_column_link_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pgapex.report_column_link_report_column_link_id_seq OWNER TO t143682;

--
-- Name: report_column_link_report_column_link_id_seq; Type: SEQUENCE OWNED BY; Schema: pgapex; Owner: t143682
--

ALTER SEQUENCE pgapex.report_column_link_report_column_link_id_seq OWNED BY pgapex.report_column_link.report_column_link_id;


--
-- Name: report_column_report_column_id_seq; Type: SEQUENCE; Schema: pgapex; Owner: t143682
--

CREATE SEQUENCE pgapex.report_column_report_column_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pgapex.report_column_report_column_id_seq OWNER TO t143682;

--
-- Name: report_column_report_column_id_seq; Type: SEQUENCE OWNED BY; Schema: pgapex; Owner: t143682
--

ALTER SEQUENCE pgapex.report_column_report_column_id_seq OWNED BY pgapex.report_column.report_column_id;


--
-- Name: report_column_type; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.report_column_type (
    report_column_type_id character varying(30) NOT NULL
);


ALTER TABLE pgapex.report_column_type OWNER TO t143682;

--
-- Name: report_region; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.report_region (
    region_id integer NOT NULL,
    template_id integer NOT NULL,
    schema_name character varying(64) NOT NULL,
    view_name character varying(64) NOT NULL,
    items_per_page integer NOT NULL,
    show_header boolean DEFAULT true NOT NULL
);


ALTER TABLE pgapex.report_region OWNER TO t143682;

--
-- Name: report_template; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.report_template (
    template_id integer NOT NULL,
    report_begin text NOT NULL,
    report_end text NOT NULL,
    header_begin text NOT NULL,
    header_row_begin text NOT NULL,
    header_cell text NOT NULL,
    header_row_end text NOT NULL,
    header_end text NOT NULL,
    body_begin text NOT NULL,
    body_row_begin text NOT NULL,
    body_row_cell text NOT NULL,
    body_row_end text NOT NULL,
    body_end text NOT NULL,
    pagination_begin text NOT NULL,
    pagination_end text NOT NULL,
    previous_page text NOT NULL,
    next_page text NOT NULL,
    active_page text NOT NULL,
    inactive_page text NOT NULL
);


ALTER TABLE pgapex.report_template OWNER TO t143682;

--
-- Name: schema; Type: MATERIALIZED VIEW; Schema: pgapex; Owner: t143682
--

CREATE MATERIALIZED VIEW pgapex.schema AS
 SELECT DISTINCT a.database_name,
    i.schema_name
   FROM pgapex.application a,
    LATERAL pgapex.f_get_schema_meta_info(a.database_name, a.database_username, a.database_password) i(schema_name)
  WITH NO DATA;


ALTER TABLE pgapex.schema OWNER TO t143682;

--
-- Name: session; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.session (
    session_id character varying(128) NOT NULL,
    application_id integer NOT NULL,
    data jsonb NOT NULL,
    expiration_time timestamp without time zone NOT NULL
);


ALTER TABLE pgapex.session OWNER TO t143682;

--
-- Name: template; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.template (
    template_id integer NOT NULL,
    name character varying(60) NOT NULL
);


ALTER TABLE pgapex.template OWNER TO t143682;

--
-- Name: textarea_template; Type: TABLE; Schema: pgapex; Owner: t143682
--

CREATE TABLE pgapex.textarea_template (
    template_id integer NOT NULL,
    template text NOT NULL
);


ALTER TABLE pgapex.textarea_template OWNER TO t143682;

--
-- Name: view; Type: MATERIALIZED VIEW; Schema: pgapex; Owner: t143682
--

CREATE MATERIALIZED VIEW pgapex.view AS
 SELECT DISTINCT a.database_name,
    i.schema_name,
    i.view_name
   FROM pgapex.application a,
    LATERAL pgapex.f_get_view_meta_info(a.database_name, a.database_username, a.database_password) i(schema_name, view_name)
  WITH NO DATA;


ALTER TABLE pgapex.view OWNER TO t143682;

--
-- Name: application application_id; Type: DEFAULT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.application ALTER COLUMN application_id SET DEFAULT nextval('pgapex.application_application_id_seq'::regclass);


--
-- Name: fetch_row_condition fetch_row_condition_id; Type: DEFAULT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.fetch_row_condition ALTER COLUMN fetch_row_condition_id SET DEFAULT nextval('pgapex.fetch_row_condition_fetch_row_condition_id_seq'::regclass);


--
-- Name: form_field form_field_id; Type: DEFAULT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_field ALTER COLUMN form_field_id SET DEFAULT nextval('pgapex.form_field_form_field_id_seq'::regclass);


--
-- Name: form_pre_fill form_pre_fill_id; Type: DEFAULT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_pre_fill ALTER COLUMN form_pre_fill_id SET DEFAULT nextval('pgapex.form_pre_fill_form_pre_fill_id_seq'::regclass);


--
-- Name: list_of_values list_of_values_id; Type: DEFAULT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.list_of_values ALTER COLUMN list_of_values_id SET DEFAULT nextval('pgapex.list_of_values_list_of_values_id_seq'::regclass);


--
-- Name: navigation navigation_id; Type: DEFAULT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation ALTER COLUMN navigation_id SET DEFAULT nextval('pgapex.navigation_navigation_id_seq'::regclass);


--
-- Name: navigation_item navigation_item_id; Type: DEFAULT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_item ALTER COLUMN navigation_item_id SET DEFAULT nextval('pgapex.navigation_item_navigation_item_id_seq'::regclass);


--
-- Name: page page_id; Type: DEFAULT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page ALTER COLUMN page_id SET DEFAULT nextval('pgapex.page_page_id_seq'::regclass);


--
-- Name: page_item page_item_id; Type: DEFAULT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_item ALTER COLUMN page_item_id SET DEFAULT nextval('pgapex.page_item_page_item_id_seq'::regclass);


--
-- Name: region region_id; Type: DEFAULT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.region ALTER COLUMN region_id SET DEFAULT nextval('pgapex.region_region_id_seq'::regclass);


--
-- Name: report_column report_column_id; Type: DEFAULT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.report_column ALTER COLUMN report_column_id SET DEFAULT nextval('pgapex.report_column_report_column_id_seq'::regclass);


--
-- Name: report_column_link report_column_link_id; Type: DEFAULT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.report_column_link ALTER COLUMN report_column_link_id SET DEFAULT nextval('pgapex.report_column_link_report_column_link_id_seq'::regclass);


--
-- Data for Name: application; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.application (application_id, authentication_scheme_id, login_page_template_id, database_name, authentication_function_name, authentication_function_schema_name, name, alias, database_username, database_password) FROM stdin;
22	USER_FUNCTION	1	t142431	f_on_juhataja	public	t142431	Epood	t142431	parool1
27	NO_AUTHENTICATION	\N	t142772	\N	\N	climb_db	hello_world	t142772	kartultomatkapsas
36	USER_FUNCTION	1	t143061	kas_on_piletite_kontroller	public	LaevaFirma	\N	piletite_kontroller	Neptune6814
29	USER_FUNCTION	1	t142678	f_on_juhataja	public	Sinu Epood - sulle ja mulle	KaupadeEpood	t142678_juhataja	porgand
30	USER_FUNCTION	1	t143044	f_on_juhataja	public	Raamatupoe andmebaas	\N	t143044	parool
25	USER_FUNCTION	1	t143062	f_on_juhataja	public	Hovershop	\N	juhataja_hover	1JuhatajaHover
28	USER_FUNCTION	1	t143055	f_juhataja_saab_logida	public	Seaside Hill Surgeons GYM	\N	seaside_gym	seaside
21	USER_FUNCTION	1	t135060	f_on_juhataja	public	MänguEpood	E_pood	t135060_rakendus	rakenduseparool
23	USER_FUNCTION	1	t143032	f_on_juhataja	public	Jalatsite ePood	J_epood	t143032	A143032T
20	USER_FUNCTION	1	t142290	f_on_juhataja	public	ElektroonikaPood	ToodeteArvestus	t142290_juhataja	haikala
16	USER_FUNCTION	1	AWESOMESHOP	f_sisselogimine	public	AWESOMESHOP	\N	awesomeshop_juhataja	christmas
18	USER_FUNCTION	1	t134293	f_on_trykise_haldur	raamatupood	raamatupood	\N	t143075	iUiSLALBg5KT2SrfJlyV
37	USER_FUNCTION	1	t134660	f_auth	public	Golfirajad	\N	golfirajad_juhataja	password
26	USER_FUNCTION	1	t142683	f_on_juhataja	public	RS6_V10	\N	t142683	rs6v10biturbo426
39	USER_FUNCTION	1	t130596	on_juhataja	public	Kaup_t130596	\N	t130596_juhataja	q56Zn87
41	NO_AUTHENTICATION	\N	t172948	\N	\N	app27-10-2017	\N	t172948	vova3713
48	USER_FUNCTION	1	t142600	f_on_juhataja	public	Arvutikomponentide E-pood	\N	juhataja_arvutikomponendid	V3RIS2F3
43	NO_AUTHENTICATION	\N	messages	\N	\N	pildid	pildid	erki	miksud
44	NO_AUTHENTICATION	\N	t081943	\N	\N	t08test1	\N	t081943	javaveeb
46	NO_AUTHENTICATION	\N	1test_12_uus	\N	\N	1test_12_uus	\N	t081943	javaveeb
57	USER_FUNCTION	1	t155245	f_on_juhataja	public	Laudade broneerimine	t155245_lauad	t155245	c9mgt6
72	NO_AUTHENTICATION	\N	t164473	\N	\N	t164473	\N	t164473	sanderjasven
12	USER_FUNCTION	1	rooms	f_is_boss	functions	Toad2	Juhataja	toad_juhataja	AG12F8
51	NO_AUTHENTICATION	\N	t155389	\N	\N	test80085	\N	t155389	arva2ra666
53	USER_FUNCTION	1	t155412	f_on_juhataja	public	t155412_kaubad	\N	t142766	Sammi123
61	NO_AUTHENTICATION	\N	t154766_restoran	\N	\N	t154766_restoran	\N	t154766	Sirtal96
54	USER_FUNCTION	1	t155761	f_on_juhataja	public	HairSalon	\N	t154908	Qweasd123
60	USER_FUNCTION	1	t142855	f_on_juhataja	public	Relvapood	\N	t134655_juhataja	randomPassword231
49	USER_FUNCTION	1	t155199	f_on_juhataja	public	Tähenärija	t155199	raamatupood_tahenarija	andm3baas!d0nMuL3mmika!n3
50	USER_FUNCTION	1	t155389	f_on_juhtaja	public	Kaup_t155389	\N	juhataja_epood	password
62	USER_FUNCTION	1	t155409	f_on_juhataja	public	t155409 Restorani laudade arvestus	\N	juhataja_tookoht	juhataja
85	USER_FUNCTION	1	t164844	f_on_kasutaja	public	t164844_Laudade_arvestus	\N	t164844_juhataja	123
59	USER_FUNCTION	1	t155387	f_on_juhataja	public	t155387	\N	t155387_db_user	heaparool
42	USER_FUNCTION	1	t155196	f_tuvasta_juhataja	public	Sülearvuti epood	\N	t155196_juhataja	sqlDoesntForget
63	USER_FUNCTION	1	t154831	f_on_juhataja	public	t154831_parklakohad	\N	t154831_juhataja	admin
64	USER_FUNCTION	1	t155241	f_on_juhataja	public	t155241	t155241	toidupoodi_juhataja	juhataja
45	USER_FUNCTION	1	t156215	f_user_authentication	public	Parkla - t156215	Juhataja_155691	t156215louella	tlouella
68	NO_AUTHENTICATION	\N	t154844	\N	\N	Mehaaniliste klaviatuuride e-pood	\N	t154844	f4fc8ae1eB
55	USER_FUNCTION	1	t155406	f_on_juhataja	public	Hulgiladu	\N	t155406	91774154
66	USER_FUNCTION	1	t155680	f_on_juhataja	public	t155680	\N	t155680_juhataja	juhataja
67	USER_FUNCTION	1	t155150	f_on_juhataja	public	t155150_restoran	\N	t155150	T0oH4rdP4ssW0rd
65	USER_FUNCTION	1	t172499_1	f_on_juhataja	public	t172499	\N	proovikasutaja	proovikasutaja
70	NO_AUTHENTICATION	\N	t135159	\N	\N	MarianaTest	\N	t134696	Mariana1
71	NO_AUTHENTICATION	\N	t154831	\N	\N	novaApp	novaapp	postgres	postgres
73	NO_AUTHENTICATION	\N	t164208	\N	\N	PeopleFitness	\N	t164026	jepokiut12
75	NO_AUTHENTICATION	\N	t164416	\N	\N	Restorani_laudade_arvestus_t164416	\N	t164416	laintrusa
69	NO_AUTHENTICATION	\N	t155376	\N	\N	KWH_Epood	\N	t155376	Melonyard1975
88	USER_FUNCTION	1	t164051	f_on_juhataja	public	Mahenta Park	\N	Mahentapark	xdxdxd
78	NO_AUTHENTICATION	\N	t164648	\N	\N	Laoruumide haldamine	\N	t164838	Andmebaazid3
87	USER_FUNCTION	1	t163966	f_on_juhataja	public	t163966	\N	t163966	aRmC8axpuy41VFsH
1	USER_FUNCTION	1	rooms	f_is_boss	functions	Toad	rooms	t143682	APX16k
100	NO_AUTHENTICATION	\N	parklaab2	\N	\N	parklaab2	\N	t142268	a1r2t3u4r5
80	USER_FUNCTION	1	t155233	f_on_juhataja	public	Prooviruum	juhataja	phil_hole	edward_wilson
83	USER_FUNCTION	1	t164488	f_on_juhataja	public	t164488_parklakohad	Parklakohad	t164488	Andmebaasid2PostgreSQL
47	NO_AUTHENTICATION	\N	t155133	\N	\N	Teater	\N	t155133	S3ganeM6te
81	USER_FUNCTION	1	t183373	f_on_juhataja	public	t183373_spordiklubi	PAR_spordiklubi	t183373_juhataja	Boss
86	USER_FUNCTION	1	t164701	f_on_juhataja	public	Spordiklubi	\N	t164475	Kikujasimba1
79	USER_FUNCTION	1	t183000	f_on_juhataja	public	A_Pallipood	\N	pallipoe_juhataja	EALB18IABM
84	USER_FUNCTION	1	t164648	f_on_juhataja	public	t164648 Juuksurisalong	Juuksurisalong	t164648_juhataja	IDU0230JH
76	NO_AUTHENTICATION	\N	-	\N	\N	t164773	\N	t164773	5224852a
82	USER_FUNCTION	1	t155420	f_on_juhataja	public	Autorent OÜ	\N	t155420_autorendiettevotte_juhataja	s3cret
74	USER_FUNCTION	1	t164214	f_tuvasta_juhataja	public	t164214 Restorani laudade arvestus	\N	t164214_pgapex	k0ppk0pp
91	USER_FUNCTION	1	t164214	f_tuvasta_juhataja	public	t164214 xyzzy test	\N	t164214_pgapex	k0ppk0pp
99	USER_FUNCTION	1	t163913	f_on_juhataja	public	t163913	\N	t163913_parklakohtade_juhataja	tahtisParool
101	USER_FUNCTION	1	t183014	f_on_kauba_haldur	public	t183014_2	\N	t183014	Chs1171
98	USER_FUNCTION	1	t164428	f_on_juhataja	public	t164428_Parklakohad	\N	juhataja_t164428	juhatajaKonto
92	USER_FUNCTION	1	t183014	f_on_kauba_haldur	public	t183014	Andmebaasid2_app	t183014_kauba_haldur	joseIsCool
102	NO_AUTHENTICATION	\N	t182949	\N	\N	Rendikas	\N	t182949	S182949
90	USER_FUNCTION	1	t164225	f_on_juhataja	public	t164225 - Parkla parklakohtade arvestus	\N	t164225_juhataja	%UXf{KnWN5TW`7&:
93	NO_AUTHENTICATION	\N	t164844	\N	\N	t155609_laudade_arvestus	Laudade_arvestus	t155609	Skorpion123
95	USER_FUNCTION	1	t142459	f_on_tootaja	public	t142459_parklakohad	\N	t142459_juhataja	tere1234
96	USER_FUNCTION	1	t142459	f_on_tootaja	public	t142459_parklakohad_2	\N	t142459_juhataja	tere1234
\.


--
-- Data for Name: authentication_scheme; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.authentication_scheme (authentication_scheme_id) FROM stdin;
USER_FUNCTION
NO_AUTHENTICATION
\.


--
-- Data for Name: button_template; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.button_template (template_id, template) FROM stdin;
9	<div class="form-group">\n  <div class="col-sm-offset-2 col-sm-10">\n    <button type="submit" name="#NAME#" class="btn btn-primary">#LABEL#</button>\n  </div>\n</div>
\.


--
-- Data for Name: display_point; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.display_point (display_point_id) FROM stdin;
BODY
POSITION_1
POSITION_2
POSITION_3
POSITION_4
POSITION_5
POSITION_6
POSITION_7
POSITION_8
\.


--
-- Data for Name: drop_down_template; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.drop_down_template (template_id, drop_down_begin, drop_down_end, option_begin, option_end) FROM stdin;
8	<select class="form-control" name="#NAME#">	</select>	<option value="#VALUE#"#SELECTED#>	</option>
\.


--
-- Data for Name: fetch_row_condition; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.fetch_row_condition (fetch_row_condition_id, form_pre_fill_id, url_parameter_id, view_column_name) FROM stdin;
4	4	44	room_code
16	16	346	kood
\.


--
-- Data for Name: field_type; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.field_type (field_type_id) FROM stdin;
TEXT
PASSWORD
RADIO
CHECKBOX
DROP_DOWN
TEXTAREA
\.


--
-- Data for Name: form_field; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.form_field (form_field_id, region_id, field_type_id, list_of_values_id, input_template_id, drop_down_template_id, textarea_template_id, field_pre_fill_view_column_name, label, sequence, is_mandatory, is_visible, default_value, help_text, function_parameter_type, function_parameter_ordinal_position) FROM stdin;
41	6	DROP_DOWN	13	\N	8	\N	\N	Ruum	10	t	t	\N	Valige ruum, mida soovite lõpetada	int4	1
42	8	TEXT	\N	11	\N	\N	room_code	Vana ruumi kood	50	f	f	\N	\N	int4	1
43	8	TEXT	\N	11	\N	\N	room_code	Uus ruumi kood	60	f	t	\N	\N	int4	2
44	8	TEXT	\N	11	\N	\N	room_name	Ruumi nimi	40	f	t	\N	\N	varchar	3
45	8	DROP_DOWN	14	\N	8	\N	bed_type_code	Voodi tüüp	20	f	t	\N	\N	varchar	4
46	8	TEXT	\N	11	\N	\N	area	Piirkond	30	f	t	\N	\N	numeric	5
47	8	TEXT	\N	11	\N	\N	night_price	Öö hind	80	f	t	\N	\N	numeric	6
48	8	TEXT	\N	11	\N	\N	minimal_night_price	Min öö hind	90	f	t	\N	\N	numeric	7
49	8	TEXT	\N	11	\N	\N	max_number_of_people	Inimeste arv	100	f	t	\N	\N	int4	8
50	8	TEXTAREA	\N	\N	\N	10	description	Kirjeldus	10	f	t	\N	\N	varchar	9
51	8	TEXT	\N	11	\N	\N	picture_address	Pildi aadress	70	f	t	\N	\N	varchar	10
58	27	DROP_DOWN	21	\N	8	\N	\N	Tuba	1	t	t	\N	Valige lõpetatav ruum	int4	1
267	177	DROP_DOWN	69	\N	8	\N	\N	Treening	1	t	t	\N	\N	int4	1
276	187	TEXT	\N	11	\N	\N	kood	Kood	0	f	f	\N	\N	int4	1
79	83	DROP_DOWN	25	\N	8	\N	\N	Toode	1	t	t	\N	Valige lõpetatav tuba	int8	1
84	103	DROP_DOWN	27	\N	8	\N	\N	Kauba kood	0	t	t	\N	\N	int4	1
86	78	DROP_DOWN	29	\N	8	\N	\N	Vali toode	0	t	t	\N	Valige lõpetatav toode	int4	1
89	155	PASSWORD	\N	12	\N	\N	\N	Parool	2	t	t	\N	\N	text	2
90	155	TEXT	\N	11	\N	\N	\N	Kasutajanimi	1	t	t	\N	\N	text	1
285	255	TEXT	\N	11	\N	\N	\N	Pealkiri	1	t	t	\N	\N	text	2
286	255	TEXT	\N	11	\N	\N	\N	Kood	2	t	t	\N	\N	varchar	1
287	255	DROP_DOWN	73	\N	8	\N	\N	Kategooria	3	t	t	\N	\N	int2	7
288	255	DROP_DOWN	74	\N	8	\N	\N	Kirjastus	4	t	t	\N	\N	int2	5
236	209	DROP_DOWN	64	\N	8	\N	\N	Kauba nimi	1	t	t	\N	\N	int4	1
289	255	DROP_DOWN	75	\N	8	\N	\N	Seisund	5	t	t	\N	\N	int2	6
290	255	TEXT	\N	11	\N	\N	\N	Hind	6	t	t	\N	\N	numeric	4
291	255	TEXT	\N	11	\N	\N	\N	Tootaja	7	t	t	\N	\N	int4	8
292	255	TEXT	\N	11	\N	\N	\N	Lehekyljed	8	t	t	\N	\N	int2	3
241	222	DROP_DOWN	68	\N	8	\N	\N	Kauba kood	0	t	t	\N	\N	varchar	1
298	267	DROP_DOWN	80	\N	8	\N	\N	Lopeta rada	0	t	t	\N	Vali rada, mida lopetada.	int4	1
299	264	DROP_DOWN	81	\N	8	\N	\N	Rada, mida unustada	0	t	t	\N	Vali rada, mida unustada	int4	1
300	258	DROP_DOWN	82	\N	8	\N	\N	Pilet	1	t	t	\N	Valige Kasutatav Pilet	int4	1
302	227	TEXT	\N	11	\N	\N	\N	Teenuse kood	1	t	t	\N	\N	int4	1
179	183	DROP_DOWN	53	\N	8	\N	\N	Kaup	1	t	t	\N	Kustutatava kauba kood	int4	1
304	275	DROP_DOWN	84	\N	8	\N	\N	Kaup	1	t	t	\N	Valige Lõpetatav kaup	int4	1
185	194	DROP_DOWN	55	\N	8	\N	\N	Raamat	1	t	t	\N	Vali lõpetatav raamat	int4	1
403	381	TEXT	\N	11	\N	\N	\N	Kauba kood	0	t	t	\N	\N	int4	1
404	404	DROP_DOWN	109	\N	8	\N	\N	Kauba kood	5	f	t	\N	Valige kaup, mida lõpetada	varchar	1
460	496	DROP_DOWN	137	\N	8	\N	\N	Laua nimetus	1	t	t	\N	\N	int2	1
316	339	DROP_DOWN	94	\N	8	\N	\N	Kauba id	0	t	t	\N	\N	int8	1
411	424	DROP_DOWN	110	\N	8	\N	\N	Lõpeta teenus	0	t	t	\N	Valige teenus, mida soovite lõpetada.	int2	1
412	349	DROP_DOWN	111	\N	8	\N	\N	Lõpeta kaup	10	t	t	\N	Valige kaup, mida soovite lõpetada.	int8	1
468	467	TEXT	\N	11	\N	\N	\N	Kaup ID	0	t	t	\N	\N	int4	1
416	340	DROP_DOWN	115	\N	8	\N	\N	Parkimiskoht	1	t	t	\N	Valige lõpetatav parkimiskoht	int8	1
417	421	DROP_DOWN	116	\N	8	\N	\N	Kaup:	1	t	t	\N	Kauba kood GTINina	d_gtin	1
418	446	DROP_DOWN	117	\N	8	\N	\N	Laud	1	t	t	\N	Valige lõpetatav laud	int4	1
471	511	DROP_DOWN	145	\N	8	\N	\N	Laud	1	t	t	\N	Valige lõpetatav laud	int4	1
425	453	DROP_DOWN	124	\N	8	\N	\N	Kood	0	t	t	\N	\N	int8	1
426	458	DROP_DOWN	125	\N	8	\N	\N	Parklakoha kood	10	t	t	\N	\N	int2	1
427	458	DROP_DOWN	126	\N	8	\N	\N	Parkla kood	20	t	t	\N	\N	int4	2
442	486	DROP_DOWN	131	\N	8	\N	\N	Auto	1	t	t	\N	Valige lõpetatav auto	int4	1
381	357	DROP_DOWN	107	\N	8	\N	\N	Kauba kood	0	t	t	\N	\N	int4	1
391	311	DROP_DOWN	108	\N	8	\N	\N	Kaup	1	t	t	\N	Valige lõpetatav kaup	int4	1
474	534	DROP_DOWN	146	\N	8	\N	\N	Lõpeta Kaup	10	t	t	\N	Valige kaup, mida soovite lõpetada.	varchar	1
481	542	DROP_DOWN	151	\N	8	\N	\N	Lõpetatava kauba kood	1	t	t	\N	\N	int4	1
555	708	DROP_DOWN	213	\N	8	\N	\N	Parklakoha kood	1	t	t	\N	\N	int4	1
485	558	DROP_DOWN	154	\N	8	\N	\N	Auto kood	3	t	t	\N	Sisesta auto kood, mida soovid lõpetada.	int4	1
558	710	DROP_DOWN	215	\N	8	\N	\N	Parklakoha kood	1	t	t	\N	\N	int4	1
559	704	DROP_DOWN	216	\N	8	\N	\N	Prooviruumi kood	0	t	t	\N	\N	int4	1
497	573	DROP_DOWN	166	\N	8	\N	\N	Treeningu kood	3	t	t	\N	Sisesta treeningu kood, mida soovid lõpetada	varchar	1
522	609	DROP_DOWN	181	\N	8	\N	\N	Laua kood	0	t	t	\N	Lõpetatava laua kood	usmallint	1
531	629	DROP_DOWN	190	\N	8	\N	\N	Parklakoha kood	10	t	t	\N	\N	int4	1
532	570	DROP_DOWN	191	\N	8	\N	\N	Teenus	0	t	t	\N	\N	int4	1
534	657	DROP_DOWN	193	\N	8	\N	\N	Laua kood	1	t	t	\N	Vali lõpetatav laud	int2	1
540	661	DROP_DOWN	199	\N	8	\N	\N	Parkimiskoha kood	3	t	t	\N	Sisesta parkimiskoha kood, mida soovid lõpetada.	int4	1
541	671	DROP_DOWN	200	\N	8	\N	\N	Parkimiskoha kood	3	t	t	\N	Sisesta parkimiskoha kood, mida soovid unustada	int4	1
542	617	DROP_DOWN	201	\N	8	\N	\N	Teenus	1	t	t	\N	Valige lõpetatav teenus	int2	1
794	787	TEXT	\N	11	\N	\N	\N	Parklakoha kood	1	t	t	\N	\N	int4	1
932	759	DROP_DOWN	304	\N	8	\N	\N	Unusta kaup	0	t	t	\N	\N	varchar	1
795	787	TEXT	\N	11	\N	\N	\N	Parkla nimetus	2	t	t	\N	\N	d_nimetus	2
734	775	DROP_DOWN	253	\N	8	\N	\N	Parklakoht	1	t	t	\N	Valige lõpetatav parklakoht	int4	1
961	722	DROP_DOWN	326	\N	8	\N	\N	Kauba kood	0	t	t	\N	\N	varchar	1
962	722	DROP_DOWN	327	\N	8	\N	\N	Protessor	5	t	t	\N	\N	int4	2
963	722	DROP_DOWN	328	\N	8	\N	\N	Sisemälu	3	t	f	\N	\N	int4	3
964	722	DROP_DOWN	329	\N	8	\N	\N	Resulutsioon	2	t	t	\N	\N	int4	4
965	722	DROP_DOWN	330	\N	8	\N	\N	T Kaamera	7	t	t	\N	\N	int4	5
966	722	DROP_DOWN	331	\N	8	\N	\N	E Kaamera	8	t	t	\N	\N	int4	6
967	722	DROP_DOWN	332	\N	8	\N	\N	Diagonaal	4	f	t	\N	\N	numeric	7
968	722	CHECKBOX	\N	14	\N	\N	\N	Veekindel	6	f	t	\N	\N	bool	8
969	722	CHECKBOX	\N	14	\N	\N	\N	Sormejaljelugeja	1	f	t	\N	\N	bool	9
814	789	TEXT	\N	11	\N	\N	\N	p_brand_kood	3	t	t	\N	\N	int4	4
815	789	TEXT	\N	11	\N	\N	\N	p_kirjeldus	5	f	t	\N	\N	d_kirjeldus	6
816	789	TEXT	\N	11	\N	\N	\N	p_kauba_kood	0	t	t	\N	\N	varchar	1
817	789	TEXT	\N	11	\N	\N	\N	p_registreerija_isik_id	4	t	t	\N	\N	int4	5
818	789	TEXT	\N	11	\N	\N	\N	p_nimetus	1	t	t	\N	\N	varchar	2
819	789	TEXT	\N	11	\N	\N	\N	p_hind	2	t	t	\N	\N	numeric	3
820	789	TEXT	\N	11	\N	\N	\N	p_pildi_aadress	6	f	t	\N	\N	varchar	7
976	800	DROP_DOWN	335	\N	8	\N	\N	Kauba kood	1	t	t	\N	\N	varchar	1
977	800	DROP_DOWN	336	\N	8	\N	\N	Värv	0	t	t	\N	\N	int4	2
984	803	DROP_DOWN	343	\N	8	\N	\N	Kaup	0	t	t	\N	\N	varchar	1
985	803	DROP_DOWN	344	\N	8	\N	\N	kategooria	1	t	t	\N	\N	int2	2
986	805	DROP_DOWN	345	\N	8	\N	\N	kaup	0	t	t	\N	\N	varchar	1
987	805	DROP_DOWN	346	\N	8	\N	\N	Kategooria	1	t	t	\N	\N	int2	2
616	630	DROP_DOWN	221	\N	8	\N	\N	Parklakoht	1	t	t	\N	Valige lõpetatav parklakoht	int4	1
617	729	DROP_DOWN	222	\N	8	\N	\N	Aktiveeri kaup	0	t	t	\N	\N	varchar	1
988	798	DROP_DOWN	347	\N	8	\N	\N	Kauba kood	1	t	t	\N	\N	varchar	1
989	798	DROP_DOWN	348	\N	8	\N	\N	Värv kood	0	t	t	\N	\N	int4	2
990	807	TEXT	\N	11	\N	\N	\N	Brand koos	3	t	t	\N	\N	int4	4
991	807	TEXT	\N	11	\N	\N	\N	Kirjeldus	2	t	t	\N	\N	d_kirjeldus	6
992	807	TEXT	\N	11	\N	\N	\N	Kauba kood	0	t	t	\N	\N	varchar	1
917	740	TEXT	\N	11	\N	\N	eesmine_kaamera_kood	Kauba kood	2	f	t	\N	\N	varchar	1
918	740	TEXT	\N	11	\N	\N	kauba_nimetus	nimetus	0	f	t	\N	\N	varchar	2
919	740	TEXT	\N	11	\N	\N	kauba_hind	Hind	3	f	t	\N	\N	numeric	3
626	736	DROP_DOWN	224	\N	8	\N	\N	Muuda kaup mitteaktiivseks	0	t	t	\N	\N	varchar	1
920	740	TEXT	\N	11	\N	\N	kauba_kirjeldus	Kirjeldus	1	f	t	\N	\N	d_kirjeldus	4
921	740	TEXT	\N	11	\N	\N	kauba_pildi_aadress	Pilt	4	f	t	\N	\N	varchar	5
993	807	TEXT	\N	11	\N	\N	\N	Reg isik	5	t	t	\N	\N	int4	5
994	807	TEXT	\N	11	\N	\N	\N	Nimetus	1	t	t	\N	\N	varchar	2
995	807	TEXT	\N	11	\N	\N	\N	Hind	4	t	t	\N	\N	numeric	3
996	807	TEXT	\N	11	\N	\N	\N	Pilt	6	f	t	\N	\N	varchar	7
\.


--
-- Data for Name: form_pre_fill; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.form_pre_fill (form_pre_fill_id, schema_name, view_name) FROM stdin;
4	public	all_rooms
16	public	kaubad_lopetamiseks
\.


--
-- Data for Name: form_region; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.form_region (region_id, form_pre_fill_id, template_id, button_template_id, schema_name, function_name, button_label, success_message, error_message, redirect_url) FROM stdin;
6	\N	7	9	functions	f_permanently_inactivate_a_room	Lõpeta tuba	Tuba on lõpetatud	Toa lõpetamine ebaõnnestus	\N
8	4	7	9	functions	f_change_a_room	Muuda toa andmeid	Ruumi andmed on muudetud	Ruumi andmete muutmine ebaõnnestus	\N
27	\N	7	9	functions	f_permanently_inactivate_a_room	Lõpeta	Toa lõpetamine õnnestus	Toa lõpetamine ebaõnnestus	\N
267	\N	7	9	public	f_lopeta_rada	Lopeta rada	Rada viidud seisundisse Lopetatud	Viga lopetamisel.	\N
264	\N	7	9	public	f_unusta_rada	Unusta rada	Rada edukalt unustatud!	\N	\N
258	\N	7	9	public	kasuta_pilet	Kasuta	Pileti Kasutamine Õnnestus	Pileti Kasutamine Ebaõnnestus	\N
227	\N	7	9	public	f_lopeta_teenus	Send	\N	\N	\N
275	\N	7	9	public	lopeta_kaup	Lõpeta kaup	Kaup on edukalt lõpetatud	Kauba lõpetamine ebaõnnestus	\N
183	\N	7	9	public	f_lopeta_kaup	Lõpeta	Kauba lõpetamine õnnestus	Kauba lõpetamine ebaõnnestus	\N
83	\N	7	9	public	f_lopeta_kaup	Lõpeta	Toote lõpetamine õnnestus	Toote lõpetamine ebaõnnestus	\N
194	\N	7	9	public	f_lopeta_raamat	Lõpeta	Raamat edukalt lõpetatud.	Raamatu lõpetamine ebaõnnestus.	\N
103	\N	7	9	public	f_lopeta_kaup	Lõpeta kaup	Kaup lõpetatud	Kaupa ei olnud võimalik lõpetada	&APPLICATION_ROOT&/app/&APPLICATION_ID&/koik_kaubad
78	\N	7	9	public	f_lopeta_toode	Lõpeta	Toode edukalt lõpetatud	Toote lõpetamine ebaõnnestus	\N
155	\N	7	9	public	f_on_juhataja	Login	\N	Vale kasutajanimi või parool!	\N
187	16	7	9	public	f_lopeta_kaup	Lõpeta	Korras!	Viga!	&APPLICATION_ROOT&/app/&APPLICATION_ID&/lopeta_kaup
209	\N	7	9	public	f_lopeta_kaup	Lõpeta kaup	Kaup edukalt lõpetatud!	Kaupa ei saanud lõpetada!	\N
255	\N	7	9	raamatupood	f_lisa_trykis	Registreeri	Registreerimine õnnestus!	Registreerimine ebaõnnestus!	\N
222	\N	7	9	public	f_lopeta_kaup	Lõpeta	Kaup on lõpetatud	Mingi viga juhtus	\N
177	\N	7	9	public	f_lopeta_treening	Lõpeta	Treeningu lõpetamine õnnestus	Treeningu lõpetamine ebaõnnestus	\N
381	\N	7	9	public	f_lopeta_kaup	Lõpeta kaup	Kaup on lõpetatud	Kaup ei ole lõpetatud	\N
404	\N	7	9	public	f_lopeta_kaup	Lõpeta	Kaup lõpetatud!	Kauba lõpetamine ebaõnnestus!	\N
339	\N	7	9	public	f_lopeta_kaup	Lõpeta	Kaup edukalt lõpetatud	Kauba lõpetamine ebaõnnestus	\N
357	\N	7	9	public	f_lopeta_kaup	Lõpeta	Kaup edukalt lõpetatud.	Kauba lõpetamine ebaõnnestus.	\N
311	\N	7	9	public	f_lopeta_kaup	Lõpeta kaup	Kauba lõpetamine õnnestus	Kauba lõpetamine ebaõnnestus	\N
424	\N	7	9	public	f_lopeta_teenus	Lõpeta	Teenus edukalt lõpetatud	Teenuse lõpetamine ebaõnnestus	\N
349	\N	7	9	public	f_lopeta_kaup	Lõpeta kaup	Kaup on lõpetatud.	Kaupa ei saanud lõpetada.	\N
486	\N	7	9	public	f_lopeta_auto	Lõpeta	Auto lõpetamine õnnestus	Auto lõpetamine ebaõnnestus	\N
340	\N	7	9	public	f_lopeta_parkimiskoht	Lõpeta	Parkimiskoha lõpetamine õnnestus!	Parkimiskoha lõpetamine õnnestus!	\N
421	\N	7	9	public	f_lopeta_kaup	Lõpeta kaup	Kaup lõpetatud	Ei leitud vastavat kaupa või kaupa ei saa lõpetada	\N
446	\N	7	9	public	f_lopeta_laud	Lõpeta	Laua lõpetamine õnnestus	Laua lõpetamine ebaõnnestus	\N
453	\N	7	9	public	f_lopeta_kaup	Lõpeta	Lõpetatud	Viga	\N
458	\N	7	9	public	f_lopeta_parklakoht	Lõpeta	Parklakoht oli lõpetatud	Parklakoha lõpetamise protsessis tekkis viga	\N
496	\N	7	9	public	f_lopeta_laud	Lõpeta	On lõpetatud	On viga	\N
467	\N	7	9	public	f_lopeta_kaupa	Lopeta	Kaup lõpetanud.	Error	\N
511	\N	7	9	public	f_lopeta_laud	Lõpeta	Laua lõpetamine õnnestus	Laua lõpetamine ebaõnnestus	\N
534	\N	7	9	public	f_lopeta_kaup	Lõpeta Kaup	Kaup lõpetatud.	Kaupa ei saanud lõpetada.	\N
800	\N	7	9	public	f_lisa_kaup_variant	Eemalda	Done!	Not Done!	\N
807	\N	7	9	public	f_lisa_kaup	Lisa	Done!	Not Done!	\N
542	\N	7	9	public	f_lopeta_kaup	Lõpeta	Kauba lõpetamine õnnestus	Kauba lõpetamisel tekkis viga!	\N
573	\N	7	9	public	f_lopeta_treening	Lõpeta	Treeningu lõpetamine õnnestus	Treeningut ei õnnestunud lõpetada	\N
570	\N	7	9	public	f_lopeta_teenus	Lõpeta teenus	Teenus on edukalt lõpetatud!	Teenuse lõpetamine ebaõnnestus!	\N
558	\N	7	9	public	f_lopeta_auto	Lõpeta	Auto lõpetamine õnnestus!	Autot ei õnnestunud lõpetada.	\N
803	\N	7	9	public	f_lisa_kaup_kategooria	Lisa	Done!	Not Done!	\N
661	\N	7	9	public	f_lopeta_parkimiskoht	Lõpeta	Parkimiskoha lõpetamine õnnestus!	Parkimiskoha ei õnnestunud lõpetada.	\N
609	\N	7	9	public	f_lopeta_laud	Lõpeta laud	Laud lõpetatud	Lauda ei lõpetatud	\N
657	\N	7	9	public	f_lopeta_laud	Lõpeta	Laud lõpetatud.	Laua lõpetamine ebaõnnestus.	\N
708	\N	7	9	public	f_parklakoha_lopetamine	Lõpeta	Parklakoht on viidud seisundisse lõpetatud	Parklakoha lõpetamine ebaõnnestus	\N
729	\N	7	9	public	f_muuda_kaup_aktiivseks	Aktiveeri	Done!	Not Done!	\N
671	\N	7	9	public	f_unusta_parkimiskoht	Unusta	Parkimiskoha unustamine õnnestus!	Parkimiskohta ei õnnestunud unustada!	\N
617	\N	7	9	public	f_lopeta_teenus	Lõpeta	Teenuse lõpetamine õnnestus	Teenuse lõpetamine ebaõnnestus	\N
629	\N	7	9	public	f_lopeta_parklakoht	Lõpeta parklakoht	Success	Error	\N
710	\N	7	9	public	f_parklakoha_lopetamine	Lõpeta	Parklakoht on viidud seisundisse lõpetatud	Parklakoha lõpetamine ebaõnnestus	\N
704	\N	7	9	public	f_lopeta_prooviruum	Lõpeta	Prooviruum edukalt lõpetatud.	Prooviruumi lõpetamine ebaõnnestus.	\N
630	\N	7	9	public	f_lopeta_parklakoht	Lõpeta	Parklakoha lõpetamine õnnestus	Parklakoha lõpetamine ebaõnnestus	\N
736	\N	7	9	public	f_muuda_kaup_mitteaktiivseks	Muuda mitteaktiivseks	Done!	Not Done!	\N
722	\N	7	9	public	f_lisa_nutitelefon	Registreeri	Done!	Not Done!	\N
740	\N	7	9	public	f_uuenda_kaupa	Uuenda kaupa	Done!	Not Done!	\N
805	\N	7	9	public	f_eemalda_kaup_kategooria	Eemalda	Done!	Not Done!	\N
798	\N	7	9	public	f_lisa_kaup_variant	Lisa	Done!	Not Done!	\N
775	\N	7	9	public	f_lopeta_parklakoht	Lõpeta	Parklakoht on edukalt lõpetatud	Parklakoha lõpetamine ebaõnnestus	\N
787	\N	7	9	public	f_lopeta_parklakoht	Lõpeta	Parklakoht oli edukalt lõpetatud	Viga parklakoha lõpetamisel! Parklakoha seisund ei olnud muudetud	\N
789	\N	7	9	public	f_lisa_kaup	Registreeri	Done!	Not Done!	\N
759	\N	7	9	public	f_unusta_kaup	Unusta	Done!	Not Done!	\N
\.


--
-- Data for Name: form_template; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.form_template (template_id, form_begin, form_end, row_begin, row_end, "row", mandatory_row_begin, mandatory_row_end, mandatory_row) FROM stdin;
7	<form class="form-horizontal" method="POST" action="">	#SUBMIT_BUTTON#</form>	<div class="form-group">	</div>	<label class="col-sm-2 control-label" title="#HELP_TEXT#">#LABEL#</label><div class="col-sm-10">#FORM_ELEMENT#</div>	<div class="form-group">	</div>	<label class="col-sm-2 control-label" title="#HELP_TEXT#">#LABEL# *</label><div class="col-sm-10">#FORM_ELEMENT#</div>
\.


--
-- Data for Name: html_region; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.html_region (region_id, content) FROM stdin;
2	Allpool näete <strong>raporteid</strong>
32	Hotelli infosüsteemi, ruumide funktsionaalse allsüsteemi, juhataja töökoht.\n\n<p>Õppeaine <b>"Andmebaasid II"</b> näiterakendus.</p>
65	<h1>Kõik poe kaubad</h1>
239	<h1>Vali kaup mida soovid lõpetada</h1>
240	<h1>Koondaruanne</h1>
245	<h2 style="margin-left:195px;">Kas oled kindel, et soovid lõpetada?</h2>
279	content here
288	Allpool näete <strong>parkimiskohtade koondaruannet</strong>
330	<h1>Kõik telefonid</h1>
387	Allpool on esitatud aruanded.
336	<h1>Kaupade koondaruanne</h1>
332	<h1>Lõpeta kaupu</h1>
359	<h3>Tähenärija</h3>\n<h4>IDU0230 Andmebaasid II</h4>\n<p>Projektrakendus</p>\n<br>\n<p>\n<b>Autorid:</b><br>\nJaanus Keller 155243IAPB<br>\nRasmus Tomsen 155199IAPB<br>\nEva Maria Veitmaa 155408IAPB</p>\n<br>\n\n<p>2017</p>
508	<b>Aktiivsete laudade nimekiri</b><hr>
505	<b>Kõiki laudade nimekiri</b><hr>
514	Restorani infosüsteemi, laudade funktsionaalse allsüsteemi, juhataja töökoht.\n\n<p>Õppeaine <b>"Andmebaasid II"</b> näiterakendus.</p>
519	<!DOCTYPE html>\n<html>\n<body>\n\n<h1>My First Heading</h1>\n\n<p>My first paragraph.</p>\n\n</body>\n</html>
442	Restoraani infosüsteemi, laudade funktsionaalse allsüsteemi, juhataja töökoht.\n\n<p>Õppeaine <b>"Andmebaasid II"</b> rakendus.</p>
468	Jah, ma tean, et see lahendus (et võtmed korduvad dropdown-ites) ei ole kõige parem ning oleks palju ilusam kasutada mingit parklakoha_id bigserial tüüpiga surrogaat võtit Parklakoht tabelis, aga siis tulevad nii suured struktuuri muutused, et ma lihtsalt ei suuda nii palju aega raisata uue struktuuri kontrollimiseks.\nKui platvormina kasutada mitte pgApex vaid midagi muud, siis võiks ka teha lihtsama filtreeringu juba rakenduses, et seda probleemi lahendada...
483	Autorendiettevõtte autode arvestus infosüsteemi, auto funktsionaalse allsüsteemi, juhataja töökoht.\n\n<p>Õppeaine <b>"Andmebaasid II"</b> rakendus.</p>
529	<div>Alguma coisa</div>
528	Alguma coisa
499	<b>Lauad, mida saab lõpetada</b><hr>
547	Kõikide treeningute nimekiri
548	Valitud treeningu detailvaade
642	<h3>Parkla parklakohtade arvestus</h3>\n<h4>IDU0230 Andmebaasid II</h4>\n<p>Projekti rakendus</p>\n<br>\n<p>\n<b>Autorid:</b><br>\nVladimir Kulagin 164225IAPB<br>\nDmitri Kondratjev 164422IAPB<br>\n</p><br>\n\n<p>2018</p>
551	<h3>Spordiklubi PAR tegevuse haldamise rakendus</h3>\n<br>\n<p>\n<b>Autorid:</b><br>\nPeep Binsol<br>\nArt Arukaevu<br>\nRainer Mulk</p>\n<br>\n\n<p>© 2018-2019</p>
562	<h3>Juuksurisalong</h3>\n<h4>IDU0230 Andmebaasid II</h4>\n<p>\n<b>Autorid:</b><br>\nAngelina Polštšikova 164471IABB<br>\nDaniel Tšarin 164648IABB<br>\nIgor Nehorošev 164642IABB</p>\n<br>\n\n<p>2018</p>
282	Hooandja lehekülg
589	Parklate infosüsteemi, parklakohtade funktsionaalse allsüsteemi, juhataja töökoht.\n\n<p>Õppeaine <b>"Andmebaasid II"</b> näiterakendus.</p>
611	Restorani infosüsteemi laudade funktsionaalse allsüsteemi juhataja töökoht.\n\nLoodud õppeaine "Andmebaasid II" raames.
619	Kõikide treeningute olekute koguste koondaruanne
678	<h3>Prooviruum</h3>\n<h4>IDU0230 Andmebaasid II</h4>\n<p>Projektrakendus</p>\n<br>\n<p>\n<b>Autorid:</b><br>\nStiv Kapten 155233IAPB<br>\nMarkus Tarn 155048IAPB<br>\nMarkus Luik 163914IAPB</p>\n<br>\n\n<p>2018</p>
681	Aruanded:
712	Vali prooviruum mida lõpetada ja vajuta lõpeta:
714	Prooviruumide detailandmed:
717	Rakendus realiseerib parklakohtade infosüsteemi juhataja töökohta. <br>\nAutorid:<br>\n\n<ul><li>Caroline Treu 142459IAPB</li>\n<li>Anna Juurik 142598IAPB</li></ul>
\.


--
-- Data for Name: input_template; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.input_template (template_id, template, input_template_type_id) FROM stdin;
11	<input type="text" class="form-control" placeholder="#ROW_LABEL#" name="#NAME#" value="#VALUE#">	TEXT
12	<input type="password" class="form-control" placeholder="#ROW_LABEL#" name="#NAME#" value="#VALUE#">	PASSWORD
13	<div><input type="radio" name="#NAME#" value="#VALUE#"#CHECKED#> #INPUT_LABEL#</div>	RADIO
14	<input type="checkbox" class="checkbox" name="#NAME#" value="#VALUE#"#CHECKED#>	CHECKBOX
\.


--
-- Data for Name: input_template_type; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.input_template_type (input_template_type_id) FROM stdin;
TEXT
PASSWORD
RADIO
CHECKBOX
\.


--
-- Data for Name: list_of_values; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.list_of_values (list_of_values_id, value_view_column_name, label_view_column_name, view_name, schema_name) FROM stdin;
13	room_code	room_name	active_temporariliy_inactive_rooms	public
14	bed_type_code	bed_type_name	all_bed_types	public
21	room_code	room_name	active_temporariliy_inactive_rooms	public
25	kauba_kood	nimetus	aktiivsed_mitteaktiivsed_kaubad	public
27	kaup_kood	kaup_kood	vaade_koik_kaubad	public
29	toode_id	nimetus	lopeta_toode	public
53	kauba_kood	kauba_nimetus	kaupade_lopetamine	public
55	raamat_id	isbn	lopetatavad_raamatud	public
64	kauba_kood	nimetus	lopetatavad_kaubad	public
68	kaup_kood	kaup_kood	kaup_aktiivne_mitteaktiivne	public
69	treening_id	nimetus	aktiivsed_mitteaktiivsed_treeningud	public
73	trykise_kategooria_kood	nimetus	trykiste_kategooriad	raamatupood
74	kirjastuse_kood	nimetus	kirjastused	raamatupood
75	trykise_seisundi_kood	nimetus	trykiste_seisundi_liigid	raamatupood
80	raja_kood	nimetus	lopeta_rada	public
81	raja_kood	nimetus	unusta_rada	public
82	pilet_kood	pilet_kood	piletid_kasutamiseks	public
84	kauba_kood	kauba_kood	aktiivsed_voi_mitteaktiivsed_kaubad	public
94	kaup_id	kaup_id	aktiivsed_mitteaktiivsed_kaubad	public
107	kaup_kood	kaup_kood_nimetus	aktiivsed_mitteaktiivsed_kaubad	public
108	kauba_kood	kauba_nimetus	kauba_aktiivne_voi_mitteaktiivne	public
109	kauba_kood	kauba_kood	kaup_aktiivne_mitteaktiivne	public
110	teenus_kood	nimetus	aktiivsed_mitteaktiivsed_teenused	public
111	kauba_kood	nimetus	kauba_aktiivsus	public
115	parklakoha_kood	nimetus	v_aktiivsed_mitteaktiivsed_parkimiskohad	public
116	kaup_kood	nimetus	v_lopetatavad_kaubad	public
117	laua_kood	nimetus	aktiivsed_voi_mitteaktiivsed_lauad	public
124	kaup_id	kaup_id	kaup_aktiivne_voi_mitteaktiivne	public
125	parklakoha_kood	parklakoha_kood	parklakohad_lopetamiseks	public
126	parkla_kood	parkla_kood	parklakohad_lopetamiseks	public
131	auto_kood	nimetus	aktiivsed_voi_mitteaktiivsed_autod	public
137	laud_kood	nimetus	aktiivsed_voi_mitteaktiivsed_lauad	public
145	laud_id	laua_nimetus	aktiivsed_mitteaktiivsed_lauad	public
146	kauba_kood	kauba_nimetus	aktiivsed_mitteaktivsed_kaubad	public
221	parklakoht_kood	kommentaar	aktiivsed_mitteaktiivsed_parklakohad	public
222	kauba_kood	kauba_kood	aktiveeritavad_kaubad_v	public
151	kauba_kood	kauba_kood	aktiivsed_mitteaktiivsed_kaubad	public
224	kauba_kood	kauba_kood	aktiivsed_kaubad_v	public
154	auto_kood	auto_kood	aktiivsed_mitteaktiivsed_autod	public
166	treeningu_kood	treeningu_kood	aktiivsed_mitteaktiivsed_treeningud	public
304	kauba_kood	kauba_nimetus	ootel_kaubad_v	public
181	laua_kood	laua_kood	aktiivsed_mitteaktiivsed_lauad	public
253	parklakoha_kood	parklakoha_kood	lopetatavad_parklakohad	public
190	parklakoht_kood	parklakoht_kood	aktiivsed_mitteaktiivsed_parklakohad	public
191	teenus_kood	teenus_nimetus	koik_mitteaktiivsed_ja_aktiivsed_teenused	public
193	laua_kood	laua_kood	laud_ootel_mitteaktiivne	public
326	kauba_kood	kauba_nimetus	koik_kaubad_v	public
327	protsessor_kood	protsessor_nimetus	protsessor_v	public
328	sisemalu_kood	sisemalu_nimetus	sisemalu_v	public
199	parkimiskoha_kood	parkimiskoha_kood	aktiivsed_mitteaktiivsed_parkimiskohad	public
200	parkimiskoha_kood	parkimiskoha_kood	ootel_parkimiskohad	public
201	teenus_kood	teenus_nimetus	aktiivsed_mitteaktiivsed_teenused	public
329	ekraani_resolutsioon_kood	ekraani_resolutsioon_nimetus	ekraani_resolutsioon_v	public
330	kaamera_kood	kaamera_nimetus	kaamera_v	public
331	kaamera_kood	kaamera_nimetus	kaamera_v	public
332	diagonaal_kood	diagonaal_nimetus	diagonaal_v	public
335	kauba_kood	kauba_kood	kauba_variandid_v	public
336	varv_nimetus	varv_nimetus	kauba_variandid_v	public
213	parklakoht_kood	parklakoht_kood	lopetatavad_parklakohad	public
215	parklakoht_kood	parklakoht_kood	lopetatavad_parklakohad	public
216	prooviruumi_kood	prooviruumi_nimetus	aktiivsed_mitteaktiivsed_prooviruumid	public
343	kauba_kood	kauba_nimetus	muudetavad_kaubad_v	public
344	kauba_kategooria_nimetus	kauba_kategooria_nimetus	valitavad_kategooriad_v	public
345	kauba_kood	kauba_nimetus	muudetavad_kaubad_v	public
346	kauba_kood	kauba_kategooria_nimetus	kauba_kategooriad_v	public
347	kauba_kood	kauba_nimetus	kauba_variandid_v	public
348	varv_kood	nimetus	valitavad_varvi_variandid_v	public
\.


--
-- Data for Name: navigation; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.navigation (navigation_id, application_id, name) FROM stdin;
1	1	Navigatsioon
4	21	Sisukord
8	20	nav-top
11	25	Navigation
14	26	Koondaruanne
29	28	Nav
30	23	nav
31	22	Nav
35	30	Navigatsioon
36	29	Epood
38	16	Main navigation
9	23	menubar
40	18	registreeri trükis
41	18	vaata trükiseid
42	36	Nav
43	37	Main nav
45	39	Navigation
46	41	Nav
47	44	navigation1
50	45	satnav
58	50	Navigation
61	53	menu
64	48	Navigatsioon
66	55	MegaNavigation
70	60	Nav
69	59	Navigation
72	54	Navigatsioon
73	47	Nav
74	62	Navigation
75	42	Nav
76	63	Top navigation
77	64	nav1
78	66	Navigation
79	67	Navigation
81	65	navigation
82	68	Pealeheküljele
83	69	Koond_Nav
49	46	Projektidnavi1
85	71	outro
84	71	Navegador
86	79	Nav
3	12	Nav
88	81	Navigeeri
60	49	Menüü
89	82	Navigation
90	84	NavigationBar
91	86	Kõik treeningud
94	83	Nav
95	76	Teenuste_detailid
99	74	Nav
100	87	Navigatsioon
101	90	Navigatsioon
103	91	Nav
104	85	Navigatsioon
97	88	Nav
87	80	Menüü
107	95	Top navigation
108	96	Navigation
110	98	Peamine navigatsioon
106	92	top-nav
113	99	Nav
114	101	top-nav
\.


--
-- Data for Name: navigation_item; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.navigation_item (navigation_item_id, parent_navigation_item_id, navigation_id, page_id, name, sequence, url) FROM stdin;
2	\N	1	2	Lõpeta tuba	20	\N
3	\N	1	\N	Logi välja	30	&LOGOUT_LINK&
1	\N	1	1	Aruanded	10	\N
72	\N	31	29	Kõik kaubad	10	\N
73	\N	31	71	Kaupade koondaruanne	20	\N
74	\N	31	73	Lõpeta kaup	30	\N
75	\N	31	\N	Logi välja	40	&LOGOUT_LINK&
7	\N	3	14	Kõik toad	10	\N
9	\N	3	16	Lõpeta tuba	30	\N
10	\N	3	\N	Logi välja	50	&LOGOUT_LINK&
12	\N	3	18	Programmist	40	\N
80	\N	35	\N	Logi välja	15	&LOGOUT_LINK&
14	\N	3	21	Tubade koondaruanne	20	\N
15	\N	4	25	Index	0	\N
16	\N	4	27	Koondaruanne	1	\N
86	\N	36	81	Kaupade koondaruanne	3	\N
87	\N	36	82	Lõpeta kaup	4	\N
81	\N	35	78	Lõpeta raamat	4	\N
79	\N	35	76	Koondaruanne	3	\N
88	\N	35	80	Raamatute info	2	\N
24	\N	8	32	Toodete koondaruanne	1	\N
22	\N	8	30	Kõik tooted	0	\N
89	\N	36	85	Kõik kaubad	1	\N
29	\N	8	\N	Logi välja	30	&LOGOUT_LINK&
91	\N	36	\N	Logi Välja	99	&LOGOUT_LINK&
30	\N	8	36	Lõpeta toode	2	\N
31	\N	11	\N	Logi välja	50	&LOGOUT_LINK&
33	\N	11	44	Toodete koondaruanne	20	\N
34	\N	11	45	Lõpeta toode	30	\N
36	\N	14	47	Koondaruanne	0	\N
38	\N	14	49	Kõik teenused	2	\N
41	\N	11	52	Kõik tooted	0	\N
42	\N	4	41	Kõik kaubad	2	\N
95	\N	38	91	Kõik kaubad	0	\N
92	\N	38	22	Aruanded	1	\N
94	\N	38	90	Lõpeta kaupu	2	\N
96	\N	38	\N	Logi välja	3	/pgapex/public/index.php/logout/16
101	\N	14	96	Lõpeta teenus	10	\N
28	\N	9	37	Kõik kaubad	0	\N
71	\N	9	70	Kustuta kaup	2	\N
103	\N	9	100	Koondaruanne	3	\N
105	\N	40	106	Registreeri trükis	1	\N
106	\N	41	105	Vaata trükiseid	1	\N
64	\N	29	64	Treeningud	10	\N
65	\N	29	65	Treeningute koondaruanne	20	\N
67	\N	29	67	Treeningute eemaldamine	40	\N
107	\N	42	\N	Logi Välja	20	&LOGOUT_LINK&
70	\N	29	\N	Logi välja	79	&LOGOUT_LINK&
108	\N	42	108	Vali Kasutatud Pilet	10	\N
109	\N	43	110	Radade aruanne	0	\N
110	\N	43	111	Radade list	1	\N
111	\N	43	112	Unusta rada	2	\N
112	\N	43	113	Lopeta rada	4	\N
113	\N	43	\N	Logi välja	99	&LOGOUT_LINK&
115	\N	45	116	Lõpeta kaup	40	\N
117	\N	45	115	Kõik kaubad	30	\N
116	\N	45	118	Kauba koondaruanne	50	\N
118	\N	45	\N	Logi välja	70	&LOGOUT_LINK&
119	\N	49	126	navigation1	1	\N
204	\N	77	209	Vaata kõik kaubad	4	\N
121	\N	50	131	Koondaruanne	10	\N
122	\N	50	132	Lõpeta parkimiskoht	20	\N
203	\N	77	207	Vaata aruannet	5	\N
124	\N	50	133	Kõik parkimiskohad	5	\N
205	\N	77	210	Detaalne info	88	\N
131	\N	58	140	Kõik kaubad	10	\N
132	\N	58	142	Kauba koondaruanne	20	\N
133	\N	58	141	Lõpeta kaup	30	\N
134	\N	58	\N	Logi välja	50	&LOGOUT_LINK&
141	\N	60	151	Kaupade detailid	2	\N
142	\N	60	\N	Logi välja	10	&LOGOUT_LINK&
140	\N	60	150	Lõpeta kaup	4	\N
143	\N	61	152	Kõik kaubad	0	\N
145	\N	61	154	Kaupade koondaruanne	2	\N
146	\N	61	\N	Logi välja	10	&LOGOUT_LINK&
144	\N	61	153	Lõpeta kaupu	1	\N
123	\N	50	\N	Logi välja	300	&LOGOUT_LINK&
160	\N	66	165	Kõik kaubad	30	\N
151	\N	64	134	Lõpeta kaupu	20	\N
153	\N	60	160	Info	5	\N
155	\N	61	162	Kaupade detailvaade	3	\N
163	\N	66	172	Lõpeta kaup	20	\N
164	\N	66	173	Kaubade koondaruanne	60	\N
150	\N	64	\N	Logi välja	50	&LOGOUT_LINK&
138	\N	60	149	Aruanded	1	\N
167	\N	64	176	Kõik kaubad	40	\N
152	\N	64	137	Kaupade koondaruanne	10	\N
168	\N	66	\N	Logi välja	300	&LOGOUT_LINK&
161	\N	66	168	Kaubade detailid	50	\N
172	\N	69	177	Vaata kõiki kaupu	10	\N
176	\N	70	184	Lõpeta kaup	15	\N
177	\N	70	185	Koondaruanne	10	\N
175	\N	70	183	Kõik kaubad	9	\N
178	\N	70	\N	Logi välja	50	&LOGOUT_LINK&
171	\N	69	179	Lõpetatavad kaubad	30	\N
179	\N	69	186	Vaata kaupade koondaruannet	20	\N
174	\N	69	\N	Logi välja	100	&LOGOUT_LINK&
182	\N	72	157	Kõik teenused	0	\N
183	\N	72	193	Teenuste koondaruanne	1	\N
184	\N	72	158	Lõpeta teenus	2	\N
185	\N	72	\N	Logi välja	30	&LOGOUT_LINK&
187	\N	73	194	Etendused	2	\N
166	\N	64	175	Kauba detailid	30	\N
188	\N	74	196	Kõik lauad	10	\N
189	\N	74	197	Laudade koondaruanne	20	\N
190	\N	74	198	Lõpeta laud	30	\N
191	\N	74	199	Programmist	40	\N
192	\N	74	\N	Logi välja	50	&LOGOUT_LINK&
193	\N	75	130	Kaubad	0	\N
194	\N	75	200	Lõpeta kaupu	1	\N
195	\N	75	201	Aruanded	2	\N
197	\N	76	203	Lõpetamiseks	20	\N
198	\N	76	205	Parklakohtade täpsem vaade	30	\N
199	\N	76	204	Koondaruanne	40	\N
200	\N	76	\N	Log out	50	&LOGOUT_LINK&
196	\N	76	202	Kõikide parklakohtade seisundid	10	\N
208	\N	78	214	Kõik autod	1	\N
209	\N	78	215	Auto koondaruanne	2	\N
210	\N	78	216	Lõpeta auto	3	\N
211	\N	78	217	Programmist	4	\N
212	\N	78	\N	Logi välja	5	&LOGOUT_LINK&
225	\N	81	\N	Logi välja	5	http://apex.ttu.ee/pgapex/public/#/logout
214	\N	79	218	Kõik lauad	1	\N
201	\N	77	208	Kauba lõpetamine	2	\N
215	\N	79	220	Koondaruanne	2	\N
216	\N	79	221	Lõpeta laud	3	\N
343	\N	106	329	Registreeri nutitelefon	2	\N
226	\N	82	227	ASD	0	\N
221	\N	81	213	Kõik lauad	1	\N
222	\N	81	224	Lõpeta laud	2	\N
217	\N	79	\N	Logi välja	5	&LOGOUT_LINK&
219	\N	79	223	Aktiivsed lauad	0	\N
231	\N	83	\N	Logi välja	99	&LOGOUT_LINK&
228	\N	83	229	Vaata kaupu	1	\N
223	\N	81	225	Programmist	4	\N
224	\N	81	226	Laudade koondaruanded	3	\N
229	\N	83	230	Vaata kaupu detailselt	2	\N
227	\N	83	228	Koondaruanne	0	\N
230	\N	83	231	Aktiivsed Mitteaktiivsed Kaubad	3	\N
232	\N	84	232	Home	1	\N
233	\N	84	233	ietm02	6	\N
234	\N	85	232	manu01	6	\N
235	\N	86	241	Kaupade koondaruanne	1	\N
236	\N	86	242	Lõpeta kaubad	2	\N
237	\N	86	244	Kõik kaubad	0	\N
240	\N	87	\N	Logi välja	50	&LOGOUT_LINK&
361	\N	106	355	Lisa kauba variant	8	\N
344	\N	106	328	Aktiveeri kaup	3	\N
345	\N	106	334	Muuda kaup mitteaktiivseks	4	\N
245	\N	88	252	Info	9	\N
242	\N	88	249	Kõik treeningud	0	\N
243	\N	88	251	Treeningu detailid	1	\N
346	\N	106	335	Unusta kaup	5	\N
247	\N	89	253	Kõik autod	1	\N
248	\N	89	254	Autode koondaruanne	2	\N
249	\N	89	255	Lõpeta auto	3	\N
250	\N	89	256	Autode detailid	4	\N
244	\N	88	\N	Logi välja	10	&LOGOUT_LINK&
251	\N	89	\N	Logi välja	10	&LOGOUT_LINK&
254	\N	90	260	Teenuste detailid	2	\N
256	\N	90	263	Teenuste koondaruanne	4	\N
253	\N	90	259	Kõik teenused	1	\N
255	\N	90	262	Lõpeta teenus	3	\N
257	\N	88	257	Lõpeta treening	3	\N
259	\N	86	245	Kaupade detailandmed	3	\N
260	\N	91	265	Kõik treeningud	1	\N
263	\N	94	267	Vaata kõiki parklakohti	10	\N
264	\N	94	269	Vaata parklakohtade koondaruannet	20	\N
265	\N	94	271	Programmist	40	\N
266	\N	95	239	Avaleht	0	\N
353	\N	113	346	Parklakohtade detailvaade	2	\N
309	\N	106	\N	Logi välja	99	&LOGOUT_LINK&
339	\N	110	339	Parklakohtade koondaruanne	1	\N
356	\N	110	348	Lõpetatavad parklakohad	2	\N
357	\N	110	350	Parklakohtade detailid	3	\N
252	\N	90	258	Info	5	\N
272	\N	90	\N	Logi välja	6	&LOGOUT_LINK&
358	\N	114	351	Registreeri kaup	0	\N
275	\N	99	280	Lõpeta laud	2	\N
276	\N	99	282	Programmist	3	\N
277	\N	99	\N	Logi välja	4	&LOGOUT_LINK&
278	\N	100	266	Kõik teenused	10	\N
359	\N	113	353	Kõik parklakohad	1	\N
282	\N	88	286	Treeningute koondaruanne	4	\N
355	\N	113	\N	Logi välja	5	&LOGOUT_LINK&
354	\N	113	347	Lõpeta parklakoht	4	\N
352	\N	113	341	Parklakohtade koondaruanne	3	\N
78	\N	35	77	Kõik raamatud	1	\N
347	\N	106	336	Muuda nutitelefoni andmeid	6	\N
360	\N	106	354	Vaata kõiki ootel või mitteaktiivseid kaupu	7	\N
297	\N	104	302	Vaata kõiki laudu	1	\N
286	\N	94	290	Lõpeta parklakoht	30	\N
362	\N	106	356	Eemalda kauba variant	9	\N
363	\N	106	357	Lisa kaup kategooriasse	10	\N
364	\N	106	358	Eemalda kaup kategooriast	11	\N
273	\N	99	294	Kõik lauad	0	\N
289	\N	103	295	Kõik lauad	0	\N
365	\N	106	362	Lisa kaup	1	\N
290	\N	101	288	Parklakohtade detailid	2	\N
283	\N	101	287	Kõik parklakohad	1	\N
285	\N	101	289	Lõpeta parklakoht	3	\N
292	\N	101	\N	Logi välja	6	&LOGOUT_LINK&
366	\N	83	235	Lõpeta Kaup	4	\N
287	\N	101	291	Parklakohtade koondaruanne	4	\N
291	\N	101	296	Info	5	\N
293	\N	94	\N	Logi välja	60	&LOGOUT_LINK&
269	\N	97	275	Lõpeta parkimiskoht	3	\N
301	\N	97	306	Parkimiskoha detailid	2	\N
302	\N	97	270	Avaleht	1	\N
303	\N	97	307	Parkimiskohtade koondaruanne	4	\N
274	\N	99	281	Laudade koondaruanne	1	\N
325	\N	108	\N	Logi välja	5	&LOGOUT_LINK&
280	\N	100	284	Teenuste koondaruanne	20	\N
281	\N	100	285	Lõpeta teenus	30	\N
304	\N	97	\N	Logi väja	6	&LOGOUT_LINK&
305	\N	97	308	Unusta parkimiskoht	5	\N
306	\N	106	297	Kõik kaubad	0	\N
310	\N	100	\N	Logi välja	50	&LOGOUT_LINK&
311	\N	87	314	Aruanded	1	\N
312	\N	87	250	Prooviruumide detailid	2	\N
313	\N	87	313	Info	4	\N
314	\N	107	316	Kõik parklakohad	10	\N
316	\N	107	317	Detailandmed	30	\N
317	\N	107	315	Koondaruanne	40	\N
318	\N	107	\N	Log out	50	&LOGOUT_LINK&
319	\N	87	319	Lõpeta prooviruum	3	\N
321	\N	108	321	Kõik parklakohad	1	\N
322	\N	108	322	Lõpeta parklakoht	2	\N
323	\N	108	323	Koondaruanne	3	\N
324	\N	108	324	Detailandmed	4	\N
326	\N	107	325	Rakendusest	45	\N
299	\N	104	\N	Logi välja	6	&LOGOUT_LINK&
296	\N	104	301	Koondaruanne	3	\N
327	\N	104	326	Vaata aktiivseid/mitteaktiivseid laudu	2	\N
300	\N	104	304	Laudade detailid	4	\N
298	\N	104	303	Lõpeta laudu	5	\N
320	\N	107	320	Lõpetatavad parklakohad	20	\N
341	\N	110	\N	Logi välja	5	&APPLICATION_ROOT&/logout/&APPLICATION_ID&
\.


--
-- Data for Name: navigation_item_template; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.navigation_item_template (navigation_item_template_id, navigation_template_id, active_template, inactive_template, level) FROM stdin;
1	3	<li class="active"><a href="#URL#">#NAME#</a></li>	<li><a href="#URL#">#NAME#</a></li>	1
\.


--
-- Data for Name: navigation_region; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.navigation_region (region_id, navigation_type_id, navigation_id, template_id, repeat_last_level) FROM stdin;
5	MENU	1	3	f
7	MENU	1	3	f
1	MENU	1	3	f
165	MENU	29	3	f
168	MENU	29	3	f
26	MENU	3	3	f
167	MENU	29	3	f
31	MENU	3	3	f
182	MENU	31	3	f
36	MENU	3	3	f
44	MENU	4	3	f
49	MENU	31	3	f
186	MENU	31	3	f
53	MENU	8	3	f
192	MENU	35	3	f
58	MENU	8	3	f
66	MENU	9	3	f
72	MENU	4	3	f
62	MENU	8	3	f
74	MENU	8	3	f
59	MENU	8	3	f
193	MENU	35	3	f
82	MENU	11	3	f
84	MENU	11	3	f
196	MENU	35	3	f
90	MENU	14	3	t
95	MENU	14	3	f
98	MENU	11	3	f
104	MENU	4	3	f
203	MENU	36	3	f
204	MENU	36	3	f
205	MENU	35	3	f
210	MENU	36	3	f
215	MENU	38	3	f
218	MENU	38	3	f
226	MENU	14	3	f
180	MENU	9	3	f
241	MENU	9	3	f
252	MENU	40	3	f
254	MENU	41	3	f
261	MENU	43	3	f
262	MENU	43	3	f
265	MENU	43	3	f
268	MENU	43	3	f
256	MENU	42	3	f
276	MENU	45	3	f
277	MENU	45	3	f
278	MENU	45	3	f
287	MENU	50	3	f
290	MENU	50	3	f
291	MENU	50	3	f
307	MENU	58	3	f
310	MENU	58	3	f
313	MENU	58	3	f
322	MENU	60	3	f
324	MENU	60	3	f
328	MENU	60	3	f
334	MENU	61	3	f
335	MENU	61	3	f
338	MENU	61	3	f
348	MENU	64	3	f
350	MENU	64	3	f
366	MENU	61	3	f
457	MENU	76	3	f
459	MENU	76	3	f
384	MENU	66	3	f
461	MENU	76	3	f
375	MENU	66	3	f
380	MENU	66	3	f
373	MENU	66	3	f
393	MENU	64	3	f
394	MENU	64	3	f
463	MENU	76	3	f
358	MENU	60	3	f
396	MENU	69	3	f
397	MENU	69	3	f
406	MENU	70	3	f
407	MENU	70	3	f
408	MENU	70	3	f
411	MENU	69	3	f
423	MENU	72	3	f
426	MENU	72	3	f
428	MENU	72	3	f
430	MENU	72	3	f
435	MENU	73	3	f
436	MENU	73	3	f
439	MENU	74	3	f
438	MENU	74	3	f
440	MENU	74	3	f
441	MENU	74	3	f
448	MENU	75	3	f
449	MENU	75	3	f
450	MENU	75	3	f
471	MENU	77	3	f
472	MENU	77	3	f
473	MENU	77	3	f
474	MENU	77	3	f
480	MENU	78	3	f
481	MENU	78	3	f
482	MENU	78	3	f
479	MENU	78	3	f
492	MENU	79	3	f
493	MENU	79	3	f
494	MENU	79	3	f
506	MENU	79	3	f
510	MENU	81	3	f
513	MENU	81	3	f
515	MENU	81	3	f
518	MENU	81	3	f
521	MENU	83	3	f
526	MENU	83	3	f
527	MENU	83	3	f
523	MENU	83	3	f
530	MENU	84	3	t
533	MENU	83	3	t
539	MENU	86	3	f
540	MENU	86	3	f
543	MENU	86	3	f
550	MENU	88	3	f
546	MENU	88	3	f
552	MENU	88	3	f
553	MENU	89	3	f
555	MENU	89	3	f
556	MENU	89	3	f
559	MENU	89	3	f
563	MENU	90	3	f
564	MENU	90	3	f
566	MENU	90	3	f
568	MENU	90	3	f
571	MENU	90	3	f
575	MENU	88	3	f
580	MENU	86	3	f
24	MENU	3	3	f
583	MENU	94	3	f
587	MENU	94	3	f
606	MENU	99	3	f
608	MENU	99	3	f
610	MENU	99	3	f
613	MENU	100	3	f
614	MENU	100	3	f
616	MENU	100	3	f
618	MENU	100	3	f
621	MENU	88	3	f
628	MENU	101	3	f
632	MENU	94	3	f
219	MENU	38	3	f
586	MENU	94	3	f
638	MENU	99	3	f
640	MENU	103	3	f
634	MENU	101	3	f
643	MENU	101	3	f
627	MENU	101	3	f
624	MENU	101	3	f
651	MENU	104	3	f
650	MENU	104	3	f
652	MENU	104	3	f
659	MENU	104	3	f
662	MENU	97	3	f
664	MENU	97	3	f
665	MENU	97	3	f
667	MENU	97	3	f
672	MENU	97	3	f
674	MENU	106	3	f
679	MENU	87	3	f
680	MENU	87	3	f
684	MENU	87	3	f
685	MENU	107	3	f
688	MENU	107	3	f
689	MENU	107	3	f
695	MENU	87	3	f
696	MENU	107	3	f
698	MENU	108	3	f
699	MENU	108	3	f
700	MENU	108	3	f
701	MENU	108	3	f
716	MENU	107	3	f
718	MENU	104	3	f
728	MENU	106	3	f
738	MENU	106	3	f
737	MENU	106	3	f
751	MENU	110	3	f
721	MENU	106	3	t
770	MENU	113	3	f
773	MENU	113	3	f
780	MENU	110	3	f
782	MENU	110	3	f
788	MENU	114	3	f
791	MENU	113	3	f
771	MENU	113	3	f
793	MENU	106	3	f
741	MENU	106	3	f
797	MENU	106	3	f
799	MENU	106	3	f
802	MENU	106	3	f
804	MENU	106	3	f
806	MENU	106	3	f
\.


--
-- Data for Name: navigation_template; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.navigation_template (template_id, navigation_begin, navigation_end) FROM stdin;
3	<ul class="nav navbar-nav">	</ul>
\.


--
-- Data for Name: navigation_type; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.navigation_type (navigation_type_id) FROM stdin;
MENU
BREADCRUMB
SITEMAP
\.


--
-- Data for Name: page; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.page (page_id, application_id, template_id, title, alias, is_homepage, is_authentication_required) FROM stdin;
81	29	2	Kaupade koondaruanne	Koondaruanne	f	t
82	29	2	Lõpetatavad kaubad	\N	f	t
85	29	2	Kõik kaubad	\N	t	t
96	26	2	Lõpeta aktiivseid ja mitteaktiivseid teenuseid	\N	f	t
100	23	2	Koondaruanne	koondaruanne	f	t
70	23	2	Lõpeta kaup	lopeta_kaup	f	t
3	1	2	Muuda toa andmeid	change_room	f	t
2	1	2	Lõpeta tuba	inactivate_rooms	f	t
1	1	2	Aruanded	reports	t	t
74	23	2	Lõpetamise kinnitus	kinnitus	f	t
37	23	2	Pealeht	\N	t	t
25	21	2	Index	\N	t	t
47	26	2	Koondaruanne	\N	f	f
29	22	2	Kõik kaubad	Kõik	t	t
27	21	2	Koondaruanne	\N	f	t
41	21	2	Kõik kaubad	\N	f	t
210	64	2	Kauba Detaalne Info	Kauba_Detaalne_Info	f	t
115	39	2	Kõik kaubad	\N	t	t
116	39	2	Lõpeta kaup	\N	f	t
118	39	2	Kauba koondaruanne	\N	f	t
44	25	2	Toodete koondaruanne	\N	f	t
45	25	2	Lõpeta toode	\N	f	t
52	25	2	Kõik tooted	Kõik	t	t
106	18	2	Registreeri trükis	\N	f	t
105	18	2	Vaata trükiseid	\N	t	t
108	36	2	Kasutatud piletite valimine	\N	t	t
22	16	2	Aruanded	\N	f	t
91	16	2	Kõik kaubad	\N	t	t
90	16	2	Lõpeta kaupu	\N	f	t
63	28	2	Login	\N	f	t
64	28	2	Treeningud	\N	t	t
65	28	2	Treeningute koondaruanne	\N	f	t
71	22	2	Kaupade koondaruanne	Koond	f	t
73	22	2	Lõpeta kaup	Lõpeta	f	t
67	28	2	Treeningute lõpetamine	\N	f	t
113	37	2	Lopeta rada	\N	f	t
110	37	2	Radade aruanne	\N	f	t
112	37	2	Unusta rada	\N	f	t
111	37	2	Kõikide radade nimekiri	\N	t	t
119	41	2	Home	\N	t	f
224	65	2	Lõpeta laud	Lõpeta	f	t
49	26	2	Kõik teenused	\N	t	f
121	43	2	Pildid	pildid	t	f
122	44	2	Main	\N	t	f
123	44	2	projektid	\N	f	f
207	64	2	Vaata koondaruanneе	koondaruanneе	f	t
225	65	2	Programmist	Programmist	f	t
126	46	2	Projektid	\N	t	f
127	46	2	Toetused	\N	f	f
128	46	2	Uusleht	\N	f	f
226	65	2	Laudade koondaruanne	Koondaruanne	f	t
209	64	2	Vaata kõik kaubad	Vaata_kaup	f	t
194	47	2	Etendused	\N	t	t
227	68	2	Pealehekülg	\N	t	f
30	20	2	Kõik tooted	kuva_koik_tooted	t	t
184	60	2	Kauba lõpetamine	\N	f	t
185	60	2	Kaupade koondaruanne	\N	f	t
33	20	2	Toodete detailandmed	kuva_detailandmed	f	t
158	54	2	Lõpeta teenus	Lõpeta	f	t
192	54	2	Kuva detailandmed	kuva_detailandmed	f	t
140	50	2	Kõik kaubad	\N	t	t
200	42	2	Lõpeta kaupu	\N	f	t
141	50	2	Lõpeta kaup	\N	f	t
142	50	2	Kauba koondaruanne	\N	f	t
193	54	2	Teenuste koondaruanne	teenuste_koondaruanne	f	t
183	60	2	Kaubad	\N	t	t
188	61	2	Switchboard	\N	t	f
173	55	2	Kaubade koondaruanne	\N	f	t
130	42	2	Kaubad	\N	t	t
162	53	2	Kaupade detailvaade	kaupade_detailvaade	f	t
152	53	2	Kõik tooted	kuva_koik_tooted	t	t
154	53	2	Kaupade koondaruanne	kaupade_koondaruanne	f	t
153	53	2	Lõpeta kaupu	lopeta_kaupu	f	t
203	63	2	Parklakohad lõpetamiseks	Lõpetamiseks	f	t
204	63	2	Parklakohtade koondaruanne	Koond	f	t
133	45	2	Kõik parkimiskohad	Kõik	t	t
132	45	2	Lõpeta parkimiskoht	Lõpeta	f	t
171	57	2	Login	Login	t	t
131	45	2	Parkimiskohtade koondaruanne	Koond	f	t
196	62	2	Kõik lauad	\N	t	t
197	62	2	Laudade koondaruanne	\N	f	t
157	54	2	Kõik teenused	Kõik	t	t
134	48	2	Lõpeta kaup	\N	f	t
176	48	2	Kõik kaubad	\N	f	t
175	48	2	Kauba detailid	\N	f	t
198	62	2	Lõpeta laud	\N	f	t
137	48	2	Kaupade koondaruanne	\N	t	t
32	20	2	Toodete koondaruanne	kuva_toodete_koondaruanne	f	t
34	20	2	Otseturundusega nõustunud kliendid	kuva_otseturundusega_noustunud_klientide_andmed	f	t
36	20	2	Lõpeta toode	lopeta_toode	f	t
199	62	2	Programmist	\N	f	t
179	59	2	Lõpetatavad kaubad	\N	f	t
165	55	2	Kõik kaubad	\N	f	t
195	47	2	Etendus	\N	f	f
186	59	2	Vaata kaupade koondaruannet	\N	f	t
177	59	2	Vaata kõiki kaupu	\N	t	t
172	55	2	Lõpeta kaup	\N	f	t
168	55	2	Kaubade detailid	\N	t	t
205	63	2	Parklakohtade täpsem vaade	Täpsem	f	t
202	63	2	Kõik parklakohad (seisunditega)	Kõik	t	t
201	42	2	Aruanne	\N	f	t
214	66	2	Kõik autod	\N	t	t
215	66	2	Auto koondaruanne	\N	f	t
216	66	2	Lõpeta auto	\N	f	t
217	66	2	Programmist	\N	f	t
208	64	2	Kauba lopetamine	Kauba_lopetamine	t	t
213	65	2	Kõik lauad	Kõik	t	t
218	67	2	Kõik lauad	\N	f	t
220	67	2	Laudade koondaruanne	\N	f	t
221	67	2	Lõpeta laud	\N	f	t
76	30	2	Koondaruanne	\N	f	t
150	49	2	Lõpeta kaup	\N	f	t
78	30	2	Lõpeta raamat	\N	f	t
80	30	2	Raamatute info	\N	f	t
151	49	2	Kaupade detailid	\N	f	t
230	69	2	Vaata Kaupu Detailselt	\N	f	t
160	49	2	Info	\N	f	t
149	49	2	Aruanded	\N	t	t
223	67	2	Aktiivsed lauad	\N	t	f
234	72	2	...	\N	t	t
233	71	2	Página02	pg02	f	f
232	71	2	Pagina01	pg01	t	f
358	92	2	Eemalda kaup kategooriast	\N	f	t
236	73	2	Homepage	\N	t	t
16	12	2	Lõpeta tuba	Lõpeta	f	t
21	12	2	Tubade koondaruanne	Koond	f	t
18	12	2	Programmist	Info	f	t
14	12	2	Kõik toad	Kõik	t	t
239	76	2	Avaleht	\N	t	f
267	83	2	Kõik parklakohad	Kõik	t	t
290	83	2	Lõpeta parklakoht	Lõpeta	f	t
244	79	2	Kõik kaubad	\N	t	t
270	88	2	Aruanded (avaleht)	\N	t	t
308	88	2	Unusta parkimiskoht	\N	f	t
258	84	2	Info	\N	f	t
269	83	2	Parklakohtade koondaruanne	Koond	f	t
229	69	2	Vaata Kaupu	\N	t	t
253	82	2	Kõik autod	\N	t	t
254	82	2	Autode koondaruanne	\N	f	t
256	82	2	Autode detailid	\N	f	t
259	84	2	Kõik teenused	\N	t	t
262	84	2	Lõpeta teenus	\N	f	t
260	84	2	Teenuste detailid	\N	f	t
263	84	2	Teenuste koondaruanne	\N	f	t
271	83	2	Programmist	Info	f	t
281	74	2	Laudade koondaruanne	\N	f	t
251	81	2	Detailvaade	Detailid	f	t
252	81	2	Info	Info	f	t
257	81	2	Lõpeta treening	Treeningu_lopetamine	f	t
249	81	2	Kõik treeningud	Kõik	t	t
245	79	2	Kauba detailandmed	\N	f	t
242	79	2	Lõpeta kaubad	\N	f	t
241	79	2	Vaata koondaruannet	\N	f	t
265	86	2	Kõik treeningud	\N	t	f
302	85	2	Vaata kõiki laudu	\N	t	t
303	85	2	Lõpeta laudu	\N	f	t
301	85	2	Vaata laudade koondaruannet	\N	f	t
287	90	2	Kõik parklakohad	\N	t	t
289	90	2	Lõpeta parklakoht	\N	f	t
291	90	2	Parklakohrade koondaruanne	\N	f	t
288	90	2	Parklakohtade detailid	\N	f	t
296	90	2	Info	\N	f	t
77	30	2	Kõik raamatud	\N	t	t
304	85	2	Laudade detailid	\N	f	t
334	92	2	Muuda kaup mitteaktiivseks	\N	f	t
286	81	2	Treeningute koondaruanne	Treeningute_koondaruanne	f	t
266	87	2	Kõik teenused	koik_teenused	t	t
285	87	2	Lõpeta teenus	lopeta_teenus	f	t
284	87	2	Teenuste koondaruanne	Teenuste_koondaruanne	f	t
283	87	2	Aktiivsed ja mitteaktiivsed teenused	aktiivsed_mitteaktiivsed_teenused	f	t
315	95	2	Koondaruanne	parklakohtade_koondaruanne	f	t
317	95	2	Parklakoha detailandmed	parklakoha_detailandmed	f	t
316	95	2	Kõik parklakohad	koik_parklakohad	t	t
280	74	2	Lõpeta laud	\N	f	t
282	74	2	Programmist	\N	f	t
294	74	2	Kõik lauad	\N	t	t
295	91	2	Kõik lauad	\N	t	t
255	82	2	Lõpeta auto	\N	f	t
319	80	2	Lõpeta prooviruum	Lõpeta	f	t
320	95	2	Lõpetatavad parklakohad	lopetatavad_parklakohad	f	t
321	96	2	Kõik parklakohad	koik_parklakohad	t	t
322	96	2	Lõpetatavad parklakohad	lopetatavad_parklakohad	f	t
323	96	2	Koondaruanne	parklakohtade_koondaruanne	f	t
324	96	2	Parklakohtade detailandmed	parklakoha_detailandmed	f	t
325	95	2	Andmed	rakenduse_andmed	f	t
275	88	2	Lõpeta parkimiskoht	\N	f	t
326	85	2	Vaata aktiivseid/mitteaktiivseid laudu	\N	f	t
329	92	2	Registreeri nutitelefon	\N	f	t
297	92	2	Kõik kaubad	\N	t	t
350	98	2	Parklakohtade detailid	\N	f	t
335	92	2	Unusta kaup	\N	f	t
306	88	2	Parkimiskohtade detailid	\N	f	t
307	88	2	Parkimiskohtade koondaruanne	\N	f	t
250	80	2	Prooviruumide detailandmed	Detailandmed	f	t
313	80	2	Info	Info	f	t
314	80	2	Aruanded	Aruanded	t	t
336	92	2	Uuenda kaupa	\N	f	t
231	69	2	Aktiivsed ja mitteaktiivsed kaubad	\N	f	t
228	69	2	Koondaruanne	\N	f	t
235	69	2	Lõpeta Kaup	\N	f	t
347	99	2	Lõpeta parklakoht	lopeta_parklakoht	f	t
348	98	2	Aktiivsed ja mitteaktiivsed parklakohad	\N	f	t
328	92	2	Aktiveeri kaup	\N	f	t
327	92	2	Kaupade lisamine	\N	f	t
352	101	2	Proov	\N	f	f
341	99	2	Parklakohtade koondaruanne	koond	f	t
346	99	2	Parklakohtade detailvaade	parklakohtade_detailvaade	f	t
354	92	2	Vaata kõiki ootel või mitteaktiivseid kaupu	\N	f	t
339	98	2	Parklakohtade koondaruanne	\N	t	t
355	92	2	Lisa kauba variant	\N	f	t
351	101	2	Registreeri Kaup	\N	t	t
353	99	2	Kõik parklakohad	koik_parklakohad	t	t
356	92	2	Eemalda kauba variant	\N	f	t
362	92	2	Lisa kaup	\N	f	t
357	92	2	Lisa kaup kategooriasse	\N	f	t
359	102	2	Koondaruanne	KA	t	t
\.


--
-- Data for Name: page_item; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.page_item (page_item_id, page_id, form_field_id, region_id, name) FROM stdin;
43	2	41	\N	p_room_code
44	3	42	\N	p_room_code_old
45	3	43	\N	p_room_code_new
46	3	44	\N	p_room_name
47	3	45	\N	p_bed_type_code
48	3	46	\N	p_area
49	3	47	\N	p_night_price
50	3	48	\N	p_minimal_night_price
51	3	49	\N	p_max_number_of_people
52	3	50	\N	p_description
53	3	51	\N	p_picture_address
54	1	\N	16	page_atir
131	64	\N	157	p
239	78	\N	195	raamatud_lopetamiseks
63	16	\N	28	page_atir
64	16	58	\N	p_room_code
77	32	\N	56	toodete_koondaruanne
240	78	185	\N	raamat_id
346	74	276	\N	kauba_kood
2	1	\N	4	page_norbs
369	111	\N	260	koik_rajad
106	44	\N	81	page_nrbs
107	45	79	\N	p_kauba_kood
108	45	\N	85	page_atir
279	82	\N	201	page
297	82	236	\N	Kood
298	22	\N	213	p
300	22	\N	217	q
301	91	\N	220	q
373	113	\N	266	lopeta_rada
304	90	\N	223	q
84	27	\N	71	page
79	34	\N	61	otseturundusega_noustunud_kliendid
374	113	298	\N	raja_kood_in
375	112	299	\N	raja_kood_in
307	90	241	\N	kaup_kood
85	41	\N	73	page
370	112	\N	263	unusta_rada
368	110	\N	259	radade_aruanne
123	41	84	\N	kauba_kood
125	36	86	\N	p_id
112	49	\N	92	koikTeenused
291	85	\N	208	page
364	108	\N	257	page_oor
128	63	89	\N	password
129	63	90	\N	username
376	108	300	\N	pileti_identifikaator
378	96	302	\N	Teenusekood
110	47	\N	88	koondaruanne
379	115	\N	270	page_oor
382	116	\N	273	page_oor
383	118	\N	274	page_oor
385	116	304	\N	kauba_identifikaator
1	1	\N	3	page_oor
231	73	179	\N	p_kauba_kood
230	73	\N	184	page_atir
72	29	\N	48	page_oor
278	81	\N	200	page
116	52	\N	100	page_oor
280	80	\N	206	raamatute_info
333	65	\N	234	p
334	67	267	\N	p_treening_id
236	76	\N	188	koondaruanne
347	105	\N	247	A
356	106	285	\N	Pealkiri
357	106	286	\N	Kood
228	71	\N	181	page_nrbs
237	77	\N	190	koik_raamatud
358	106	287	\N	Kategooria
359	106	288	\N	Kirjastus
360	106	289	\N	Seisund
361	106	290	\N	Hind
227	70	\N	179	AZ
362	106	291	\N	Tootaja
363	106	292	\N	Lehekyljed
339	100	\N	242	nr
81	37	\N	64	page
401	141	\N	312	kaubalopetamine
387	121	\N	281	q
417	152	\N	331	page
419	154	\N	337	nr
597	215	\N	485	page_nrbs
598	216	442	\N	p_auto_kood
536	179	\N	414	page
481	162	\N	365	page
398	140	\N	308	kaubadetailid
579	208	\N	466	q
582	209	\N	469	koik_kaubad
583	210	\N	475	Detailid
578	207	\N	465	q
399	142	\N	309	kaubakoondaruanne
518	172	403	\N	p_kauba_kood
418	153	\N	333	page
420	153	316	\N	kaup_id
519	173	\N	383	A
392	132	\N	293	page_atis
526	176	\N	392	page_koikkaubad
524	21	\N	390	ss
78	33	\N	60	detailandmed
88	36	\N	76	lopeta_toode
527	140	\N	395	kaubadetailandmed
525	175	\N	391	page_pohjalikuddetailid
555	132	416	\N	p_parkimiskoha_kood
492	168	\N	369	A
530	184	404	\N	kauba_kood
531	185	\N	405	kaup
442	137	\N	352	page_norbs
534	186	\N	412	page
543	157	\N	422	page_koikteenused
560	198	418	\N	p_laua_kood
493	150	381	\N	kaup_kood
74	30	\N	52	kuva_koik_tooted
414	150	\N	326	lopeta
544	158	411	\N	p_teenuse_kood
547	192	\N	427	detailandmed
548	193	\N	429	teenuste_koondaruanne
546	158	\N	425	lopeta_teenus
528	183	\N	401	kaup
529	184	\N	403	kaup
470	165	\N	362	A
389	131	\N	286	page_koondaruanne
553	183	\N	434	page
535	177	\N	413	page
554	194	\N	437	page
521	149	\N	386	koond
409	151	\N	323	detailid
408	149	\N	321	koik_kaubad
556	179	417	\N	kaup_kood
557	196	\N	443	page_oor
559	198	\N	445	page_atir
558	197	\N	444	page_nrbs
570	203	\N	460	page
571	204	\N	462	page
565	200	\N	454	q
575	200	425	\N	Kood
576	203	426	\N	parklakoht
577	203	427	\N	parkla
567	202	\N	456	page
562	201	\N	451	q
572	205	\N	464	page
561	130	\N	447	q
517	172	\N	382	A
545	134	412	\N	p_kauba_kood
596	214	\N	484	page_oor
599	216	\N	487	page_atir
391	133	\N	292	page_all
503	141	391	\N	p_kauba_kood
613	220	\N	495	koondaruanne
621	221	460	\N	laud
617	221	\N	497	lopeta
600	218	\N	490	koik_lauad
625	223	\N	507	aktiivsed_lauad
630	208	468	\N	p_kaup_id
635	226	\N	517	laudade_kategooriate_omamiste_alamparingud
631	213	\N	509	koik_lauad
634	226	\N	516	laudade_koonaruanded
633	224	\N	512	aktiivsed_mitteaktiivsed_lauad
637	224	471	\N	p_laud_id
638	228	\N	520	koondaruanne
642	232	\N	531	a
641	231	\N	525	akt_mitakt_kaubad
645	235	474	\N	p_kauba_kood
710	283	\N	612	page_aktiivsed_mitteaktiivsed_teenused
711	284	\N	615	page_teenuste_koondaruanne
1191	335	932	\N	p_kauba_kood
714	286	\N	620	treeningute_koondaruanne
757	307	\N	666	parkimiskohtade_koondaruanne
656	242	481	\N	p_kauba_kood
649	242	\N	538	lk
756	306	\N	663	parkimiskohtade_detailid
764	275	540	\N	A
783	320	\N	697	page
660	254	\N	554	autode_koondaruanne
661	253	\N	557	koik_autod
766	308	541	\N	A
667	255	485	\N	A
658	249	\N	545	treeningute_ylevaade
982	346	\N	772	page
665	255	\N	561	Aktiivsed_mitteaktiivsed_autod
659	251	\N	549	_
716	287	\N	623	page_koik_parklakohad
984	347	734	\N	p_parklakoht_kood
743	289	531	\N	p_parklakoha_kood
744	262	532	\N	teenus_kood
670	262	\N	569	lopeta_teenus
765	275	\N	670	lopetatavad_parkimiskohad
672	263	\N	572	teenused
767	308	\N	673	unustatavad_parkimiskohad
799	317	\N	715	page
981	341	\N	769	page
859	290	616	\N	p_parklakoht_kood
860	328	617	\N	p_kauba_kood
678	257	\N	574	Aktiivsed_mitteaktiivsed_treeningud
1245	358	986	\N	p_kauba_kood
727	290	\N	631	page_aitir
684	257	497	\N	L
1246	358	987	\N	p_kauba_kategooria_kood
687	245	\N	579	detailid
648	241	\N	537	a
657	244	\N	544	k
668	259	\N	565	koik_teenused
760	270	\N	669	parkimiskohtade_koondaruanne
869	334	626	\N	p_kauba_kood
60	14	\N	22	page_oor
67	21	\N	37	page_nrbs
768	285	542	\N	p_teenus_kood
639	229	\N	522	kaubad
749	302	\N	654	lauad
694	267	\N	593	page_oor
695	270	\N	595	koik_parkimiskohad
640	230	\N	524	kaubad_detailid
717	288	\N	625	page_parklakohtade_detailid
696	269	\N	596	page_nrbs
983	347	\N	774	page
733	280	522	\N	laua_kood
732	294	\N	639	aet
734	295	\N	641	aet
688	266	\N	581	page_koikteenused
770	314	\N	683	koondaruanne
704	280	\N	604	aktiivsed_ja_mitteaktiivsed_lauad
729	291	\N	635	page_parklakohtade_koondaruanne
663	256	\N	560	autode_detailid
891	339	\N	752	start
669	260	\N	567	teenuste_detailid
800	326	\N	719	aktiivne_mitteaktiivne
747	301	\N	649	koondaruanne
1124	354	\N	795	mitteaktiivsed
752	303	\N	658	lopetatavad_lauad
753	303	534	\N	laud_kood
754	304	\N	660	detailid
728	289	\N	633	page_parklakohad_mida_saab_lopetada
705	281	\N	605	laudade_koondaruanne
758	285	\N	668	page_aktiivsed_mitteaktiivsed_teenused
771	315	\N	686	page
784	323	\N	702	page
785	319	\N	703	lopeta
790	321	\N	707	page
791	322	555	\N	parklakoht
795	320	558	\N	parklakoht
769	314	\N	682	koik_prooviruumid
797	319	559	\N	prooviruumi_kood
798	250	\N	713	detailid
796	316	\N	711	page
1176	336	917	\N	p_kauba_kood
1177	336	918	\N	p_nimetus
1178	336	919	\N	p_hind
1179	336	920	\N	p_kirjeldus
1180	336	921	\N	p_pildi_aadress
845	297	\N	727	koik_kaubad
1095	353	\N	792	page
1010	329	\N	776	Nutitelefonid
1012	339	\N	778	startParklakohad
1123	354	\N	794	Ootel_kaubad
1017	348	\N	779	start
1220	329	961	\N	p_kauba_kood
1221	329	962	\N	p_protsessor_kood
1222	329	963	\N	p_sisemalu_kood
1223	329	964	\N	p_ekraani_resolutsioon_kood
1224	329	965	\N	p_tagumine_kaamera_kood
1225	329	966	\N	p_eesmine_kaamera_kood
1226	329	967	\N	p_diagonaal_kood
1227	329	968	\N	p_on_veekindel
1228	329	969	\N	p_on_sormejaljelugeja
1018	350	\N	781	start
1235	356	976	\N	p_kauba_kood
1236	356	977	\N	p_kauba_varv_kood
1049	348	794	\N	p_parklakoha_kood
1050	348	795	\N	p_parkla_nimetus
1243	357	984	\N	p_kauba_kood
1244	357	985	\N	p_kauba_kategooria_kood
1247	355	988	\N	p_kauba_kood
1248	355	989	\N	p_kauba_varv_kood
1249	362	990	\N	p_brand_kood
1250	362	991	\N	p_kirjeldus
1251	362	992	\N	p_kauba_kood
1252	362	993	\N	p_registreerija_isik_id
1253	362	994	\N	p_nimetus
1254	362	995	\N	p_hind
1255	362	996	\N	p_pildi_aadress
1069	351	814	\N	p_brand_kood
1070	351	815	\N	p_kirjeldus
1071	351	816	\N	p_kauba_kood
1072	351	817	\N	p_registreerija_isik_id
1073	351	818	\N	p_nimetus
1074	351	819	\N	p_hind
1075	351	820	\N	p_pildi_aadress
1076	351	\N	790	Ootel_kaubad
\.


--
-- Data for Name: page_template; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.page_template (template_id, page_type_id, header, body, footer, error_message, success_message) FROM stdin;
1	LOGIN	<!DOCTYPE html>\n<html lang="en">\n  <head>\n    <meta charset="utf-8">\n    <meta http-equiv="X-UA-Compatible" content="IE=edge">\n    <meta name="viewport" content="width=device-width, initial-scale=1">\n    <title>#APPLICATION_NAME# :: #TITLE#</title>\n\n    <!-- Bootstrap core CSS -->\n    <link href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css" rel="stylesheet">\n    <!-- HTML5 shim and Respond.js for IE8 support of HTML5 elements and media queries -->\n    <!--[if lt IE 9]>\n      <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>\n      <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>\n    <![endif]-->\n  </head>	  <body>\n    <nav class="navbar navbar-inverse">\n      <div class="container">\n        <div class="navbar-header">\n          <a class="navbar-brand" href="#">#APPLICATION_NAME#</a>\n        </div>\n      </div>\n    </nav>\n\n\n    <div class="container">\n      #SUCCESS_MESSAGE#\n      #ERROR_MESSAGE#\n      <form class="form-horizontal" method="post" action="">\n        <input name="PGAPEX_OP" type="hidden" value="LOGIN">\n        <div class="form-group">\n          <div class="col-sm-12">\n            <div class="input-group">\n              <span class="input-group-addon">\n                <span class="glyphicon glyphicon-user" aria-hidden="true"></span>\n              </span>\n              <input name="USERNAME" type="text" class="form-control" required autofocus>\n            </div>\n          </div>\n        </div>\n        <div class="form-group">\n          <div class="col-sm-12">\n            <div class="input-group">\n              <span class="input-group-addon">\n                <span class="glyphicon glyphicon-lock" aria-hidden="true"></span>\n              </span>\n              <input name="PASSWORD" type="password" class="form-control" required>\n            </div>\n          </div>\n        </div>\n        <div class="form-group">\n          <div class="col-sm-12">\n            <button type="submit" class="btn btn-primary btn-block">Login</button>\n          </div>\n        </div>\n      </form>\n    </div><!-- /.container -->\n\n    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js"></script>\n    <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js"></script>\n  </body>	</html>	<div class="alert alert-danger" role="alert">#MESSAGE#</div>	<div class="alert alert-success" role="alert">#MESSAGE#</div>
2	NORMAL	<!DOCTYPE html>\n<html lang="en">\n  <head>\n    <meta charset="utf-8">\n    <meta http-equiv="X-UA-Compatible" content="IE=edge">\n    <meta name="viewport" content="width=device-width, initial-scale=1">\n    <title>#APPLICATION_NAME# :: #TITLE#</title>\n\n    <!-- Bootstrap core CSS -->\n    <link href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css" rel="stylesheet">\n    <!-- HTML5 shim and Respond.js for IE8 support of HTML5 elements and media queries -->\n    <!--[if lt IE 9]>\n      <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>\n      <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>\n    <![endif]-->\n  </head>	  <body>\n    <nav class="navbar navbar-inverse">\n      <div class="container">\n        <div class="navbar-header">\n          <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target="#navbar" aria-expanded="false" aria-controls="navbar">\n            <span class="sr-only">Toggle navigation</span>\n            <span class="icon-bar"></span>\n            <span class="icon-bar"></span>\n            <span class="icon-bar"></span>\n          </button>\n          <a class="navbar-brand" href="#">#APPLICATION_NAME#</a>\n        </div>\n        <div id="navbar" class="collapse navbar-collapse">\n        #POSITION_1#\n        </div><!--/.nav-collapse -->\n      </div>\n    </nav>\n\n\n    <div class="container">\n      #SUCCESS_MESSAGE#\n      #ERROR_MESSAGE#\n      #BODY#\n    </div><!-- /.container -->\n\n    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js"></script>\n    <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js"></script>\n  </body>	</html>	<div class="alert alert-danger" role="alert">#MESSAGE#</div>	<div class="alert alert-success" role="alert">#MESSAGE#</div>
\.


--
-- Data for Name: page_template_display_point; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.page_template_display_point (page_template_display_point_id, page_template_id, display_point_id, description) FROM stdin;
1	2	BODY	Body
2	2	POSITION_1	Navigation
\.


--
-- Data for Name: page_type; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.page_type (page_type_id) FROM stdin;
LOGIN
NORMAL
\.


--
-- Data for Name: region; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.region (region_id, page_id, template_id, page_template_display_point_id, name, sequence, is_visible) FROM stdin;
5	2	5	2	Navigatsioon	10	t
7	3	5	2	Navigatsioon	10	t
1	1	5	2	Navigatsioon	10	t
2	1	4	1	Info	10	t
6	2	4	1	Lõpeta tuba	10	t
8	3	4	1	Muuda toa andmeid	10	t
16	1	4	1	Ootel või mitteaktiivsed toad	15	t
53	30	5	2	Kuva kõik tooted	0	t
59	33	5	2	Toodete detailandmed	2	f
392	176	4	1	Kõik kaubad	10	t
56	32	4	1	Toodete koondaruanne	1	t
165	64	5	2	Navigatsioon	10	t
58	32	5	2	Toodete koondaruanne	1	t
393	176	5	2	Navigatsioon	10	t
26	16	5	2	Lõpeta tuba	30	t
3	1	4	1	Kõik toad	20	t
168	65	5	2	Treeningute koondaruanne	20	t
31	18	5	2	Programmist	40	t
28	16	4	1	Toad, mida saab lõpetada	20	t
27	16	4	1	Lõpeta tuba	10	t
66	37	5	2	Topic1	3	t
167	67	5	2	Treeningute eemaldamine	40	t
192	77	5	2	Nav	1	t
81	44	4	1	Toodete koondaruanne	10	t
4	1	4	1	Tubade koondaruanne	30	t
82	44	5	2	Toodete koondaruanne	10	t
83	45	4	1	Lõpeta toode	10	t
36	21	5	2	Tubade koondaruanne	10	t
84	45	5	2	Lõpeta toode	30	t
85	45	4	1	Tooted, mida saab lõpetada	20	t
252	105	5	2	Registreeri trükis	1	t
193	76	5	2	Nav	1	t
182	71	5	2	Kaupade koondaruanne	10	t
44	25	5	2	Navigatsioon	0	t
90	47	5	2	Navigation	1	t
254	106	5	2	Vaata trükiseid	0	t
95	49	5	2	Nav	52	t
49	29	5	2	Navigatsioon	10	t
180	70	5	2	Põhimenüü	1	t
98	52	5	2	Kõik tooted	10	t
72	27	5	2	Sisukord	0	t
71	27	4	1	Koondaruanne	1	t
61	34	5	1	Otseturundusega nõustunud kliendid	4	f
62	34	5	2	Otseturundusega nõusunud kliendid	3	f
74	36	5	2	Lõpeta toode	3	t
190	77	4	1	Kõik raamatud	1	t
270	115	4	1	Kõik kaubad	10	t
195	78	4	1	Raamatud, mida saab lõpetada	2	t
183	73	4	1	Lõpeta kaup	10	t
258	108	4	1	Kasuta Pilet	20	t
260	111	4	1	Kõikide radade ülevaade	1	t
104	41	5	2	Sisukord	0	t
73	41	4	1	Kõik kaubad	1	t
186	73	5	2	Lõpeta kaup	30	t
261	111	5	2	Navigatsioon	0	t
262	110	5	2	Navigatsioon	0	t
201	82	4	1	Lõpetatavad kaubad	4	t
103	41	4	1	Lõpeta kaup	3	t
208	85	4	1	Kõik kaubad	1	t
78	36	4	1	Lõpeta toode	0	t
92	49	4	1	Kõik teenused	2	t
184	73	4	1	Kaubad, mida saab lõpetada	20	t
196	78	5	2	Nav	0	t
157	64	4	1	Treeningud	1	t
48	29	4	1	Kõik kaubad	20	t
266	113	4	1	Lopeta rada	0	t
267	113	4	1	Lopeta rada	99	t
200	81	4	1	Kaupade koondaruanne	1	t
32	18	4	1	Taust	10	t
264	112	4	1	Unusta rada	99	t
263	112	4	1	Rajad, mida saab unustada	0	t
64	37	5	1	Kõik kaubad	1	t
259	110	4	1	Radade aruanne	1	t
194	78	4	1	Lõpeta raamat	1	t
256	108	5	2	Navigatsioon	30	t
188	76	4	1	Koondaruanne	1	t
257	108	4	1	Reisijate Piletid	10	t
88	47	4	1	Koondaruanne	0	t
209	82	4	1	Lõpeta kaup	3	t
203	81	5	2	KoondaruanneNav	1	t
227	96	4	1	Lõpeta teenus	2	t
204	82	5	2	LõpetaNav	1	t
100	52	4	1	Kõik tooted	20	t
205	80	5	2	Nav	1	t
206	80	4	1	Raamatute täpne info	1	t
273	116	4	1	Lõpeta kaup	10	t
274	118	4	1	Kauba koondaruanne	10	t
181	71	4	1	Kaupade koondaruanne	10	t
155	63	4	1	Login	1	t
210	85	5	2	KõikkaubadNav	1	t
276	115	5	2	Navigation 2	100000	t
277	118	5	2	Navigation 2	1000000	t
215	22	5	2	Navigation	0	t
223	90	4	1	Kaubad mida saab lõpetada	1	t
213	22	4	1	Kauba aruanne	0	t
217	22	4	1	Töötajate aruanne	1	t
218	90	5	2	Navigation	0	t
220	91	4	1	Kõik kaubad	0	t
222	90	4	1	Lõpeta kaup	0	t
226	96	5	2	nav	1	t
234	65	4	1	Treeningute koondaruanne	1	t
177	67	4	1	Aktiivsete ja mitteaktiivsete treeningute lõpetamine	1	t
65	37	5	1	Tabel 1 pealkiri Kõik poe kaubad	0	t
247	105	4	1	Trükised	0	t
255	106	4	1	Registreeri trükis	1	t
265	112	5	2	Navigeeri	0	t
268	113	5	2	Navbar	0	t
275	116	4	1	Lõpeta kaup	20	t
239	70	5	1	Vali kaup mida soovid lõpetada	0	t
278	116	5	2	Navigation 2	100000	t
37	21	4	1	Tubade koondaruanne	10	t
22	14	4	1	Kõik toad	20	t
219	91	5	2	Nav	0	t
179	70	5	1	Kaubad lõpetamisele	1	t
240	100	5	1	Koondaruanne	0	t
241	100	5	2	menu	0	t
242	100	5	1	Koondaruanne	2	t
187	74	5	1	Kinnita lõpetus	1	t
245	74	5	1	Kas oled kindel	0	t
279	119	5	1	HTML	2	t
394	175	5	2	Navigatsioon	10	t
281	121	4	1	pildid	1	t
391	175	4	1	Põhjalikud detailid	10	t
287	131	5	2	Navigatsioon	10	t
290	132	5	2	Navigatsioon	10	t
312	141	4	1	Kaubad mida saab lõpetada	20	t
413	177	4	1	Kaubad	0	t
288	131	4	1	Info	10	t
291	133	5	2	Navigatsioon	10	t
437	194	4	1	Etendused	1	t
395	140	4	1	Detailandmed	35	t
404	184	4	1	Lõpeta kaup	5	t
405	185	4	1	Kaupade koondaruanne	5	t
406	183	5	2	Navigatsioon	1	t
407	184	5	2	Navigatsioon	1	t
408	185	5	2	Navigatsioon	1	t
358	160	5	2	Menüü	1	t
359	160	4	1	Info	0	t
369	168	4	1	Kaubade detailid	0	t
396	177	5	2	Navigatsioon	10	t
307	140	5	2	Navigation	10	t
397	179	5	2	Navigatsioon	20	t
309	142	4	1	Kauba koondaruanne	10	t
310	142	5	2	Kauba koondaruanne	10	t
313	141	5	2	Lõpeta kaup	30	t
411	186	5	2	Navigation	20	t
322	149	5	2	Menüü	1	t
324	151	5	2	Menüü	1	t
348	134	5	2	Navigatsioon	10	t
308	140	4	1	Kõik kaubad	30	t
350	137	5	2	Navigatsioon	10	t
365	162	5	1	Kaupade detailvaate tabel	3	t
328	150	5	2	Menüü	1	t
412	186	4	1	Kaupade koondaruanne	0	t
440	198	5	2	Navigation	30	t
330	152	5	1	Pealeht	0	t
422	157	4	1	Kõik teenused	0	t
334	152	5	2	Peamenüü	5	t
335	153	5	2	Peamenüü	5	t
336	154	5	1	Kaupade koondaruanne pealkiri	0	t
337	154	5	1	Kaupade koondaruanne tabel	1	t
338	154	5	2	Peamenüü	5	t
332	153	5	1	Lõpeta kaupu pealkiri	0	t
52	30	4	1	Kuva kõik tooted	0	t
423	157	5	2	Navigatsioon	0	t
333	153	5	1	Lõpeta kaupu tabel	2	t
339	153	5	1	Lõpeta kaup	1	t
424	158	4	1	Lõpeta teenus	0	t
349	134	4	1	Lõpeta kaup	10	t
331	152	5	1	Kõik kaubad	1	t
426	158	5	2	Lõpeta teenus	3	t
427	192	4	1	Teenuste detailandmed	0	f
428	192	5	2	Teenuste detailandmed	2	f
429	193	4	1	Teenuste koondaruanne	1	t
430	193	5	2	Teenuste koondaruanne	1	t
425	158	4	1	Teenused mida saab lõpetada	1	t
401	183	4	1	Kõik kaubad	10	t
403	184	4	1	Aktiivsed ja mitteaktiivsed kaubad	10	t
382	172	4	1	Lõpetatavad kaubad	0	t
352	137	4	1	Kaupade koondaruanne	50	t
381	172	4	1	Lõpeta kaup	10	t
383	173	4	1	Kaubade koondaruanne	10	t
326	150	4	1	Lõpetatavad kaubad	2	t
435	194	5	2	Menu	1	t
384	173	5	2	Kaubade koondaruanne	70	t
386	149	4	1	Kaupade koondaruanne	2	t
434	183	4	1	Detailvaade	20	t
436	195	5	2	Menu	1	t
286	131	4	1	Parkimiskohtade koondaruanne	30	t
323	151	4	1	Detailid	1	t
362	165	4	1	Kõik kaubad	2	t
321	149	4	1	Kõik kaubad	1	t
293	132	4	1	Parkimiskohad, mida saab lõpetada	20	t
366	162	5	2	Peamenüü	5	t
340	132	4	1	Lõpeta parkimiskoht	10	t
421	179	4	1	Lõpeta kaup	0	t
357	150	4	1	Lõpeta kaup	0	t
375	165	5	2	Kõik kaubad	40	t
387	149	4	1	Info	0	t
414	179	4	1	Lõpetatavad kaubad	10	t
439	197	5	2	Navigation	20	t
441	199	5	2	Navigation	40	t
380	172	5	2	Lõpeta kaup	20	t
438	196	5	2	Navigation	10	t
442	199	4	1	Info	10	t
443	196	4	1	Kõik lauad	20	t
445	198	4	1	Lauad, mida saab lõpetada	20	t
444	197	4	1	Laudade koondaruanne	30	t
311	141	4	1	Lõpeta kaup	10	t
373	168	5	2	Kaubade detailid	10	t
446	198	4	1	Lõpeta laud	10	t
60	33	4	1	Toodete detailandmed	0	f
76	36	4	1	Tooted mida saab lõpetada	1	t
448	130	5	2	Nav	0	t
449	201	5	2	Nav	0	t
450	200	5	2	Nav	0	t
451	201	4	1	Kauba aruanne	0	t
390	21	4	1	Ruumid seisundi järgi	20	f
292	133	4	1	Kõik parkimiskohad	20	t
453	200	4	1	Lõpeta kaupu	0	t
447	130	4	1	Kaubad	0	t
467	208	4	1	Kauba lopetamine	1	t
457	202	5	2	Nav	10	t
459	203	5	2	Nav	10	t
460	203	4	1	Parklakohad lõpetamiseks	20	t
461	204	5	2	Nav	10	t
462	204	4	1	Koondaruanne	10	t
463	205	5	2	Nav	10	t
458	203	4	1	Lõpeta parklakoht	10	t
464	205	4	1	Parklakohtade täpsem vaade	10	t
456	202	4	1	Kõik parklakohad koos hetkeseisundiga	10	t
454	200	4	1	Kaubad	1	t
510	213	5	2	Navigatsioon	10	t
468	203	4	1	Disclaimer	11	t
471	208	5	2	nav1	4	t
472	209	5	2	nav1	9	t
473	207	5	2	nav1	9	t
474	210	5	2	nav1	99	t
499	221	5	1	Tabeli nimetus	2	t
526	230	5	2	Vaata kaupu detailselt	1	t
513	224	5	2	Lõpeta laud	2	t
515	225	5	2	Programmist	4	t
496	221	4	1	Lõpeta laud	1	t
514	225	4	1	Programmi taust	4	t
497	221	5	1	Laudade tabel	3	t
517	226	4	1	Laua kategooriate omamiste alampäringud	20	f
490	218	5	1	Kõiki laudade tabel	3	t
518	226	5	2	Laudade koondaruanne	3	t
527	231	5	2	Aktiivsed Mitteaktiivsed Kaubad	1	t
506	223	5	2	Navbar	1	t
480	215	5	2	Navigation	1	t
481	216	5	2	Navigation	1	t
482	217	5	2	Navigation	1	t
483	217	4	1	Programmist	1	t
507	223	5	1	Aktiivsete laudade tabel	2	t
485	215	4	1	Auto koondaruanne	1	t
479	214	5	2	Navigation	1	t
486	216	4	1	Lõpeta auto	1	t
484	214	4	1	Kõik autod	1	t
487	216	4	1	Autod, mida saab lõpetada	2	t
508	223	5	1	Tabeli nimetus	1	t
505	218	5	1	Tabeli nimetus	2	t
523	229	5	2	Vaata kaupu	1	t
492	218	5	2	Navbar	1	t
493	220	5	2	Navbar	1	t
494	221	5	2	Navbar	1	t
520	228	4	1	Koondaruanne	0	t
495	220	5	1	Koondaruanne	1	t
530	233	4	2	nav02	5	t
529	232	4	1	ourta regiao	3	t
528	232	4	1	Regiao01	2	t
531	232	4	1	Tipos de serviço	11	t
469	209	4	1	Koik kaubad	1	t
533	235	5	2	Navigatsioon	10	t
525	231	5	1	Aktiivsed ja mitteaktiivsed kaubad	0	t
465	207	4	1	Koondaruanne	1	t
475	210	4	1	Kaupade detaalne info	1	t
466	208	4	1	Kaubad lõpetamiseks	2	t
519	227	4	1	Test	0	t
509	213	4	1	Kõik lauad	20	t
516	226	4	1	Laudade koondaruanne	3	t
512	224	4	1	Lauad, mida saab lõpetada	20	t
511	224	4	1	Lõpeta laud	10	t
521	228	5	2	Navigatsioon	0	t
534	235	4	1	Lõpeta Kaup	10	t
555	253	5	2	Nav	1	t
539	242	5	2	Nav	1	t
540	241	5	2	Nav	1	t
556	255	5	2	Nav	1	t
559	256	5	2	Nav	1	t
542	242	4	1	Lõpeta kaup	1	t
538	242	4	1	Lõpeta kaubad	2	t
543	244	5	2	Nav	1	t
574	257	4	1	Aktiivsed/mitteaktiivsed treeningud	1	t
557	253	4	1	Kõik autod	1	t
771	346	5	2	Parklakohtade detailvaade	2	t
547	249	4	1	Kirjeldus	0	t
548	251	4	1	Kirjeldus	0	t
575	257	5	2	Navigeeri	0	t
550	251	5	2	Navigeeri	1	t
546	249	5	2	Navigeeri	1	t
552	252	5	2	Navigeeri	1	t
773	347	5	2	Lõpeta parklakoht	3	t
558	255	4	1	Lõpeta auto	2	t
551	252	4	1	Programmi info	0	t
545	249	4	1	Treeningud	1	t
569	262	4	1	Kõik mitteaktiivsed ja aktiivsed teenused	1	t
553	254	5	2	Nav	1	t
554	254	4	1	Autode koondaruanne	1	t
568	262	5	2	NavigationBar	1	t
775	347	4	1	Lõpeta parklakoht	1	t
561	255	4	1	Aktiivsed/mitteaktiivsed autod	4	t
549	251	4	1	Detailid	1	t
562	258	4	1	Info	0	t
563	258	5	2	NavigationBar	1	t
564	259	5	2	NavigationBar	1	t
566	260	5	2	NavigationBar	1	t
571	263	5	2	NavigationBar	0	t
572	263	4	1	Teenuste koondaruanne	0	t
567	260	4	1	Teenuste detailid	1	t
565	259	4	1	Kõik teenused	0	t
560	256	5	1	Autode detailid	1	t
524	230	5	1	Vaata kaupu detailselt	0	t
282	126	4	1	Hooandja pealeht	1	f
573	257	4	1	Lõpeta treening	0	t
522	229	4	1	Vaata kaupu	1	t
579	245	4	1	Kaupade detailandmed	1	t
580	245	5	2	nav	0	t
537	241	4	1	Kaupade koondaruanne	1	t
544	244	4	1	Kõik kaubad	2	t
570	262	4	1	Lõpeta teenus	0	t
583	267	5	2	Navigatsioon	10	t
24	14	5	2	Navigatsioon	10	t
587	271	5	2	Programmist	40	t
589	271	4	1	Taust	10	t
593	267	4	1	Kõik parklakohad	20	t
581	266	4	1	Kõik teenused	10	t
595	270	4	1	Kõik parkimiskohad	1	t
673	308	4	1	Unustatavad parkimiskohad	2	t
632	290	5	2	Lõpeta parklakoht	30	t
596	269	4	1	Parklakohtade koondaruanne	10	t
721	329	5	2	Registreeri kaup	0	t
759	335	4	1	Unusta kaup	0	t
606	280	5	2	Navigation	0	t
727	297	4	1	Kõik kaubad	0	t
608	281	5	2	Navigation	0	t
610	282	5	2	Navigation	0	t
740	336	4	1	Muuda nutitelefoni andmeid	0	t
604	280	4	1	Aktiivsed ja mitteaktiivsed lauad	1	t
611	282	4	1	Programmist	0	t
613	283	5	2	Navigatsioon	10	t
614	266	5	2	Navigatsioon	10	t
612	283	4	1	Aktiivsed ja mitteaktiivsed teenused	20	t
615	284	4	1	Teenuste koondaruanne	10	t
616	284	5	2	Navigatsioon	10	t
618	285	5	2	Navigatsioon	10	t
619	286	4	1	Koondaruanne	0	t
621	286	5	2	Navigeeri	3	t
620	286	4	1	Treeningute koondaruanne	1	t
586	269	5	2	Parklakohtade koondaruanne	10	t
710	320	4	1	Lõpeta parklakoht	1	t
638	294	5	2	Navigation	0	t
651	301	5	2	Navigatsioon	2	t
650	303	5	2	Navigatsioon	3	t
609	280	4	1	Lõpeta laud	0	t
639	294	4	1	Kõik lauad	0	t
640	295	5	2	Nav	0	t
641	295	4	1	Kõik lauad	0	t
652	302	5	2	Navigatsioon	1	t
617	285	4	1	Lõpeta teenus	10	t
695	319	5	2	Menüü	1	t
643	296	5	2	Navigatsioon	1	t
628	289	5	2	Navigatsioon	1	t
635	291	4	1	Parklakohtade koondaruanne	1	t
631	290	4	1	Parklakohad, mida saab lõpetada	20	t
634	291	5	2	Navigatsioon	1	t
627	288	5	2	Navigatsioon	1	t
658	303	4	1	Lõpetatavad lauad	2	t
624	287	5	2	Navigatsioon	1	t
657	303	4	1	Lõpeta laud	1	t
659	304	5	2	Navigatsioon	1	t
660	304	4	1	Laudade detailid	1	t
625	288	4	1	Detailid	1	t
674	297	5	2	nav	0	t
662	270	5	2	Lõpeta parkimiskoht	1	t
664	275	5	2	Nav	8	t
665	306	5	2	Nav	8	t
623	287	4	1	Kõik parklakohad	1	t
642	296	4	1	Info	1	t
629	289	4	1	Lõpeta parklakoht	1	t
696	320	5	2	Navigation	1	t
667	307	5	2	Nav	1	t
605	281	4	1	Laudade koondaruanne	0	t
668	285	4	1	Aktiivsed ja mitteaktiivsed teenused	20	t
729	328	5	1	Aktiveeri kaup	0	t
663	306	5	1	Parkimiskoha detailid	1	t
679	313	5	2	Menüü	1	t
661	275	4	1	Lõpeta parkimiskoht	1	t
678	313	4	1	Info	0	t
671	308	4	1	Unusta parkimiskoht	1	t
672	308	5	2	Nav	9	t
670	275	4	1	Lõpetatavad parkimiskohad	2	t
680	314	5	2	Menüü	1	t
681	314	4	1	Info	0	t
683	314	4	1	Prooviruumide koondaruanne	2	t
684	250	5	2	Menüü	1	t
685	315	5	2	Navigation	1	t
688	317	5	2	Navigation	1	t
689	316	5	2	Navigation	1	t
698	323	5	2	Navigation	1	t
699	321	5	2	Navigation	1	t
700	322	5	2	Navigation	1	t
686	315	4	1	Koondaruanne	1	t
701	324	5	2	Navigation	1	t
702	323	4	1	Koondaruanne	1	t
703	319	4	1	Lõpetatavad prooviruumid	2	t
707	321	4	1	Kõik parklakohad	1	t
708	322	4	1	Lõpeta parklakoht	1	t
654	302	4	1	Vaata kõiki laudu	1	t
682	314	4	1	Kõik prooviruumid	1	t
704	319	4	1	Lõpeta prooviruum	1	t
712	319	4	1	Info	0	t
713	250	4	1	Detailid	1	t
714	250	4	1	Info	0	t
711	316	4	1	Kõik parklakohad	1	t
697	320	4	1	Lõpetatavad	2	t
715	317	4	1	Detailandmed	1	t
716	325	5	2	Navigation	1	t
717	325	4	1	Rakendusest	1	t
718	326	5	2	Navigatsioon	1	t
719	326	4	1	Vaata aktiivseid/mitteaktiivseid laudu	1	t
633	289	5	1	Parklakohad, mida saab lõpetada	2	t
728	328	5	2	Kaupade haldus	3	t
630	290	4	1	Lõpeta parklakoht	10	t
666	307	4	1	Parkimiskohtade koondaruanne	1	t
669	270	4	1	Parkimiskohade koondaruanne	2	t
736	334	4	1	Muuda kaup mitteaktiivseks	5	t
738	335	5	2	Unusta kaup	0	t
737	334	5	2	Muuda kaup mitteaktiivseks	0	t
649	301	4	1	Vaata laudade koondaruannet	1	t
803	357	4	1	Lisa kaup kategooriasse	0	t
804	358	5	2	Eemalda kaup kategooriast	0	t
770	341	5	2	NavRegion	1	t
805	358	4	1	Eemalda kauba kategooria	0	t
798	355	4	1	Lisa kauba variant	0	t
751	339	5	2	Peamine navigatsioon	1	t
752	339	4	1	Parklakohtade koondaruanne	1	t
806	362	5	2	Lisa kaup	0	t
769	341	4	1	Koondaruanne	1	t
807	362	4	1	Lisa kaup	0	t
776	329	4	1	Nutitelefonid	1	t
778	339	4	1	Kõik parklakohad	2	t
779	348	4	1	Lõpetatavad parklakohad	2	t
780	348	5	2	Peamine navigatsioon	1	t
782	350	5	2	Peamine navigatsioon	1	t
781	350	4	1	Parklakohtade detailid	1	t
787	348	4	1	Lõpeta parklakoht	1	t
788	351	5	2	Registreeri nutitelefon	0	t
789	351	4	1	Registreeri Kaup	0	t
790	351	4	1	Kõik kaubad	1	t
791	353	5	2	Kõik parklakohad	1	t
792	353	4	1	Kõik parklakohad	1	t
774	347	4	1	Lõpetatavad parklakohad	2	t
772	346	4	1	Parklakohtade detailvaade	1	t
793	354	5	2	Vaata kõiki ootel või mitteaktiivseid kaupu	0	t
794	354	4	1	Vaata kõiki ootel kaupu	0	t
795	354	4	1	Vaata kõiki mitteaktiivseid kaupu	1	t
741	336	5	2	Muuda nutitelefoni andmeid	0	t
722	329	4	1	Registreeri nutitelefon	0	t
797	355	5	2	Lisa kauba variant	0	t
799	356	5	2	Eemalda kauba variant	0	t
800	356	5	1	Eemalda kauba variant	0	t
802	357	5	2	Lisa kaup kategooriasse	0	t
\.


--
-- Data for Name: region_template; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.region_template (template_id, template) FROM stdin;
4	<div class="panel panel-default">\n  <div class="panel-heading">#NAME#</div>\n  <div class="panel-body">#BODY#</div>\n</div>
5	#BODY#
\.


--
-- Data for Name: report_column; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.report_column (report_column_id, report_column_type_id, region_id, view_column_name, heading, sequence, is_text_escaped) FROM stdin;
703	COLUMN	48	kauba_kood	Kauba kood	10	t
41	COLUMN	16	room_code	Toa kood	20	t
42	LINK	16	\N	Toa nimi	10	t
43	COLUMN	16	current_state	Toa olek	30	t
310	COLUMN	56	seisundi_nimetus	Seisundi nimetus	1	t
704	COLUMN	48	kauba_nimetus	Kauba nimetus	20	t
705	COLUMN	48	kauba_seisundi_nimetus	Kauba seisundi liik	30	t
706	COLUMN	48	lopphind	Hind	40	t
707	COLUMN	48	reg_kp	Registreerimise kuupäev	50	t
824	COLUMN	190	raamat_id	ID	1	t
825	COLUMN	190	isbn	ISBN	3	t
826	COLUMN	190	pealkiri	Pealkiri	4	t
827	COLUMN	190	netohind	Netohind	5	t
828	COLUMN	190	laohind	Laohind	6	t
829	COLUMN	190	reg_aeg	Registreerimisaeg	8	t
830	COLUMN	190	tootaja_nimi	Töötaja	9	t
831	COLUMN	190	tootaja_email	Email	10	t
311	COLUMN	56	arv	Toodete arv	2	t
312	COLUMN	56	toote_seisundi_liik_kood	Toote seisundi kood	0	t
832	COLUMN	190	hetkeseisund	Hetke seisund	7	t
858	COLUMN	201	kauba_kood	Kauba kood	4	t
859	COLUMN	201	nimetus	Kauba nimi	3	t
725	COLUMN	195	raamat_id	ID	1	t
726	COLUMN	195	ilmumisaasta	Ilmumisaasta	2	t
727	COLUMN	195	isbn	ISBN	3	t
728	COLUMN	195	pealkiri	Pealkiri	4	t
729	COLUMN	195	netohind	Netohind	5	t
730	COLUMN	195	laohind	Laohind	6	t
860	COLUMN	201	seisund	Hetkeseisund	5	t
861	COLUMN	201	reg_aeg	Registreerimisaeg	7	t
962	COLUMN	179	kood	Kood	0	t
963	COLUMN	179	nimetus	Nimetus	2	t
251	COLUMN	71	kauba_seisundi_liik_kood	Kauba seisundi kood	0	t
252	COLUMN	71	nimetus	Kauba seisundi nimetus	1	t
253	COLUMN	71	count	Arv	2	t
254	COLUMN	61	eesnimi	Eesnimi	0	t
255	COLUMN	61	perenimi	Perekonnanimi	1	t
256	COLUMN	61	synni_kp	Sünni kuupäev	2	t
257	COLUMN	61	e_meil	E-mail	3	t
111	COLUMN	28	room_code	Toa kood	10	t
112	COLUMN	28	room_name	Toa nimi	20	t
113	COLUMN	28	current_state	Hetkeseisund	30	t
258	COLUMN	61	telefoninumber	Telefoninumber	4	t
964	LINK	179	\N	Kustuta	4	f
965	COLUMN	179	seisund	Brand	1	t
966	COLUMN	179	registreeritud	Registreeritud	3	t
976	COLUMN	242	kauba_seisundi_liik_kood	Seisundi kood	0	t
977	COLUMN	242	nimetus	Seisundi nimetus	1	t
978	COLUMN	242	arv	Kaupade arv	2	t
124	COLUMN	4	room_count	Tubade arv	20	t
125	COLUMN	4	room_state_type	Toa olek	10	t
1067	COLUMN	260	raja_kood	Raja kood	0	t
1068	COLUMN	260	nimetus	Raja nimi	1	t
1069	COLUMN	260	kirjeldus	Raja kirjeldus	2	t
1070	COLUMN	260	tase	Raja raskustase	3	t
1071	COLUMN	260	rendihind	Rendihind	4	t
348	COLUMN	81	kauba_seisundi_liik_kood	Kauba seisundi liik kood	5	t
349	COLUMN	81	nimetus	Seisundi nimetus	10	t
350	COLUMN	81	arv	Toodete arv seisundis	15	t
351	COLUMN	85	kauba_kood	Toote kood	10	t
352	COLUMN	85	nimetus	Nimetus	20	t
353	COLUMN	85	kirjeldus	Kirjeldus	30	t
354	COLUMN	85	varvus	Värvus	40	t
355	COLUMN	85	hind	Hind	50	t
356	COLUMN	85	seisund	Seisund	60	t
1963	COLUMN	391	kauba_kood	Kauba kood	10	t
1964	COLUMN	391	nimetus	Nimetus	20	t
1965	COLUMN	391	kategooria	Kategooria	50	f
1966	COLUMN	391	tyki_hind	Väljamüügihind (käibemaksuta)	80	t
1967	COLUMN	391	brand	Bränd	40	t
1968	COLUMN	391	reg_aeg	Registreerimise aeg	70	t
1969	COLUMN	391	registreerija	Registreerija	90	f
1970	COLUMN	391	pildi_link	Pildi link	100	t
1971	COLUMN	391	kauba_tyyp	Kauba tüüp	30	t
1972	COLUMN	391	omadused	Omadused	60	f
1189	COLUMN	3	room_name	Toa nimi	5	t
1190	COLUMN	3	bed_type_name	Voodi tüüp	10	t
1191	COLUMN	3	current_state	Hetkeolek	20	t
714	COLUMN	188	raamatute_arv	Raamatute arv	0	t
715	COLUMN	188	nimetus	Nimetus	1	t
1192	COLUMN	3	night_price	Öö hind (EUR)	30	t
1095	COLUMN	263	raja_kood	Raja kood	0	t
1096	COLUMN	263	nimetus	Raja nimetus	1	t
1097	COLUMN	263	tase	Raja tase	2	t
1193	COLUMN	3	person_who_registered	Registreerija	50	t
1194	COLUMN	3	minimal_night_price	Minimaalne öö hind (EUR)	40	t
1195	COLUMN	3	registration_year	Registreerimisaasta	60	t
1196	COLUMN	3	room_code	Toa kood	2	t
440	COLUMN	73	kaup_kood	Kauba kood	0	t
441	COLUMN	73	nimetus	Nimetus	1	t
442	COLUMN	73	kauba_seisundi_liik_kood	Seisundi kood	2	t
443	COLUMN	73	hind	Hind	3	t
444	COLUMN	73	kogus	Kogus	4	t
445	COLUMN	73	platvorm_kood	Platvormi kood	5	t
716	COLUMN	188	raamatu_seisundi_liik_kood	Raamatu seisundi liigi kood	2	t
731	COLUMN	195	raamatu_seisundi_liik_kood	Raamatu seisundi liigi kood	7	t
732	COLUMN	195	reg_aeg	Registreerimisaeg	8	t
833	COLUMN	157	treening	Treening	1	t
834	COLUMN	157	treeningu_seisund	Seisund	9	t
835	COLUMN	157	treeningu_kategooria	Kategooria	2	t
836	COLUMN	157	raskusaste	Raskusaste	3	t
837	COLUMN	157	raskusaste_kirjeldus	Raskusaste kirjeldus	4	t
838	COLUMN	157	treener_eesnimi	Treeneri eesnimi	6	t
839	COLUMN	157	treener_perenimi	Treeneri perenimi	7	t
840	COLUMN	157	treening_kirjeldus	Treeningu kirjeldus	8	t
841	COLUMN	157	reg_aeg	Registreerimisaeg	5	t
484	COLUMN	92	nimetus	Nimetus	0	t
485	COLUMN	92	hinna_vahemiku_lopp	Hinnavahemiku lõpp	1	t
486	COLUMN	92	hetke_seisund	Hetkeseisund	2	t
487	COLUMN	92	teenus_kood	Teenuse kood	3	t
488	COLUMN	92	hinna_vahemiku_algus	Hinnavahemiku algus	4	t
489	COLUMN	92	teenuse_tuup	Teenuse tüüp	5	t
2524	COLUMN	454	kaubakoodid	Kaubakoodid	1	t
2525	COLUMN	454	nimetus	Nimetus	2	t
2526	COLUMN	454	seisundi_olek	Seisund	3	t
2527	COLUMN	454	hind	Hind	4	t
2528	COLUMN	454	kaup_id	Kood	0	t
2271	COLUMN	437	lavastus	Lavastus	1	t
2272	COLUMN	437	kirjeldus	Kirjeldus	2	t
2273	COLUMN	437	hooaja_nimi	Hooaeg	3	t
1037	COLUMN	247	pealkiri	Pealkiri	0	t
1038	COLUMN	247	hind	Hind	1	t
1039	COLUMN	247	trykise_kood	Trükise kood	2	t
1040	COLUMN	247	lehekylgede_arv	Lehekülgede arv	3	t
1041	COLUMN	247	kirjastus	Kirjastus	4	t
1042	COLUMN	247	ilmumisaasta	Ilmumisaasta	5	t
1043	COLUMN	247	aktiivsus	Aktiivsus	6	t
1044	COLUMN	247	kategooria	Kategooria	7	t
688	COLUMN	184	kauba_kood	Kauba kood	10	t
689	COLUMN	184	kauba_nimetus	Kauba nimetus	20	t
690	COLUMN	184	kauba_seisundi_nimetus	Kauba seisund	30	t
691	COLUMN	184	reg_kp	Registreerimis kuupäev	40	t
692	COLUMN	184	lopphind	Hind	50	t
693	COLUMN	184	eesnimi	Eesnimi	60	t
694	COLUMN	184	perenimi	Perenimi	70	t
788	COLUMN	200	seisundi_nimetus	Kauba seisund	1	t
789	COLUMN	200	arv	Kaupade arv seisundis	2	t
794	COLUMN	100	kauba_kood	Kauba kood	5	t
795	COLUMN	100	nimetus	Nimetus	10	t
796	COLUMN	100	kirjeldus	Kirjeldus	15	t
797	COLUMN	100	varvus	Varvus	20	t
798	COLUMN	100	hind	Hind	25	t
799	COLUMN	100	kategooria	Kategooria	30	t
800	COLUMN	100	registreerija	Registreerija	35	t
801	COLUMN	100	reg_aeg	Registreerimisaeg	40	t
802	COLUMN	100	seisund	Seisund	45	t
803	COLUMN	206	raamat_id	ID	1	t
804	COLUMN	206	isbn	ISBN	2	t
805	COLUMN	206	pealkiri	Pealkiri	3	t
806	COLUMN	206	autorid	Autor(id)	4	t
807	COLUMN	206	kategooriad	Kategooria(d)	5	t
808	COLUMN	206	ilmumisaasta	Ilmumisaasta	6	t
809	COLUMN	206	lk_arv	Lk arv	7	t
810	COLUMN	206	formaat	Formaat	8	t
812	COLUMN	181	kauba_seisundi_nimetus	Kauba seisundi nimetus	10	t
813	COLUMN	181	kauba_seisundi_liik	Kauba seisundi liigi kood	20	t
814	COLUMN	181	arv	Kaupade arv seisundis	30	t
992	COLUMN	64	kood	Kood	0	t
993	COLUMN	64	brand	Brand	1	t
994	COLUMN	64	nimetus	Nimetus	2	t
995	COLUMN	64	seisund	Seisund	3	t
996	COLUMN	64	varv	Värvus	5	t
1089	COLUMN	266	raja_kood	Raja kood	0	t
997	COLUMN	64	materjal	Materjal	6	t
998	COLUMN	64	sihtgrupp	Sihtgrupp	7	t
999	COLUMN	64	kategooria	Kategooria	8	t
1000	COLUMN	64	registreerija	Registreerija	9	t
1001	COLUMN	64	kirjeldus	Kirjeldus	10	t
1002	COLUMN	64	hind	Hind	11	t
1003	COLUMN	64	pilt	Pilt	12	f
1004	COLUMN	64	registreeritud	Registreeritud	4	t
2274	COLUMN	437	saal	Saal	5	t
2275	COLUMN	437	alguse_aeg	Algus aeg	4	t
2276	COLUMN	437	seisund	Seisund	6	t
2277	COLUMN	386	kogus	Kaupade arv	0	t
2278	COLUMN	386	seisund	Seisundi nimetus	1	t
2279	COLUMN	386	seisund_kood	Seisundi liigi kood	2	t
3324	COLUMN	466	sailivusaeg	Säilivusaega tüüp	5	t
1090	COLUMN	266	nimetus	Raja nimi	1	t
1091	COLUMN	266	tase	Raja tase	2	t
1098	COLUMN	259	radade_arv	Radade arv	2	t
885	COLUMN	213	kaup_seisund_liik_kood	Kauba seisundi kood	0	t
886	COLUMN	213	kaup_seisund_liik_nimetus	Kauba seisundi nimi	1	t
887	COLUMN	213	kaup_arv	Kaupade arv	2	t
888	COLUMN	217	tootaja_kood	Kood	0	t
889	COLUMN	217	nimi	Nimi	1	t
890	COLUMN	217	isik_email	Email	2	t
891	COLUMN	217	tootaja_seisund_liik_nimetus	Seisund	3	t
892	COLUMN	217	kaupade_arv	Seotud kaupade arv	4	t
893	COLUMN	217	amet_nimetus	Amet	5	t
894	COLUMN	220	kaup_kood	Kood	0	t
895	COLUMN	220	kaup_brand_nimetus	Brand	1	t
896	COLUMN	220	kaup_nimetus	Nimetus	2	t
897	COLUMN	220	kaup_kirjeldus	Kirjeldus	3	t
898	COLUMN	220	kaup_hind	Hind	4	t
899	COLUMN	220	kaup_seisund_liik_nimetus	Seisund	5	t
900	COLUMN	220	kaup_reg_aeg	Registreerimis aeg	6	t
901	COLUMN	223	kaup_kood	Kood	0	t
902	COLUMN	223	kaup_nimetus	Nimetus	1	t
903	COLUMN	223	kaup_kirjeldus	Kirjeldus	2	t
904	COLUMN	223	kaup_hind	Hind	3	t
905	COLUMN	223	kaup_seisund_liik_nimetus	Seisund	4	t
1099	COLUMN	259	nimetus	Nimetus	0	t
1100	COLUMN	259	raja_kood	Seisundi kood	1	t
1598	COLUMN	362	nimetus	Nimetus	0	t
925	COLUMN	234	treeningu_seisundi_liik_kood	Seisundi kood	1	t
926	COLUMN	234	nimetus	Seisund	2	t
927	COLUMN	234	count	Treeninguid seisundis	3	t
1141	COLUMN	208	kauba_kood	Kauba kood	1	t
1142	COLUMN	208	nimetus	Kauba nimi	2	t
1143	COLUMN	208	hind	Hind	3	t
1144	COLUMN	208	hetkeseisund	Hetkeseisund	4	t
1145	COLUMN	208	kategooriad	Kauba kategooria	5	t
1146	COLUMN	208	omadused	Kauba omadused	6	f
1147	COLUMN	208	reg_aeg	Registreerimisaeg	7	t
1148	COLUMN	208	e_meil	Registreerija	8	t
1149	COLUMN	257	reis_kood	Reisi Kood	5	t
1150	COLUMN	257	alguse_kuupaev	Alguse Kuupäev	10	t
1151	COLUMN	257	saabumise_kuupaev	Saabumise Kuupäev	15	t
1152	COLUMN	257	pilet_kood	Pileti Kood	20	t
1153	COLUMN	257	pileti_seisundi_liik_kood	Pileti Seisund	25	t
1157	COLUMN	88	teenuse_seisundi_liik_kood	Teenuse seisundi liik kood	0	t
1158	COLUMN	88	seisundi_liik	Seisundi liik	1	t
1159	COLUMN	88	arv	Teenuseid selles olekus	2	t
1160	COLUMN	270	kauba_kood	Kauba kood	1	t
1161	COLUMN	270	brandi_kood	Brandi kood	2	t
1162	COLUMN	270	hind	Hind	3	t
1163	COLUMN	270	nimetus	Nimetus	4	t
1164	COLUMN	270	kauba_seisundi_liigi_nimetus	Kauba seisundi liigi nimetus	5	t
1165	COLUMN	273	kauba_kood	Kauba kood	1	t
1166	COLUMN	273	brandi_kood	Brandi kood	2	t
1167	COLUMN	273	kauba_seisundi_liigi_nimetus	Kauba seisundi liigi nimetus	3	t
1168	COLUMN	273	nimetus	Nimetus	4	t
1169	COLUMN	273	hind	Hind	5	t
1170	COLUMN	274	kauba_seisundi_liigi_nimetus	Kauba seisundi liigi nimetus	1	t
1171	COLUMN	274	kauba_seisundi_liigi_kood	Kauba seisundi liigi kood	2	t
1172	COLUMN	274	kaupade_arv	Kaupade arv	3	t
4984	COLUMN	778	parklakoha_kood	Parklakoha kood	1	t
4985	COLUMN	778	parkla_nimetus	Parkla nimetus	2	t
4986	COLUMN	778	parklakoha_tyybi_nimetus	Parklakoha tüüp	3	t
2280	COLUMN	323	zanrid	Žanrid	17	t
2281	COLUMN	323	keskmine_hinnang	Keskmine hinnang	19	t
2184	COLUMN	52	seisund	Seisund	1	t
2185	COLUMN	52	nimetus	Nimetus	2	t
2186	COLUMN	52	kirjeldus	Kirjeldus	3	t
2187	COLUMN	52	hind	Hind	4	t
1203	COLUMN	281	name	Pildi nimi	1	t
1204	COLUMN	281	image	Pilt	2	f
2282	COLUMN	323	kategooria	Kategooria	18	t
2283	COLUMN	323	kaup_kood	Kauba kood	0	t
2188	COLUMN	52	pildilink	Toote pilt	6	f
1998	COLUMN	395	kauba_kood	Kauba kood	1	t
1999	COLUMN	395	kauba_nimetus	Kauba nimetus	2	t
2000	COLUMN	395	hetkeseisundi_nimetus	Kauba hetkeseisund	3	t
2001	COLUMN	395	hind	Kauba hind	4	t
1836	COLUMN	60	seisund	Seisund	0	t
1837	COLUMN	60	nimetus	Nimetus	1	t
1838	COLUMN	60	kirjeldus	Kirjeldus	2	t
1839	COLUMN	60	hind	Hind	3	t
1840	COLUMN	60	pilt	Pilt	10	t
1841	COLUMN	60	reg_aeg	Reg aeg	5	t
1842	COLUMN	60	eesnimi	Lisaja eesnimi	6	t
1843	COLUMN	60	perenimi	Lisaja perenimi	7	t
1844	COLUMN	60	e_meil	Lisaja email	8	t
2002	COLUMN	395	kirjeldus	Kauba kirjeldus	5	t
2003	COLUMN	395	pilt	Kauba pilt	6	t
2004	COLUMN	395	registreerimise_aeg	Kauba registeerimise aeg	7	t
2005	COLUMN	395	registreerija_eesnimi	Kauba registeerija eesnimi	8	t
2006	COLUMN	395	registreerija_perenimi	Kauba registeerija perenimie	9	t
2007	COLUMN	395	registreerija_email	Kauba registeerija email	11	t
2008	COLUMN	395	brandi_nimetus	Kauba brandi nimetus	12	t
2009	COLUMN	395	kategooriad	Kauba kategooria	13	t
2189	COLUMN	52	reg_kp	Reg aeg	7	t
2190	COLUMN	52	toode_id	Kood	0	t
2191	COLUMN	52	kogus_kokku	Kogus	5	t
2223	COLUMN	403	kauba_kood	Kood	5	t
2224	COLUMN	403	nimetus	Nimetus	10	t
2225	COLUMN	403	seisund	Hetkeseisund	15	t
2284	COLUMN	323	kaup_nimetus	Kauba nimetus	1	t
3297	COLUMN	465	seisundi_nimetus	Sesundi nimetus	1	f
3298	COLUMN	465	kauba_seisundi_liik_kood	Kauba seisundi liik kood	2	f
3299	COLUMN	465	arv	Arv	3	f
3313	COLUMN	475	hetke_seisund	Hetke seisund	8	f
3314	COLUMN	475	hind	Väljamüügi hind	9	f
1263	COLUMN	309	seisundi_kood	Seisundi kood	10	t
1264	COLUMN	309	seisundi_nimetus	Seisundi nimetus	15	t
1265	COLUMN	309	kaupade_arv	Kaupade arv	20	t
1460	COLUMN	352	hetke_seisundi_liik_nimetus	Seisundi nimetus	10	t
1461	COLUMN	352	hetke_seisundi_liik_kood	Seisundi kood	20	t
1462	COLUMN	352	kaupade_arv	Kaupade arv	30	t
1492	COLUMN	326	kaup_kood	Kauba kood	0	t
1493	COLUMN	326	kaup_nimetus	Kauba nimetus	1	t
1494	COLUMN	326	kauba_seisundi_liik_nimetus	Kauba seisundi liik	4	t
1495	COLUMN	326	kaup_tyyp	Kauba tüüp	3	t
1496	COLUMN	326	myygi_hind	Müügihind (EUR)	2	t
1845	COLUMN	60	tootetyyp	Tootetüüp	9	t
1846	COLUMN	60	brand	Bränd	4	t
1863	COLUMN	76	nimetus	Nimetus	2	t
1864	COLUMN	76	kirjeldus	Kirjeldus	3	f
1865	COLUMN	76	seisund	Seisund	1	t
4987	COLUMN	778	parklakoha_hetke_seisund	Parklakoha seisund	4	t
1866	COLUMN	76	toode_id	Kood	0	t
1867	COLUMN	76	reg_kp	Reg.kp	7	t
1868	COLUMN	76	hind	Hind	4	t
1869	COLUMN	76	pildilink	Pilt	6	f
1870	COLUMN	76	kogus_kokku	Kogus	5	t
3325	COLUMN	466	kauba_nimetus	Nimetus	3	t
2285	COLUMN	323	myygi_hind	Müügihind (EUR)	2	t
2286	COLUMN	323	kauba_seisundi_liik_nimetus	Kauba seisundi liik	3	t
2287	COLUMN	323	kaup_tyyp	Kauba tüüp	4	t
2288	COLUMN	323	registreerija	Registreerija	6	t
3326	COLUMN	466	kauba_kood	EAN kood	2	t
3327	COLUMN	466	kaup_id	ID	1	t
3328	COLUMN	466	hetke_seisund	Seisund	4	t
3329	COLUMN	466	hind	Väljamüügi hind	6	t
3330	COLUMN	466	paritoluriik	Paritoluriik	7	t
2289	COLUMN	323	reg_aeg	Registreerimisaeg	5	t
2290	COLUMN	323	isbn	ISBN	7	t
2291	COLUMN	323	alapealkiri	Alapealkiri	8	t
2292	COLUMN	323	autorid	Autorid	9	t
2293	COLUMN	323	kirjeldus	Kirjeldus	10	f
2294	COLUMN	323	keeled	Keeled	11	t
2295	COLUMN	323	kirjastus_nimetus	Kirjastus	12	t
2296	COLUMN	323	lehekylgede_arv	Lehekülgede arv	13	t
2297	COLUMN	323	ilmumisaasta	Ilmumisaasta	14	t
2298	COLUMN	323	sari_nimetus	Sari	15	t
2299	COLUMN	323	mootmed	Mõõtmed (mm x mm)	16	t
2549	COLUMN	292	parklakoha_kood	Parklakoha kood	10	t
2550	COLUMN	292	nimetus	Nimetus	20	t
2551	COLUMN	292	parklakoha_tyyp	Tüüp	30	t
2552	COLUMN	292	hetke_seisund	Hetkeseisund	40	t
2553	COLUMN	292	tunni_hind	Tunni hind (EUR)	50	t
1731	COLUMN	312	kauba_kood	Kauba kood	5	t
1732	COLUMN	312	kauba_nimetus	Kauba nimetus	10	t
1733	COLUMN	312	seisundi_nimetus	Seisundi nimetus	15	t
1363	COLUMN	337	kauba_seisundi_liik_kood	Seisundi kood	0	t
1364	COLUMN	337	seisundi_nimetus	Seisundi nimetus	1	t
1365	COLUMN	337	arv	Kaupade arv	2	t
1734	COLUMN	312	hind	Kauba hind	20	t
1950	COLUMN	392	kauba_kood	Kauba kood	10	t
1951	COLUMN	392	nimetus	Nimetus	20	t
1952	COLUMN	392	hetke_seisundi_nimetus	Hetke seisundi nimetus	30	t
1740	COLUMN	308	kauba_kood	Kauba kood	5	t
1741	COLUMN	308	kauba_nimetus	Kauba nimetus	10	t
1742	COLUMN	308	kirjeldus	Kauba kirjeldus	15	t
1377	COLUMN	333	tootja	Bränd	1	t
1378	COLUMN	333	nimetus	Nimetus	2	t
1379	COLUMN	333	kauba_tyyp	Kauba tüüp	3	t
1380	COLUMN	333	hetke_seisund	Hetke seisund	4	t
1381	COLUMN	333	hind	Hind	5	t
1382	COLUMN	333	kaup_id	Kauba id	0	t
1743	COLUMN	308	hetkeseisundi_nimetus	Hetkeseisund	20	t
1744	COLUMN	308	hind	Kauba hind	25	t
1499	COLUMN	331	tootja	Bränd	0	t
1500	COLUMN	331	nimetus	Kauba nimetus	1	t
1501	COLUMN	331	kauba_tyyp	Kauba tüüp	2	t
1502	COLUMN	331	hetke_seisund	Hetke seisund	3	t
1503	COLUMN	331	hind	Hind (EUR)	4	t
1746	COLUMN	382	kauba_kood	Kauba kood	0	t
1747	COLUMN	382	nimetus	Nimetus	1	t
1748	COLUMN	382	hind	Hind	2	t
1749	COLUMN	382	kauba_tyyp	Kauba tüüp	3	t
1750	COLUMN	382	hetke_seisund	Seisund	4	t
1751	COLUMN	383	arv	Arv	0	t
1752	COLUMN	383	kauba_seisundi_liigi_kood	Kauba seisundi liigi kood	1	t
1753	COLUMN	383	seisundi_nimetus	Seisundi nimetus	2	t
1599	COLUMN	362	kauba_kood	Kauba kood	1	t
1600	COLUMN	362	hind	Hind	2	t
1601	COLUMN	362	kauba_tyyp	Kauba tüüp	3	t
1602	COLUMN	362	hetke_seisund	Seisund	4	t
3264	COLUMN	469	kauba_nimetus	Nimetus	3	f
3265	COLUMN	469	hind	Väljamüügi hind	4	f
3266	COLUMN	469	hetke_seisund	Hetke seisund	6	f
3267	COLUMN	469	riik_kood	Paritoluriik	5	f
3268	LINK	469	\N	Detailid	8	f
3269	COLUMN	469	kaup_id	ID	1	f
3270	COLUMN	469	kauba_kood	EAN kood	2	f
3271	COLUMN	469	sailivusaeg	Säilivusaega tüüp	7	f
2300	COLUMN	321	kaup_kood	Kauba kood	0	t
2301	COLUMN	321	kaup_nimetus	Kauba nimetus	1	t
2021	COLUMN	369	nimetus	Nimetis	1	t
2022	COLUMN	369	kauba_kood	Kauba kood	0	t
2023	COLUMN	369	hind	Hind	2	t
2024	COLUMN	369	kirjeldus	Kirjeldus	3	t
2025	COLUMN	369	pilt	Pilt	4	f
2026	COLUMN	369	reg_aeg	Registreerimise aeg	5	t
2027	COLUMN	369	hetke_seisund	Seisund	6	t
2028	COLUMN	369	kauba_tyyp	Kauba tüüp	7	t
2029	COLUMN	369	koha_tyyp	Koha tüüp	8	t
2030	COLUMN	369	sailitamise_tyyp	Säilitamise tüüp	9	t
2031	COLUMN	369	registreerija	Registreerija	10	t
2032	COLUMN	369	kategooriad	Kategooriad	11	f
2302	COLUMN	321	myygi_hind	Müügihind (EUR)	2	t
2303	COLUMN	321	kauba_seisundi_liik_nimetus	Kauba seisundi liik	3	t
2304	COLUMN	321	kaup_tyyp	Kauba tüüp	4	t
2305	LINK	321	\N	Detailid	5	t
2306	COLUMN	365	kaup_id	Kauba ID	0	t
2307	COLUMN	365	registreerija	Registreerija	1	t
2308	COLUMN	365	hetke_seisund	Kauba seisundi liik	2	t
2309	COLUMN	365	kauba_tyyp	Kauba tüüp	3	t
2310	COLUMN	365	pordi_tyyp	Pordi tüüp	4	t
2311	COLUMN	365	op_sys	Operatsioonisüsteem	5	t
2312	COLUMN	365	tootja	Tootja	6	t
2313	COLUMN	365	nimetus	Nimetus	7	t
2045	COLUMN	405	seisundi_kood	Seisundi kood	5	t
2046	COLUMN	405	seisund	Seisundi nimi	10	t
2047	COLUMN	405	arv	Kaupu seisundis	15	t
2314	COLUMN	365	hind	Hind (EUR)	8	t
2315	COLUMN	365	aku_mahtuvus	Aku mahtuvus (mAh)	9	t
2316	COLUMN	365	ekraani_suurus	Ekraani suurus (toll)	10	t
2317	COLUMN	365	esi_mp_arv	Esikaamera megapikslite arv	11	t
2318	COLUMN	365	taga_mp_arv	Tagakaamera megapikslite arv	12	t
2319	COLUMN	365	graafikakaart	Graafikakaardi nimetus	13	t
2320	COLUMN	365	kaal	Kaal (g)	14	t
2321	COLUMN	365	kirjeldus	Kirjeldus	15	t
2322	COLUMN	365	ooteaeg_kuni	Ooteaeg kuni (h)	16	t
2323	COLUMN	365	koneaeg_kuni	Kõneaeg kuni (h)	17	t
2324	COLUMN	365	korgus	Kõrgus (mm)	18	t
2325	COLUMN	365	laius	Laisu (mm)	19	t
2326	COLUMN	365	aku_mahtuvus	On 3.5mm pesa	20	t
2327	COLUMN	365	on_4g	On 4G	21	t
2328	COLUMN	365	on_bluetooth	On bluetooth	22	t
2329	COLUMN	365	on_gps	On GPS	23	t
2330	COLUMN	365	on_mitmikpuute_tugi	On mitmikpuute tugi	24	t
2067	COLUMN	412	kaupade_arv	arv	3	t
2068	COLUMN	412	kauba_seisundi_nimetus	nimetus	1	t
2069	COLUMN	412	kauba_seisundi_liik_kood	kood	2	t
2331	COLUMN	365	on_nfc	On NFC	25	t
2332	COLUMN	365	on_wifi	On WiFi	26	t
1888	COLUMN	390	rooms	State	1	f
1889	COLUMN	390	room_state	Rooms	2	t
2333	COLUMN	365	opmalu_suurus	Operatiivmälu suurus (GB)	27	t
2334	COLUMN	365	protsessori_kiibistik	Protsessori kiibistik	28	t
2335	COLUMN	365	protsessori_tuumade_arv	Protsessori tuumade arv	29	t
2336	COLUMN	365	reg_aeg	Registreerimise aeg	30	t
2337	COLUMN	365	resolutsioon	Resolutsioon (laius x kõrgus)	31	t
2338	COLUMN	365	sisemalu_suurus	Sisemälu suurus (GB)	32	t
2339	COLUMN	365	sygavus	Sügavus (mm)	33	t
2340	COLUMN	365	pildi_aadress	Pildi aadress	34	t
2346	COLUMN	293	parklakoha_kood	Parkimiskoha kood	10	t
2347	COLUMN	293	nimetus	Nimetus	20	t
2348	COLUMN	293	hetke_seisund	Hetkeseisund	40	t
2349	COLUMN	293	parklakoha_tyyp	Tüüp	30	t
2350	COLUMN	293	tunni_hind	Tunnihind	50	t
2351	COLUMN	286	seisundi_nimetus	Seisundi liik	1	t
2352	COLUMN	286	arv	Parkimiskohtade arv	2	t
2353	COLUMN	414	kaup_kood	Kood	10	t
2354	COLUMN	414	nimetus	Kauba nimetus	20	t
2355	COLUMN	414	hind	Kauba hind (€)	30	t
2356	COLUMN	414	seisnud_nimetus	Seisund	40	t
2357	COLUMN	414	tootja_garantii_aastates	Tootja garantii (aastates)	50	t
2358	COLUMN	414	brand_nimetus	Bränd	60	t
2359	COLUMN	414	reg_aeg	Registreerimisaeg	70	t
2360	COLUMN	414	registreerija	Registreerija	80	t
2361	COLUMN	414	kirjeldus	Kauba kirjeldus	90	t
2362	COLUMN	413	kaup_kood	Kood	10	t
2363	COLUMN	413	nimetus	Kauba nimetus	20	t
2364	COLUMN	413	hind	Kauba hind (€)	30	t
2365	COLUMN	413	seisnud_nimetus	Seisund	40	t
2366	COLUMN	413	tootja_garantii_aastates	Tootja garantii (aastates)	50	t
2367	COLUMN	413	brand_nimetus	Bränd	60	t
2368	COLUMN	413	reg_aeg	Registreerimisaeg	70	t
2369	COLUMN	413	registreerija	Registreerija	80	t
2370	COLUMN	413	kirjeldus	Kauba kirjeldus	90	t
2371	COLUMN	413	kategooriad	Kauba kategooriad	100	f
2372	COLUMN	413	komponendid	Kauba komponendid	110	f
2373	COLUMN	443	laua_kood	Laua kood	1	t
2374	COLUMN	443	nimetus	Laua nimetus	2	t
2375	COLUMN	443	laua_tyyp	Laua tüüp	3	t
2376	COLUMN	443	hetke_seisund	Hetkeseisund	4	t
2377	COLUMN	443	registreerija	Registreerija	5	t
2378	COLUMN	443	reg_aeg	Registreerimise aeg	6	t
2379	COLUMN	443	hinnavahemiku_algus	Hinnavahemiku algus	7	t
2380	COLUMN	443	hinnavahemiku_lopp	Hinnavahemiku lõpp	8	t
2381	COLUMN	443	laua_kategooriad	Laua kategooriad	9	f
2382	COLUMN	443	kirjeldus	Kirjeldus	10	t
2226	COLUMN	403	kaal	Kaal (kg)	20	t
2227	COLUMN	403	hind	Hind (€)	25	t
2228	COLUMN	403	case	Tüüp	30	t
2483	COLUMN	451	kauba_arv	Kaupade arv	2	t
2484	COLUMN	451	seisundi_olek	Seisund	1	t
2485	COLUMN	451	seisundi_kood	Kood	0	t
2486	COLUMN	464	parklakoha_kood	Parklakoha kood	10	t
2487	COLUMN	464	parkla_kood	Parkla kood	20	t
2488	COLUMN	464	parklakoha_nimetus	Parklakoha nimetus	30	t
2489	COLUMN	464	seisund	Hetkeseisund	40	t
2490	COLUMN	464	suuruse_nimetus	Suurus	50	t
2491	COLUMN	464	kommentaar	Kommentaar	60	t
2492	COLUMN	464	tootaja_nimi	Registreeris	70	t
2493	COLUMN	464	email	Registreerija email	80	t
2494	COLUMN	464	kategooriad	Kategooriad	51	f
2495	COLUMN	464	parkla_nimetus	Parkla nimetus	31	t
2496	COLUMN	456	seisundi_nimi	Hetkeseisund	40	t
2497	COLUMN	456	parklakoha_nimi	Parklakoha nimetus	30	t
2498	COLUMN	456	parkla_kood	Parkla kood	20	t
2499	COLUMN	456	parklakoha_kood	Parklakoha kood	10	t
2500	COLUMN	447	hind	Hind	15	t
2501	COLUMN	447	varv	Värv	16	t
2502	COLUMN	447	displayport	Displayport arv	18	t
2503	COLUMN	447	hdmi	Hdmi arv	17	t
2504	COLUMN	447	videokaart	Videokaart	14	t
2505	COLUMN	447	protsessor	Protsessor	13	t
2506	COLUMN	447	operatsioonisysteem	Operatsioonisüsteem	12	t
2507	COLUMN	447	operatiivmalu	Operatiivmälu	11	t
2508	COLUMN	447	kovaketas	Kõvaketas	10	t
2509	COLUMN	447	resolutsioon	Resolutsioon	9	t
3784	COLUMN	537	arv	Arv	3	t
2510	COLUMN	447	maatriks	Maatrikstehnika	8	t
2511	COLUMN	447	diagonaal	Diagonaal	7	t
2512	COLUMN	447	nimetus	Nimetus	4	t
2513	COLUMN	447	kaubamark	Kaubamärk	3	t
2514	COLUMN	447	seisundi_olek	Seisund	2	t
2515	COLUMN	447	kaubakood	Kaubakood	1	t
2516	COLUMN	447	kauba_kategooria_koos_tyybiga	Kategooria	0	t
2517	COLUMN	447	tootaja_nimi	Töötaja nimi	5	t
2518	COLUMN	447	tootaja_email	Töötaja email	6	t
3069	COLUMN	517	laud_id	Laua id	1	t
3070	COLUMN	517	kategooria	Laua kategooria	2	t
2846	COLUMN	497	laud_kood	Kood	1	t
2847	COLUMN	497	nimetus	Nimetus	2	t
2848	COLUMN	497	hetke_seisund	Seisund	3	t
2849	COLUMN	497	toa_tyyp	Toa tüüp	4	t
2850	COLUMN	497	registreerija	Registreerija	5	t
2851	COLUMN	497	reg_aeg	Registreerimise aeg	6	t
2852	COLUMN	497	rendihind	Rendihind(EUR)	7	t
2860	COLUMN	490	laud_kood	Kood	1	t
2861	COLUMN	490	nimetus	Nimetus	2	t
2862	COLUMN	490	hetke_seisund	Seisund	3	t
2863	COLUMN	490	laua_tyyp	Laua tüüp	4	t
2864	COLUMN	490	toa_tyyp	Toa tüüp	5	t
2865	COLUMN	490	registreerija	Registreerija	6	t
2866	COLUMN	490	reg_aeg	Registreerimise aeg	7	t
2867	COLUMN	490	rendihind	Rendihind(EUR)	8	t
2868	COLUMN	507	laud_kood	Kood	1	t
2869	COLUMN	507	nimetus	Nimetus	2	t
2870	COLUMN	507	laua_tyyp	Laua tüüp	3	t
2871	COLUMN	507	toa_tyyp	Toa tüüp	4	t
2872	COLUMN	507	registreerija	Registeerija	5	t
2873	COLUMN	507	reg_aeg	Registreerimise aeg	6	t
2874	COLUMN	507	rendihind	Rendihind(EUR)	7	t
3461	COLUMN	531	seisundi_kood	1	1	t
4970	COLUMN	769	parklakoha_seisundi_liik_kood	Parklakoha seisudi liigi kood	0	t
4971	COLUMN	769	seisundi_nimetus	Seisundi nimetus	1	t
4972	COLUMN	769	arv	Arv	2	t
3477	COLUMN	525	kauba_tyyp	Tyyp	4	t
3478	COLUMN	525	kauba_nimetus	Nimetus	2	t
3479	COLUMN	525	hind	Müügihind (EUR)	3	t
3480	COLUMN	525	kauba_kood	Kauba kood	1	t
3481	COLUMN	525	seisund	Seisund	5	t
3340	COLUMN	509	e_meil	Isiku e-meil	9	t
3341	COLUMN	509	laud_id	Laua id	1	t
3342	COLUMN	509	laua_nimetus	Laua nimetus	2	t
2386	COLUMN	445	laua_kood	Laua kood	1	t
2387	COLUMN	445	nimetus	Laua nimetus	2	t
2388	COLUMN	445	hetke_seisund	Hetkeseisund	3	t
2389	COLUMN	444	laua_seisundi_liik_kood	Laua seisundi liigi kood	1	t
2390	COLUMN	444	seisundi_nimetus	Seisundi nimetus	2	t
2391	COLUMN	444	arv	Seisundis olevate laudade arv	3	t
3343	COLUMN	509	laua_seisundi_liik_nimetus	Laua seisundi liigi nimetus	3	t
3344	COLUMN	509	laua_tyyp_nimetus	Laua tüübi nimetus	4	t
3345	COLUMN	509	reg_aeg	Laua registreerimis aeg	5	t
3346	COLUMN	509	ruumi_tyyp_nimetus	Ruumi tüübi nimetus	6	t
2181	COLUMN	422	teenus	Teenus	1	t
2182	COLUMN	422	teenuse_seisundi_liik	Teenuse seisund	2	t
2183	COLUMN	422	teenus_kood	Teenuse kood	0	t
3347	COLUMN	509	hoone_nimetus	Hoone nimetus	7	t
3348	COLUMN	509	isik_id	Isiku id	8	t
3349	COLUMN	516	laua_seisundi_liik_id	Laua seisundi liigi id	1	t
2195	COLUMN	427	teenus_kood	Teenuse kood	0	t
2196	COLUMN	427	teenus	Nimetus	1	t
2197	COLUMN	427	reg_aeg	Reg aeg	2	t
2198	COLUMN	427	teenuse_hind	Hind	3	t
2199	COLUMN	427	seisund	Seisund	4	t
2200	COLUMN	427	registreerija_e_meil	Registreerija kontakt	5	t
2201	COLUMN	427	registreerija_amet	Registreerija amet	6	t
2202	COLUMN	429	teenuse_seisundi_liik_kood	Teenuse seisundi kood	0	t
2203	COLUMN	429	seisundi_nimetus	Seisundi nimetus	1	t
2204	COLUMN	429	seisundist_olevate_teenuste_arv	Teenuste arv	2	t
2205	COLUMN	425	teenus_kood	Kood	0	t
2206	COLUMN	425	nimetus	Nimetus	1	t
2207	COLUMN	425	hetke_seisundi_nimetus	Seisund	2	t
3350	COLUMN	516	seisundi_nimetus	Laua seisundi liigi nimetus	2	t
3351	COLUMN	516	arv	Laudu kokku selles seisundis	3	t
3352	COLUMN	512	laua_nimetus	Laua nimetus	2	t
3353	COLUMN	512	laud_id	Laua id	1	t
3354	COLUMN	512	laua_seisundi_liik_nimetus	Laua seisundi liigi nimetus	3	t
2743	COLUMN	485	auto_seisundi_liik_kood	Auto seisundi liigi kood	1	t
2744	COLUMN	485	seisundi_nimetus	Seisundi nimetus	2	t
2745	COLUMN	485	auto_arv	Seisundis olevate autode arv	3	t
2746	COLUMN	484	auto_kood	Auto kood	1	t
2217	COLUMN	401	kauba_kood	Kood	5	t
2218	COLUMN	401	nimetus	Nimetus	10	t
2219	COLUMN	401	seisund	Hetkeseisund	15	t
2220	COLUMN	401	kaal	Kaal (kg)	20	t
2221	COLUMN	401	hind	Hind (€)	25	t
2222	COLUMN	401	tuup	Tüüp	30	t
4988	COLUMN	779	parkla_nimetus	Parklakoht	1	t
4989	COLUMN	779	parklakoha_tyybi_nimetus	Parklakoha tüüp	2	t
4990	COLUMN	779	parklakoha_hetke_seisund	Parklakoha seisund	3	t
5106	COLUMN	772	parklakoha_kood	Parklakoha kood	1	t
5107	COLUMN	772	seisund	Seisund	2	t
5108	COLUMN	772	teekate	Teekate	3	t
5109	COLUMN	772	asetus	Asetus	4	t
5110	COLUMN	772	asukoht	Asukoht	5	t
5111	COLUMN	772	parkla	Parkla	6	t
5112	COLUMN	772	laius	Laius (cm)	7	t
2747	COLUMN	484	nimetus	Auto nimetus	2	t
2748	COLUMN	484	hetke_seisund	Hetkeseisund	3	t
2749	COLUMN	484	auto_tyyp	Auto tüüp	4	t
2750	COLUMN	484	kytuse_tyyp	Kütuse tüüp	5	t
2751	COLUMN	484	parkla	Parkla	6	t
2752	COLUMN	484	registreerija	Registreerija	7	t
2753	COLUMN	484	reg_aeg	Registreerimise aeg	8	t
2754	COLUMN	484	hind	Auto hind	9	t
2755	COLUMN	484	auto_kategooriad	Auto kategooriad	10	f
2756	COLUMN	484	kirjeldus	Auto kirjeldus	11	t
2757	COLUMN	484	pildi_aadress	Auto pildi aadress	12	t
2758	COLUMN	487	auto_kood	Auto kood	1	t
2759	COLUMN	487	nimetus	Auto nimetus	2	t
2760	COLUMN	487	hetke_seisund	Hetkeseisund	3	t
2761	COLUMN	487	hind	Auto hind (EUR)	4	t
2762	COLUMN	487	kirjeldus	Auto kirjeldus	5	t
3355	COLUMN	512	laua_tyyp_nimetus	Laua tüübi nimetus	4	t
3356	COLUMN	512	registreerija_id	Laua registreerija id	5	t
3357	COLUMN	512	reg_aeg	Laua registreerimis aeg	6	t
3358	COLUMN	512	e_meil	Isiku e-meil	7	t
2420	COLUMN	460	parklakoha_kood	Parklakoha kood	10	t
2421	COLUMN	460	parkla_kood	Parkla kood	20	t
2422	COLUMN	460	parklakoha_nimetus	Parklakoha nimetus	30	t
2423	COLUMN	460	seisund	Parklakoha hetkeseisund	40	t
2254	COLUMN	434	kauba_kood	Kood	5	t
2255	COLUMN	434	kategooriad	Kategooriad	33	t
2256	COLUMN	434	kaliiber	Kaliiber (mm)	50	t
2257	COLUMN	434	kaal	Kaal (kg)	15	t
2258	COLUMN	434	salve_suurus	Salve suurus (tk)	45	t
2259	COLUMN	434	hind	Hind (€)	20	t
2260	COLUMN	434	sihiku_tuup	Sihiku tüüp	40	t
2261	COLUMN	434	relva_tuup	Relva tüüp	35	t
2262	COLUMN	434	registreerija	Registreerija	30	t
2263	COLUMN	434	nimetus	Nimetus	10	t
2264	COLUMN	434	registreerimise_aeg	Registreerimise aeg	25	t
2265	COLUMN	434	laske_kiirus	Laske kiirus (lask/min)	55	t
2424	COLUMN	460	kommentaar	Kommentaar	50	t
2425	COLUMN	462	seisundi_kood	Seisundi kood	10	t
2426	COLUMN	462	upper	Seisundi nimi	20	t
2427	COLUMN	462	arv	Koguarv	30	t
2779	COLUMN	495	seisundi_nimetus	Laua seisund	1	t
2780	COLUMN	495	arv	Laudade arv	2	t
3315	COLUMN	475	kauba_kood	EAN Kood	11	f
3316	COLUMN	475	reg_aeg	Registreerimise aeg	12	f
3317	COLUMN	475	kaup_kategooria_det	Kategooriad	13	f
3318	COLUMN	475	kaup_id	ID	0	f
3319	COLUMN	475	paritoluriik	Paritoluriik	2	f
3320	COLUMN	475	kirjeldus	Kirjeldus	3	f
3321	COLUMN	475	registreerija	Registreerija	4	f
3322	COLUMN	475	kauba_nimetus	Nimetus	5	f
3323	COLUMN	475	sailivusaeg	Säilivusaega tüüp	6	f
3457	COLUMN	520	seisundi_kood	Seisundi kood	1	t
3458	COLUMN	520	seisundi_nimetus	Nimetus	2	t
3459	COLUMN	520	arv	Arv	3	t
3785	COLUMN	537	kauba_seisundi_nimetus	Seisundi nimetus	2	t
3786	COLUMN	537	kauba_seisundi_kood	Seisundi kood	1	t
4587	COLUMN	605	laua_seisundi_liik_kood	Seisundi liigi kood	0	t
4588	COLUMN	605	laua_seisundi_nimetus	Seisundi nimetus	1	t
4589	COLUMN	605	laudade_arv	Laudade arv	2	t
3837	COLUMN	593	parklakoht_kood	Parklakoht kood	5	t
3838	COLUMN	593	pindala_m2	Parklakoht pindala	10	t
3839	COLUMN	593	hetke_seisund	Hetke seisund	15	t
3840	COLUMN	593	parkimine_tund_hind	Parkimise tunnihind	20	t
3841	COLUMN	593	kommentaar	Kommentaar	25	t
3842	COLUMN	593	parkla	Parkla nimetus	30	t
3843	COLUMN	595	parkimiskoha_kood	Parkimiskoha kood	0	t
3844	COLUMN	595	reg_aeg	Registreerimise aeg	1	t
3517	COLUMN	538	kauba_kood	Kauba kood	1	t
3518	COLUMN	538	kauba_nimetus	Kauba nimetus	2	t
3519	COLUMN	538	kauba_hetkeseisund	Kauba hetkeseisund	3	t
3520	COLUMN	538	ostu_hind_km_ta	Ostuhind km-ta	4	t
3521	COLUMN	538	kauba_tyyp	Kauba tüüp	5	t
4643	COLUMN	673	parkimiskoha_kood	Parkimiskoha kood	1	t
4644	COLUMN	673	nimetus	Parkimisplatsi nimetus	2	t
4645	COLUMN	673	reg_aeg	Registreerimise aeg	3	t
4646	COLUMN	673	laius	Laius(cm)	4	t
4647	COLUMN	673	pikkus	Pikkus(cm)	5	t
3845	COLUMN	595	hetkeseisund	Seisund	2	t
3846	COLUMN	595	aadress	Aadress	4	t
3847	COLUMN	595	parkimisplats	Parkimisplats	5	t
4648	COLUMN	673	kategooria_tyybiga	Kategooriad	6	t
4671	COLUMN	625	parklakoha_kategooriad	Parklakoha kategooriad	7	f
4672	COLUMN	625	parklakoht_kood	Kood	2	t
4673	COLUMN	625	seisund	Seisund	3	t
4674	COLUMN	625	kulumus	Kulumus	4	t
4675	COLUMN	625	parkla_aadress	Parkla Aadress	1	t
4676	COLUMN	625	pikkus	Pikkus (m)	5	t
4677	COLUMN	625	laius	Laius (m)	6	t
4678	COLUMN	625	kommentaar	Kommentaar	8	t
3861	COLUMN	596	seisund	Parklakoha seisund	10	t
3862	COLUMN	596	arv	Parklakohtade arv seisundis	20	t
3863	COLUMN	596	seisundi_kood	Parklakoha seisundi kood	30	t
3575	COLUMN	554	auto_seisundi_liik_kood	Seisundi kood	1	t
3576	COLUMN	554	seisundi_nimetus	Seisund	2	t
3577	COLUMN	554	seisundis_autode_arv	Seisundis autode arv	3	t
3787	COLUMN	544	kauba_tyyp	Kauba tüüp	6	t
4596	COLUMN	668	teenuse_yhik	Teenuse ühik	60	t
4597	COLUMN	668	hinnavahemiku_lopp	Hinnavahemiku lõpp	50	t
3788	COLUMN	544	myygi_hind_km_ta	Müügihind km-ta	5	t
3789	COLUMN	544	ostu_hind_km_ta	Ostuhind km-ta	4	t
3790	COLUMN	544	kauba_hetkeseisund	Kauba hetkeseisund	3	t
3791	COLUMN	544	kauba_nimetus	Kauba nimetus	2	t
3792	COLUMN	544	kauba_kood	Kauba kood	1	t
3793	LINK	544	\N	Vaata detaile	7	t
3616	COLUMN	557	auto_kood	Kood	1	t
3617	COLUMN	557	auto_nimetus	Nimetus	2	t
3618	COLUMN	557	mudel	Mudel	4	t
3619	COLUMN	557	mark	Mark	3	t
3620	COLUMN	557	valjalaske_aasta	Väljalaskeaasta	5	t
3621	COLUMN	557	reg_number	Registreerimisnumber	6	t
3622	COLUMN	557	vin_kood	VIN kood	7	t
3623	COLUMN	557	hetkeseisund	Seisund	8	t
3624	LINK	557	\N	Detailid	9	t
3628	COLUMN	545	treeningu_kood	Kood	1	t
3629	COLUMN	545	treeningu_nimetus	Nimetus	2	t
3630	COLUMN	545	treeningu_seisundi_liik_nimetus	Seisund	3	t
3631	LINK	545	\N	Detailvaade	4	t
4393	COLUMN	569	teenus_kood	Teenuse kood	1	t
4394	COLUMN	569	teenus_nimetus	Teenuse nimetus	2	t
4395	COLUMN	569	teenus_hetkeseisund	Teenuse hetkeseisund	3	t
4403	LINK	565	\N	Vaata detailid	6	t
3637	COLUMN	561	auto_kood	Kood	1	t
3638	COLUMN	561	hetkeseisund	Seisund	3	t
3639	COLUMN	561	auto_nimetus	Nimetus	2	t
3640	COLUMN	549	treeningu_kood	Kood	0	t
3641	COLUMN	549	treeningu_nimetus	Nimetus	1	t
3642	COLUMN	549	treeningu_hetke_seisund	Hetkeseisund	2	t
3643	COLUMN	549	raskusaste	Raskusaste	3	t
3644	COLUMN	549	reg_aeg	Registreerimise aeg	4	t
3645	COLUMN	549	registreerija	Registreerija	5	t
3646	COLUMN	549	kalorite_arv	Keskmised kalorid	6	t
3647	COLUMN	549	tutvustus	Tutvustus	7	t
3648	COLUMN	549	treeningu_kategooria	Kategooria	8	t
4404	COLUMN	565	teenus_nimetus	Nimetus	1	t
4405	COLUMN	565	teenus_kood	Teenuse kood	0	t
4406	COLUMN	565	teenus_hind	Hind KM-ga	3	t
4407	COLUMN	565	teenus_kommentaar	Kommentaar	5	t
4408	COLUMN	565	teenuse_osutamise_saal	Teenuse osutamise saal	4	t
4409	COLUMN	565	teenus_hetkeseisund	Hetkeseisund	2	t
4418	COLUMN	22	person_who_registered	Registreerija	40	t
4419	COLUMN	22	registration_time	Registreerimise aeg	35	t
4420	COLUMN	22	current_state	Hetkeseisund	30	t
4421	COLUMN	22	minimal_night_price	Minimaalne öö hind  (EUR)	20	t
4422	COLUMN	22	night_price	Öö hind (EUR)	25	t
4423	COLUMN	22	bed_type_name	Voodi tüüp	15	t
4424	COLUMN	22	room_name	Toa nimi	10	t
4425	COLUMN	22	room_code	Toa kood	5	t
5091	COLUMN	792	asetus	Asetus	7	t
3703	COLUMN	572	teenuse_seisundi_liik_kood	Seidundi liik kood	0	t
3704	COLUMN	572	teenuse_seisundi_liik_nimetus	Nimetus	1	t
3705	COLUMN	572	teenuste_arv	Arv	2	t
4504	COLUMN	567	teenus_kategooriad	Kategooriad	8	f
3738	COLUMN	574	treeningu_seisundi_nimetus	Seisund	3	t
3739	COLUMN	574	treeningu_nimetus	Nimetus	2	t
3740	COLUMN	574	treeningu_kood	Kood	1	t
4505	COLUMN	567	teenus_hetkeseisund	Hetkeseisund	2	t
4506	COLUMN	567	teenuse_osutamise_saal	Teenuse osutamise saal	4	t
4507	COLUMN	567	teenus_registreerija	Teenuse registreerija	6	t
4508	COLUMN	567	teenus_registreerimise_aeg	Registreerimise aeg	7	t
4509	COLUMN	567	teenus_kommentaar	Kommentaar	5	t
4510	COLUMN	567	teenus_hind	Hind KM-ga	3	t
4511	COLUMN	567	teenus_nimetus	Nimetus	1	t
4512	COLUMN	567	teenus_kood	Teenuse kood	0	t
4525	COLUMN	658	laua_kood	Laua kood	1	t
4526	COLUMN	658	asukoht	Laua asukoht	2	t
3771	COLUMN	579	kauba_omadused	Kauba omadused	10	f
3772	COLUMN	579	kauba_kategooriad	Kauba kategooriad	9	f
3773	COLUMN	579	kauba_variandid	Kauba variandid	8	f
3774	COLUMN	579	kauba_tyyp_nimetus	Kauba tüüp	7	t
3775	COLUMN	579	registreerija	Registreerija	12	f
3776	COLUMN	579	reg_aeg	Registreerimisaeg	11	t
3777	COLUMN	579	materjali_nimetus	Materjal	6	t
3778	COLUMN	579	brandi_nimetus	Bränd	5	t
3779	COLUMN	579	kauba_seisundi_liik_nimetus	Kauba hetkeseisund	4	t
3780	COLUMN	579	ostu_hind_km_ta	Ostu hind km-ta	3	t
3781	COLUMN	579	myygi_hind_km_ta	Müügi hind km-ta	2	t
3782	COLUMN	579	kauba_nimetus	Kauba nimetus	1	t
3783	COLUMN	579	kauba_kood	Kauba kood	0	t
4598	COLUMN	668	hinnavahemiku_algus	Hinnavahemiku algus	40	t
4599	COLUMN	668	hetke_seisund	Teenuse seisund	30	t
4600	COLUMN	668	teenus_nimetus	Nimetus	20	t
4601	COLUMN	668	teenus_kood	Teenuse kood	10	t
4131	COLUMN	631	parklakoht_kood	Parklakoha seisundi kood	10	t
4132	COLUMN	631	parkla	Parkla nimi	20	t
4133	COLUMN	631	hetke_seisund	Parklakoha seisund	30	t
4631	COLUMN	670	kategooria_tyybiga	Kategooriad	6	t
4632	COLUMN	670	pikkus	Pikkus (cm)	5	t
4374	LINK	623	\N	Detailid	5	t
4375	COLUMN	623	parklakoht_kood	Kood	2	t
4376	COLUMN	623	seisund	Seisund	3	t
4377	COLUMN	623	kulumus	Kulumus	4	t
4378	COLUMN	623	parkla_aadress	Parkla Aadress	1	t
4633	COLUMN	670	laius	Laius (cm)	4	t
4634	COLUMN	670	reg_aeg	Registreerimise aeg	3	t
4635	COLUMN	670	nimetus	Parkimisplatsi nimetus	2	t
3906	COLUMN	581	teenus_nimetus	Nimetus	20	t
3907	COLUMN	581	hetke_seisund	Hetke seisund	30	t
3908	COLUMN	581	hinnavahemiku_algus	Hinnavahemiku algus	40	t
3909	COLUMN	581	hinnavahemiku_lopp	Hinnavahemiku lõpp	50	t
3910	COLUMN	581	teenuse_yhik	Teenuse ühik	60	t
3911	COLUMN	581	teenus_kood	Teenuse kood	10	t
4636	COLUMN	670	parkimiskoha_kood	Parkimiskoha kood	1	t
4426	COLUMN	37	room_state_type	Toa seisund	10	t
4427	COLUMN	37	room_count	Tubade arv seisundis	20	t
4428	COLUMN	37	room_state_type_code	Toa seisundi kood	0	t
5065	COLUMN	790	kauba_kood	Kauba kood	0	t
5066	COLUMN	790	kauba_nimetus	Nimetus	1	t
3929	COLUMN	604	laua_kood	Laua kood	0	t
3930	COLUMN	604	laua_seisundi_liik_nimetus	Seisund	1	t
3931	COLUMN	604	restorani_nimi	Restoran	2	t
3932	COLUMN	604	kohtade_arv	Kohtade arv	3	t
3933	COLUMN	604	laua_teenindamise_liik_nimetus	Teenindamise liik	4	t
3934	COLUMN	604	kommentaar	Kommentaar	5	t
5067	COLUMN	790	kauba_hind	Hind	2	t
5068	COLUMN	790	brand_kood	Brandi kood	3	t
5069	COLUMN	790	registreerija_e_meil	reg email	4	t
5070	COLUMN	790	kaup_kirjeldus	Kirjeldus	5	t
5071	COLUMN	790	kauba_pildi_aadress	Pildi aadress	6	t
3941	COLUMN	612	hetke_seisund	Teenuse seisund	30	t
3942	COLUMN	612	teenuse_yhik	Teenuse ühik	60	t
3943	COLUMN	612	hinnavahemiku_lopp	Hinnavahemiku lõpp	50	t
3944	COLUMN	612	hinnavahemiku_algus	Hinnavahemiku algus	40	t
3945	COLUMN	612	teenus_nimetus	Nimetus	20	t
3946	COLUMN	612	teenus_kood	Teenuse kood	10	t
3948	COLUMN	615	seisundi_nimetus	Teenuse seisund	10	t
3949	COLUMN	615	arv	Teenuse arv seisundis	20	t
3952	COLUMN	620	arv	Kogus	2	t
3953	COLUMN	620	seisundi_nimetus	Seisund	0	t
3954	COLUMN	620	treeningu_seisundi_liik_kood	Kood	1	t
5092	COLUMN	792	asukoht	Asukoht	6	t
5093	COLUMN	792	parkla_nimi	Parkla	5	t
5094	COLUMN	792	seisund	Seisund	2	t
5095	COLUMN	792	pikkus	Pikkus (cm)	4	t
5096	COLUMN	792	laius	Laius (cm)	3	t
5097	COLUMN	792	parklakoha_kood	Parklakoha kood	1	t
5113	COLUMN	772	pikkus	Pikkus (cm)	8	t
5114	COLUMN	772	kategooriad	Kategooriad	9	f
4241	COLUMN	639	kategooriad_tyypidega	Kategooriad	5	t
4242	COLUMN	639	kommentaar	Kommentaar	4	t
4243	COLUMN	639	kohtade_arv	Kohtade arv	3	t
4244	COLUMN	639	restorani_nimi	Restoran	2	t
4245	COLUMN	639	laua_seisund	Seisund	1	t
4246	COLUMN	639	laua_kood	Kood	0	t
4247	COLUMN	639	reg_aeg	Reg. aeg	6	t
4248	COLUMN	639	reg_tootaja_e_meil	Reg. e-meil	9	t
4249	COLUMN	639	reg_tootaja_perenimi	Reg. perenimi	8	t
4250	COLUMN	639	reg_tootaja_eesnimi	Reg. eesnimi	7	t
4251	COLUMN	641	kategooriad_tyypidega	Kategooriad	0	t
4284	COLUMN	635	seisundi_nimetus	Parklakoha seisund	10	t
4285	COLUMN	635	arv	Parklakohtade arv seisundis	20	t
4296	COLUMN	560	reg_number	Registreerimisnumber	9	t
4297	COLUMN	560	hetkeseisund	Seisund	12	t
4298	COLUMN	560	valjalaske_aasta	Väljalaskeaasta	5	t
4299	COLUMN	560	vin_kood	VIN kood	10	t
4300	COLUMN	560	kytuse_liik	Kütuse liik	8	t
4301	COLUMN	560	reg_aeg	Registreerimise aeg	13	t
4302	COLUMN	560	istekohtade_arv	Istekohtade arv	6	t
4303	COLUMN	560	registreerija	Registreerija	14	t
4304	COLUMN	560	mootori_maht	Mootorimaht	7	t
4305	COLUMN	560	mudel	Mudel	4	t
4306	COLUMN	560	mark	Mark	3	t
4307	COLUMN	560	auto_nimetus	Nimetus	2	t
4308	COLUMN	560	auto_kood	Kood	1	t
4309	COLUMN	560	auto_kategooria	Auto kategooria(d)	11	t
4527	COLUMN	658	laua_seisund	Laua seisund	3	t
4604	COLUMN	663	registreerija	Parkimiskoha registreerija	7	t
4605	COLUMN	663	pikkus	Parkimiskoha pikkus(cm)	6	t
4606	COLUMN	663	laius	Parkimiskoha laius(cm)	5	t
4607	COLUMN	663	hetkeseisund	Parkimiskoha hetkeseisund	4	t
4608	COLUMN	663	parkimisplatsi_aadress	Parkimisplatsi aadress	3	t
4609	COLUMN	663	parkimisplatsi_nimetus	Parkimiskoha nimetus	2	t
4610	COLUMN	663	parkimiskoha_kood	Parkimiskoha kood	1	t
4537	COLUMN	660	laua_materjal	Laua materjal	9	t
4538	COLUMN	660	kommentaar	Kommentaar	8	t
4539	COLUMN	660	laua_seisund	Laua seisund	7	t
4540	COLUMN	660	kohtade_arv	Kohtade arv	6	t
4541	COLUMN	660	asukoha_kirjeldus	Laua asukoht	5	t
4542	COLUMN	660	e_meil	E-mail	4	t
4543	COLUMN	660	registreerija	Registreerija	3	t
4544	COLUMN	660	reg_aeg	Registreerimise aeg	2	t
4545	COLUMN	660	laua_kood	Laua kood	1	t
4611	COLUMN	663	kategooriad	Kategooriad	8	t
4679	COLUMN	625	registreerimise_aeg	Registreerimise aeg	9	t
4680	COLUMN	625	registreerija	Registreerija	10	t
4686	COLUMN	683	prooviruum_seisund_liik_kood	Seisundi kood	0	t
4687	COLUMN	683	seisundi_nimetus	Seisundi nimetus	1	t
4688	COLUMN	683	arv	Kogus	2	t
4708	COLUMN	686	arv	Parklakohtade arv	3	t
4709	COLUMN	686	parklakoha_seisund_nimetus	Seisundi nimi	2	t
4710	COLUMN	686	parklakoha_seisund_kood	Seisundi kood	1	t
4719	COLUMN	702	parklakoha_seisund_kood	Seisundi kood	1	t
4720	COLUMN	702	parklakoha_seisund_nimetus	Seisundi nimi	2	t
4721	COLUMN	702	arv	Parklakohtade arv	3	t
4722	COLUMN	703	prooviruumi_kood	Prooviruumi kood	0	t
4723	COLUMN	703	prooviruumi_nimetus	Prooviruumi kood	1	t
4724	COLUMN	703	prooviruumi_seisund	Seisund	2	t
4725	COLUMN	703	reg_aeg	Registreerimise aeg	3	t
4731	COLUMN	707	parklakoht_kood	Parklakoha kood	1	t
4732	COLUMN	707	parkla_kood	Parkla kood	2	t
4733	COLUMN	707	aadress	Parkla aadress	3	t
4734	COLUMN	707	suurus	Suurus	4	t
4735	COLUMN	707	kommentaar	Kommentaar	5	t
4736	COLUMN	707	seisund	Seisund	6	t
4754	COLUMN	682	hetke_seisund	Seisund	4	t
4755	COLUMN	682	võimekus	Prooviruumi võimekus	3	t
4756	COLUMN	682	nimetus	Hoone	2	t
4757	COLUMN	682	prooviruumi_nimetus	Prooviruumi nimetus	1	t
4758	COLUMN	682	prooviruumi_kood	Prooviruumi kood	0	t
4759	LINK	682	\N	Detailid	5	t
4760	COLUMN	713	prooviruumi_kood	Kood	0	t
4761	COLUMN	713	prooviruumi_nimetus	Prooviruum	1	t
4762	COLUMN	713	nimetus	Hoone	2	t
4763	COLUMN	713	hetke_seisund	Seisund	3	t
4764	COLUMN	713	voimekus	Võimekus	4	t
4765	COLUMN	713	registreerija	Registreerija	5	t
4766	COLUMN	713	reg_aeg	Registreerimise aeg	6	t
4767	COLUMN	713	kategooria_tyybiga	Kategooriad	7	t
4768	COLUMN	711	parkla_kood	Parkla kood	2	t
4769	COLUMN	711	parklakoht_kood	Parklakoha kood	1	t
4770	COLUMN	711	aadress	Parkla aadress	3	t
4771	COLUMN	711	suurus	Suurus	4	t
4772	COLUMN	711	kommentaar	Kommentaar	5	t
4773	COLUMN	711	seisund	Seisund	6	t
4774	COLUMN	697	parklakoht_kood	Parklakoha kood	1	t
4775	COLUMN	697	parkla_kood	Parkla kood	2	t
4776	COLUMN	697	aadress	Parkla aadress	3	t
4777	COLUMN	697	suurus	Suurus	4	t
4778	COLUMN	697	seisund	Seisund	5	t
4792	COLUMN	715	registreerija	Registreerija	8	t
4793	COLUMN	715	seisund	Seisund	10	t
4794	COLUMN	715	reg_aeg	Registreerimise aeg	9	t
4795	COLUMN	715	kommentaar	Kommentaar	7	t
4796	COLUMN	715	laius	Laius	6	t
4797	COLUMN	715	pikkus	Pikkus	5	t
4798	COLUMN	715	suurus	Suurus	4	t
4799	COLUMN	715	aadress	Parkla aadress	3	t
4800	COLUMN	715	parkla_kood	Parkla kood	2	t
4801	COLUMN	715	parklakoht_kood	Parklakoha kood	1	t
4802	COLUMN	715	kategooria	Kategooria	11	f
4803	COLUMN	654	laua_seisund	Laua seisund	2	t
4804	COLUMN	654	asukoha_kirjeldus	Laua asukoht	1	t
4805	COLUMN	654	laua_kood	Laua kood	0	t
4809	COLUMN	719	laua_kood	Laua kood	1	t
4810	COLUMN	719	asukoht	Laua asukoht	2	t
4811	COLUMN	719	laua_seisund	Laua seisund	3	t
4812	COLUMN	633	kulumus	Kulumus	4	t
4813	COLUMN	633	parkla_aadress	Parkla Aadress	1	t
4814	COLUMN	633	seisund	Seisund	3	t
4815	COLUMN	633	parklakoht_kood	Kood	2	t
4976	COLUMN	776	ekraani_resolutsiooni_nimetus	Resulutsioon	2	t
4977	COLUMN	776	on_sormejaljelugeja	Sõrmejäljelugeja	1	t
4978	COLUMN	776	kauba_nimetus	Kauba kood	0	t
4979	COLUMN	776	sisemalu_nimetus	Sisemälu	3	t
4980	COLUMN	776	protsessori_nimetus	Protsessor	5	t
4981	COLUMN	776	on_veekindel	Veekindel	6	t
4982	COLUMN	776	tagumise_kaamera_nimetus	T Kaamera	7	t
4983	COLUMN	776	eesmise_kaamera_nimetus	E Kaamera	8	t
4848	COLUMN	666	parkimiskoha_seisundi_liigi_kood	Seisundi kood	1	t
4849	COLUMN	666	arv	Parkimiskohtade arv	3	t
4850	COLUMN	666	nimetus	Seisund	2	t
4851	COLUMN	669	arv	Arv	3	t
4852	COLUMN	669	nimetus	Nimetus	2	t
4853	COLUMN	669	parkimiskoha_seisundi_liigi_kood	Seisundi liigi kood	1	t
5052	COLUMN	781	parklakoha_kategooriad	Seotud kategooriad	8	f
5053	COLUMN	781	parklakoha_kood	Parklakoha kood	1	t
4875	COLUMN	649	laua_seisundi_liik_kood	Laua seisundi liigi kood	0	t
4876	COLUMN	649	seisund	Seisundi nimetus	1	t
4877	COLUMN	649	laudade_arv	Laudade arv seisundis	2	t
4887	COLUMN	752	parklakoha_seisundi_liik_kood	Parklakoha seisundi kood	1	t
4888	COLUMN	752	parklakoha_seisundi_nimetus	Parklakoha seisundi nimetus	2	t
4889	COLUMN	752	arv	Arv	3	t
5054	COLUMN	781	parkla_nimetus	Parkla nimetus	2	t
5055	COLUMN	781	aadress	Parkla aadress	3	t
5056	COLUMN	781	reg_aeg	Registreerimise aeg	9	t
5057	COLUMN	781	registreerija	Registreerija	10	t
5058	COLUMN	781	parklakoha_suurus	Parklakoha suurus	4	t
5059	COLUMN	781	kommentaar	Kommentaar	5	t
5060	COLUMN	781	parklakoha_tyybi_nimetus	Parklakoha tüüp	6	t
5061	COLUMN	781	parklakoha_hetke_seisund	Parklakoha seisund	7	t
5062	COLUMN	781	koht_horedas_pingereas	Koht pingereas	0	t
5098	COLUMN	774	parklakoha_kood	Parklakoha kood	1	t
4900	COLUMN	727	kauba_kood	Kood	2	t
4901	COLUMN	727	kauba_nimetus	Nimetus	0	t
4902	COLUMN	727	kaup_kirjeldus	Kirjeldus	1	t
4903	COLUMN	727	brand	Brand	3	t
4904	COLUMN	727	reg_aeg	Reg aeg	4	t
4905	COLUMN	727	kauba_hind	Hind	5	t
4906	COLUMN	727	registreerija_e_meil	emeil	9	t
4907	COLUMN	727	kauba_pildi_aadress	pilt	6	t
4908	COLUMN	727	registeerija_eesnimi	Eesnimi	7	t
4909	COLUMN	727	registeerija_perenimi	Perenimi	8	t
5099	COLUMN	774	laius	Laius (cm)	3	t
5100	COLUMN	774	pikkus	Pikkus (cm)	4	t
5101	COLUMN	774	seisund	Seisund	2	t
5102	COLUMN	774	asukoht	Asukoht	5	t
5103	COLUMN	774	asetus	Asetus	6	t
5104	COLUMN	774	parkla_nimi	Parkla	7	t
5105	COLUMN	774	kommentaar	Kommentaar	8	t
5115	COLUMN	772	reg_aeg	Registreerimise aeg	10	t
5116	COLUMN	772	registreerija_nimi	Registreerija	11	t
5117	COLUMN	772	kommentaar	Kommentaar	12	t
5118	COLUMN	794	kauba_nimetus	Nimetus	1	t
5119	COLUMN	794	kauba_kood	Kauba kood	0	t
5120	COLUMN	794	kauba_kirjeldus	Kirjeldus	2	t
5121	COLUMN	794	kauba_hind	Hind	3	t
5122	COLUMN	794	kauba_brand	Brand	4	t
5123	COLUMN	794	reg_aeg	reg aeg	5	t
5124	COLUMN	795	kauba_kood	Kauba kood	0	t
5125	COLUMN	795	kauba_nimetus	Nimetus	1	t
5126	COLUMN	795	kauba_kirjeldus	Kirjeldus	2	t
5127	COLUMN	795	kauba_hind	Hind	3	t
5128	COLUMN	795	kauba_brand	Brand	4	t
5129	COLUMN	795	reg_aeg	Reg aeg	5	t
5140	COLUMN	522	hind	Müügihind (EUR, maksudeta)	4	t
5141	COLUMN	522	kauba_tyyp	Tyyp	3	t
5142	COLUMN	522	seisund	Seisund	2	t
5143	COLUMN	522	kauba_nimetus	Nimetus	1	t
5144	COLUMN	522	kauba_kood	Kauba kood	0	t
5155	COLUMN	524	kirjeldus	Kirjeldus	3	t
5156	COLUMN	524	suurus	Suurus (toll)	5	t
5157	COLUMN	524	registreerija	Registreerija	9	t
5158	COLUMN	524	varv	Varv	6	t
5159	COLUMN	524	kauba_tyyp	Tyyp	7	t
5160	COLUMN	524	kauba_nimetus	Nimetus	2	t
5161	COLUMN	524	materjal	Materjal	8	t
5162	COLUMN	524	kauba_kood	Kauba kood	1	t
5163	COLUMN	524	hind	Müügihind (EUR, maksudeta)	4	t
5164	COLUMN	524	registreerimisaeg	Registreerimise aeg	10	t
\.


--
-- Data for Name: report_column_link; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.report_column_link (report_column_link_id, report_column_id, url, link_text, attributes) FROM stdin;
5	42	&APPLICATION_ROOT&/app/&APPLICATION_ID&/change_room?p_room_code_old=%room_code%	%room_name%	class="btn btn-primary"
18	964	&APPLICATION_ROOT&/app/&APPLICATION_ID&/kinnitus?kauba_kood=%kood%	Kustuta	class="btn btn-primary"
32	2305	&APPLICATION_ROOT&/app/&APPLICATION_ID&/151	Detailid	\N
58	3268	&APPLICATION_ROOT&/app/&APPLICATION_ID&/210	Detailid	\N
69	3624	&APPLICATION_ROOT&/app/&APPLICATION_ID&/256	Detailid	\N
70	3631	&APPLICATION_ROOT&/app/&APPLICATION_ID&/251?p_treeningu_kood=%treeningu_kood%	Detailvaade	\N
75	3793	http://apex.ttu.ee/pgapex/public/index.php/app/79/245	Vaata detaile	\N
95	4374	http://apex.ttu.ee/pgapex/public/index.php/app/90/288	vaata	\N
97	4403	&APPLICATION_ROOT&/app/&APPLICATION_ID&/260	Vaata detailid	\N
98	4759	&APPLICATION_ROOT&/app/&APPLICATION_ID&/250	Detailid	\N
\.


--
-- Data for Name: report_column_type; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.report_column_type (report_column_type_id) FROM stdin;
LINK
COLUMN
\.


--
-- Data for Name: report_region; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.report_region (region_id, template_id, schema_name, view_name, items_per_page, show_header) FROM stdin;
16	6	public	active_temporariliy_inactive_rooms	2	t
242	6	public	kaubad_koondaruanne	15	t
28	6	public	active_temporariliy_inactive_rooms	15	t
64	6	public	kaubad_ulevaade	15	t
4	6	public	number_of_rooms_by_state	2	t
73	6	public	vaade_koik_kaubad	15	t
247	6	raamatupood	trykiste_detailid	15	t
92	6	public	koik_teenused	15	t
184	6	public	kaupade_lopetamine	15	t
48	6	public	koik_kaubad	15	t
188	6	public	koondaruanne	15	t
195	6	public	lopetatavad_raamatud	15	t
260	6	public	koikide_radade_list	15	t
71	6	public	vaade_kaupade_koondaruanne	15	t
61	6	public	kuva_otseturundusega_noustunud_klientide_andmed	20	t
266	6	public	lopeta_rada	15	t
56	6	public	toodete_koondaruanne	15	t
263	6	public	unusta_rada	15	t
259	6	public	radade_aruanne	15	t
200	6	public	koondaruanne	15	t
100	6	public	koik_kaubad	15	t
81	6	public	koondaruanne_kaubad	15	t
85	6	public	aktiivsed_mitteaktiivsed_kaubad	15	t
206	6	public	raamatute_info	15	t
181	6	public	koondaruanne	15	t
190	6	public	koik_raamatud	15	t
157	6	public	koik_treeningud	15	t
201	6	public	lopetatavad_kaubad	15	t
208	6	public	koik_kaubad	15	t
257	6	public	piletid_kasutamiseks	15	t
88	6	public	teenuste_liigiti_koondaruanne	15	t
270	6	public	koik_kaubad	15	t
273	6	public	aktiivsed_voi_mitteaktiivsed_kaubad	20	t
274	6	public	kauba_koondaruanne	15	t
213	6	public	kaup_aruanne	15	t
217	6	public	tootaja_aruanne	15	t
220	6	public	kaup_detailid	15	t
223	6	public	kaup_aktiivne_mitteaktiivne	15	t
3	6	public	overview_of_rooms	2	t
234	6	public	treeningute_koondaruanne	15	t
179	6	public	kaubad_lopetamiseks	15	t
281	6	public	pilt_vaatamine	15	t
362	6	public	koik_kaubad	15	t
76	6	public	lopeta_toode	15	t
365	6	public	kauba_detailvaade	15	t
309	6	public	kauba_koondaruanne	15	t
405	6	public	kauba_seisundi_liik_kaup	15	t
52	6	public	vaata_koiki_tooteid	20	t
352	6	public	kauba_koondaruanne	15	t
427	6	public	teenuste_yksikasjad	15	t
312	6	public	kauba_aktiivne_voi_mitteaktiivne	15	t
337	6	public	kaupade_koondaruanne	15	t
333	6	public	aktiivsed_mitteaktiivsed_kaubad	15	t
308	6	public	kauba_yldine	15	t
326	6	public	aktiivsed_mitteaktiivsed_kaubad	15	t
331	6	public	koik_kaubad	15	t
382	6	public	aktiivsed_mitteaktiivsed_kaubad	15	t
383	6	public	kaubade_koondaruanne	15	t
429	6	public	teenuste_koondaruanne	15	t
425	6	public	aktiivsed_mitteaktiivsed_teenused	15	t
390	6	public	rooms_by_state	15	t
412	6	public	v_kaupade_koondaruanne	15	t
60	6	public	kuva_detailandmed	20	t
401	6	public	kaup_koik	15	t
293	6	public	v_aktiivsed_mitteaktiivsed_parkimiskohad	15	t
392	6	public	koik_kaubad	15	t
403	6	public	kaup_aktiivne_mitteaktiivne	15	t
391	6	public	kauba_pohjalikud_detailid	15	t
395	6	public	kauba_detailid	1	t
369	6	public	kaubade_detailid	15	t
286	6	public	v_parkimiskohtade_koondaruanne	5	t
434	6	public	kaup_detailvaade	15	t
460	6	public	parklakohad_lopetamiseks	15	t
422	6	public	koik_teenused	15	t
462	6	public	parklakohtade_koondaruanne	15	t
437	6	public	hooaja_etendus_vaade	15	t
386	6	public	kaupade_koondaruanne	15	t
323	6	public	kaupade_detailid	15	t
321	6	public	koik_kaubad	15	t
414	6	public	v_lopetatavad_kaubad	15	t
413	6	public	v_kaupade_ulevaade	15	t
443	6	public	laudade_detailid	15	t
445	6	public	aktiivsed_voi_mitteaktiivsed_lauad	15	t
444	6	public	laudade_koondaruanne	15	t
454	6	public	kaup_aktiivne_voi_mitteaktiivne	15	t
456	6	public	parklakohtade_nimekiri_seisundiliikidega	15	t
451	6	public	kaup_aruanne	15	t
464	6	public	parklakoha_tapsem_vaade	15	t
447	6	public	kaup_detail	15	t
292	6	public	v_koik_parkimiskohad	50	t
485	6	public	auto_koondaruanne	15	t
484	6	public	koik_autod	15	t
487	6	public	aktiivsed_voi_mitteaktiivsed_autod	15	t
495	6	public	koondaruanne	15	t
490	6	public	koik_lauad	15	t
466	6	public	kaupade_lopitamine	15	t
475	6	public	kaupade_detailid_koos_kategooriatega	15	t
465	6	public	kaupade_koondaruanne	15	t
469	6	public	koik_kaubad	15	t
497	6	public	aktiivsed_voi_mitteaktiivsed_lauad	15	t
507	6	public	aktiivsed_lauad	15	t
517	6	public	laudade_kategooriate_omamiste_alamparingud	15	t
509	6	public	koik_lauad	15	t
516	6	public	laudade_seisundite_koondaruanded	15	t
512	6	public	aktiivsed_mitteaktiivsed_lauad	15	t
37	6	public	number_of_rooms_by_state	15	t
520	6	public	mv_kaupade_koondaruanne	15	t
531	6	public	parklakohtade_koondaruanne	15	t
525	6	public	mv_aktiivsed_mitteaktiivsed_kaubad	15	t
620	6	public	treeningute_koondaruanne	15	t
670	6	public	aktiivsed_mitteaktiivsed_parkimiskohad	30	t
538	6	public	aktiivsed_mitteaktiivsed_kaubad	15	t
673	6	public	ootel_parkimiskohad	15	t
669	6	public	parkimiskohtade_koondaruanne	10	t
625	6	public	parklakohtade_detailid	15	t
623	6	public	koik_parklakohad	15	t
554	6	public	autode_koondaruanne	30	t
569	6	public	koik_mitteaktiivsed_ja_aktiivsed_teenused	15	t
557	6	public	koik_autod	30	t
545	6	public	treeningute_ylevaade	15	t
565	6	public	koik_teenused	15	t
561	6	public	aktiivsed_mitteaktiivsed_autod	30	t
549	6	public	treeningute_detailid	15	t
22	6	public	overview_of_rooms	15	t
683	6	public	prooviruumide_koondaruanne	15	t
572	6	public	teenuste_koondaruanne	15	t
649	6	public	laud_koondaruanne	15	t
686	6	public	parklakohtade_koondaruanne	15	t
574	6	public	aktiivsed_mitteaktiivsed_treeningud	15	t
579	6	public	detailsed_kaubad	15	t
537	6	public	koikide_kaupade_seisundid	15	t
544	6	public	koik_kaubad	15	t
567	6	public	teenuste_detailid	15	t
631	6	public	aktiivsed_mitteaktiivsed_parklakohad	15	t
593	6	public	koik_parklakohad	15	t
595	6	public	koik_parkimiskohad	15	t
702	6	public	parklakohtade_koondaruanne	15	t
596	6	public	parklakohtade_koondaruanne	15	t
581	6	public	koik_teenused	15	t
604	6	public	aktiivsed_mitteaktiivsed_lauad	15	t
612	6	public	aktiivsed_mitteaktiivsed_teenused	15	t
615	6	public	teenuste_koondaruanne	15	t
703	6	public	aktiivsed_mitteaktiivsed_prooviruumid	15	t
658	6	public	laud_ootel_mitteaktiivne	15	t
660	6	public	laud_detailid	15	t
707	6	public	koik_parklakohad	15	t
639	6	public	laudade_detailvaade_kategooriatega	50	t
641	6	public	laudade_detailvaade_kategooriatega	15	t
752	6	public	parklakohtade_koondaruanne	15	t
635	6	public	parklakohtade_koondaruanne	15	t
781	6	public	parklakohtade_detailid_kategooriatega	15	t
560	6	public	autode_detailid	30	t
727	6	public	koik_kaubad_v	15	t
682	6	public	koik_prooviruumid	15	t
605	6	public	laudade_koondaruanne	30	t
668	6	public	aktiivsed_mitteaktiivsed_teenused	15	t
663	6	public	parkimiskoha_detailid	29	t
713	6	public	prooviruumide_detailid	15	t
711	6	public	koik_parklakohad	15	t
697	6	public	lopetatavad_parklakohad	15	t
715	6	public	parklakoha_detailid	15	t
654	6	public	laud_koik_seisundid	15	t
719	6	public	laud_aktiivne_mitteaktiivne	15	t
633	6	public	aktiivsed_mitteaktiivsed_parklakohad	15	t
790	6	public	koik_kaubad_v	15	t
666	6	public	parkimiskohtade_koondaruanne	30	t
769	6	public	parklakohtade_koondaruanne	15	t
776	6	public	nutitelefonid_v	15	t
778	6	public	koik_parklakohad	10	t
779	6	public	aktiivsed_mitteaktiivsed_parklakohad	15	t
792	6	public	koik_parklakohad	15	t
774	6	public	lopetatavad_parklakohad	15	t
772	6	public	parklakoha_detailvaade	15	t
794	6	public	ootel_kaubad_v	15	t
795	6	public	aktiveeritavad_kaubad_v	15	t
522	6	public	kaubad	15	t
524	6	public	kaubad_detailselt	15	t
\.


--
-- Data for Name: report_template; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.report_template (template_id, report_begin, report_end, header_begin, header_row_begin, header_cell, header_row_end, header_end, body_begin, body_row_begin, body_row_cell, body_row_end, body_end, pagination_begin, pagination_end, previous_page, next_page, active_page, inactive_page) FROM stdin;
6	<div><table class="table table-bordered">	</table>#PAGINATION#</div>	<thead>	<tr>	<th>#CELL_CONTENT#</th>	</tr>	</thead>	<tbody>	<tr>	<td>#CELL_CONTENT#</td>	</tr>	</tbody>	<nav><ul class="pagination">	</ul></nav>	<li><a href="#LINK#">&laquo;</a></li>	<li><a href="#LINK#">&raquo;</a></li>	<li class="active"><a href="#LINK#">#NUMBER#</a></li>	<li><a href="#LINK#">#NUMBER#</a></li>
\.


--
-- Data for Name: session; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.session (session_id, application_id, data, expiration_time) FROM stdin;
dd6ec4e8cc76b8b9ded1768afe5ed86f189525ae854b970470f785cf7c08e0ef2c6f132bcc9a41c08378f031847af135301edcd9521662aa4da9bf9fdc8d7de2	1	{}	2016-06-01 21:42:33.447127
e24a3752b4d7447fae79133ab567a7c86f97cfc8ba6262e8a932531de1a15dfbe87b667d3444342f2c2ca20e8b68af93f617f5544ed479b3d3456194e7d7b7de	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-06-05 21:14:22.386436
a76d6b8e5321458244fd11631e0f253280d38084699a5b42fabf3c08112222e6b95071f93b864535f1bc756394d1ef10c60c44905427ef4f7711733c97914881	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-06-06 13:59:43.424047
1dcf560c33ac7c75e4e5a142ae6563226a0195c9a5cda2b44a00e6c8061673aa26acc5754a9a5605391d250d8f260ecb17465b7ea4e87b5c27fd0c7130f04d5c	1	{}	2016-06-05 02:01:54.255317
989a484a9a4e11d2617307f389c5f6abdac8f4c548632465d146ad7debc2756d04e4a7ffe0a07f4d1a213ad47a3c08ae63853467c3adf158f9a1c237aa53f869	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-06-02 13:45:19.97436
4a40d8d1b9ac65e541fde4dc8cae410349dd69e4f3bed01a0e3465101c2fc4252dfd3e12c33fec2639e666bc6319bff844ea4158d3101914fb9b82d1e2325cb5	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-06-01 02:14:41.388085
dcd3d596d91050e58bee3da4a5c819bbbdcba63bc1e26f4747f7c7ebee87d9a9b1afca109bf51c9dabf3970a5c5e19421d348894ec1be041c0519d871d4935fc	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-06-02 14:55:50.895961
d0a6f09175e9598a3dc3d7b7cb3bdaa64f43ae8e0dbb23f9056782eebdf8a14825e15b59cb112a0c5ad1d0b8da305310eef7801cba977983c98981b1befd82e1	1	{}	2016-06-03 00:40:48.883689
9b9417e7492ad20a61934e42edde7b76066b59c548232be66df8ed7de6e14396d436c6d21dd703bde06ad59dc9aa272e7c06cdfdf91f128d338262c699ac9079	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-06-06 13:56:24.952366
9dd9f3d5800ce51b5f370d9aa110017204aeef59e90b3bf034504c76748ed642caffc18505ac41f190d0659e2d554cd070bc83f8763615bb8f93762a10ea14e4	1	{}	2016-08-25 16:06:20.49919
9bc7c41e762d50e5738b898324f52bc8da4acde9b066355535292d1ec9f6589fa0ab44c6105e40f942e9f13b2bdcecd75660215d7b4bdbbdfcbc7ecc50dbbd5a	1	{}	2016-09-22 17:00:18.134521
29aaf65e3747af64a7809f18957ef7570855cf246b3b62518cf5a2e881738b2068d90b71f9cbea0b07c8d1907f2049e4995bdf40915633eb22bfa0448d27648d	12	{}	2016-11-27 02:34:07.820034
024ca8b92cbed9c54d65e3ccfb61f2c317dbd8080b5bac379c9bedb683a13da5ea4ab8a36c65ac9b0865bbc5dc6250fb0ec0fca5d0946c92cc928f1d1addf5c1	1	{}	2016-09-22 19:42:25.256809
d08bdf11c4107fc07e4f1da165661f63c10984bf85768dd30c58c2221ffde95b74795413c0175fa89be92c26ff10f7430f9459369d7decbfed451066d1a27039	1	{}	2016-09-05 10:49:22.927254
d3dabd5ed9909142655792d55d888c5d6afe2cb9ec7abcb12a78ec69318c0c6dee6733141ba38931feb5dde067b350a8f8c9a404bfb4fce9a7c238ac29ce1055	1	{}	2016-09-07 21:28:07.676885
9609e72ed12409f0e836830ce32f1cd8d09b4a27aef38619a32fbe8dd8dbadb5fa9c3808da02637fd3eb8c65f60f05801916712fb2219b7a3f8d920f664b93be	1	{}	2016-09-05 12:10:54.714269
6604c7f07b68db66f5058f49f6c18abd5ac681c26562f4a821eafc3c3761fbd42f36f75c523528f15eb4cfaaa23f2c7148d31eddd131da6e8bd3b27626fed28b	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-05 11:22:28.050017
c869a40a034888fca55dabc21be4f08da2a91f20aaa1570ad3755405112c30ecd5470227e9cdcc54ce89fcd70cb75640da169a67ae19d4de45a30ed59596aa16	1	{}	2016-08-25 16:11:20.001209
1737d0624d456ae0aacb7360e2dc308b39739b431961f5d0b9d1f94ff5c937cc307dda4c7568eb6d25bc23109946209959cb7ced3c61dbd3f327f12fa8774420	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-08 16:01:37.232722
99306b463d1aec3fa4606bfb0c2862741eb1ddeb62c44ca65a0a9afe66221810e63c4c15731c207139e70008a1098b7e58c5a8d19230fb0aaa358e1a3c9899c3	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-05 11:46:57.501379
2c04f960fa37f6fb93174b03ebe2f3b3df683b6ea30fd284619f2e109e3ae02946f96700078964d0ad61d583d39df5dc9a149f9231bbcae975c48fb71d898f2e	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-05 12:22:05.486864
5ca5ce2ebe8bff5c7c49465a7e991f6ae8411c228a99109e88872fde0941257288f12c65ce74b09c184eca36c9a9cb191e535e6fe5e92d5312420e5b0678e8e1	1	{}	2016-09-05 12:30:10.145115
93f37297c80b90329609e25313a2f06fa612ac46b13afe02ff1ba5c2533bbe0a8e68fe79b434c0b1c53754970c5d8c73e3da77fb4d58d3d3acc76e5df61d7c67	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-08 17:48:23.945916
c0f08ad0eb546def9c80310127272da795a64302446f6c78eddd3581a697769061c32fb4e39cf16458bdb5ee2311c966d9eecb5d8ae07ae743d1997963286230	1	{}	2016-09-05 14:05:37.236397
e1bf8cb1af21cf7c34e3c497696ecdbce81584fd487f32f2d28a269926c703329e5f354531a089bc84b8d07fc69856f6277ead2ed2a380933061d1865519f09d	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-09 14:12:08.577312
936dbb980438ff5c2c03e0b5f2d882302a4844b7a7f29f35f86b12f9956d4543b831b43c03a9ac54e3648e22bd7304b1dde3eab73b2b7ed7f663bdea5f00adbb	1	{}	2016-08-25 17:47:54.469776
7ec3adec13eca4a99929f7741481ab4fdff3e28894da67314f4e479c619d93701709521d203e85cb6df393c63818e4caeece571cead0b50ab621238b55252cfe	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-11 14:08:24.237102
d18d86349b5130b320330309729f6be57145d650279e80b769f06b99afd7c28ece3bba2e530e6cc298dd5166267ce7523779d06d17301f53e2819557ca946e2b	1	{}	2016-08-26 15:37:14.836076
08b6a271a866324a6f04b442b28c3337e363595852cf59489f286a9a27e6a821005d2b47fa842c0a7bca66ec788c03df56f5d0401a7e92053cbc8c8b4be8e020	1	{}	2016-08-27 10:47:06.437038
10d5786445fe32ab0a6edb9da8442d43a34b78ca08383c32ea7eded267b5fc11db9748ddd7058ea12093e6a118a003b9e6c7aef31865c4453b9b45e1b991a7af	1	{}	2016-09-11 22:44:47.798045
eb6345b78ad877207b66a5b987f063f2b220a93b8481c3c36d7124cbf29f1389ed6c1d87aad7e2327017bf5e56aef65985e51a2d875dc2d7b6ee2ec7e3ad6fd8	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-05 23:14:16.02803
724ab324d42f173abf2c03a8a644054754a27e52b0289992fd314cc4c58ca0399f367645a57a5f21ff65802731f07df7e32a784ca91ca7b03d0fb6372071ec5b	1	{}	2016-08-31 18:24:16.291947
9acef00bf5263a24b2125a9ab81418fb39da1677e90f7807dc96f60e37955141201ecef1f09d88f3acd1542de2f6ac5cde8e62704cbdd0e9dfb607b90ee5430c	1	{}	2016-09-05 09:30:05.885643
6884432478be6bc59f29c8a4bdace76fc8efe5693de16f2269633ce585e0b167f27359716d57f854c60bd3db31cdab197d7a1c36e9270c20ef8cb9c9d53c7b3a	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-05 09:46:48.780552
a45ed2be47055d2a6a88d5a362e5e1c00f28914cb56cd05d1250e351bd39fe02c183f59ae2f23de7bc3975f5e288ce2d0ee87077d70151e0567a449257ca7b79	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-07 17:44:53.81006
4d8a68d4722e79fe7d1989fd88328e0971fc8ffc4984cc701c49e9b3c64adccd82e63affd55b25c8d023246115da4420e4b2377ca1bb7f7154b59b42995014ef	1	{}	2016-09-07 18:19:31.874555
593e5cacc2642fadac73f4977a0bde4f1aa9cef0285b789b6bd7c52abfdd70817a4f19904d3ffd7adddeb61115c83cc7edc9e20f78475016cb60807035406dc4	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-06 17:25:49.429827
df1986b024ff9d3ac9bdea3ee314f07f429bb549f5393d043ebf86ba3a05478581890dc78c7e559a49199bb44362cf65aeb6ca109237baec6fa996b44aca8e48	1	{}	2016-09-07 17:24:08.566786
406b6a3bce3251d2b34c7845723da134a3d849fff5b0efe8668741b2d24e9191fbe50a4399a5691f604fe88d68768beee653e5d6358c562c51b0a83a46e5d776	12	{}	2016-11-28 09:53:07.962451
322d6a74f4e756cb21a2c23e279c33810b07f62e3f6c2bfa21175f6b541109dc1d8776e252a3cd9286c11c094877ec882a80abdf64ffac82d4fb11e71039b1de	1	{}	2016-12-01 17:53:24.565766
fd2f73692dd3193226642f0bf7fb5e180579826c4f442ec28c252c267dcc67a258d226ebabfd82787b3ffed0384bb0b84c71090a3e40a0178359e534ec1c1b36	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-11 22:47:14.256358
02bfe13075a1ab8a23691be50b7a4a96945fbd3db4dee2a8873f4fc080fb42e861c132ba9b98396ba69ae071d57701ef1d9083068818f770d2ccc3b0454176d2	1	{}	2016-09-11 22:55:19.455254
226112cfa7c215e459dc4854cc150d695ecc39fbb01203d9b4f3ea373a64e0001bd8231d7a772bcdcc85b46bf57abd7f9ab56088868cb05aa205b868eb85b38c	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-13 18:59:25.494468
365932a180654786cf739bfda91664c976c005c37ab36b36392c4a13393392c01335f0765481555dd0dc6af688717bbe345564fe33f19ef4124222c7942f3405	1	{}	2016-12-02 15:43:40.955106
8faefc461a156fdd477dac138664245c48b4281f7e81cdd013d38e3e4d0d09474626d4ffea1e1dd23c009827d753590d76b2c6310ec356c7c9f2a1d6b6c62689	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-22 17:00:48.444034
515063918bc439e40b769c388ebb69e7a22a0bec1cae2b953ce533b6b08aa39a20986f359ba3f31a0e4876de9fb8329dee5a20faa8b419144c242f683fed7085	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-12 01:36:32.712314
60c07ffc8f48d52f1b23b3fa67fbfdca25b6e181bf6a65b8c220156d64dba2630adbcf6fd29addc3daff6d94a410319419cdd44fad0067b5c2d9c85e0428ef35	1	{}	2016-10-05 18:24:26.792344
bcfb7eeffa2b696fc9c16ba4333e9177f5974669a8f6fe12b03416e33f2b32953f3de1d90373eeb05f1025000b1fb4b91ec78c8f6c46e7eacdc94bfe38caba43	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-22 17:11:01.621445
2d916d10afbe40961e87ae51d2c9502a3473489788a9f61fe72a5f6e507aee2359f2e6749e4331c5efa7d9bbef4637b09e0b59b0e15d1ff598d51b6a3a6571c9	1	{}	2016-09-29 15:35:36.888937
a3a111c8845a32bc3b2f6aaa5ecef58618524856e5c515db039f50a01e07f5430c29a91457890de281ad2473e0e11b93525fa4b61fe5b52faed47a2019761a9f	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-13 23:01:12.880525
111e32405eb2fd322a6cdb0735c7a6c1a189f89820cc3d137cc75c38cc3bae84fe27e8eedf05c06f58d81b86dd690581253a1b2cd3630dddbe5e6511bcac12d1	1	{}	2016-09-30 22:43:48.71004
2eda67cee94e8c073866d2c3002d4dc99735b47e25d9aa175b9a12bb1474595d29ac44c8de1fc502c1afd438c186a330c52d1a1fabd5f814fe8de4252b94cfcf	1	{}	2016-10-03 20:57:19.759869
35bc35b5db8f01950273293e5fbc9f1268908ce1e2164bc08634828b18d29578d7ecc3919f270103187e2896014d67b1c07478ade6af3f6cf4012068f1a8ea17	1	{}	2016-09-12 11:42:28.191511
36f4437d77c48ae84d91361323cb6719bbfff1b21fae3f31cf117c4321116a069e68680afbdd3f3a820b83bb03ac702df33409b9bd81869f2926a9facadc8524	1	{}	2016-11-27 13:37:09.968063
d61f52f585d04aad5ce2ddb454650bd9df7e27b93b9179b8248e04aa7b0c6d80494dc8ef3ba496884399bebb7e2ad919b23755efea37f6e7ba41c98d5cc3ced4	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-14 15:18:05.912525
c5e0ef19ff63d873550e73d05916556feae3e1064f1ee2c35bbd30a68b9add3d307f516bea27f5ac197ab986f53f602f41956f056363a3fe13fd912f90b6a72b	1	{}	2016-09-14 16:27:32.098851
a73c4275d2707e872931ae6e2d9a5ce468466fab64910e056e3020bd52977e34d6799c65888bf1ef7af761ee8da03391eff73ae8afbd599e41322958f675c905	1	{}	2016-10-26 07:36:43.00819
bbdf1de5dbbd64a034e54d925e7bcb00be12331c213b3a68dc3166e1327775a25a759c5874f1ec7e5f592d6d0298e4445e3e66778e4932b7771c85d568f57c0d	1	{}	2016-11-07 09:16:34.163062
2676a1973d3df8f2e330270d3611ce6e950d92a8b00a00bbe6663f48ed8e41c7650560f4a41d2af2311bf4a3b48e43088cb1c8dacb13e75199b254a9f7a089f9	1	{}	2016-09-13 12:39:19.926177
1911a2a62946f1392c7d1c7862cb77ead8eae23a14a9787097d77a7182198a9f7c667a6bcd11eb6f662a95a9282bf556100eda7c4add64788b041427b9efbc17	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-10-06 15:29:12.311733
f92c667726b9be38d034bc1aec5300f68ef5f9c95634e89c3d6ac3d2288cf39940367a69caaede5754b43a8434412cfaa043576c280c494e62e6f2f35ef47241	1	{}	2016-10-13 13:52:50.904454
986a0c7cbf570f8e3a5b0282e467d942221e1ed3aac1692f38b854ced32f88091acbfdd717b718da6695d2c835569d3e1de9a0a5c4a8825a627328479ac7b22e	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-14 17:10:32.506281
f62362c69d4bfcf646463e640d94a63f70c716f9aa4ac661b10bdf864847dc16f2da1116aa901908e805aa15396ed2d552971076d2d7a0a4fa095f1d791ab34e	1	{}	2016-09-14 17:17:08.883478
31d003e6865f9135e05f1c06ce19d02c3a5458f44edcd6ac037a323cd3376e84455d761e9e8d6224c57cf956791051461e12ec9b554fc1864a86a78a799f3e52	1	{}	2016-11-09 17:07:49.097621
78302afd23515bd7587bd918a86f747267d554a56c4564f3b346489c5740095c71c8902604fba8caba1cc04c590475abb28bdd3f7b160a9f7ad6c147257a03a7	1	{}	2016-11-12 11:17:29.161556
851ac9f71795f0e1ee1ce4e400f5ee7246a4bae9f71c1b2a7520dc37d35f12ec8dd78921535030523c0004144841dd3f5a850d09846e56f5941e5a2501aeb8bf	1	{}	2016-09-19 11:47:40.254089
32881fa73d595f548d4e9ce541f0d1bd4c195e7e9d518972ec336a573e9d821c609e632786560ebe333b63990c1f4fe1f074e160f5a9e34b4d0b8e08429309dd	1	{}	2016-11-13 13:18:23.596438
cbd7f8ca494abd3a37ec7c02fdbead18ad7195badd2dd80ae8a59e0d803b2a99e68b804749d3e168e84ee22df4b195c65ed55adb5937d301c68b3fdab3d7705a	1	{}	2016-09-14 17:28:18.47441
9ac9259c329018f227679ab4ce524adc87fc77d14ca0e8ce57e42fbcd4cd60a41ffff4b09b4c35608a2163882f3a192c23c8f7d536fc2de9baaa1c58d120910a	1	{}	2016-11-13 13:43:12.142202
45ad7cf7342d348dc405266c6eaa74e550ef487398b4cc6e83933bae94423af086448b367b0b65b2f7632f79dde964a0e38f499890f5412fed51a41e6c139e26	1	{}	2016-09-14 17:28:18.56198
59d0124aa4a93d8caca62aa2a959c58e2f8cbebf5ecd4b0b3b754264969e9fa52449bab9524d0569283d0503a74315fcbd4f7a3419914f6acb49aa2649562d36	1	{}	2016-09-14 17:28:18.664003
b08b623e40c260e04d39eda390334ea857b93a9710cff88c87e619d0b543769b336656f0107741a42223b8df59eecc314bc8027f7f7783330fd02e82471596f6	1	{}	2016-09-15 12:04:37.025152
277e32cbb8cebdc0aba61f3174b4e037efa818d7133d7c2f859f1f6e62af327b6f7defc7b95e3f568f7623c5d259db7a960894bafab8109bfc5e240deff0bc0c	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-15 16:00:02.562968
1a173f6010cbe4adaf3fdd151a082100612e4e3ebc40ef3eea26e37711465694b8eeea866e58366ddd2943ad94a403a8e7b5bbe083cd03617e3ee68c048cc04d	1	{}	2016-09-17 13:56:03.044642
2474ebe90b06695e2ea2ac1bce0cc8e5f625af2c493deed7e6d34dc8b4a42a62270e1f5f013a7741f428edf0536c2b578826a053028e2043458d1aefd3d78c60	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-19 10:48:24.893
86265f95c2d2e3c78cff337f79a024f3861b07babfd386fcfe7750e1d4d64f083e9721e50f80caf896f7ef0ec6bf17ba35c8007fd9e24bb5f876d9d77205d5d4	1	{}	2016-09-19 11:08:52.525233
668c1e971b044b6aaeda2fdfd3e532d77e9c236f229ce555c251303f8778188fa1f5bf3bc6365134a04507ae5be6909510ca014197b9ba7aef1ec9b8c2955707	1	{}	2016-09-19 11:09:54.106429
8c6c65af38da16efaa6a42ca3734524f6c2b7e3c8b956eb636bb2e1d937e0dc485a6928c3edf3cba4c2c323b9c30d6c6c74b27c3086c978ff0106909ea4f86c7	1	{}	2016-09-19 11:14:58.087912
4ac224270cdd824e018646fd0aea9ebf68b8735849ec79c12cd36d7ec657b5e0f00229bbde76a6069e995b147f622add0957a244efd3c1440053a794ff7f3529	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-09-21 16:33:43.921047
b8dc758546b8c71799b7dc7a9a424e7620032fa1b3a7bd7a45a59cd5b3a251c745858390851e013b282326b5812011174b8cc3ecef557335598d568f0b1673b8	12	{}	2016-11-28 12:35:34.958273
f6e8bc795b545c7acd388a10b506bc4ec5994941a66424eab40712cb1ecdf343e31488b43c1dc88daefc8626a48998078c621d2a2a2681a96d78167e17f0eb60	12	{}	2016-11-30 17:54:36.954046
5615421c508084a5ad0587061430f0c6f2e8127e9573b84c56e803b5c568f59e1c429bbf0c70418102cde04052f48a7cff09abaa17033853a71c5328fc82d91f	1	{}	2016-11-13 19:41:15.500949
72ab9ca8b83ccaa400b934869ae435535bfbafe69c1ea7ba9eb41d299336a27daea51883d87a5b801292a993f1055dd155a0107c4581b65ff90e1031ea2dd580	20	{}	2016-12-13 23:35:06.657412
df6ce97a1fc41043118c2db62eebe47ed86eb9d3718da9b1e61e17069b9a6678ad97da8bf6910e34e9a25d703fe6a4caaf8db0e175f04e2e761d72db2f7867fb	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 14:14:05.90019
01f323998ca8da06adbdfd73563b004b6ed15f31c0619583a41563c6391a72f28012d8c3c348171b6f8f3dd54635e0f19aade35565b0fece91b9f73d045ad428	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 11:58:40.416374
63eabb75aec9646673d75ced2ba69f122f33f9592ba82567b45d8c9a21147104685b088c6f70615c735659fb8c74de196a5105dc7fbfa4f1e14d0ff600384dcb	12	{}	2016-11-28 11:58:43.429847
64c2a593aa746e55460746b931a0fc160a326bca158e56336511eb5115677e6b458c051e58610f984caaa48a112e13a2146a6daf7e2040dd0569d58302beab86	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 09:52:39.216311
cfa4d16c43c988c11cd5e9dff42396369487842d2f43f3fb21b8fe27e74d08acb4e7fa094fdd1dc89cfe0dd7b691a1e7d045023edb351175321bc6cd8957b6b9	12	{}	2016-12-01 18:31:13.634177
bfa6425ce56156f72cb3220647fbb1a670d59da634eab66e79fc145f17820f5b69705739931543aed204851c2fb6de496c581888e2c3e15cb0a4a1b0cdacb137	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-27 02:37:39.751988
dbd41c4ca1287b821e99aec88005d995a445b3d45c775e1b3538b1ceac768545cac2304fb711423ad77b31758a1651f6f0b5ed77adf997f0eff495bd846c1617	1	{}	2016-11-14 00:10:50.242201
c17a01390b303f83dd310e197ad42fe065c713c8180fc20730e79502d53495b410d08c83e65ccf97ed06a22fc4c5f045c7f60ca38f693fcb39fe4ca81587ca80	1	{}	2016-11-16 12:50:11.531451
8a988353eda9f818bc35cf001ac4559c2edbd01cff8523029f3b41b907ee7e5f578fc54ae620003884434916b3fec1e2637986e85faf9427ad3185b54442cfe2	1	{}	2016-12-01 16:21:44.273425
4725858fb1d2a3e40fd032ec31ecccca2290b6adff9e690a5410ca0240fb0d551c099b18c27299ed633d4331a0c60dcebc2f5743b38630161e3803014d84168e	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-26 21:30:02.86793
636268d67d26b66dd0eaf2cb6d3cc61a481f641676637db27520aee0dc2a153b771b552835bdf9526eb49c0c716f1ae61b78b5c3fe6127ad54d492f7a9653704	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-16 17:11:08.958921
9d2bd7760532ccc95eb67fd00c5e23ba93d3381329b55202678a1ed95c1416b66a891f5a130fda3a3683063c5ef0cf5cdb56dc2a3d01c53c3e723bb6446c10d5	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 09:53:09.954879
2b22970a9fd86b895d947c36d1e049a984bf78772ac88fbb0a0579796efdd882645c42029753a4ee2cdb86133efe72db527fb6c71f3be224d52efcfa9d2d2447	1	{}	2016-11-17 16:31:19.495004
84a9442905fba7fc12a8b884e29f6985ddb6ad2d53df9ca428452b7ab607acfe2fbc953379c63d95997aaa5aa9189e1f016aee4359ede5c08bf9bb4012b5b0e3	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 09:53:15.942313
76fc9befcdf1165d99d5b09ae473db69584e4d7f75b016e95c53c73cfd32ae4ac8014fb8acbf30964f965b79b1c592faf110a27cb6ed493712a7da21b15bb242	1	{}	2016-11-18 13:09:03.838633
ad4d8a5e2fb2d3e0b80addfc970fd7592e9e7b244fddcfcd9902fb288600d3098548663069f4c49074287c2f41831dd48ba6109cea39eb8c813417a65e656ab2	1	{}	2016-11-20 03:05:16.383756
78345a7314769e0f853f8e1629de702a4eeefc94c31f16d056186d7d12670830dd3bffa14f2314794655baee35ef90958a5e62bfbcc9d7415c41456b395ceed7	1	{}	2016-11-24 20:44:57.969687
29ab3aa1799251934d64eda3d7b5b07a0f7e19d95fda0d043360b754dc3d3a90a953d6ead3b10bdff1de5b4568045e3325a6dd4109ee9b32035727297849ece0	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 09:54:04.018062
bacc12c4c5aa1ba4f487754c69341512e2d7e48e16e4dd761cabb62286ffa188529f9173fda788990307d59c3f81759f9efdeb362d942f322cc258cec4db368d	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 09:54:36.006769
f1b27dc1deaddb7ac5a2004028f4215608535817871bda8ad4bfe72170593d627e68885cfcf3cdd7170b69424697f6950e5f2d5d1b81e582be58cc79c4d5d32c	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 11:56:54.93632
b0ef451b67e29eaf99cdb1e9a6232b38daf5012036148c45a857ae8d7152f51d19e42291bc65590d5f855d3e0c0d1f2ce353b5e56b13d578f533257f1c84421d	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 12:00:59.9635
25059350e3d8a79b592e5970c1d259d22ca21acc7affb7b1279f68c4922cc6eedd7cc3c7b6dd32d91fd421a218566cb4293ed39ccc289df42b583cff72953e16	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 09:50:15.896225
87ceffdad634ae61f0ed6b31bad35ffa06b0e3858178ead9aabb6a6d6f178991ff59d20f3e3cbc3e1ad24ea99a0a918bdbee37d0dbbbf870cd135b266029c301	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 12:01:07.23149
ba178d1916682067072dd8530306492b109bfc1da2e2e124b0f10ec60b7c95602050547e2044f5ddc3eaa4b51e26783bc96d6f45eea0b577c21a8f21c94bc75c	1	{}	2016-11-28 09:50:34.846446
ece20c468d0dd21d457ff9ba0aa83233345b6fe12ab36b9849f36e9f60720982244b23e2ea9d9545550c20f723421d04b4988c3f86a1ee24e4644507166da543	12	{}	2016-11-28 09:50:37.092781
0640081a6248e812e2e9b39af02ff070a40b974ef48827b584345cd7e859687a78cc1cb7470e5f6e4d45a04bf004c6d727f369179ad01c7d65dc1f17a9218aad	1	{}	2016-11-27 16:25:33.523698
166783be506d11803267f138e18826c5342c83e510a5a451cc651235327ed2d9a9f2932c48b033fe4d03874a9293c1123cb98623bf9d0d82493a407112b9b220	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 09:51:06.528502
87c346be7ccaeb777db0af3dbe914d34e90e33e00fd7c2b5b480cfc188ec6ed74224d0665b80dd0f5e54966b94ec70495901810bf6025027e899d05c074bf5cf	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 11:58:22.715718
c2d383eb275f61932d884f329d63a7edce92dfa6a4df70fd891c5d6cb49f3a726a7b1cbdea9ff29c77ff21e97e06080a3d5b6ccf7c6bfb5553f9dc972b3e609e	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 09:50:46.936226
2954c223ba73c5ae34d9460384f0a369c0c0f8684a628ea788f270dba48196f38dc206c9ef897d51131c99fb8c01582ef24f8a8db2063497cf4fd9f66aeb0cce	12	{}	2016-11-28 09:51:10.70526
9c2f55fea42dad9db56928dfe518046cf99a391a72106ffb97b1d1098970f1c74266ae2eb432881f37f028e609aff08d30ccbfa4f521734af4de5413ce03a7a3	12	{}	2016-11-28 09:51:12.227133
3dc77f6eaa390478d1f9d66e21b0d9970c3c1249c7d163e60cdc1b04dadd2a558e8eaa0b457ca0a27cd28a211703ae11482a444bbd2cc3749808fa88d580fa97	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 09:51:15.158388
785875b2d6c57c10e4c70e05c61d75db5b291e37d259f90dbd0bb0519a2ae0d157cb4f0474900c7eddd1cc6a554283ea2cba2a940a5a9c5c9926ed2732822a09	12	{}	2016-12-02 14:15:40.817574
7a78192cccbb973bf163e8e414fa5aadb776db2f6267e2861d4b074ec1c263937234f33d9358d5d3b567b021b0e5d591f0fd2195e24aec2e966ad251a6dff491	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-30 17:52:21.266381
d3526943d4e4fdaf07a2bde0e6c6f5663a98ad4ba3fe0e2e3d445df1610c18c54b6812baa4348a27a47d10f00cf5491b6cb8ce5da6314e4e0edb0d9fda193aab	1	{}	2016-12-01 16:17:23.937514
5ce0e0ee1a48f2dfcd4f9747319a73f4148fc1d3a4a3bf2fe24c32309e2e467e66c7871c31adf6cc564c4de0350a365b9095f188dc07205951a0bda17b248d81	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-30 17:53:01.242806
4921378e3e0ee0c4b7c805321dce687fb30c80ef5de67b2dd497b6db42e075c5b9d6f26611751318de963d77a043a2375bbdfa1e2c0648d80d53e41f8a1e4eda	1	{}	2016-12-06 18:53:20.889489
d5d9bf4f8fd46404a4e52a703145ba4a38c0d1cbfe0fba2ba17ed0756bebfdf529870e2af2354110cd5b6f2bbdaf396adfd6d5fc75dc32e128604653b53e66b7	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-30 17:53:32.438481
63628ea3ded5dd45ef59ffd3c8019c732885ae14156c32d97a1bdf2fcac68c9e279f9e803aa40dc5433122f324ae79c976e5917f9378918fe4070912db75cd07	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-30 17:53:50.033025
474609b6d693588da105295b88c651b17cb35911352936e98df83af8998ade168710c2a5c5a3d11281d7e917c68c4e9388bfbb3b7b66530c75786a4335281557	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-30 18:13:55.149311
1af800bfd112d02f36ed0633999234029a70e118bc99dfd10deb55ceee2135b04a5ece9ba36173eebf7d75c2c1ba7add0e0a63f97505cbf3257fa8b7e8167128	1	{}	2016-12-01 01:24:21.587707
0841ebf0b7c2d3e9ac95ed4a93813cafdd9a4e2646e82f106efb09bf15c4c397b3b922e4267e5cdd60151f9d24696d4f892ad91bb88e862976e4ad6d04ed565e	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-01 16:17:43.575952
2ad9eb802ae98b6ac2e07ba108638c47ee0048e0fa0ce6c5b5d6489c3f0d82c3af2ed748637a49437e72af417f1245bf71ca4bf58e54d01703785cd711856ab3	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-01 16:19:01.04826
edcf9b0ea010d17098f31b16ca5d647931eef415aca0164672a44fe34ee9857aa4b0974dcae7aa793fc77917e5b0b17ef3e6cfd93eacd4e9f0a503e461c38ac6	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-01 16:19:54.958779
864cade70e5bd749af414bd88f9dc1c723e933fe1f344d1d976b1bf653c5c2632f606a8bea60f3f2915e6a4a0abbf7ad81361c0b909fc4ab43b1c6c0ca58000b	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 11:56:21.078168
bf16734d37066bb8a3150e5fa386a5131909c5e47d304fa4d0eb021d0c7fb5a10dd06eb95da49a18e55c4c9c494f388bfd9556acaa53c23d292e12635f1e04a5	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-01 16:19:59.483006
ffe9071d8ba44e805e05cebb929e4cef4557067ace5c7f07caecd38a42a3f3ca7ffb88d1ece145b4c2ec5cde270f950627d7650c9c63235023e2c8fdac2dc1f9	1	{}	2016-12-01 16:41:27.692001
14d58c5f4a6508c0e5284296f60af737c028b10311f1e8ad31c15c0c5857813e590dd5d454a74a1cff55db65185cfb5cee85b63018e616f13db0ec72ebe7d08f	1	{}	2016-11-28 11:59:54.386331
667763ca9688080aab0d9bab20b007f9ddb5780e35244e4bcd5894b0cb1360d95f0d18fa00e1cbfd7b7924c40cede384af532c0df3c8729e9d8cb0cede049180	1	{}	2016-11-28 11:59:55.132374
a0fe52e23fb4313e010457202e817358233b07de9458df49d93ef2c5f9ea3112823b52af2f9dfbe0056dbd860a2ac31bf44e5820d43d0814b31c6059fa4fd19d	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 11:59:57.001917
c9179130f929abac56037a8bf2395a859ffd1fd1240cce7de000c1daaab4d9d9c100af565b5c04c5da26e76045abc3ae3df435e01cb503a32d714d5f277fe3a5	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 12:00:05.649961
11cafbe9c454322889cacbf2f3f2f1ce6ec54f9d60b8f4e96d2414bc99be9204c68e339f4e7aa934ec73c30b83df348034732245309791c5c49eff2f77a704a2	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 11:57:42.085791
24df8365e4d3779e8026dee79bdcc5cbf9f976363c992143316a3a486cd2bf1a00a5ba47a586cf74d2c1abfb8aafcf4aeefb69aef56b7882ee9f71236c6728cc	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-30 02:06:57.743195
7fd84739fea2bd2fe937dd03e9ecc0c332f466407a5f3e930f746b9f653e256a17e1068250fb5c4c887fb11ebf54a355915d606910e3fffdd9e64cb4329432ea	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 11:57:58.207623
2e8ec76c0326c3a3e7a71d4c093209d6e3d35cee821ac8628f2a4fc6f4dff9c246e4192ff068d93046227f45119b388ad1a2dab8b24f723ff336e2ac8748ebc7	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-30 17:50:38.618327
2b1e30ed1a17ed18baeee0edb81c1f9877db1d51a4e32f47d7734d261a4bc2e3fad76459892a88102933141cf964ea6bc62b7592bf10e5baea2802c66204ed12	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-01 16:16:20.942197
5413039543475cad437fee139cab4c755543593ef49731dd1361ae202c72ba1a641d048255dac3347412be3f234dd81f65157de5c938f1f14683c9028af21ab2	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 12:00:51.294942
d23ec0b70acc503574706866a17a17740203b0f6a86af33584d27b8cde5c285fe5a00e348869bf5ccd0af01a3738f6cfb69af7f4ba9b9bc08a1b75982d179be2	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 12:00:53.785128
7c363670e424b7529f0b7888c3005a5ac4249e8302f13ce340aa469b8904a556d5c21f38ae5d8aa49befc1431d304bf074202fb108f0653e4be21dc9c66d0e3a	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 12:00:55.797001
5b6b819aa1f359ddac64683b845b8cff5a1f7f09660dce432af36cb5ecaceb22fd12364ee5e0c0da6dba4c5815ca3aab1bbd164c91f258b88f4326cbc6f826ef	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 12:00:57.24414
8502c7594990b00a080b12682fa03cddfcb220e1d87afdd40807483766359325e06839cb62d25fbc987c9238c899f58577438cec9babe389be438f46a7a8b0d5	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 12:01:00.573296
a953fa97f4f2139a413c9feda3734fce396f35e8acb58e5f9f791ddf3b814400dd7c4c972eb7862f02f5bd400cf2b84cccf58c15c1e46c7eb87aaed3b4405a20	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 12:01:04.540539
81e3eb456aa23c603d76d1b7f7f326f1e3e6eb2e64e95a9d3e4674e14aa5640da5a4776e880a06421799035d6b5bd98d2d486bfdb0c915d562df3ba55b6ea073	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 12:01:04.538383
ac0aefab595db286414b852c90db967f0576b1e60b4175c5a72da6068a23e271f9f7725b200090a32dbd0c0f565bfc9983ec12175f5bc3ead939b631f341a10a	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-28 12:01:05.96414
a5639f306c03a751f6e234f6bf8e69bf18bec920a459371cb5b95f7cd4a0ecf6b6c69f945b6d6dddac0b12a6427202c5d9083dd5067dd1fb1437f359d0ed054d	12	{}	2016-11-28 12:01:14.934477
bf3c0cb8fb870d90144eda7632ed05ca47aabf6a42f0e0074b30aa20dc2d602e2aa4305f9ba5a95fd10f2868f39729121f757805635845a7a2d213201ef05c01	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-30 17:52:01.452342
d602e6665fb1e8dd63ea5f0233a7ad155c811284063bdde35ff60f80d09960baa75232259a6b7138a48b08f06241234575eb790be023a3fccc00dec0b5fa4a42	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-11-30 17:52:08.374719
ff4ba602bd57aa47402aada78b8bdeb895cfac691a2c424a59d1ebd6be3782181dcb9fd80e7f24db3f61fc9f6eaf84122c07845c92a108420c3181758748e4c0	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-01 17:52:44.40633
687131b44fee5f711f9e00414b1f5cdb191c1b07dbdb48e8a3fa4914c69fabceb54bb7894c75dbae35aeb3940b01baaa67a7eb1440e0a2f0edfdf2966a24ac6a	12	{}	2016-12-01 16:20:22.510446
9f2ecac2393d98b79d4b848248acbd70e162f39dee165b7741f57e55b5ee84af8af2eb4303910c25f27a00ee738c01ad40c5acfe323073aed45279962b5d1f22	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-01 16:16:19.092584
1661c76a8f99a8da102118833b81d4ba194b7680bf60d0b1841ee7e6c7369d4d7d454f37b36975770ae4774350ae8ea62e587dd8dfc5288a9819728da9cb3a55	1	{}	2016-12-04 02:19:12.65614
f99ea0f84a33d2027a4bdfb23e3c2c42c78c0605c86e84f519d65c9b42ea9a3ed47870c6df8c9992b50ebc424276b1fa69b90255239a7f0cbaf81f9959be9439	12	{}	2016-12-05 09:41:13.156356
3fefb8891b10c16af3c5469642735124ace709d9c4756bc58afa7b62df0234a89d060b43c2664f89eb9de968df70a694aa016970a2c5d8ea6c06f5f86939950b	1	{}	2016-12-05 10:21:42.673411
085aa16d89e91d755885111baa819a64e5f495400a2e90bf3d7b92b8d4f399174b04edb7abab7b24a6b03e4f866d01eeb3fb93055d7e10879a74d1e0686f28ef	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-01 16:20:58.019419
aaa5c7669db68b8a9edcf27e9a259e970b297345d7335e2414ba848f1f551d095ddfa3fdf9cdef8ee3d2e1cc71746a6d84a4c88af304f2f80885f52f5d2500dc	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-01 16:21:02.437717
62d19d549fe05537c43bb05fadcafccae5987402c24a76d3c426cd3434959af64f66abeca7be47c9327cd88609639d5ac221dd6a248f8e00b6a5866b2d6a114e	1	{}	2016-12-01 18:04:58.414023
a0a580bc17c47dee9586a9316c12f966ffd752ef1abefbcbefe72dcb8f5be25e58759980cf18152c9ae6e98faf2ed872db29627d336ac8b1347afd84e4f23f6c	12	{}	2016-12-01 16:22:09.869652
ceea65ed838eafb205ce2d3acf35f2181fcd51a39edfa225cb787ce61b8e6be463e4078d6fc0165b682e45ead82c136230d15a2581a52fd92c0f9445397a5799	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-01 17:56:43.79666
afc9cb19be46c7ba75296c74c55164ea68ac590568bf118c0c2c1399e41f3b4de905e67e42c251db6352e914db66047b158ce6d80cd8358340c1af7d1a1243b4	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 14:27:58.894707
e1938dc7f7952e6adeb4a8afb91fefd23a2e6da2b09ff951c0465f5dcf407ae88b24e358b3aefdf0636041cd2fd87f1d6a339f0b6b2a60ef441ca2a2c92a2771	12	{"username": "Kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 14:54:55.990813
95071dfcbfcb8f776acef9441a9b83634bf68b5493ab2cf985c83e1d65e311106ac301c9e9f00105d40a98e17ef620a60c01ca0140e4d004161dfd86d8a88f8f	16	{}	2016-12-01 18:04:33.148556
d3605262af37ee9713a1208c7d1c3c09672611adf7baa7d29d8df0792e9d6f7937e403d1edd7fe12dbb68388101137c66c9caa5f1ac1f6b42f049bdd03fc1244	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-01 17:49:31.73628
2c41ecba65d858cd3451fec93454e6c78ca373e190a5c746b7a3d3d786bf06440eda2cc631fec67978d9deb7d0ec99485cd051dcf280916e9aeb9ad2f46863b1	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 14:08:48.680445
3a94262d682588f77f602695ea1847a254c6f7072357bf80fcfc4aa57698f3e44841149bbecf3f037015fbb9fd403f73a68abac460cb5df53858bd7f07a46379	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 14:07:01.764687
7268f7a91854ce94f29c63f702e491e14feb27b14d3b576d2eddd30fb160e707feca3d83b58f7a2b3a739559184805cd2f6496c8714a7daecdef4b207d50aeba	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-01 17:49:49.050803
8f61bd6aa9cc163284778c12cb943df32bda7c3c778efc209cb3e01ea653ddfb7038dedc8944ca1cc08e8c9d4724f4a53ea5c5ea9c3be90348bbebdbf3e39517	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 16:04:42.675833
ac54cc886f2d3967bd80b0393c8f9ba334aa6e7c912d7e20d08abbf013e4742a11a7d5afe9873d5231e7edbe3ed8a5a7c18004a542ea63e133f7d04e3faa8b42	1	{}	2016-12-02 14:09:48.67701
fb377c12a8a8915d06cee3bb42d71989e414279778211ee53295dd3f77a6586dae099ba840ffcb08b0a815686f4157b569ec965e0c70332fc72277c4155f8d1f	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 14:07:06.366441
34602c26246fcfce90cb0bc30a22da5533877909292327b72e2790a741545b50a328bc2f98a8744efb5d3a3eb8139ee14df95b61379feebee4d5dd9a0a2aa50e	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 14:07:21.999423
96862ef8f346deff92e2a6398574e8716f5a17ee03daa370159623d892af32b47595d935a310028bd3c578d830bdda931557648271840d9c040d8cde94b6485b	12	{}	2016-12-01 17:50:36.091412
a804522609e12f0e5a3905b3dc48b370b595e648ce07c9727b9ec194d9b3cd3823e6774f66df0d107c3334da1187cda07493dcd9b12f1cb82d5b596cf4e64e53	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-01 17:50:37.490915
ba65ce29fec3dbbdd09efb0e8ded13bfd7cc14f6919d3cf4b9c2ebf08908763f9dc0e224dd7eea5069ac94ab6665e28a1a0964337ce0bc9ab38c96dc130d895f	1	{}	2016-12-01 17:50:22.286271
8caa5d7bd56971ee25f33d7ec0ac4974e062824243f1b70fad01009ea48ec62845590ef44fdfa609fee4fd100c0d437206e4a6f0b0730bd20bc96b151b00aaa2	12	{}	2016-12-01 17:50:25.535898
5245458d777d39507aeb1e75ba13147e198e7f1a4f33c0229bbf2d5508918e485bcc9c470312b0cd7470eeeabb78769ad6d3e19110b9a2972de3ac928832f12e	1	{}	2016-12-01 17:50:31.052564
dbbf25b8541d6fd9ee29b22440be15fc08273d45d703e812375e0236ba43af02fd66155a2f1be8b98674f83668009767613fa31b67f038f84d17bd01bf851538	12	{}	2016-12-01 17:50:59.368437
d67f5ce4ace8d090a39b174af58cc2cf44f96b6b9a72930596ef73eee0686a0a26ceca9dcd69f2a04db1ebefeb041526350710d3b8c2947a3e0b284886846c82	12	{}	2016-12-01 17:51:10.683575
988e07955dcca7eb691ba69400a7f64a55bbbdde7d03b5e473a0590f7ae8aec0f9eb8265fad8d299a8e04ef337e69dc80c9a206b5c1a1001be0637f20a3f5bcc	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 14:07:35.684505
06d31017483d1bfe73b5aa622d4d0a4101f117973cb7495c9baf49a69eb2459aa1985b1ebf2bd835c3b37ca428671af0a71f9c7e57c7701de9aae4136b1aa05c	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 14:07:44.895284
9100a4284981caa5935a14abe7a9efe79aecda285914cb2376b4685285e01c6662e225650837221626a9fea07e33b9b72a3f51e1fe67be0ac83dd0df44c6a106	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 14:08:44.727121
065f6af5e0a10ad9e24f702293542bd14eb48c30a7455ecf40950cada1e09b09b4c19f2bbc81a1d9b1e4965742974dc30955f57ac0e53cdceff8aed9843a5c73	16	{}	2016-12-02 14:09:30.708484
722b9dfa6a6994460f17486191c9f17350789021f10e1a5dbff86cf1eef732a000c61c048a9a4adb3d19d6c72b0f1aa742caffc21b82a592ba2aa6ca1988c50f	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 14:11:52.283746
5421a96f13b8a06bbe7cc92e81b8d4a24592d6e1c424fdf92470515493dde3d8fec0a859a74f06536fa092d28a792c92d5b94768b1a36fa02f2449b1c6e9349d	12	{}	2016-12-02 14:11:52.519356
8e2cbc137f228e55ea6c2198d7dd06e4fc3de96b89ce9695d2dba6d92b298350008723c04019da51fba85788e9fb19731e07b7e57968bce07cc2586b31ca10d8	12	{}	2016-12-02 14:12:00.09439
9d976ac032f3545a49b930ca2c926f0ff3f41b1f639365232b012b222fec55b5fd1ca265bcd6d081f8e66650ad443bf941d07eb2d3c07d21873b713e4dd9bbbd	16	{}	2016-12-02 14:14:00.19494
7dba6952dbe29bef528e36525f5e0d796de60e45602fa15f53b5dda3cde991f8ea8aadae30890b429f3c996bbb8b9c751cb7e0516ec2d6715d92b10c6427ae3c	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 16:03:40.95312
60fdd7c3666ebe6db7d0f9eb7c31a9f4c0128740a0c411fd8da7b3472285dc784e705aa4a225ee410329a81143a3e58f35343f1acc1809b70e4d8cc3dcb610d9	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-12 16:30:23.904315
af3305f3b7fd759f510dd1d6c0179c5d32e11de99c9a18f918268805283b3a36a8c745d5aaedfb6acbef3f7a4a1945c9bbb886658d62171bb40ff9ea9ca2be94	12	{}	2016-12-12 16:30:54.13874
fd31755c95073c4c7251c3fe3ea453d151e27b5de9b39e671eb8e7189d9931038d53d33e291f31feeb2a5b00d87f94af41a26cc7a711d218eafdab36a077a456	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 16:10:53.629467
f44d021223186ca9e4d2531b83868ff3f8a634e04f5785b0a256ea5a7ea1603aca1a678eb2f73d6d2d3b08031954027a2473922b8e8d6d5c1485e2df7a5a4f57	18	{}	2016-12-02 18:32:27.044539
d20f3514e6269eb1d13f9ebcc96ed30ed1eb1146a983cc03ab71b65d6e4cd3618c974b5a148f1879ee63290240d4919f533b5fa85c86210dd8739cff17346d76	1	{}	2016-12-06 04:34:24.934153
81cd25ebde87d8da0b5ea06b5c421829f2a8bc2af1567687c0d8fe2f3fab9316c7456e413b08adcac317459ef48d030fd41b9b2af4b3e344edaacbcc1a0a937b	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 16:04:20.760219
2ec910e293abd759d71785d43ddb86c2776526ca5172db4d95b5764db6996b9e0c24f7b65932ee348d95077dbc40a1c6f27459cd98a75df9f616476a5552a67c	1	{}	2016-12-07 21:12:56.354218
823ae360d265177186bbec60103f96a8a00a1112a531ab636e12243156096064180eb18daef3fbd9b99fb8c7544e3e3344d780607822a1d7e3fb5b060ff5d9f5	20	{}	2016-12-13 23:35:34.43768
832be60202a33ff77f303dd21081dca0c708b9e4e1cbab2a949106424dec82aa3f072f6f669ec044de14c73bdfd2be2c7bc7e4f68d2a49288fdd98b8378ab64a	16	{}	2016-12-08 17:38:40.946289
69840a29c1c71c42a94ce78b16cb15decf15cecfaf9864f4aa328795a523d4882e4af7d7e1f63d940eb76412da92be99b29115d7a1296755eeb58bc98058e3c9	22	{"username": "marko.parko@ttu.ee", "is_authenticated": "true"}	2016-12-12 16:34:04.917118
19422530db03384f14cee56705d06308a7c35a9a31d5dff3b4fa42517a07b3a88e345c221cecf7bc69f5db61a3294d4c4a61a98bb72a1cc74b975c45a240e5f3	22	{}	2016-12-12 16:35:24.823111
12ef59c6d37c0b4cf4d7f8b5a72a65d7bd6d92cb5c320b9a287069eb3f7aa78d2c45707de5fced325766551d17c8640a6768dd19bb0aa629df218bd89abefd56	16	{}	2016-12-12 18:40:22.187126
7f9d6f16577457cc16eb93491c982466ff7c8035be0887301827668152eae9c9a9542f33d74aa3956280a9cabbc6649e58d58ccb6feb9679137a13acd9bd9ea8	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 16:05:00.080658
d02fbae2f17f16fac7321627e97f380ea4cfa5fb1d27f3bca298e6fb2f933e367029a2b56ce9fab121cbdc4414d21e81871d81e3ff90d402d72b737a7deb1ac5	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 16:05:07.830061
948b732a1ad5d5454fb3967cf9d93d1f7f93c48f9abb3daf957e86c6eef9b902c0b6590bfa474073d7ccd8899831024932d877645e7e99a5fb86126117e32212	16	{}	2016-12-02 16:06:32.124101
a05ebbd936961ce9d411b2fe74547eed68b7298bc4e3296f6ea152f370d27a0d879facbbea57e44c45135c93e41703b350a6c0e12c9f41fdf5a6a633a980b8c4	1	{}	2016-12-08 18:17:02.02707
b5e6ca3328e79b7dfc00ba99c4110efbca77d7f05b623d0b4e8704bccf60eb8330cd9b9c738a3f92146ecfea236d7e79ecef2b793cb6e360551dbbdefd24d4a0	18	{}	2016-12-08 18:17:08.278346
53ec9960ddb28047c5016e49ff5506fa233ad819c9ed23cdd6de8e7845bf1afeb40716407883df1b3008cd06bf3c5b827b68c0b79a673fb4b93253209fa6fc5f	20	{"username": "erol@kunman.ee", "is_authenticated": "true"}	2016-12-08 18:18:08.783701
ba100e23fc801c7fc851f600bdd10f8a20fbe0b3baba2e370fe569a9c100e4d67179e4d47092d4f589fadc629d6db6412919da26c983e25c5c3998b3b1ab8f35	1	{}	2016-12-02 16:07:13.033349
69231e807dbf3967c3e5606fdbfc588bc5dd97031de8feadd98e476bad96ae11058a00f84b496060a355628dc69dc40cc3c212d7da0d0b92e42d90be5b4a5cde	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 16:08:42.592138
526db4799be288b91e1527c77671cd69f7641a3c94201ad87a691a8b127ef7a1baaa0645dfbbdf4c6b9f68be4865c323661515616d4e0394cbd0bf6517cdee97	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 16:08:56.335348
3a1f44d543c7751d3ea5471c633c887d7312f2a313a9bf2be871ee1c537279c038dac46140154bcfcd6829174a748a24006727edbc5c21d6893f1d6f957197f6	1	{}	2016-12-02 16:09:00.643867
d2799d5ce469458d20c7687df0a846deaebb9228a4981db12ac381c1a53f956faca761d5d59c08b8d8fcc21febed94c35b6e8f04180bcc0a6d0b6f712be92ece	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-08 18:22:35.059498
35dce6add351feaa49d5add8fc8cf5f4804105ae76683d268753bfcf31724d660c5fa1c898518aeacc24e3a4a564751e0270565edafaaac5266355a500f5edfc	16	{}	2016-12-02 16:09:03.376087
0dfc2e2294c5fea45f6da337e12536cdc5f9c8fe6ccbc2ec16d452d34b6030c0570bac4b6acfde69f6b6ec55a219e2f1d08d4e0d565698973e629092b0c31808	18	{}	2016-12-02 16:09:06.730601
f1050752acf1f61178c94e4c5ec7c0a6aaa29e57c338948971b9c1017ad72a41fa0906215c4ed2a8b0065cfc5efe58afbf2f27dd868ad020acaeb48f76e19272	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-02 16:09:27.755448
edbbad696b45ef79547f7702a8a465fa2e8e57b293aef01baf3d5061b3c1a64f8c08ef8135bb16df5bb7081bc557e5c0c1eca574e798fe703b79e2df665deb7b	20	{"username": "erol@kunman.ee", "is_authenticated": "true"}	2016-12-08 18:26:51.347491
88c4e9564483b6c0cdda8127f01bdc78b35660b60c27ccf7d383bdb545b7ab959399a18c8bb10399830f57aa759e4d7fa5efe496c2186973adfd0a336222e85e	21	{}	2016-12-08 18:28:11.761042
776104173abe644ed3f74c961b9de02982545bbee8b42653c4f82bd0196e839bbc62335a0aaabc010eef2e3fc52b4321da830b811f751e5e0629ae329185b2cf	20	{}	2016-12-08 18:30:05.468592
ca53ae996a0b5a103197fdf9dff4503ef08b54966737d975727d635e7b1fb1656815db0618eef88eb427a0cc94abeeb2de18f367f0d7e8a3806940b7f29251a0	16	{}	2016-12-08 18:30:09.242423
628f50447dbd2aba33dd7e9994b51e6f953ddd61ec20e9158710fe9fdc81ca6e4d8fe6aa986b3856b86b9399e348fbae369273f7897c03d3d07bf7468ac0cd28	21	{"username": "mari.maasikas@pood.ee", "is_authenticated": "true"}	2016-12-08 18:31:01.382828
7c85af53078c6d048555f0d6c3979e5c9a19a7d599fc9cd952461bd200025733d48bf8f18badaf7a96ecb86822d9cd27cae1e0e994f0d10e91e2a0bf6f4b53f2	21	{}	2016-12-08 20:11:05.053154
74b394bb5e595da58c16b2dd7bd95b83864ea0a58e39a3f43d13a69fd8e0dfb43abc452169d23f067b276feb6151701969e770b6408802e304bbed326a0bcd0a	1	{}	2016-12-08 23:55:06.976364
1aad479427b424ccd744317f4eb396e5517d9079c0e3cf24c0c04f09d089ab957f57c6e9eb51b3e6cf34ba483a5aa91bce43477305155d21f59daa4e7b2ac669	1	{}	2016-12-10 23:38:33.999828
3202acd8135e3bf9b6334e2db0d0a7fc8dd9a18d3f96809ac34346c01ae34229d07d414773dd9058054ca348bb8395cfee14ec5cb9d98dbc3dfc2f474947977f	1	{}	2016-12-12 05:58:11.66452
6390a168ceadacc76d35d84362b60881a0c097a4c2124b7e85a45d7dc0000b4cd5eebc943870492b8c144dbe7d55bfd1a6b8379caa055a700355f4b32a8d68c0	22	{}	2016-12-12 16:27:48.324124
60f71ea3641c0d204b92dd023fd7ec7a3ea2a5d5c50c7d5c080b817e49ab1ee54171a9b4e4ff42e4d07fca2e244181da9d871075fa6330d64bebb4504e881798	20	{}	2016-12-17 23:49:18.329739
1a354e628e2f56d21b3add33dc0e3ec259a3cd76551333c996cb9c51efc51fd536b561b13c2b5b28935a6420de460f2bca05400f2ca2b09b536b34fab5fe2322	18	{}	2016-12-21 13:22:09.387877
01d32286d1656d11df67579d49d83f756ac67c09889cdc7e6a5445127c280f9ea104dbd3e9fa689cfd39affb2afb0cb7f6119c2ae884015bf119a4598152352b	1	{}	2016-12-15 20:41:19.382136
645cae22b8a5860349d81713a32f207b2589a044d93a4ba00b40fb0322fad0330b3c99b7c49f9ac467e4e717f7d61b0b4139725b08b3b883dbf0121ff19308ae	23	{"username": "mati.maalt@hot.ee", "is_authenticated": "true"}	2016-12-15 11:49:08.437602
cc3adab2fc77638e53c4634b9026e98170dcd5349cd7327f79b694c61d306dc0d9eef17a2f36a840296ac31d1662b0a05ab7b1351786feaf73dc11c612780fc4	1	{}	2016-12-14 07:48:05.504004
c46a4e642f3ac3af40bfe97f56b1da6f907210d0648db98a555dd3612351b3e75abf5ca9e0bce6562835648e027616178062a416e203ed9af88ddfcfaf1352fa	1	{}	2016-12-16 21:15:13.871978
9850054a862c9fd921351bc1bf0405d625da3e626e1c718d7c3e5ed1fe872610d188645deb4927859d85bc381c2d88eee5866df18d90b3a9e2b97a317b047257	21	{}	2016-12-14 13:22:07.830397
07100963a89c48509b17c424161509db4acc8b8f0af7d5f24160d44a44635784982084c748e89ecf9bb6a5b6e82ca8d549aa920ee7009013d2f15014fa4cfb6f	16	{}	2016-12-14 13:22:31.805975
f743e01733cedb0dd833d656bc632f79e1ca297a1f227e7c9ddf7a25cbc578a73bafe354d18479a1c803516455a21455b91e2c7c8f2c6b84bd91e682d5a4e58a	20	{}	2016-12-17 12:27:48.594579
3ae205a51f9468a1c29623a13a04cf27bdd5f4db1e726b16d0aff277287757fbd15d47daa67a93bbe12932f69d442a12765808706f8225bc402adb197f459cc6	22	{}	2016-12-13 01:33:38.410314
9039bb5829c694c76d0b744b851075772926033915ae67b73c2a5444b43ecc55a258ad36fba5d1c0f7093ff41a02ae210262744ecd574ddec80671740566a723	20	{}	2016-12-14 13:22:41.634053
9fe6dc23747a65ece0e44f00c8f408bb44af35c913100447c3e629f630fdd6a0302e63d1079f1c81b2a37de41cefaf72a6637e69cbf4ac82b3d126c144665558	18	{}	2016-12-14 13:56:11.61753
6b71e3745ce80fc05b30b224e98055e8eaa933dd6cddf6aa3f4c4a507627e714f8a25b5c4f7e2c8cd510a7746c3169638e7d48bbd92ee9e96619afc55ba021a6	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-15 14:23:48.477008
5a1cb686bf36a81260cf201b9b41a4f913f945e3f0d6321024eb5ed9115991109b616564ec0335b673451f99d15b5dd4bbacecd9c6c8b1b417cea87caeeb0f33	1	{}	2016-12-13 10:06:08.543233
77e349ab6b7ca51f3304041043e9ab4050165db0927c901a675f0bfd92ddfac957775cb0957ca91a9772d80834642ba7ca5b59c44e4c0ee327f9b9a084698f12	1	{}	2016-12-13 19:31:14.262245
324f1f341efc5b4e1d6fc833e405773316eeb17ed1ed4cd8f40af8d943013ed3d7127e75972513d99beba6d1d0f0af7d45e6e3eb46e1e9d94e8144796f42a76d	20	{}	2016-12-15 14:27:10.644082
d8a511d52b4a7db1b7672d357ae25ccc98ddeec8df377cba36de799e17ac222d4831f64a709dd83f7cdd45ccf571e72b125279dcb93229481d78c3860c3a5d2b	22	{}	2016-12-15 12:09:09.521619
c4c578c7e1ba5759dbbb5a15f11296d71c7af24858ee54e1a7d7ccf492d1c3212c5b69bf3cd44194f959471955d9d9bffc0272947c103edf5c8668a3ac1f6c14	20	{"username": "kena.myyja@pood.ee", "is_authenticated": "true"}	2016-12-15 14:34:49.789302
637c9a11018ec33a009441f5c3b0eaee09f3b74ecc6119df6d8424468bd0427245bf3e0126c491be7428eeeb8a5d7abc57ba43b986e99591a474e7c6df2ca544	16	{}	2016-12-14 15:59:36.289612
d331264dd17a94a35fdc4e6a8fa4d133d8f303c24d889f83060c11c6cada2865684d12a3e5e5155e0111c6a46dcd4266c657297808b677d9713735f0412b1641	20	{}	2016-12-14 15:59:45.88032
0b6301b4a413b280cf364527714d3b6acf073fdd643fec8e50291239f304ccd71d9d1c0b9b62b720e8dd8f9c01ffd85eef18d198a2d56c76a85f67c1ba93fb4c	12	{}	2016-12-14 16:49:47.816479
e4f128e04fff9458abf0e95495dd3aab020e1ae042e97853a27a2ee7c3b66934f7e847f6463e09101b2bf3a2cd7abf6297e0fa7b703443f12d3c2d65ecb17e2e	22	{"username": "marko.parko@ttu.ee", "is_authenticated": "true"}	2016-12-14 16:50:47.009702
781fcd942ba08fbf1180be19b89bbfbde6e890869a41c4e72d726031c3c5b7cba8bc1b63e8827438bee154c90d48a6fd8f31bf9a89ec529a62ea049cf7b6d67e	23	{}	2016-12-14 16:51:01.839482
07a8498403d09537c7a72b389a3cca5b22a64d797c683494f1155be620527d25b2f0970e8f9effc16a8d70316582caaf7d37f66b8c3ceb735a30bbac49601845	12	{}	2016-12-15 12:11:02.347316
96530abeb4aa9b52d230360acadf7eab9c1cba34767331f991bb1cb58f255fd0c9d25febfd2182b3475865c9c5e3b80651e1242e47a91c2da870dd26784b30e3	23	{}	2016-12-15 12:11:36.0965
d7d3f5c0747c2155b9b354128e04a5f85e68d8561f387690a8bf739d9ed4b004b3186a40e810773fa831871323ccc15f73024308a5d24ef28735792f5610aa45	20	{"username": "erol@kunman.ee", "is_authenticated": "true"}	2016-12-13 23:35:26.771205
60d16d0f491f4fc6a072fae276ddd1ddc48c1b96a4f75b112ec11e4a7816fdfaa63bd8c8bfacf15457c5c4dffbe5e4d8b65734694a30feed344a698ebc8c1c37	20	{}	2016-12-13 23:35:34.515501
05e03acd022bcea5d01831fd58cb4640feea59dfabe9fc9d9c30e3389d05ac38e50fc0543b87ec9efd3f22017ab4b173454fa06b8018ef746955c95d15b93ecc	20	{}	2016-12-13 23:35:35.003993
cda9efdd0510941f5e7a8d32e06199d1d9f58acaef458e96aa668a84871b1c144fcdd2213eced1329827ebd39359d2a6623b0062c0b05ce7616b8f786c591a8b	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-14 17:09:08.398289
45fdb20735298049a7837bebb96cb7f63a158d4c5e098c7b31b9305dc26938db76f8477137010dd73c154f090a75cc276012aac3447a854b9278a206d05c223a	21	{}	2016-12-14 17:04:11.103284
3cf73d0b41c8f7c67775f9d909966be863b8249c10839e7ab20c76c5973a982e94f3b1c0f393c9c133106bb96d2563ab58d7c744f55fff951d172b7cb0e1203b	20	{}	2016-12-15 16:16:18.920167
a08a622cd8ebb982be319ef5109c8217e27c424a7d213dd6927712a3eced23cf361acce750715447b7e15047e42416beff3f81d61d027d4dfbe06600e66ee6ea	21	{}	2016-12-14 00:58:54.580657
05c2367197fb3649de86f2d5b5701efec1caf43d2510a647053f295249bab8b6f9c26362998778744b8ff22b64d04e2ab5cab2a43cff8f5aaf762917de9e66bc	21	{}	2016-12-14 17:09:40.141319
f399a7da06f18ecd1d688f46c68d7d2bd3ad9a38e9281c8b6284883b613d650b625e9b7d9ec10f8d93eb235622773f3c8f27ae557219794ca00bca92ea675d02	22	{"username": "marko.parko@ttu.ee", "is_authenticated": "true"}	2016-12-14 17:10:08.977727
56c705bec1ab76474a35d07c89fdf87ca6fc6eb8a3f3e1fcc1f38553c5158fc8987724ac448cac57bced74bdcf89e6a2e94b845421744cf09d251535b5eb03a8	1	{}	2016-12-15 12:41:59.921056
0bb0512757b77aef3a414abba9af24dbb6902e05852c4d3e6a4b2b51fb0b9256bf762c9cdbae05460d5c9ff9747b1a444cc1dce1f3cceed924b976fadf6a88cd	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-14 17:10:45.499339
730d65800765d5fce9c27216e8210c0653ae282b5f0e89657ba6540492c9b3822289a516d92704c28733483a667d1add2ccd0d67e487e56b14a0dd63ce55f26b	20	{}	2016-12-15 18:04:48.446226
58980173fe6bf40707c6b62be39a4c7380d31e7396a2ae20aef32bacba7ec9d719e1cbbc71a5d8552f62140ac191ec6d00d17384d395b1c4c203f13b9e7c73ba	22	{"username": "marko.parko@ttu.ee", "is_authenticated": "true"}	2016-12-14 17:13:09.582018
ceed561fb00c7e6e1c79f839506fc191b16b0281b294dec08438a3f3d2f5a3834c3e4ddaa897477eb3652d68ebddf27406112016c1fcdff834cc2aaccf5fa294	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-14 17:16:13.320958
029075e0be73e046e0682f63e9062ee3aa1195fd5ba7124824a9b50f1284b2499460fcd017627e3e714230d9023a93041b989ec60234fb96741952d7d442d9b9	25	{"username": "juhataja@ttu.ee", "is_authenticated": "true"}	2016-12-18 16:00:09.088875
2aab2864139b7881b797a09a9ce20a4cbe080fcf7a130d0fa322e5b2b3931153f657dc94d2a8dfe0f0cc268123e8be287f9b22eb5c01fe719f5648934087be0b	27	{}	2016-12-22 21:34:55.22744
190838895806f67bf27f85a631f93a46d9980e7e85d2a2fc00f5f34142041c58e06cef111e2910c4dfc8ad9e6e42d61bc0d5404ecc0545d1a0cff9341c0f6634	20	{}	2016-12-19 20:50:22.782657
b39b4598b3a12c7a76296fb5f2678c23b91e546c89b55599d746d9827028828f9e236057a365dee2eb9c0767fbb272589aebcf1559af4080bf3e66ec466e4f4e	20	{}	2016-12-20 03:58:19.686175
4a3dc3011b250cccf650d1aa38d8fdf32264ca709d3a990447f5ea4a3f5cd244ab9bb8f4e3010a2e48acf3d2a20eded8c7068ee2733679c96f55338537f2f52e	12	{}	2016-12-21 12:47:21.05985
b3e7a75d81b5f82caa6ff2eab55a9e0c0d2fd52bef18b549b63b88666870629be94a038b378f3d10974a87b7f0b809b611c04446466da3e924aee32ca091bbd7	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-17 15:13:20.245601
daaa87626a4c14da4f6fbdff63e352680d7313744ea7500a9fed7c864c9f676f617f2b1e0f3b38eb94c33f7cc26637c9dec69cba2c9a04d8095219a8d0e42572	1	{}	2016-12-21 13:21:18.741327
fc818027b629c889341c7c1050a92e5ec7d1d531b9af4cbca4625a0380609e702071c8da1ae0d138813e6fefd2d8bb2e1d5c3be8d880111bd467439c615102ae	21	{}	2016-12-19 13:53:31.305984
13de2a577e9c614d2ac7960336f78f3600eece502188751629c791fe6d1a6f6ed8f399d5dbfb65c57ce9ad6105ed697aaf3cd95a29f25af4a7002976364000ef	25	{}	2016-12-18 16:04:39.09039
5c0f20705733afd1f10c541090a8f9e349b454730976a6bbb6518633944f3da1a5474b3a780ec3610e0977d273b614b99e1253892c2020145bc58b6a43eae743	26	{}	2016-12-18 19:54:20.536339
db5488f32e626e426cae906ebf5e32551b4595aeb03a1e8efdab00096b006da15198fa6c0a547894ebc92829c2e4569951837e77a3b3cd10f46174a04d7a8075	20	{}	2016-12-18 00:47:49.503623
ea986f57fbd452052c501f64f6cb21ea5be48d6927ec16b27d1228bbbc947ea7ce7be843325f42fa9987f4522baf3b775751c0d896e600168dbcdf37546c1fd6	25	{}	2016-12-19 00:18:06.223858
ca7036ef2dc3fd7f1c1901366170dfb187c958037e7bfa02881643cc2dd09ae6b65f47eeb09e4f2f3ed8afdbe3f3f988237e06555e36d0b9d8ed91290e4950a4	20	{}	2016-12-18 06:21:55.586202
5a0e7ae016907f6f690c45403c3bd6457a1e9a3fe6f818dd7d7586baf21e66cd2345dcdeb0503b6f462bb5d500cd054a57f6497a1ff36c361e098dea70f3ad3a	26	{}	2016-12-18 19:55:04.046237
0aaf9c2ce7db2cb92bf944dd092a3ecbdae3817d9e5881ad11004e282954895d4bd5e9d229ef47277db4e9b30b9a717e923eed8bf98fe37ec1beac4e300379af	26	{}	2016-12-18 20:07:41.41416
f461dc885a2f4e64bf5fbeca31841b39f9a62707e9f403c355e12ea1bb07a4a7a0da5a7662c0f51db3c6b3c4164c9116ce8810f37e4bb5f5e03f8aa96baba7ad	26	{}	2016-12-18 20:07:42.432336
ee0c1aaea97da6722fc8b660228c71c99073ec8214342b9bdb527b5d49cf78900efbfdddbe5032579424e53929ddda4b5ab1a56ac2ac4dd3a0c491c7363c114a	26	{}	2016-12-18 20:07:43.963806
e329166d2a4def20464f58e54f58d44db2632a5969b4f2fb34dc9a4d7358d8cb52e0d1131bdab7e25be49494f515d6d4d006afb047518a6a46cf09ed40159316	26	{}	2016-12-18 20:07:44.315022
14e418d69ab28d80d9bf41270af9b9f73f9dec2a776430c56c0c7c88d290fcfc28e52d83804a7588dd6a72f454474289f4f968bfb600d7b94c70ee85c63bb8d7	20	{}	2016-12-18 01:00:11.434681
2a5351046bdee357699fd475091836a6c4cad9a8760632a36c758d26ac506869d37615e274f7a1ab92af6a561a917562097f64a2ecfdac04ce035e0a6d2212ac	1	{}	2016-12-19 08:40:34.385966
1e61f8018768127d2dac3c92ec802d0a2403711af127a4163748191289276fc62c202e358261a55929e5bd7603baaed4915de9deae031128c98242682244f3ed	1	{}	2016-12-18 12:36:04.112243
a7f0a8a39c760d84030a45130c4db023b247b25a23023030a3d6f1578252228ad4fc249c3721356fea014d5fbb2d4b88f966b3b5c94a689e993bfea1e7175efe	25	{}	2016-12-18 19:01:21.588418
86d52e19618fe81ba1a60e16bd886eb26a5bb16c42316b4aeef17c96f62019d87f24860a739df296f18f70b198b4fb7aba88f3f0e6958e6a725fe2a716d8ccde	26	{}	2016-12-18 21:10:16.047815
db607cda77794025ba3e292657dd0cfbee1850770d1a7b1053e5efb69c0efd1ae0929a6f0bf985d79a7bc333202d6c3fb808dee263033e77f66cd819c6637d7f	20	{"username": "erol@kunman.ee", "is_authenticated": "true"}	2016-12-15 18:29:06.381291
793877befac5952ee9eb21dfe6ddf43b200fac637fceb33775dfdd4a9495bd77160c5c2f617666607e2629ef337c40ab77a2556b4e246fd0971339642d8f8633	21	{}	2016-12-18 01:24:14.392411
02cde9b669bcf92483501c22f9c8116fbd219df843d8e0cf1239e0c56e4824613999775d794549e28acb979602cefab6babf144fa6830aea204be88ba3369d30	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-16 13:24:00.347361
1d9dc8ca463391c2db5f43193380c9cbdecf205fbbeab615638bb4c81d2ff0d5af908e101b79b9466137b250e6edaac73c13b6868daca3c3ad94943342280395	20	{"username": "Erol@kunman.ee", "is_authenticated": "true"}	2016-12-18 12:51:43.692185
8cae1c8438ed45c603151bbfe6a9e9340f03f2f72f35dd3df5433e1df0a1afb5e5c23bc26fb197e017aef7b8d33697d1b737fa95648f2b0e68ef7ec1088b4f87	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-18 01:26:13.590521
ad45e61fc394b75df72312d3716afbd9a06e77436466dcb6dddeabfc331ab440b2a35d017ff00552f1789be0ad261dc40e2102823a6908f5fedc2d270079b840	26	{}	2016-12-18 19:13:51.863165
c7ab45f2d80d31e2a5cbf3d2b37d06b2ad3bfc698b82878d38e99e257dfc702021dbd06394758bb1005c228c0880f2ebfe11a988c515013d80cff1bec092f9ab	16	{}	2016-12-17 13:17:08.669446
ca5d60dac672f5da1d40708691436fe2e2c5caccb020b66bde6b62f275db9279a5ea06d0be848f06c9b7d765ef2872872e2b2a194a0bfda7f5ba0ec662dac07f	12	{}	2016-12-18 01:28:19.691392
1b20e847f7a1593216fb8a4c9ba665d9046074bfa4ad9e12867936818bfd2a5cd7259a1fb96e2d0cd6e29f0521c67cef34d2635e148316feffa0ea495a086bc8	1	{}	2016-12-18 01:37:20.94806
8aa77f7bf8d8266341e806d5e089afa67ceea907640b51804d081d83c517bb1e2f3aec919937ff845ff68f55c6a1f6d1cae0aa1a264f76ce9e31d62d323393fa	1	{}	2016-12-17 12:32:15.310858
500cd08d99364c74795e4540bbd5ab614b4327b273eb0a754131cdd777785cba9bd55cd27a928d042b559bcd3f8e50ac494f708a2a9c3d03bd8663353b560684	25	{"username": "kalliryi@gmail.com", "is_authenticated": "true"}	2016-12-18 01:39:54.390409
0769c094622084d6f57be5bb47498fa10b1299d03eff73b375b0042432c6605c9d75088cf5401fe92b45efb51b8efc8db252fd9e7b4b7d2101c627b8eb969144	20	{}	2016-12-18 12:58:13.739844
f73086964ea37e0f8069d53cc6faa8cc2e04c0d84c17ce426b45bf63e8ec0dd0beb323914983a416e2dd1b3301c0e1cd0a1f761d873ef843558f3697b399947b	20	{}	2016-12-17 13:17:39.578502
54e5378ee71c0a294ecb798089c36827e695bce535e67fec269bf6c0a7d1991ccc1e9e8a37fc5b572749137535f366407b33940e351f1625759b32d4ab3cc3d6	23	{}	2016-12-17 13:17:44.57559
43990ff2c087cbf510a504ec7fb2da9a4be94967bed7ce932ef25f18f1c9c6f631398a80094efa44d1c20fef0a173f7eec0716c8b687989d17929a3874bb4a44	21	{}	2016-12-17 13:17:48.178319
91bbeb22370f05aa207fb0c0717999ea71f5d62bbc1ceeca39824a9b3bc9bbbc87f2bf3a3040cadf3c9cb74e974b16b66becc43508e12734ee01d75647137914	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-17 13:27:49.309016
f086f57b5aa1384aaf98172caaca275225decd5fb5a4874ce9ae6b113547d81458fd80c130b79e2004a7e9abcc70729fb098cd17bd6eb5ad4765323539f8ec79	26	{}	2016-12-18 19:33:23.008158
c4e7c27527e8845d9a2546c9511ec875714b5814e0d9faa95e63d804e050bebd4f605e8777f7c82525ad946427cbbf1e357e3d9fbb7de880371dbd21992bb939	23	{}	2016-12-21 13:19:51.362059
ca221ffdb07baf51ceb494e9874f4df08f09094977ecd1616e90c14a2875fb8e852daa03c301d5fb25b60b50d77ae65b4ddfd7c71be2f3bd2b9f84bd98d7e52c	12	{}	2016-12-21 13:21:02.560255
a78556904727704bfcfa547f920197a67d98de4a7b008d4b5eb1ff761a024b5cb5cf34526a6e3fb2cdc81fbe9e9548e8ea0719ebaec91cb247df19b82f658480	28	{}	2016-12-22 23:49:44.224277
0054f70f85544655826650fbb451fda766ca18cc312d83dbc8eef57efe845cf16213db48a4a4ee5ae39dad14c93c1a01b9207337b54e5f7ce8a982e80276c87d	16	{}	2016-12-23 18:58:57.076073
95eb02242cc7cfa6085e97d5c8c4761bac7ac9c24adeb6c5c2c2895ab95127de634ded99e39050202854b0fbee13951c67d11c61cebdf6ed33870d684f51a96d	26	{}	2016-12-20 16:15:31.579339
8f2d184fe7e20ff7e3afd36d6734d2ea7f0438885006a188d37cf88e2644ecfe0e2bd7c5c1c48c6afb5e7788d94bb86c41d734c35519c78bbf5cfeda1f73360f	1	{}	2016-12-20 18:10:31.514331
0e4a0e12bfb0d44e55b902c7816cc3d982de5e0dd7e7d88c51994f08ec0585c5fa2bc12ad31a57b7e46128ca7cc701ae2dac58674ef5b08ca024bfa3894cd9f4	28	{}	2016-12-22 13:25:37.252556
84946078402a1d6f1348cc504a087da134a22d8661c2889b35d404ebb3afc316e6e9cbee9a1782eb7c932f58717be5f961bcecc6e77c1377f25c5b8c792f1688	12	{}	2016-12-21 20:04:05.987269
a1ddac45695b65b6df18233c15e27d5e84b9f8bc45bbbaf41773b1299f6c57cbea0019d4af497317b9d71feb5a5152cab71b4c442f6afaa2948420acb05f5633	26	{}	2016-12-21 01:08:24.455613
be11a24d024650c801f21b7869c45ba70e1cb913e93e6b469ca1cc1c1ebcfbab097e1b229f931c6123c70e928b3f9b0f1f07913bfd779dc4882d28297d5939f4	26	{}	2016-12-22 15:13:43.002661
684cc13a166bbfa858c8ebc9f3b83231b65244c77da5e5c2cc7f9de7937b32dfa5ff2e0e4644f868fb4b6463a4968a040f8c00e246bfa3784adec8e524fb0d76	27	{}	2016-12-22 15:43:09.229171
f2e9318702253f3497ccf3b767db2cc80254e37301132ce5efe1ae1bee5d6b5b4b8e361065e4d7be42e73358f7a10c7f974ef3c29bfbd93eff98f82d0491fb8a	26	{}	2016-12-19 13:51:50.474926
bdfff26d584284e100531ffba8c459a1427344ee35fed3ba8cef4f721d488ce9d6d1adc228da7ff9b6a8683e4aaff08e6eb9376b7404b86afc5b7f391fca1329	16	{}	2016-12-21 20:20:23.399726
09392bfc8a5544cef601f3abd7f08af16fbd8d1564d16a220499ca5c001150901e084215a8741ca960e403c5707e622af5268a27f1f0e46725fc0734ab658899	21	{"username": "mari.maasikas@pood.ee", "is_authenticated": "true"}	2016-12-20 21:09:47.782531
f2d5a1051e43db164805961338c0c3010afb5791de7b429b529e78bfd8f50fc351ff57ee6d98c1d0e9601c0861ea6498ae81ddefc06cb4486974d08c99c50e37	20	{"username": "erol@kunman.ee", "is_authenticated": "true"}	2016-12-19 14:35:32.685366
45faf64661d321279d159e584089f8de07cd503e65e027553a540b951d7b400251181c848d0ece7e7d26f9001ba454aa24fb3a83579e648ef69e55e7784556ae	20	{}	2016-12-19 15:44:52.058072
3302f1cf7a5974f040cb9b59947aec4d6f167fc875c49e6474462cb37df88bb9c2d1eeaa5074d7b1f69a687a650b10ac8ad94dc8c17e8165387ef9cb4e0a6767	25	{}	2016-12-18 21:47:28.989606
281e40aea038bfc3f5095de7a4b63db79126fc5bd9de0e3a9f8bca36fed04896b85aa74656ebfffb2badf16804d19a16e94815a606a6c2a874b5f72e21d334a1	23	{}	2016-12-20 22:53:24.166547
7073d78dfed47d007c5e53f7c2facad1c57c4b7fa2cfa668170c8bf5e98b7a967510352f2fc31dcf9697ed7da86f53a2511e1839c87a2c7160cff83e79c27e4f	1	{}	2016-12-20 22:56:11.085604
309cf587e111741bb328201384008122edd37bf2edc4021069b2db9615b296ff8f300918bf098dc1401510dd7a684596c667c9e0454b3a714d1f5166e6dd764d	22	{}	2016-12-21 00:54:02.359383
321325c7866b467f3aa133d133d1abfae3c96a551f2172068a2874323840b0f47f2a4fb3ed428dcb5d3d90a26a228ccc77f43726cd7e81c0df0a14f4b471e686	1	{}	2016-12-21 00:59:21.204588
e94200bc75917762ca890624d86ff1b6484cb066c9b0a08077c8352e3944b81f7876470565bb5bee1ceea467e9375aaa3ed22949db95cfbd868c2c038e2c61b1	20	{}	2016-12-21 01:35:43.330494
e683c86a8b4956c09d99bdbd9b51752f69f1fce14482108f63d41f85616e016faf657d34644b768ba57373d055449874ac2bf1072547d60d5cc2f7318076d1b3	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-19 17:03:30.686887
910340ebf2ea88ed26b5ba22e99329b2c8a510468f9ab49c8bd6fdcf629a9335758934b27e671e6794ffd15460acc52dbbc44fb56bde9e9b0815aebcaf48b461	28	{}	2016-12-21 01:45:23.161045
620301ee0f6ba157d98f2d7094fae52a42dbaa7ca5d55dd4e60aab357f40119db7653ba8824d5115b18a51db12e142574545dcf220f6dee4fbac32f3100e723a	28	{}	2016-12-21 01:45:24.573922
da1e4868b81a84ad6fe4d3324555960e6071829c81dd1bfcf1f72ef5ce27b59d8bd53f9f8d635ba78536dfcf294e05ffbb2739c9cdf0fc9c1f9ea5c5030d1812	26	{}	2016-12-19 17:07:37.677745
03872c0270777f63729e8008f1921a0098e828ac8f9a7a654bc87064c4da8f9fce6e634538be0f4489ad56b96b1b84171802832eff156ded21e4c11e4c964b75	12	{}	2016-12-20 23:01:01.645892
28ae65f4d83adc4f6c57ca7247047a5158acffee583ae10fad62da386bc9435783efafe9b443b4c8c7a6cec09df304a0d4dc27a41d980bd057e797edcfe087a1	20	{}	2016-12-19 17:50:10.541653
4b9c015c51d2cf27707ac820c092370b25469c18eb22b964cc4d624165b2c2242f80917905a125ce8e955e26a3dfd244cf616543b4c209efcc366cd655a0b38a	21	{"username": "mari.maasikas@pood.ee", "is_authenticated": "true"}	2016-12-19 10:35:05.794486
e81f92155c5fc6bd81b9575a8f3441bb78df21a989ef36e920f5b8fb377f01e9d15475db3b4b0d9413bbf46bbcb5686737afe34aebcc515d4143a94d393db857	1	{}	2016-12-19 18:58:31.254289
259db3873942c981f6e688ff0a7a382826f465ae443113f1d15a42258de2fb547f8c1647b6e49ca5588b75dcbbc276522982f7c2bb86b5fb5e422232433e49bc	16	{}	2016-12-21 01:02:46.969574
c65f3e087700ee3fe11e6a23ae816b310f731617380cb71ed684fba5798e38cf6b83e17768002ab06aacf72410da7ec728a3a7db48838bfc1f9e2165fa30ce1c	27	{}	2016-12-21 01:02:52.0675
d3b0b83240509a85f770cf2f7f174cdaf994101e37b578b2a7ab841d126da67a46efb8bda13d519ca3670b11a2ee000003c183b843bdacbe60dead327939f25f	25	{}	2016-12-21 01:02:57.832612
78c48e71232b29ca4b1c1128afc537f5bf439a52641326773eb8f7b1a0759dae34aa6fa9bd08bd58bb4fe8cadb14c25f5e76a2ee33b63138b67debfb49b03819	23	{}	2016-12-20 23:46:00.671101
c0b7212d8a4e66e728c71eb5d19e6e113e7667f0d7cee094eeb355719b57ba7feb4763f5cae0e5fece9ce03f736d602141c1268f6592a4db881522e5cb26d146	26	{}	2016-12-20 23:48:32.726586
686386fdf4a111e12b95aedcff04a9a8d06a8260b217d21d83d2850f780c01e642c34519837a338d257bb856ae72a33172fae86793c95f9322f0c0e0bab4956a	23	{}	2016-12-21 01:03:00.385972
fccbe08aba549fed2a9174b234614be72d4fd98f1ade5a57cb7b999b6dca45738c4dcca0a7f1d6d9b61747f7cbc0329a923affa9bbc26382216ec26de5ea6158	21	{}	2016-12-21 01:03:00.621423
fa31669ac23c618b58f18bac97b0078f143a97b45e76a37ddf86ccba13a523b501c904ca63eea0bcc43f0381c0a377c0fede295a7de39ca63fe7207899d8f5e1	18	{}	2016-12-21 01:03:00.93895
0465374734dd765f9ce0f9085713778610c01c9e45b620a8d925c68496ca30761853068d0296dfa4ad50edc2f199a21253a0ccc82d33dcd7452962ed716dd265	22	{}	2016-12-21 01:03:05.620533
7d00de93869dcb3dd804096c67914229cd8736f53816bc1f77ad7523078bf9a23472e45fa46426b86eee19e52be45cf9e75c0f3e67b08f47f58fbf8f746574bb	1	{}	2016-12-21 01:03:07.74245
ceb83a385826e66008726d64c6614a4f5aae8a694aa8e5f347264f3a759e71049a2b92245339aab36b060518d736bce22dccf7fee463786283b03c12167af5b5	26	{}	2016-12-21 01:03:44.324257
fc6a54cea7aee1e621f0cdc67c6666db45c1f14d603a1a75a6424305bb240e432d8b3b06ebc08a0dd2506cb8b6cabcda1f4692902d39626f9471ea4d59d5d695	16	{}	2016-12-23 14:43:06.083042
95f25b7fd2b3302834bf53be4d7c9af98993e17de416823c11ad39a0420bd9a8f4e8ff2a56a5f86f4b7c0ecdc3e97b9c34ff69ec42785f497caf9f5507fc3eb0	12	{}	2016-12-21 20:24:33.187518
48d68b5f4dd1e6b65640a1519818ff230fb47edda52ef649a92d390c1f896dad1cc18badb73255e74cac9678a09469f25c23436a995056d2c8b0171271c6ceb2	1	{}	2016-12-24 05:55:24.657484
5b121086f4143c7551c150803ea0f92b400c4359e6b170abd98b7378caca77334d69b85954d3e22c90da699bd5217ab1a1db0e7d61204b082a581b6a12b1db9f	28	{}	2016-12-21 14:43:00.569154
ac0c5ca957a71a68cdce9e6c8e43fde2fa579079da061066e6c48addcd318c144b0647cbf1bace248e16afe57668436000c93066d3f9430d68a3b7d5076ea221	28	{}	2016-12-21 12:16:51.78189
afa8f02042a79a64047a9baab91980b06273bcbcfe0d7231a5d09974c4b411aadb190d06d206466c855877b4fd52bf98d13f65818a88bfb55397e3a4623e351a	12	{}	2016-12-23 18:12:42.419055
633f628766ae912830ddd33cdcfc629a2705a85093e13f18605a370f130b136d83d72c7253be3f60608ce0816597382b947d69c1123208ef95fd3692d410d266	20	{}	2016-12-22 19:07:16.669874
1aeb9fc477be59869caf3c65bfe860d614fa64a32a1bd74b646843e46226b401e199aa0e90f75333ec7f1cc8bd50f25360b747fd862d774ed00e0c8a68121f62	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-21 23:49:52.910692
d417d08642cd88d2c18c1ff4eae4233b1d5413969471a8478fcd294b3411215ec6e605bb13eea0cd0222fbe8d3fbf9421aa6eb8624ee1798dd9f5de38b9184d6	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-22 14:56:38.612238
c67720e37b14d2abf286bb8417f35b77a5f449d4ac5c8b892755e4a822035075b09194fa0ca8bcf23b17397967816de5db91af5c8e48e9ead85e050348f9baee	16	{}	2016-12-23 15:10:45.012852
3f6e6ed7f1cdecf1589f51144fa1297e75e1d5ad66ec2875dacd17a64d84bc800bbe6de0f0839d21e4b80e94bac14c28e1e1674bef95fc7d9edeb22e6c00fef8	21	{}	2016-12-23 09:37:01.503143
ac1d13d146cc1bf0b45d29e3866cbf251b082950b5a07ece7171f9e5fa09bccfb44becc03c34e0d9e857a90c6f8a496d845f012fcd047af5574a08603f0a2940	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-22 13:21:04.419533
d23f7e1c65eb2d358aedfbb634341f4694a5507d58a8dead4beb0fc95dfaf5bfcc33270cd574f8b0ffa8d4f4d92396b176327f70cad1ce6319b23106f81abfeb	16	{}	2016-12-23 18:58:57.216031
74c12e396c3aa5197c41cdc782e800eb954ff1dd7e7491d8f70471b350b7dab2e9ce5bc39b4c936c9fc3939cd6a17a43dd83f3eee5217f2d1bcb83a544accde1	20	{}	2016-12-21 12:04:32.320907
3c11ab41cafee024e6ec58e6d85e92d85ef4d58a51c5b8bff78c91d797abd5694e08957640f941b3ab5af316918a0a8e597e655b8e17f11eed7e3e2fb52be3a9	25	{}	2016-12-21 12:04:35.267788
3c4232f8089634dc2e0dbe569c41ce3c0476691ce906241e1d61bf21f8fde2f2611f3c729b20a4c2cc41457d4ddb1481390e8a0ec262189a55ae477f6cb9454e	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-21 01:21:56.775452
3f70092346a65cecd78c1912d344cd7620285071abb329e3a80b01add839e1404c124fa1068e19ff796cf011fd7567e8b1178d1e4f7d425f08a2e9f904b1b136	25	{}	2016-12-21 20:38:31.772315
010ac5dfafeab65d70170591a8ef6ab7f4306b8a86fea857eb61d1808d245b5e3155587f454f52dbe43a04b9bd89f80ff2b5c66460ba085a0cc859a041e00bfb	29	{}	2016-12-23 11:33:14.821256
f9b2df1075ee43e53176950273713229fa3cdf9769fe5b08c2bf4865f22aab720fc3fcde2c5664c7d13bc3fbf1c204717622b44c0c0fe316aca1b0c65fba0dcf	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-21 21:51:49.256028
1b7bd9a92d5b9431ebe6a70892b2c286a41d649e29f1ecce5551575143fc56821fc1caba84d99d84dc888ba93401cbab51d962a30b7b33955f26eccd68addaa7	22	{}	2016-12-21 13:22:23.556896
a7f4db2207593a332bf3eeff29dc046af2f8ccb3e5363da4878a9da1858ed86ca5f4fbc3d9046c1c23fe000a1c1673472c2a1c813e72085fb8fbec1804e1bcc7	28	{}	2016-12-22 00:03:48.74491
fa6fe18ca1970f645f2ee92f363c6a84f7e44d6c68ea8a103354d79a2bd5cf37676f4d381b1707f7a67d0d556102bda0111a2a3a590e084afcea207273bb14f2	26	{}	2016-12-21 13:21:27.709423
8a58aa558b9c3dffd3b6e7ef0a9923f1c7fce30229ef584893ffdaa0e5804f8f8e406fd83ad33063314b9de14d49b010e3f7f2fc7ffb358a95fa40df5ee4e2ae	27	{}	2016-12-21 13:22:12.384379
5eae9a82637656f90d67b594a2fc8f476eec271ae200c729f0153827a5d614b5ebb8337cd94cab5f2bf6f8c5360cba18a5979e99c199d1eefa2cbe9bd56bce0c	16	{}	2016-12-21 13:22:14.853722
7cfa588383d91dd6d08f018a1ea523c8b5d4252eeff5e83a1732af79c2f3a92fad76b4c942d9af7cd946ea8d6f1d36d8061bee6007df334cd297807b8e96071a	28	{}	2016-12-21 13:02:23.837427
52e10f83a61fc8cebef0e60185c79795f61c1609a2cf58953e658ce981d1ea8bef3ad403fb47504172ad6c8191edcb771939b26768c298f156b575ad3e5b24f2	23	{}	2016-12-21 13:22:19.184452
853ab2b95a79e72b9108885f674eefbb3566bdb0aa02784213c133571b2350666b2521e058da72ee26cbb039b4db663d0d1419bcf8d202db318aecfb7534990e	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-22 01:19:27.204565
465d62e4794cbc6194c72fbdb2197a0ec0d3c0b0f7746c84003224767341005192d14c468fbd867173d4dca02e1e69dfc1abb32c632e153e47ea086e99253ead	21	{}	2016-12-21 22:15:14.714859
760e26038782798d6433420ea97fd5fd1e17f9295a68fa1ea01e4bba9fbcbc440a22fe8593b5c56d9427a5f6f49df2a7c7c7f97cbdee8c08fed54408b72408cc	21	{}	2016-12-21 22:15:21.721271
659cad748417ed9d12b873d46bf85ecb37d248314ac65ffc9b390f9bb4abaf3513859128289345c5c63a2aa9986d6d147de24e6973d00863b8649a7777b23602	21	{"username": "mari.maasikas@pood.ee", "is_authenticated": "true"}	2016-12-21 22:16:07.113518
0b7561a7e3ff6cc54693255aeca223d675b03c8d33758d79de1d00af416d7ba3649df1f9e1b4a2e91d8865f5952253db70d55991a890f3240737cc594dff8095	20	{}	2016-12-21 22:18:20.067341
3afa677483a37e5e68c69a3dfecbc4944bc49c1fc31dea5467cee064dbf03d1d7ac05f0849ad4bd344530067dac003fe3de50d9ca42c15123b0ff114d0ef18b7	1	{}	2016-12-21 22:23:32.545813
b880a7358b224b56cf52ca3add3b1036bc54888c81fe380034257b9604101b81f79bcf2a2a6c069ed3e70bbb743b0420854cd49c24da6b11614c4420df17d465	16	{}	2016-12-22 13:01:17.329216
8afe81943176f1ae04e32704f62060ee2befd45056091eab6e8a02920526d1decbdea3cda51ad2eb64bfe2f114fde6dc9b87786515eb42b65a093f95225a78e2	28	{"username": "juhataja", "is_authenticated": "true"}	2016-12-21 21:14:57.507425
77fc7b7b7f88939eda8d57b2c5c96764ed85830cfb4d52fe03cfb2ddeb1ae98c076bd41e72f0d73cb8270b5ef0e02d43b3ba56f56a5694105cd878bc73373e24	29	{}	2016-12-22 13:08:42.568741
57afb5639dc6925d90f451ae54eb28c6861aa578ba4a492b18ac843653568e4edfd48151ec073db736a05565426d77c04132c45534409ac149dc6a276df04cd1	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-22 13:07:35.532932
b44af90060fda0621bd1d566bb262a4a4c54ea58a869c265c54bf4e0e8734f8e67f4386544659b6b5f81508db18f8f6aca3cea9cd72a4ff8b29a4cdce3c705df	21	{}	2016-12-22 13:08:37.567991
9c1a4d57ae2d404dd85aabd26c3ee333b0305da8f1010352d10c5af674c04ac45fff313ff6b7b431188cb909e68551fb65f34e2016277c2c58759696f32582f5	29	{}	2016-12-22 13:12:27.075447
3f07e6a2102907fe0c68130b2c77eb3204a8534e918a53c646ca884a2ac55cc646aa3a11c5715ce861c20e05df92ee3435b3d7da0dc90f6c1c235bfca8b7153e	28	{}	2016-12-22 13:12:41.169127
010769c56c275b70b01246c59224f51d044d681f507bc0fd0b0df65b37dffdb092852649ca559f319c2652f717d9be05ce2759caacacc34a2935f7cba0b2d607	16	{}	2016-12-23 14:43:07.458807
e5480a9763b37d14b7a463533717d82fd403c3bb41c37d82e40be38d3a70dc78989dc432f7e3da38c9215ee0e97f92cbdfed6c8462e7e50a78138ba0d35a5a20	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-22 13:27:10.206802
9a325bb13cc9715b838b4daf83a84b139697bd31c92f0f3f2f2bec2cbdac28d80995f2832b37b0c1943534407f37fa6052e2f5928b7308df4222aa5399b6aafe	16	{}	2016-12-23 08:59:35.643109
19d05cb4723c6dd11c8af6816fb2275845df63e66cf013c9117de21201a6d82ddc1e9b50ef86fb17006053f62bfe7fa3d132633b728280165229fb188d007d43	1	{}	2016-12-23 20:40:32.334373
eb5faa663decd9f4fb6e4ac1e5e05e83ab2877f2efa536b3b1731b91701410219c00ce9eab108b25c1654239aaa9ec8c78831053656a7577a2d2b6db4e3aa982	30	{}	2016-12-22 23:43:30.165492
f8c3b2b7717ace81ad4a0ec978f5fd6e52b5e202254847b3e7adc4b4372e35df862242c631e57ebeb456a255a19b1d6c65555346eefb332a2701c907bebcd4b1	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-22 13:27:46.828615
3d69c81294bfca1891685c4cc9f04a85f222ba29d108ac9b47a3230bdfa4d117c462353fe0d9bd2e67052e7eeadf5b7d56432dedd9c54fbc6c2190425c6588cf	18	{}	2016-12-23 23:09:13.9226
d79e731d59f4b696a4eb66efe0e44d5722f9e3c782497303712fc2f57e11a818b2bb243ae0cb70068f9c0d080d079b703655afb82424e15a139bb93bf0cf6152	30	{}	2016-12-22 23:48:46.630859
7fa4f5bcb0b002b26cc1c10adb1897b7f3d40487453243f08e2310bd87830092d46a3d138990c743bf0a5480100c8e668a7b8ec4483b5af410be50094c76f049	16	{}	2016-12-23 21:22:13.877208
b4a87d948de0693330bda49037f5cc8000865b7ceb9a704e883bafee5820b82cbbbb682fd7312fe1c4c987d2b9ad52025c07475f9bb516b1b1a51fc639ba7508	1	{}	2016-12-23 19:42:48.344268
8ea348bbe445c3cec184160c78819572cb8b5b407ff1b8fe6340e54a96be0eb0f8d34c7e5624ef819340e9b016121d63a69f45d7da5924e581de60af26fea2da	22	{"username": "marko.parko@ttu.ee", "is_authenticated": "true"}	2016-12-23 11:30:11.52765
54aa2f58adf010a879bc588810c165c45c14ab1e5307a32e1bce62c42e130a5037f5bd1b2fb138f849426dbe9ad417c46f8f5539ec60c5e483ed8b056b511f70	29	{}	2016-12-22 13:46:42.445342
b9ae915292e9a65b0e7f834a5c95411338335f42246a05d0b2e9635724b3f032d9b64abf1c5982645a7a6dafb15ed6354245ced4568451fa6069e737d3320ae7	22	{"username": "marko.parko@ttu.ee", "is_authenticated": "true"}	2016-12-22 15:03:43.708928
3c9090df38c3a68103b5d970f7443cf2b57936008f73c5ffc3f3b0ad762b1b261b1ab0761c3184a116f9a5a5586918da6fc2f7041834115b3e214d7600415427	30	{"username": "test@test.com", "is_authenticated": "true"}	2016-12-23 00:24:51.478442
55bbdb121ed6b3d5098f5d4ea0963510c6dee10f3bc13352de5d39fd7d7bdb1ea48e9b27ba59cada4f35352048753bb753984d08af9869c835048a741fac34e2	16	{}	2016-12-22 13:46:47.073151
fa99fd4478416ca8ffed6ec325239891d230981fd928a9a76acff0f2047c3296267d09c2826b834f76d63e9def1ac300bdf06652990761eaa2cc86533fd2093a	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-22 17:30:27.124127
64dd34f45f9044630b9c61cbc8a2d0958cb19faa9e40967dd5880df86cff0e2f83a4d77aa2df05b2931222d30463634bf7452f06e659742dc6699fad4e51e82c	12	{}	2016-12-22 14:06:19.896526
2313be460101ceb2f9aa05828864540a856d3d2d291f7c77aeceae05d79bb5451d87be90e1e5cda50ba74e0309df1ba47457f564c7b80c0156facb3f1936c6f1	12	{}	2016-12-22 14:06:29.12624
748fea4bc89524243b2a334592d7e57d312048d33c7d073d29347731cfbf0ed0c854fd7ee83b99267ebcce227bbb8b71e8196221a202e00b664681f4dd4eb6ea	12	{}	2016-12-22 14:14:21.788556
8eec02d167572c0128dbc454f85fdfbbdb4b010733b0e6b9c75cad000872aafcfdf78840567ad7c3dc6e425036c5a60ff9bc26c2c6c9553b2f29fa3fb1d34342	12	{}	2016-12-22 14:14:26.751189
d5b39a3192e186488020b969a2422fa38b061a3a944ab57b3af5503c630879103aa289a1afc5ac55e2fa632f52c95cf21ae23e18b7bc85846247d7cd8515a73e	12	{}	2016-12-22 14:14:27.31717
c07bcd0d83d465e6ca69eea327bbbf8bda9188ab5fe404340279215f4b9de2313b7ae4d0b837f7d0631b6b0853e90afa55cd8b61ab65b14fb8e113ce3acdea55	12	{}	2016-12-22 14:14:27.390939
b6998f785ce227d328902159986a29731ccb5c34f63faabbce1e9b5884859a7bb8bbca457e7ea4e423f2bbbbc123337bbe6504e978e9dbb326eafb1e6c0397b4	22	{}	2016-12-22 14:17:38.814381
dabfea090a76f096a7dcc015735492645e1f8ce0be25263a5b75d4c8ac97f1abad195e1ef0ee6d2fe66fefeb808c33ef9f84bedb43b3914e9dd63d4d972d65f0	22	{}	2016-12-22 14:18:45.178263
7a7348554379285153a27c3237a03b607878875c7f0ccbbd05b9ccbd8ffb3e0d06b271daf8f70f46860042c3e7398ac98c3058649f05705d5aba0d1723daca12	22	{}	2016-12-22 14:18:50.773384
8f4701457ab3c28afa2e433a05b8ac0633801c9c6529b0e860e0268ab167433439cfecbb08ef8b19643da3540c34de2a3246a19b07581075d9043e404a94e084	22	{}	2016-12-22 14:18:51.165192
a0330466e79ba7872461a3201a275e023a651528a568152cd1c3c6aa79cf9401a86eb349d47d5df4062d562d0d8b2d86d433b4ca139c272419d4b0618680aace	22	{}	2016-12-22 14:18:51.412946
07f98ea4f61ae9ffa58313e8aaff2da056bac64780f8c8e2e5c9c658a5dbcde58391e7288ef32cfa8d3d68d9942474d9e97baa0ba50ba247c921467a4c96fc32	22	{}	2016-12-22 14:19:08.152777
a66743547877ba75c33c03a2bbbbab63de35776e6730f34187fa03a72bb0dace4e36d77884f06db35c20226e5b834df84a9333151c903784410300f01b6d23c3	20	{}	2016-12-22 15:43:15.346445
86a1862b8beddb50a60c012e09ed8a81e3eee5480e8046828f58834d820e61ef31e9c8504e68c76aeea9e0703ce3ba8f5985cab9b6d46eed8bdf40b59f6ab382	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-22 15:43:53.784247
aa58b3953e26a45ece680edf76b21aacd6250c37d4b4ff6b8d93fbd827faf58ff9c2cea3633379a0711bf26c584abf342194d1fa865ad57a0881fd1d67b32a6a	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-22 14:43:43.780729
1ba8dc605c8d9d88d3ee0adb47910cec79a4b4f34055a559403d3cd35578fd3ca94a1acf3d3527d5305f44241152ab352039fc6ceaeb1f21363d571c278f2eda	21	{"username": "mari.maasikas@pood.ee", "is_authenticated": "true"}	2016-12-22 16:21:51.420752
9edbf0f6032598e12fd3d4b4443748374225b51cee4d7bce83d884380371e94cc05cc89878346a5826d1c3bf8774d6cd950583f24360711d5fec124051f4c8cd	25	{"username": "juhataja@test.ee", "is_authenticated": "true"}	2016-12-22 15:53:10.695794
a65f4d5d90aa28ffc308038c1dec9901bca15988ef393d985e43ae8439434063bb671727992009b62704db62f3ddf3a786ce766b52d170ffaad610ec05dd5dbe	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-22 17:40:20.785443
6c975cec38f0ef899c46a2fcf3bcfb2bc1b65a4b40298b5c14dd02f77f2d21164c64301b6fb38ac8b565963a84913fc4948412065dd2a804f57fae554c6ff718	12	{}	2016-12-22 16:37:43.10742
c0fa83f6aaa503a13b5abf9b11725988a5d83423b0eb9ddec2bda7771b062c7d786a025bf16bbfeea89042f8d10cbbc9c20864f88414c99fd445fa2ea8a4f67f	26	{}	2016-12-22 16:41:06.82613
4f5c319fa8a6bc849ed4eb325eeda5dd8e9c4e53ef04138c7a847ce3bc412f3ee5bf26d05efe1386b2c51bb7746b11f5d640cabf94bbdf87786af9fbf7ae5732	30	{}	2016-12-22 17:58:31.843856
101b7860544f780fba77e910ceccc53f0158cf33b9b6f672cef78f9f3aa6cbab019196c92accdbce6b6d317c71f96422bf6d1a44dfe9ca2b89307f1256638536	21	{"username": "mari.maasikas@pood.ee", "is_authenticated": "true"}	2016-12-22 18:01:59.939044
7ced7e76443111f19ec698b364a8d06ceafbd47ebc3a5639195b8b2ed916b749d3a40c4067d60c6df9a929bad15595959e5edad9f1c2c27aa400c9b6dba10b8b	20	{}	2016-12-22 18:22:53.380179
9ef2cb627c71a00b54bff278b779f4315cb2503325eb54567380974d6272216dc051faf6b54104ebad42cf2336430fa885ec40b1ca214ea4c7f7886ceba4773e	30	{}	2016-12-22 23:43:30.818694
f1f1399037589577ae0962e14b9ea9da789f513f63b47ee089ba6b71eac2afec0bb7acc37757da655526a4531654d16ca3953954849629774c19a04710283df2	1	{}	2017-01-03 13:44:37.492667
d13ecf22d5bba53867409d06196d68c96e495396dbaa6fcc66fc86cd89928cc72ac2002359ba980ba887cdd776b6e63683a4aaa0e1e7120fd55635b059baf8b5	20	{}	2016-12-23 08:59:40.485942
bf2d7cc13a372e7cfcaacae61fdc265c8ac25b311797ab7ce8a7ef3f161fbb68e08153aa9b5993de32b6668873afea45fc187782b39c5697018d4b60da7b1f0a	20	{}	2016-12-23 14:45:09.702321
ec403a390ab39b34cc1f763ff5a743806fec1213e39d708bf1ace1abd130b3d564d2e19d29ea6add554e3b677e00fc41588fd64ae88b04f8b174acdb31a5c82b	29	{"username": "asd@gmail.com", "is_authenticated": "true"}	2016-12-23 12:14:45.492673
750260190b9ab3626afcd70d4042c71ce39e1027c5822d39377e6a0f40f28f9522ccb4391ec6a820a4025880159b01a7ab3391b47e4068653150d3fdf2d413b5	12	{}	2016-12-25 17:57:32.00914
2c7ebd6dc1daca0ccdae22f69e69f16538d3f790ac82ddbd0b19e2d3e2c2b56b748f049b0573a4ae85b25c0bd97fe62ac504c2b66a6e33adb4d0567bcc8e737b	20	{}	2016-12-23 11:01:18.216619
7879785bb211779982b9e263ab0005022cb454229d8c6f45fe5bace163a50f4225635a59a79b86857c4400bd44760d9f898e0b02ded16e3b8f621efec6e859a8	12	{}	2016-12-23 11:12:20.757364
678506530bf5aab6984b4e79159abb24f687f1e64067af7e32626926b63320afc8c405c093dc0c4461d07dffaac184866e264e3af993e062bb4c240378e07c3c	28	{}	2016-12-22 23:49:43.417614
9ab26f70eeb790edaed79047dc2f604887557b89a53abd43693efc99e3c73d30c318d2f8f2167a503710bcde5ae23f3a0735507de743a2365caf7e21e375a5b5	1	{}	2016-12-31 03:49:01.832593
16b5774f487a72d844fcafe923327c649194a159d9b1f7a414e33644eedc35d057b781624f4de37d9d125a9fc77938e97a329a8b98d1a6bd18a49a044693cf90	28	{}	2016-12-22 23:49:58.699393
94c60a60648b76604e2ab481cb7f7b750c1d8c589d417974c3a8473c4c7c159306399228255011d74e1b1609c93490d4d0b06da2d1ad326cf4ed1a17185984c3	20	{}	2016-12-23 15:50:53.35329
8503c32b4c3078263aafe749c152089130436db953105114af722f941b7fdf17efc0219ca5a7dc09013bc57f4db26723074ca752233fe1ff7884777f412c1496	26	{}	2016-12-23 13:36:18.847755
49f24cb688de662956505ffcdb17e782b6b230baacf2f19bb20d3326bf8d4d9f9ca0c29eb28c746896f54fce21f0fca6ecf999d6b580a9a16599082e20ef775b	21	{}	2016-12-22 20:22:06.775265
5de3a9825a50e73ca960d7848fcfdbf5a17b68d23c81e59b2053e487f99736f48dbdc3327fbc69fad5188222a39562b30baf45bc776ef01f24eac8502be84158	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-23 14:52:56.111225
50478efd0ad6c86030dc8fb465f552a71752f753657f04c1d1ced16d3f67b3b0686ef8e8808f5e4d6b4f9bc010c983c1e175a866db63e3cef078aadbe1eb640d	29	{}	2016-12-22 20:26:12.829569
2cc529133da2cbbf37c40003d7cc43f96e60c50c12a0e04ae85c4c620b88ba4faf6afb5385054ce4a81b7acbeefb28e3626382b6ab4309e08528b69be904ba80	12	{}	2016-12-23 20:40:50.869992
4c4812fb40df0bc9f6e1d0640e23610618e805225fef71c2e1454776686c387c377c98aa11058aedc48b0f1ec42820aa1617c4e688e66a2b9f9f4c9a6b98d35c	23	{"username": "mati.maalt@hot.ee", "is_authenticated": "true"}	2016-12-23 21:08:46.213558
70a9f37b6badfc229952c29593e6d4fe717f0fa293a917a9be02612cb03f82ae8df88f5d2fa2b53756406f979aa514c3a06a73cc2128d2285baddf3e3164e94c	29	{}	2016-12-23 17:36:51.333121
6938c4d64a4b8b20b2eacb2c8a21fb3e08d381f2de640f0d0045c12e9b4200b7c89f848f76c8209ecc7a055bffabf025526fe81c37cdbccaed7ca3c580d9dae3	29	{"username": "asd@gmail.com", "is_authenticated": "true"}	2016-12-23 15:04:56.767368
7d98a5427da2d561895236692ca287a00f4d8306645263c08b789b77679d9e9d171fc233e595075ffa73bd415e2682a5a30fac68ed3ea42ea03bc7757ad02360	25	{}	2016-12-23 21:22:24.297003
34497ba0796e74b2412da123d0c1971bcd2d5131b1bdd4fd1e3cc4ab8ccf6e0508d79c8559530b95af1e9bb702e7b4e4b52cb500bf54334270f29729d3ed4a76	29	{}	2016-12-22 21:30:53.334717
909c62a8f48164676a798288adb577f445d07748e83a00ab5e10e420e84cc926bea37453a39d10fb440ada111696a6fbbf419348c1eca94f66a00ec7182e6019	21	{}	2016-12-23 23:09:16.391292
244f8d8cf5ba4ccae6ac4c040546b9167394a3f635ce000ce627e6291f088ab050f3acd9856064a3d31b1b2df31e38125a198fa622453b9f178ea12e80090524	30	{"username": "test@test.com", "is_authenticated": "true"}	2016-12-23 00:01:25.086235
441b5dedf59682ef97b1a51d2b886a2d29881d5b464020cc78dfc743b9b8093011b56bd391c24f1731904049a55b16bc09ab16db944972177fb36c80134c8945	16	{}	2016-12-23 18:58:57.314638
0eb972310ed7320b8e73a697d18ec71d8beade9d0e8a11363753d81a30a143475820666de977bac3c6379659c2d54e0d8067c8f3d81efbed44ee3b12d7fdac2d	25	{}	2016-12-22 22:30:18.160493
50da94ff9865ed853542689a4544c8f47ffbb04ec9efd7805ad19516110eb2c2bbf4cb815d3a6a09f38cf186b4143b41bb176fd1c0cad2d971fcae01bdc46c40	22	{"username": "marko.parko@ttu.ee", "is_authenticated": "true"}	2016-12-22 23:17:32.151533
eff499919fe135d5f0ba5a23e91b6d8eebd68d78ee570699b34b68b7e5ab45cee3f81a15c55f38d364b76c2f65e408ce23b3d0b480c060bb8f291cb8402bf556	16	{}	2016-12-23 14:37:16.006398
03fc059e8148ca4d083fae77c5f547ee53139047baacafdca84fc774c29caf2afb620733674839fe855a2dcf74272c9ff6df99e03a47a7ff63329c704e744908	29	{}	2016-12-22 20:43:57.211525
b82445a81af31d7d1345c6296eca8053c5c565f7026e3ac4667d24e87236a71ecd39002a12a8c54b553ab1c5c0ab1da0019d4477a9b3df68949dd876c774cc97	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-22 20:44:22.472444
02b65a4185e6e0af47311715f3aec07f1dd11a38d6af4016b93e7c52a0ef54ea15415ca17225d6a29cd2722e7f75c2867e0ba43d4929fd46f7d82a13c884f2fb	29	{}	2016-12-22 20:47:43.562462
23da0b85c6bb0b574d8c7be498615d0b7fc47005506b24e6f800c27113c2663da9155534712e702ffa4f7f00e58f5c42c2886074cbf172e890b5db76411fdb9b	22	{"username": "esimene@gmail.com", "is_authenticated": "true"}	2016-12-22 20:56:54.670895
a1da041958076a932ae4c0755c038ff3cd3ef54f98a964afbb7fccfae284fc51f0cead22da4857c82c46c25d3433e33bc032a2d4a513aa24668118382b983ee7	22	{"username": "marko.parko@ttu.ee", "is_authenticated": "true"}	2016-12-22 20:57:31.40933
1e8c733e20d951dcc696f967bff245cf8240ac03313479df976d441ea59bc39440edf9925d457c5b382429ed86388936748d2b3d473c22ad437593354a4780e2	16	{"username": "random5@mail.no", "is_authenticated": "true"}	2016-12-23 19:09:41.520392
bb0c6076b8f202f915e06ad64045940f6ca318aa94f80120ef1509da2569b30a8763669c4cc648bb1803be717467cd8c3f30165b7f736a923295e6c2e11b7e21	21	{}	2016-12-23 15:45:44.982306
7740c2eb2a90c87a7f7322a86fc3bd62d078997c800b446c91529e2a24478f8ffe8b42e403631c77e35524ba2c48905daba4b4fa3b751c74d46e4fe07c6ee58c	12	{}	2016-12-23 01:30:02.488116
13588dd0de1d40249b363836c04fe05a6b030f2d3353d5d66d79902ff9eebaef133d4e15067a472e6c90f78c93c0b67512a5952e590020078fa282127b976d49	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-22 21:25:03.892183
ed0edcd0df4d2d2718d89a73dac9cf9ca5562febdf72ce1380909ea4dbd921681d6e71b9625daa58d230c34971cde98d7cb0fc6f9582bbc56453cfe44102e1a9	1	{}	2016-12-22 21:25:25.466459
c144ae68d0492c3c07308f6dfdeb1a3df8c2a96fab3ac0871a4b9501a100385e15ab7228cc0eab91dd1eae5801390cc441da2f30c1c5d071f839aa4916869c50	28	{}	2016-12-23 01:50:14.830056
48c9a39463ae92784ac7bad360ab0a9c6732a1063f93cd27e5da3a9c355ddb3898b27db58010524fe8c5ae205e5e777e865e900fc71b0cdd4ab4840b3a355464	16	{}	2017-01-03 14:32:56.405938
f4ee24486956e7b2aeb078e6511107642ca0c7928a9947aa931a16833c721366c72f325ea2c0b3cab9e531d38d8eb74037b325f06f6dbb67bc60152c2be0de0f	16	{"username": "random5@mail.no", "is_authenticated": "true"}	2016-12-23 22:50:01.450208
d29d1079e15ecee62b446cce54839dad07e486023d9c38958bffdb9f1467ad0e0afd4f3e3287a2112e473fd2a1d3d01ae78c1593300cd28172522e32629c2156	37	{}	2016-12-29 13:32:33.880976
fd8c83aab57820e4c29e9e02033c6c6b4e11e3515c01a32c35e7e287ac16c464e6ef6d9c03457d1391dec268d47844da600bd732b745a9e9b9821a8d27e8d4c9	22	{"username": "Marko.parko@ttu.ee", "is_authenticated": "true"}	2016-12-23 22:25:52.410794
fb115553170c5b8e48507def15f6b711bee3923e0629c1bb724874448eb25d5fb5fef57fa77d45375f4ad3be5a65259b381a87cb39d1962f98111e26aa036d10	30	{"username": "test@test.com", "is_authenticated": "true"}	2016-12-23 12:23:55.114798
e8a620a432c34e1833ab308b8b5fe4eb41dd9e57fff1b2193b0a45cbb346f509bd503c83891a9128d2a8252bfae397193e641adf0c85dcdaa038eb50dd5195f1	36	{}	2016-12-28 20:34:53.341351
e122d2ceba4000463c64dabf3132272e373e6c72f21f5f5aca86795f01b491dee53a3bc754f9af9fb16efe3a27bf18d55a5e8bf2e527ac3732a0a5930f19cf8a	26	{}	2016-12-23 20:47:49.693306
ce5d93a4a127e6d9917915b52a193e4ccfb6b229056704b98c0b20e55d9b0db436a5db086b5ea29992eabf0007d2410aecfd1851c19a3c26cd3f8f31f4d4e633	20	{"username": "poe.juhataja@pood.ee", "is_authenticated": "true"}	2016-12-24 11:32:13.2462
7916c595ce29b7be53df0e764707f2a2db614911146b7038baf24d65e5eaa9ff42575a293f14bdc9c4069fa316933d6975993f290e15f51e6e296bd7aa98b6d0	1	{}	2016-12-29 00:24:20.147146
c50266eb45921624300285d1a81e43b49d6ff5c11afb64b30810105d1d6a52bfe7b812b882281a20817758a1e1748dedf0e887cc79c0a20d7c1eb2713703bcaf	1	{}	2017-01-04 09:38:19.942669
57cced97a027f38119e28869862783d47aed8bc3033ffbba426dc5fecb93f4a881b98766a895ce4bec82369e061a14452d14a8364d842d6abbd3fe481f576abf	1	{}	2016-12-23 06:38:29.988408
78bc1e818cffc3f257c19fddc2f26a2234d0d88a893edebc3013453839f4641d6f9040fd544787be1c897ca8e58fa364e18071dfd1091ef77cb5546cb79df9d6	16	{"username": "random5@mail.no", "is_authenticated": "true"}	2016-12-23 20:54:31.097949
42511c8bf5d14a676cbd663b899b3f67fd6f4ecdf8fd4107eda2539c83d16dc73afe07ba33150005ad816bfb9807d68cc64848371eda656c6817fb26098f6f36	1	{}	2017-01-04 12:35:23.961063
a2a7fb3000ae39b0cb66d10c28e64f951a31277c7cc51ba9f3d9db7653b2ca10035c49c59f0788d00644b758e230d173677572dbece7142048b12a5e6718113c	21	{}	2016-12-23 14:45:15.167037
a87ef24ce0fb87e4b79a49bdb60459f1f299f711d747873486682365e20166d27d0ee3759d3bd147f8dda022dccb81736176b1973d2d87c32a53e1471cd282bd	36	{}	2016-12-27 21:40:53.539965
dbfb141595064a28391315382ca3c3d3347104395a60818bc6afe822172d027685d5c65c19bd13a07c2d0def72d437450c5bd1f1e91275c8b373e961258fffef	1	{}	2017-01-05 08:43:59.539331
b942f6ad378b211d939a5c9c5329a2b948745e1c06dae9e1070f12171b470ff785e9c989ee3f6c3ffe86cd561adb50db38a10cefdd847f4c9b4f008a402006b8	26	{}	2016-12-30 23:40:39.000672
d00515889e3af62a4711a20a6ec94b697705f3dbbca5c4e7e3acebe90b157562593c8fee6006b9f290715c2c09bd30eda8fd90573fa6d46f4a97e6245bf37809	16	{"username": "random5@mail.no", "is_authenticated": "true"}	2016-12-24 00:22:05.543983
ef907b96f4218ba5aca7de6a78f7a905aaf0af4cdf7458d5c0815bf87c51ef8f4ed1b8f04a4c5e603bd7af6323fdcfcfff8a3fc11178d11652839107a140ae0f	29	{"username": "asd@gmail.com", "is_authenticated": "true"}	2016-12-24 00:38:05.768895
e2007e617fd1ab9acb0c0e06bf7519b39f2654edf8e023bb28c492747b1226854c9241cb9f7361cd2f14f959cabf685398d6acd2dfa06359ef5041fa8456bb54	27	{}	2017-01-02 13:16:27.242253
e3eba2059b81207e0264617d9f347a73f8d39a0faab3c3f8a79b8b8900f08368bd689229c983294bf10d33fa5f0d1bccb5279720736acc602a18460c73fac440	29	{}	2016-12-23 11:33:13.553001
e89578e9a4e58a717574bdc03eda2260ba30825b04a4d09c52966d4bb3b140c9d0c850338428db71d2753bb9fd03689c9e54a6fb2d3e67a2ec34fa42995094b1	37	{}	2016-12-29 18:52:42.535795
2526ed9048a2afb3e1ab98c4972d724bee533598bccaa364e1e2621013daa32bb920674d66f3c35fa4f16e9a4415ae8e24e759a63e34a729a65614ee3a074dd5	1	{}	2016-12-23 18:53:04.334044
f91ca20cfd9a26a351adcf7055d57d4406fa083e45dbfa1b9d8bbe9382f489ad3d36ba5080c9db10c9e595c467baa59ebbf98deacb35285b78ed0f884459eb49	18	{}	2017-01-02 14:13:49.752399
d61ad358d737f6c92d91b3b75c56c9cd5c15d2812ad85eb56a966210430f35a3a85f691cc89f93d22d1b8bbe3e745861d68dca43151447778c3c5bfbbec11891	29	{"username": "ASD@GMAIL.COM", "is_authenticated": "true"}	2016-12-23 23:19:10.833159
14a751f52aa73c098a242a4594b33fcebb866510fdcf170ce0ef60b24b5f22cea2c2b610a49c668bb94f8f4f7bec3cabe330f35acf56b3f9027e1ab58fc10253	23	{"username": "mati.maalt@hot.ee", "is_authenticated": "true"}	2016-12-24 01:18:24.949256
6bbeefba23c8cd4a2791b975f5a79640c0523c0b7d1824336cd265d67ae3201dd4a6bd8727065116cb4b17a6df1a08d696cc7c0f8eceda703234e8c8ec28c423	18	{}	2016-12-24 02:00:33.772624
4668c55ba68cec6d6bb3a430e4fbf7b7b298cecc2e17057040dc6878f085595843be0918723db5378a4b77f82851c750792c3f16355087eec8d89f9d8ca2d2b6	12	{}	2016-12-23 09:30:46.759079
dfe9e891ccb26ee8b82c35123523b8da9f938513a2f15b4e9544a771b81eaceeec51084beebc5877b81e3f4f453aa3b354052dcae1af98e984c9fd97b0371d88	1	{}	2016-12-23 09:37:36.997424
cfd7616b2e15bb6b232b52b485447baedc9fff8ae36eaf5683c921f97882f98d272ea052c33e76f1f4deb3bcc05a5698e0973e2440e669f633b7139d7fb43b1f	22	{"username": "marko.parko@ttu.ee", "is_authenticated": "true"}	2016-12-23 16:29:19.294718
112faee7bc370d4fdd6b60d81e50cb6ab83590ea54b3214f7dfb70132d849ddf8cfd6dd9c78bbadfc93adfefc015903915a3b1b39c878ef9db60a7f9f765ccff	16	{}	2016-12-23 14:37:15.672589
dae7e6b133b7f4adbb3816c7dcf01a18ed3cdc2e9581b7a671d93f513bab6b9725c9a710aab0401d8638abed43155aeb654bbac4671fd53891932fd224e8b2ec	37	{}	2016-12-29 22:47:36.557753
5fcb7016b5dd8cbfe4df2d21a2482653fc21ed141532f44b727ca10fcc8f48fc1ddf808d9fbeae6ac22a695b06b1d179289206a54968ef6b50db33fa73ca841c	30	{}	2016-12-29 22:58:07.84054
a550b7316f71e0086a7bc695c4df7016b381ea11621f88f2b0d7cf8e0282d596e8b8a1a652d9beda17dff35a452d617bff48fedc49cc8be3402b2abf043d51a3	26	{}	2016-12-23 19:53:04.646353
c06d4f5d05bcedef66237aefdf31584f4d8f6c01104b5d6d53abfe25ad5ceca46a682e16e09f998d4898b3804b27454f6c0cbeee4e7a1008fa1c7c47de5919af	22	{"username": "marko.parko@ttu.ee", "is_authenticated": "true"}	2016-12-23 15:42:17.205061
858a0573620dfebf602441e585d166ace7eb3fe288383ba628fb10496e1e926dbb0e8fa6ecc1e34a95ff6970ee7895739011a31a66bbc263ca5b7d78b22a2faf	28	{"username": "juhataja", "is_authenticated": "true"}	2016-12-23 19:59:41.193563
3c08ddbb97fdd317f5a2eb16b71636ba672f0fcbe2442ea707e4ca9b1e0039a2723fb7974b38f7a514535c2d5668391a8feaa5c8f707f114b0f23c0c42a5f681	26	{}	2016-12-23 17:23:13.16026
15ef4705d4db5f7787f4a47b371d91ff4b49f298a3d62d81075d2904c3f356e5e6d76b66a6281a5fc6cd73924d286a87cdedd66c910dd5074911b7b3eb25a6c8	1	{}	2016-12-23 17:46:25.916589
958d5e268b8aadd159449cf3e4a282f52d404e99ec694ff6f7f0832e635b43a2094c56e3095bb69dc83ba251e6fef2ba190255c563209ae0618e36906dbba63c	20	{}	2017-01-03 14:33:01.423883
5d1edc08f2ff3adf2ed764419e0674571f2b29b51b6d51974ae5d06ae100b0b98ea06cf7532a9ed1e823ad77fea81d43ac52c673f13ff0a891fcd41b826e2069	1	{}	2016-12-29 17:00:25.843382
02f93ef96bf6cfba89ab35c0848c2b4c06f1c944bc377472ee2bf23600b9763eea0f1e564f8c16d298155fa6eb008a779505b28bf6f89ededdb30cab851bef77	20	{}	2016-12-23 21:23:24.788118
153545351112c596c1adcb08c1a17082dd0df3b0a323a005fcdc993430225d0944f84689d697c12ec7eb45e9be5eddbc52c57d25d60f8a4be27e1c44b9cc56c1	1	{}	2017-01-06 12:52:23.983245
839326e330e8cbf899ccf1dbd94e57c3d1635135fba26599a8415586b39ba69f2d2d32c10a7efd3bade1e622b69a02ed4c34df5a6a2f6841aaba9b94a6e27167	18	{}	2016-12-29 12:20:15.110172
709401fba85ac10f4b255d63a29e79dd85143147f3324635787c2e6eea27aa7ad528de382ef74062eca8bb5f74cdf62411190a05a3d0d51d85e7d198b81776b4	29	{}	2016-12-26 18:54:13.2104
ca384cc8f932aaeb30238cf4ed666ad0ed32e5041ed8e79bfe858881731dfe1b2598be5be18e3401b6440e88c1c7679acd66d16a30ceaa562410f7d4dfa35094	36	{}	2016-12-27 21:40:14.748857
d38097a0650da7617bc4d618cbfdbed4672fa273229033ac56176fc4ca5c3b08989516202b609b169e2fc962afc1d48a08758efcd727658fff69d4198724cb0d	1	{}	2017-01-26 15:33:53.568714
c6694d28f52ef141b5023d8b6ed7e32521ccaf4daac1bc91b01da7d15e1c4b08231d3073105acd823ede515ee909c31cd81d39ff928fb719da8c61f3ba3b440d	37	{"username": "argo@argo.com", "is_authenticated": "true"}	2016-12-29 23:11:41.218491
0622c9958413e62b144ee930c8acc3405f02a933e420ef383c816fc61d0735735fd5ab0e08cd76d616d98795843bca2dba112ce8dfd18602a6ef0fa689d82f1c	20	{}	2016-12-24 00:43:14.114462
7515762c0fcfd7d3d2a4e0299f218d7bd08d3d1ec10d81145cadc407b15ba573fbe581ef7d60be074d15331a28944b6d90dcd9532741e0eb3cb4984bcfd312ba	36	{"username": "piletite_kontroller", "is_authenticated": "true"}	2016-12-27 21:42:35.60168
f13a12ba58f4db0b94737a9e1d57e98e7c341c324178a024659524b7cd25e8096f327fe4eb023ada022c678111cfe3fdc60ce3d0282a8690bb312f1a78087e99	18	{}	2016-12-24 02:00:34.095414
0effad0811a3d01e19153bdcb55eae679e72e224bcc87e6838d4cbcf5c2e1b0914e7246d0f4f154af48fa40e8038063b4b791b6eb677c304cdfccbe5aef15c3b	1	{}	2016-12-23 20:59:02.962087
8344da1f588285232fe57046743bad19b75fbf836a8f2bd7de6f1ac3d35d89ad5bc467a76486d33f74a6025d7c9eb645954f03eff6dff54b22a7127162ffcea6	18	{"username": "kati.karu@mail.ee", "is_authenticated": "true"}	2016-12-24 03:00:27.564878
1a60f704fde65cdc99869cf04de7ad1b5cf9fcfb173a3dbed03e199a835285f90b457c0501b61c0b68a8e03034297dd0e9425aee2b1dc04ed8c075ee22048f5b	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-29 22:36:30.218749
dbf4d5cafd24334d6360189d4a0dc6aee6c58a01b3f9b11ef2c8209e9e406df6894244c93f8d1aa722ce972cfb25fe194fc0c2a5dff6c1efc04e0d1b37096ac8	23	{"username": "mati.maalt@hot.ee", "is_authenticated": "true"}	2016-12-24 11:40:12.547653
1cb3a734126dfee59e3463a2c7938d358c45e2cf9b970e1b6644c5b514eddc5c4494c5aa9ea0a6adc812fba74e453392b8ace214fb93eb10bb77b3634ca88072	18	{}	2016-12-29 22:58:10.395844
dd7ec2b54315185941001203239c9aefd5122186d9c80e5e0e2e0364d446343202f060df79fe69bca394ff7c52fe9c5f2cca80fcf03866cb8f3a1d748dd765b5	28	{"username": "juhataja", "is_authenticated": "true"}	2016-12-23 22:41:24.608108
4209fdfc8d4b3e776327ce93a011461f90e48f32fb89e64682d3a0a415b887e770ff85d76def55c3c3178eb0fee5f97d86ded436eff06d2098561ea6ec91f74a	29	{"username": "asd@gmail.com", "is_authenticated": "true"}	2016-12-29 23:27:34.883951
c7020a1fa08cf86fbc060cb6caa32210171caa55a08c00ed10b77692efa563a7b434422c6d7e32dbec76a92937b4fcf8ffe27d1e101246eb8c912e55b0bd2fb4	28	{"username": "juhataja", "is_authenticated": "true"}	2016-12-23 22:41:51.707877
4aa32f8263ad32fcb38df95561c6ce2a9b112d9de595040164a24dd34d8f286c97379b549e5ab74d75b0b35f064089c5e9daa8847fef7b942660cb654f75d9cd	18	{"username": "kati.karu@mail.ee", "is_authenticated": "true"}	2016-12-24 15:00:12.924244
6795d0327578cf200943fd8117b172f7720f3341952317b24ec54b112074950f2fe0ee5530ce0960c655ef03dd1544a772aa01e21405c66363877355c4eda523	18	{}	2016-12-24 18:06:37.204461
77dbef79e0298d3d68348a2013268d8fd1b794cbec9b56b3d0af379e81c808b33acb380cd815f9db87081f3f703abfb23cbf0590064edffb63b5540c51de06b4	1	{}	2016-12-25 12:13:35.195025
27ba1c73926bd5c886489682234f31f4b741a3808e9fa866a5cac5f1bb389c4f8d70205ba2ad306e244e01bd2b57961d37b40e9702128c1af71aa580ea5eb324	29	{}	2016-12-29 23:51:24.226399
fe3e40f777a150fcde6233add8d36d2315697d04479cbd6abb0de5f0999d8a94fd74f9d6388e4da9e8fbb118b1a9e3099fa296d32b7c6b4bcc0ac5dec7cfec54	1	{}	2016-12-30 00:08:56.294538
c4c5be6b40ff1bb40327e4c9cff26e99598f4d95be983009b8029db35832bea2873755d13b3bfce42aa7d509776cc1a86526aca4eaeacd6f73f9fda1dad21862	36	{}	2016-12-29 13:17:10.688028
ca0e268244a79c3986295b47f0800d448938b1c4a14f260a7aee1d2063221cdd32550a2f84b24a52a2c8839705c5e9db62bda717e256587ea3f9e60504ac2533	20	{}	2016-12-25 17:56:45.900463
65d0bcc0d004b59e5e53fa06e69d5544fad6f65982441f5e1ab121ec200661ac45de22b529550ba25b4a396bd024d69c4bdaa8e45383453fecfcd0275fba9a59	20	{}	2016-12-26 06:51:49.752765
8eea15c4101aee0e0c218e3edd92bf718bfd239264b1f592ce25687d0b6116bbb62ab3f4590c1296a075d59dda71bff57b395b58fc54572291c3cd9ae0a9d418	37	{}	2016-12-30 00:09:17.973012
1a437e97c7b7f345756d6e5aa281780ef05435220a8d508dcd39127de90b5eed9d1565ef3158dfb9c743aca6f6100ea0f7391b7e03e00927dd96336753f9e6df	37	{}	2016-12-29 13:32:22.466581
e053dad474b38a9161140cb8d5ef7edab55f99765a0d044159439a23593158b2f5605508ac195676601274582881db4c23c80d2dfacf631752c704221311eb80	37	{}	2016-12-29 13:32:27.393602
8964733b8c1369459cc6c33fb919bc6741dad4532f1b39c9311d8b9343417c18f7cd8845a4f2875c716daaa66a1ba3eb2d69469608783983440ba3f81df74907	37	{}	2016-12-29 13:32:34.14739
cbdd6111136ed8f4f0c06ea26a81fa120db1b48f117529e928e75ae80b8d0c579c115aa1ab5ae2ecd517280475f7b08c9c82f02deec0ff5198fcffa6b04ed5c8	36	{}	2017-01-02 14:13:43.657255
4ed2d3bab0c11b7986d428d162c6daa4ca01a5f4da5b7a0fa842cce1b021b9b0419f9bc6d5f4dc3bbc11c815c4b8f0180d339fd4721444a5141b33dac63f3c58	26	{}	2017-01-02 14:13:54.444069
c31a825864a301707d310036d7deed1334594879f736cfa6e46be93e4da959489c48c2fcfa6624598f19a9bfb28ca0be3ef2b8145e4fbb3e86e4b172a930cfb1	36	{"username": "piletite_kontroller", "is_authenticated": "true"}	2016-12-29 14:30:02.956529
64befe744c4ac4a4c078c93f27d3cd94ac4f1c2b70933d30c9bd7a8a86b5e4cb7f8cf6da397466c5b8e9e69cf9537061b1d4f4f007505a94d91db8e0d8ed5c8e	37	{"username": "argo@argo.com", "is_authenticated": "true"}	2016-12-30 02:49:43.604697
d551aaddf101846f3a183c6e4882a9dea636da621fa33a6e9dd9ddfbf32a47f55be27d7f1777b8fa0e8536aba605e9536b3931cb5cd041556589349f845e367c	37	{"username": "argo@argo.com", "is_authenticated": "true"}	2016-12-30 02:52:20.870807
6e169eff08363264ea8225620018e86eabd9ce4f484f111f4086b178af79f9f15f03ce303ca35d8cb3ea0cc6332b4e2b057b9dd2a4ac0f24b7c606b2eaaa76e9	36	{}	2016-12-30 12:58:05.552097
f348d597ad456b24022dbff8d9c0179916af5d8ce229493a7de3ddcb8df41abfe4526059162d8c7b4b2e8643afe69cd0e92fa1c45462fa40f02e21c3f3edc883	36	{}	2016-12-30 22:50:22.459411
ebcc8b5f0da7d6cfb1aefac26c5531f168d7a081ef46f2a25cb0f1c6eacd23a4b4a3a8c43556d80afe1d0ed9177a08ef2ade9e8beccaa863c2ea836da0222fab	20	{"username": "poe.juhataja@pood.ee", "is_authenticated": "true"}	2016-12-27 13:31:19.260152
876761f857563e0e00287d24b8d2ce93de37f193280452ab177dd185b13086756f531db5ab2a835767224cdbfe64f7d7b6c9b19ef346174a2a3a9e98c228a5ab	1	{}	2017-01-01 05:20:54.584655
33fbbcada027cc13953f9dc97b4e679ea65fc0fe152cdd788a06d94ec86d5d5e83503a069443175d31dd2171b0cbd5097479047455fafca7036ea522a87d0768	29	{"username": "asd@gmail.com", "is_authenticated": "true"}	2016-12-29 17:22:08.858254
9b08cabd7b6d74637d634e73a3473a89fa486c724d5f3a41ccdd03a09df8f31d1ea3790f8bd12bb758c28da6301407dff61a975cfb55f3578fd5131d431fcd3a	25	{}	2017-01-03 14:33:06.338802
bc403fdbd3f936bff4c376ad642790a04cff5f5db7bdad976e7fd49409f44848035448dc5c7aa4b1bb048bbff78fb502b704bf113aa642e8e5e2ef53da765bd9	1	{}	2017-01-02 07:42:53.59558
eabdbc46160a30d0fe81001036e9b9c984d3035698bd60e7bfada2e928750cf171993f0997765a7b3c6618c33c3b11d78fe4d4585bd2aff2db602ad7be958c5d	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2016-12-28 20:20:10.229011
0f1ea0cc233c60f2b3d4b9331c39d2eec038070ffe11573402c5be1ac2868d116113a7a1e3b13c8345add165666a2c355ea0d6c094138731489a5cd07326afd9	22	{}	2016-12-23 23:08:58.188226
9037235cab61f76caf90554442a7439eed20190a3f8d08ee260b729e50c81b29e01f661ec0b96787b4400c46dd1440e30ffffbf1c74382d2fba0bff6f5e65861	12	{}	2016-12-27 13:20:00.472393
80628399d9726da7194cc571640d916bcec00d64d41459df2c0d1c1f736a96a560fef783309fcfbd6650f5b3700b4c9f140b970a4500d584d87cf139dda06b44	1	{}	2017-09-08 23:45:03.702877
93c0c45e7de002675c59a48905cb978a30fabfa0924da73e2ebfcf06abc56c075ed54e78c9561135942b13954905bb4f0a8399a2f2943747bc6e9bc5ad589b9d	30	{"username": "test@test.com", "is_authenticated": "true"}	2016-12-23 21:20:54.528865
1491c19362e6ced1409283319eecb00a7f57010936ac96a938cb14644980e63fbfcaca56cee3423e6b7de62c833b596ce0804267276588631805588981c96c4d	21	{"username": "mari.maasikas@pood.ee", "is_authenticated": "true"}	2017-01-03 14:34:48.201929
8b9ead3434fa49614c80feefeaa288487cc735c0126ce7d7d801f349f2dfb89ed1ececb397c7e6dc18b416c9feb12315efc3328b30cbdec87a5a56987ddc72e7	1	{}	2017-09-10 15:44:04.891852
e6d81f0c636b5bf7de2f2227eed35a4ba70f958516cb6fbf2f7be546b12a1b109614d9860d63f5329d724413440311577b9781c415eb7024e1f3d063120b6da9	37	{}	2016-12-29 13:32:33.85441
6c2408a75481e7466cc95d220480c6f0e246c0b5a5474bdbbfe0acb948ee8ebcb8161fe3887f79cd8d76f509ac701363e2df25e5fc5369f5add0ae2e6a92c636	21	{}	2016-12-23 21:23:53.608375
4eaca88c0fb0dbd9fc259d34e9d576f270d2b3bbc48a2bf7ca0de0fa8dcf7f3d95c209191f1387281afbe86f419a11617b30c1e7ce10acb8fb7891977f7ce2ee	18	{"username": "kati.karu@mail.ee", "is_authenticated": "true"}	2016-12-24 02:55:44.451861
b37d1314ef0e5756bf18ec3de731ebf0739bd62f45a2e9ac5ef68fb618df06dcbd8aa56b0590227caf890de3bad0acbb0d20f85114382e3a2c897dfd7f4f39b8	37	{}	2016-12-29 22:58:12.455142
5d2f17868dc618c188711bbee36b15baae7bfe4870845a07f1843bdc089a0e3407be2734ef5f01daa5e2728700a19c9fa397feccf454ef4ab5c15ff764ed5c96	29	{"username": "asd@gmail.com", "is_authenticated": "true"}	2016-12-27 15:59:45.697284
66e25b17d27c7f3ad8c188af80dbef8f33c15447d9eb7c9d34e0faa09dbef8d3739ccbf83c565e2a849cd740351d0dc98290c361d465088884692982a381b542	18	{"username": "Kati.karu@mail.ee", "is_authenticated": "true"}	2016-12-24 14:59:15.390036
ae18edce9bb13048301d8197a1e5a67c4ff170c842251b73d44c6dd83816c65f9ac45447e266e84ee5880c452c83a8244153d08ddd0b1e51351067f869005bbd	1	{}	2016-12-29 22:59:08.210411
87fbf08b46b77aaa0f633f4f65c640dbf0e825de44e15378fc83936ea23227f10802293ac2f4cfe7dc2b945ca476356847934f2231889ce24ff4961fa9e2ebd2	26	{}	2016-12-24 00:17:58.380685
978d061e15f4a474cf322dfb5702e18ee5a4544d9dee3a3ddd1de1ceb5c651723ab92cc07a1624993e5031a48b370334618590c84d29c09706ccf912f2d80e89	26	{"username": "janar@gmail.com", "is_authenticated": "true"}	2016-12-24 00:18:22.672186
4cfe0436ca4d9e2925dc792ef2e2f90fd979a7c0002ff4418e264b32bb5b9dada1f9af505a6d61fc1e12402f8b3ef477f2ecdc7942428bc5cc10c3a927630b5d	20	{}	2016-12-24 00:44:04.884017
c4ba44c5db4495536103135b477f7d87e70e4623425083628d1a08ed6e1fe911d27a26ab7b4b8c364e443b66fb6ba8cf8711a5f78c98f3c8f43e8fbf922d8616	1	{}	2016-12-26 11:09:54.764429
8f07d43cdce2505f77911eb788af00b1f0612cc8d83aaa5e807d9451a124be1acb4233c7df083c9ff6bb0f82e8d3735e5b9d85999fd1029958f2aeb4bf7f4f7e	22	{"username": "marko.parko@ttu.ee", "is_authenticated": "true"}	2016-12-27 16:38:02.731681
dec56f5f6890c9d09b1921adbdcea45ddf9ff057295d092027e1dc3a608759d469f2d9d7ee11f0491864282641b7d006b953c08521458cb8af0f29b8437959f8	29	{}	2016-12-27 17:11:04.840048
02444a869861d9853b9881ef3e326fb7f2a6160328e573da86d5acb1519619e09b46af508e5686b8187c857e19a5562e697644f34efd43c9a8ce52e4eec278c8	1	{}	2016-12-27 19:35:48.928301
8823c44993c5d6a6f32db8bb3d564c6a1cf3d075bda1af5f183a0e362c5b6b316e8d33e2e4a7d6c30a757bb3e87590290c47b7c594a529930efd30721dc160dc	1	{}	2016-12-27 20:02:58.514123
32fb1e4514570524439b26dffcbd3dc4048c92866e1be73512b11fd9bc07bafe4889260a7f0b35a271a3df1d4d605fe5c9656627011ceacd20b929bb3a60879e	36	{"username": "piletite_kontroller", "is_authenticated": "true"}	2016-12-27 21:15:10.324927
f8a7dddea87471104aac5f87c880618a628d94d564d24cce436920c47ed4f6436e3c1e406d752628824967b23f7778dfca67d4be0b2a4fb56c62ba258f68a773	28	{"username": "juhataja", "is_authenticated": "true"}	2016-12-23 22:46:10.871204
817aa543500793c7e5eb3e72a1bd38fe12a6ea688e1fb0d72db7228d35745600b9a7c9ce03b2a8330bc1c52a2333c44eb8ea2e3998f9c49a3f7d7653d528dbf7	36	{}	2016-12-27 21:15:39.536085
f3a7970dd70a6d151a131ddf55441fa4f3b05073348ba0a140f79529ed4d135128282c6818f7f6a074b9918f96e5ec6015715ba478b2940a665bafef92b5bab1	12	{}	2016-12-27 21:09:55.934969
39cae1c1e1ee7997629218c49af49c1ea778b69b47fa6f09e466fe12a411c12013dbdd9a9d944b8978cbfb1fd195b77f15e80a68ae83858eaa298a52fce92f3c	37	{"username": "argo@argo.com", "is_authenticated": "true"}	2016-12-29 18:52:33.389329
90168215bb9cf16343ca46d2a3957c480289cce20ea96ff584df7cfa358ece2e966efa8bbcaa2cf0706f2f82ca4f65fd823ae2f8d3621956c42db6e06b38dac9	37	{}	2016-12-29 18:52:41.560828
e5143cb296a33c3ee9a4573ee2f42df38e13dde8c39d7c1c1bc3456fb83a1bf08da16f7c87cfdd742481e7a588748c3bf53a20d16da94b35b8a02742b407c516	36	{}	2016-12-27 21:40:38.285268
e07e88ecaa47c2dee19edaadbcc1ab86effafa4121ff04de69c3448232e5a11a6b5e4bd72a9c9adaa4fc0b462d342aba37aa7a6c9df0ac0530f4fb3ef1e13d66	36	{}	2016-12-27 21:49:32.352669
f9953e1e1a903746c0f7f19f03bd70a27d4197dee25e9f0b611694d45dc26a965597e571582573ea8c761819e9b9f2765dece5d4a0fa7e7c18735af7287fb023	20	{}	2016-12-28 09:06:45.488232
ac6bf3b5d37f2cb95fa9b559c94143b269d74ad69e9cc116c7e15f22827be2fb9e6bf7ec4c4b8e4c95d004e8c5ac057f62c318b3f716c4c7473459695b1dc70d	1	{}	2016-12-29 20:07:51.922163
3f919902c00235c1dd4c4f8d1b96d2ce403f49b023a2e85ad8a35630e8da46c6bf258983ced8b63f80e065551b26cb5ac93d691d90f94eaf5aa06aefe5d3dade	23	{}	2017-01-03 14:33:09.807023
29131b5afd6a653dfc31ca0d6e16a7623813cf701e91e8f3cb89b5b553dc45954f3cce8ed913021c5a74884713fc3e06e59fd9b67ecf673eecdeefb1ab6074a1	16	{"username": "random5@mail.no", "is_authenticated": "true"}	2017-01-04 00:48:20.285423
a523c211aa32f300a8db9bb43326e2665c555f10729a99947c213fb541a23e943f43edc4e1445ae807f6d6a2d0c7bc9be858294b8a7e47fb5a7aa49e0e95d709	1	{}	2017-01-07 23:58:56.960918
820e386f27238208dbf4537a6efcc840b48b7ad5e174605c44a195d9c7906e38fd6552a5f5047592487a0ac94b84b1d26eeb23ddbb2f251ed1f4a8077f567ee9	28	{}	2016-12-30 14:45:18.790515
902a3d1495d03cbfdc95185780603ea49a74c6ebb6ace913cf0d65a45f9f74f6517e013e59c8d919d8a2e3c61b96a581c0fb5413f9a75b84f9ce50c392d5b134	1	{}	2017-01-08 20:41:09.245875
e5ded26ba4e69f1550d3a65678961c384295232f2f6cc72af94e3cbc26b6672e3bdc9a07ae158313a7fe4d71f642fae75d3566197b7d87463d5f0633e0e5b8ca	1	{}	2017-01-10 07:39:21.674297
25c22e70598b902eaef4eb403427c1d44aaf1fa8923b0bad69333b87fa19ff4f67a9573437670088053c4388469dbe1586d0e3cb5d2bd1d13fda61c0ce059d94	1	{}	2017-01-11 16:21:26.160477
7fb547afbcb6420675d54c3df3137ab9a6aa7eeae64bda9d636141537617c7f9d2dc405f8179f64fd24d3a18f458636730a56ab9c77f67a557cf58454628a9c0	26	{}	2016-12-30 17:29:06.168702
038379cde5ebf36ec7dfd74c11f4034aebc3014e59c662d60117941da25c91b62cf83823f60e4cc825298da27f0609e8a2c1543b56f5fe1773a0ef38cca55849	36	{}	2016-12-30 19:34:30.460385
2366276b672cd8786e62b79d345c61fe7ed13fc2c71dcb8f6451aa3428fe5e29c79c756ce547f076aaaff110362bbe17f1af6e55245157311a244d9851022ffc	1	{}	2017-01-15 15:56:05.458501
2a9b2dd64c95dce6eca381730a7d427702d5277662e12e6bec91be6503a413cafad9ea86e9550f7e59905f1f3e8dca048e9013091503640a22d6ea8c5bcc5972	30	{"username": "test@test.com", "is_authenticated": "true"}	2017-01-11 17:44:48.252158
32da34853a7caf0309ad3fddb6b1a839b1c17301ad363a27cf4b6b53148d1ca964a5357506fc43bcde8f51f045109c3c1d8e10136843e72e1698723579c96133	1	{}	2017-01-12 20:44:43.934226
abd87163d9f7083a5a7d37d4a52f37620893b2ff9743af40817421c9dc71858cf2e2c1498cc768fa2a9003dc0d9dde9b997d1d41cab273c8b773cbb51f2448f9	36	{"username": "piletite_kontroller", "is_authenticated": "true"}	2016-12-30 19:37:11.480239
ed36639c898baceec4e1280600b119243c4026ff5421154208352b0a871d8a1179fc2d1c9bc3d17b332b77e714a852cda70c388001a7ed30ea8f107843c70b0f	1	{}	2017-01-14 21:00:52.510452
c8e0c73b82c6644771eaefe454c07b305f5fe6bfba0bac864c3706662ebbcc14d1da5adf53a91a0c36c0d7d3662b66e78d2203fc3ec93686c4b2404c260f1b7f	1	{}	2017-01-02 11:35:09.398574
c701c952cbfb0b8a103c5c4cc724b57ca9d63ab2044fe3b7287369a5296d55d86c5e7cdec91e64a4bc0d7843359cd92355ba838a36ac7f05af2d3bb198025a6e	16	{}	2017-01-15 17:53:02.173526
ffb5a9daa353de24853d8cefaacd1a9075c5b5c064fd74710a6f4822ea571a1b1ef980d9db9b3c42f0936d72686cea9eafc5120bf91062f8430b47d8e87c6cfe	37	{}	2017-01-15 17:54:15.848707
936a0c82e0fc0430514cfc6df5b68eba87ea668b7ede4c87a7596479385ba344951fd3f35d2e3f1871119b8d661156a908234577f80e14bd0a2493a6de93d5c0	21	{}	2017-01-15 17:54:23.922414
210632d50bf25767f15098ec1bd331eefd168c06c3b00ced9054a2f1c1be4873532bde2e5d165d14861d5bdaafaefc7229c00c04df5f61cce1292533ac49dd2c	37	{"username": "argo@argo.com", "is_authenticated": "true"}	2017-01-02 14:05:24.230094
f9d15917b5bc735209641fd0567c5343f05fb158b9b9bbfd59049f397494a1dc57a835f1234e674d52dbe808ac94c5d072ccb4d1984642561a3efc2d9cce235e	1	{}	2017-01-16 13:32:57.866997
c0f943815402e258e29f51752a83e8d80616e8956434bd1c22727a0dde2996a8f0037e38f81318ebf1332e35743ab7a2c3aee1ee7fb7c1ab4a79083a221634d4	30	{}	2017-01-02 14:13:46.568283
f38888b835cea95c7a17cb287abb0964f842a247fe30c47db45237555f2ce2e10696f7c63cac5cde28ad873ac548483153822b2bfb1039246bb9227df338da81	1	{}	2017-01-17 13:42:10.002284
3c72c8c782bf05aa999b31caa099a14a85c7f2d2be1dad2cc0c32c86c5145a864d50b4e5efaee1484ae82f0fddcfaf39468a0b8989e1fab51de7ddbce12079cf	1	{}	2017-01-19 07:48:28.969557
a95c992376cc3859e9a72be685884b06ea8a1455392801efe8ae47e0b874180ecc0852e64fb2a4853c0be020b1e78a41ede5b43d0c7372973173437be305cd83	37	{}	2017-01-19 11:05:41.659575
6a882c80b1b93d843c8d425932b76a928c9deefa86f3bd9414b266ba2ab6e9d512fc2543220608aab2b853964bf9f6d57e0c1c73904d1e10264b1ffd0c1d31e9	39	{}	2017-01-21 00:48:21.300436
c408dfcb27d85d320d3cddda62bbadf55621f1112e67d7a7e61655455a3b002d868b40df65a0cb7bb2f7e015dca098943c4ee6f21f636a223fd9e54bac79a9fa	1	{}	2017-01-21 08:24:52.536439
b09b9fb98471ef1cf01977706a51d4929097d36f0e0fdafe6e7e72f218e931d5c21d8b34c7c61c8a9c72c6d544b8d837c4d5503726d52479b4087d4f74a5d741	39	{}	2017-01-21 13:19:23.837548
83c2433d87bdf6b60eb2f7b2e570407b1de4991ddce6246a9dd2a13f99c5d6fa33f4aeb445fdf6dc177d9102bf52fb2020bc2b6b57d69ceb34407b9294ed5999	29	{"username": "asd@gmail.com", "is_authenticated": "true"}	2017-01-02 16:07:31.646877
15ad8394f42aa329400d272719e755463f93c48177bb39adf449da8279075c0f27aab31daa077e69d999c7f141857eff77e3ea08d00b38fdb7c4fa5ca1a9d54e	16	{}	2017-01-21 20:40:33.801862
25f9bfe4e4a2bd4b22564f676b4afdae6b0c6cde255e1a5523ae20644394e9ddb3a5e175eb01ec45b87118ad897c0790799ca47d4d4161962294221c584a1d59	37	{}	2017-01-21 20:40:56.399268
62ce88cd43c4c32614e65eea1d51b1acadd2b22cc7e7dd2edb028a037c0b1651f666a3119958198f45421d7f584a010089b680ddeaa71146456e3378cc2328a5	39	{}	2017-01-21 21:24:21.835242
3a6a06ba84132a59e5ad0509852bda4330b14c91c59caad03deb61357c66476203966f7e74b81b1d4f313b31820dbde0c30327166be3f6c24b4554a64d2ac111	1	{}	2017-12-19 07:58:31.200327
888bf8f38b39c453e8886da8ce25826e774bab37e98773b9419b3fda1d53be788a07ddd1d9e264b3419551e3b38357509015af97732dfa90d73f8e40bfa9dbb9	39	{}	2017-01-21 21:25:09.826856
62fd670e6803422e16b1526566570196c3fe43936eef8ff46fb5212110a1e91ba2e9bb63e396088b446bfab0c22bcf677c7b2096072b405aef66c8e557dcd7f1	39	{}	2017-01-21 21:31:10.297049
a675077951dfe93a12953bff3bf6bb89aaca6f64e60b7f7e5453d8bf8358f4da3725542ad1ac97f576d4ada8a179208093288d6294c58f331a07ebf44bc2734a	1	{}	2017-01-22 17:41:09.760164
d3d6142b19025c4dfd06007d31132192a03c03ad59caa1c1906a9b6609de38b2c16abc49351f01bcbde050fda6c66eb3673c45f4d28b38467ebe3ca91d84c63a	39	{}	2017-01-22 17:48:20.687232
cfd1bf3e8ad415ed0011b7cf29a05d2a275531e8fdea669e01505e51e5b80d3045596b1e33c88d67f273fdc95178bf054b04398bcf21f1e9dbb2e1e3bf8573f2	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-01-22 17:53:50.611013
1810647f23dd3b7addd4b1a72de3b7e6a014be13478f91ec508004fd3699be157f8e3bdc530820dfe21edb1704aeb998ed74562545801f05ccb725a5b8a393cc	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-01-22 17:55:34.792881
cbd0a53f974a63fbe1677b52bfdaac130e336d29d4ad6fadbcc01e35c6fa186af39d73785196afddc289973c175ca53ab00f8001a0f81801e9f96f935d809dd7	1	{}	2017-01-23 18:24:02.763551
e897ce330e6714b59c073da65004fbcf31d7e870a4c88e2a424c2d12c03ec7ac4da87bfc48e92643798273f0762d49a8c4b60f9e790f1fd5e1a97cee6439f05c	1	{}	2017-01-23 22:41:32.729014
85ce542de592e0a1179cc5018956f87354f538ce0d8212aee92978afd325b7b258c3c9a6cf750f0964c14372afd332e4da1fb114827359cd41f4f8a0451b94cb	1	{}	2017-01-25 04:51:02.794507
9ac1186f00518ca9caa4b005a9f4e1831c319abce84cc9c70e3b97a41f201e6001b597f339d7737e1fbb52a9e131677290a5eb2ab63dec908bd5715f8f5f3b7a	1	{}	2017-01-26 18:17:15.788617
4825bb4bd677a9b7282a2a30a17fecd0f14390e57dac88f7213123e00fc82614934af997fa237ed040978259561ba2f1f827ce09e74e9eb44047333708b0e4af	1	{}	2017-01-27 02:15:36.684438
25d638e20235f727ed06e8a9df79ec28ba038284c2696d167d9a386cc6806fb2699c141a81159eaaf5f850f6e45f2d66a3a3c43c31182a72b4bf289475a05041	1	{}	2017-01-28 21:16:32.277593
da63a460eb40024b523b6096ccdab0f05b9d62d389d68f37d7144ec781d5b6a33d0eb5730f527f6d74bd2293bb046f05dc5f18e8cfd1ceb7a5ddaec6d1dc87d7	1	{}	2017-01-29 13:20:59.519427
8868db6a99ead4fa86a32f734b1af708d78aafba769ad6b42c9a963431d87f974f6bb2d6558c2e754e58573bbeab113288c0c68123ad3bb1b808dcb71b300129	1	{}	2017-01-30 00:17:46.600551
e47d24348df129a889a4fcca110452917cb04e4c7f8af2315d47e531228d7708e67a6201232343688e267b87fcd9b7af56371a59e77827f67e1c60a3bbbbdb4e	1	{}	2017-01-30 13:58:07.533375
b59a3967bee3dd11b41d17987f2d9e37fc9ad8a85cdc6476a5bd0f1306a90b732d21c16c3eed4c1d906b5488cdadbc7e8cd8e7182c65be8067a55042b11bbc2a	1	{}	2017-01-31 07:59:37.829497
548e654c0cd1f352203a2f8964e26b761f1150f4c837952f587d25fea7c1e4fbd19b3050be706795990322367ce76636890519de775b447fc90ed881c3f5a350	1	{}	2017-02-01 16:13:26.146392
fcb5554fdd64af255bb103d65a3cbb60e9d3c231f8e1a2fd6958cad94044390c0858b755e9e9c5af6fce862cf2399b9271c433fddf895fe4caf8f4e3ba578d32	1	{}	2017-02-03 01:02:54.591856
ca9d9cb87ee6e515bee9d7bbee25534a1c1cc030b9fca64e76b03afb99b640d39e52709c9bb7c0f520e5caf340a4969d039bd795298d162daadd73c9a65ceaa2	1	{}	2017-02-04 17:52:33.091687
d802e74c0e8e4cd075afb7885d98c36dbfb52ba438d847883c0b8d527db5a1623dd05a2575a02c158768e296f9daac48566c092a94e5d6d86b7aa8ec0645a15a	1	{}	2017-02-06 16:34:35.12566
295099a8a2149d87b06f279e96caecffdf6ce928130d5fe7960d374a70fef5e137ed66b97723277054756a58df308fceed9daa8cfef30a93f0c750c1c21ee8ab	1	{}	2017-02-10 01:00:30.085461
1f0035ccca00590b5721c03b8f34f311c2722658507f8dba85640691c6365097eb2d3f3be154c48cc36b0cf0ce1d1f261c00c781344f5ddbe1d677b0d66494f8	1	{}	2017-02-11 09:48:06.773026
74209356512379ed2e75112b0aa492c2fcd902ce6b64701879b5421763551f45fbd3a1ca94c3ea03f253cd419bf2e2c366a53110961289343c43d819371fa436	1	{}	2017-02-13 07:35:39.957006
a6385f754e7e6e09a324e96c11704f9accb0244836195ba72207e603043887575c90404e12c3bfe9d68c36ed33f4ab610786af26be4b4248198e1c3d1af85f52	1	{}	2017-02-15 02:03:32.545553
53ced1439794033d4cc10c2a7ba71d784eb0e1679bbc21ee4f5378af65d2d2fa751749608a878c4bdc067d9192fc7c3211efc5521ae3c78c3c6c9eab6199a8e2	1	{}	2017-02-16 18:51:26.307932
d3232dc4f3fa4608a19a45266d91f35122da3c445c883a2a7420472024660eba76bd04aaa950b0af0a4eefb0feb5f961494508bfe382bc94ce99d5dc9d208255	1	{}	2017-02-18 05:39:11.079998
7384d01e90f2f01b3657fac7bcf12ff170a05f22c3f6e54b755849a5b50b858473689e686dfcf28f570f175ba98132aa161fd7840c9480a3e6826e7e1f65f9ee	1	{}	2017-02-18 17:42:08.053624
ae69178eccb1a74c6b90ca16dbbfba5676582057e25af9319bb3d65f4876e1124bd91128674fe4b11df6bbe02a050fd28216666ca69b1a3cddc8c1fbc7840b2b	1	{}	2017-02-18 21:47:44.75458
87df542e1d8584f63d6ae75abc2d50340686603d252cdac94834ceed1bb8e1de958416250c2122362a48ffec0ed16db031df05fb4adc99fc5687e5e2f6c9b33a	1	{}	2017-02-19 15:17:09.454438
21cf1dbe86306a4a4b45eaf55c6b78a7d6c13f3bdc08ee3e5c5b8e3aae980e67b26c6dcec0939bee51047f5633611aad83ed321fc9e2d2548d9a62e5afb50acd	1	{}	2017-02-22 01:40:59.173885
e9be2630f2b22fc6f6d653b93e558bf898709c6055cf3310ed8627078b20897b2f8cf0f09a98fd45a02aabc1f76a128d2193172313b3aeab3f495b9c21cd6277	1	{}	2017-02-22 18:40:12.93414
d9d02cc55b02b1e79eafce568994da915eecaa2bcc7db5c2a26ea5845fa4990a5d8fb313e8cafd59c25cb6314a1e13e2573fd7ee2d991ef2ef65824dedd5a4c5	1	{}	2017-02-24 02:24:51.063116
8f5991fa8847e1ee5393d3051ccd327f26f8eb4ade8a8974ecd263e9e94bbc21dff099606e7398d1a53b3a566b0771fdcbbd6afc8ea4b8e2a6192e9a0ae425dc	1	{}	2017-02-26 00:25:01.91135
d0c09b6848710017d48ab925b75e38ef04d5a08149d2c421ca731b4449f355887593b42c3a174b9858adaf73022e4c53d02077c75d65fe67d2b8216e59dab604	1	{}	2017-02-27 08:28:53.137303
6812a9ffd882feec9f9593fa3bd0bcdfff57d0627deea516be08a314f6dda434bc1d08265b6162161fc6e89441e48bf11a91facfa98a4737dd07528d75e7c58f	1	{}	2017-02-27 08:28:55.120711
5cfcb6ba17b5839ea71c8c2f91bc79b38470957d818040c9a022a4d6b5c3ae16fc0e5e3b16de942eaff973b945c20a62c118d78db2f06d62c57249b5c8d2a2e8	1	{}	2017-02-28 10:36:29.977705
a051758ead43e9523cc14f8b6d5fbe5e3d7eb4514390eb0b672d733c174b77e0266abc6717038d184208af327a7073a28de15dbdb5723f5f29214e74c39e3859	1	{}	2017-03-02 04:13:42.656876
86a2c5b6bfc861449bf6a0e4f4c0c50948346e2dc1c081e24d73fe57898309e317a2b8564475bcb78b653020ea859cb992aac9a8ffcc860109740994fd28aa17	1	{}	2017-03-10 04:59:33.38715
b50ee76074eb9032deca7334d0101c2a41bd5f956b34c9f547f90dbacf9372391abef67251ea1779d078b58a84b80925a0484f9822a02768444d1493bc35eac6	1	{}	2017-03-11 06:58:57.809982
5da297a15235e6a89d66cbbb8defef21afd021381fceccb4df9d2cfba0495f8e5525c832ac63ea12096ddbb1d9840ac6d46c835a952ab2f9bf4563b922610ec9	30	{"username": "test@test.com", "is_authenticated": "true"}	2017-03-04 02:00:13.400995
ada84942105e4e447579df3e7245124d60f32f4a7661a2606a5a671f37ab9ad38a3fc8929e5d4851592aa711496088598f90336775563802a15dca8d66826578	1	{}	2017-03-04 03:36:32.792183
ca8cf4cf3b06e3cde72245e9687c67e6e850e38e297b2b009820a5e14de448c23320c88439f97bb756dbc1b173ad31da83c83cdc19a60c594e4a1839decdf815	1	{}	2017-03-06 08:08:43.588169
bb07495133d092fec81823a3b97c86b44823b918ddf840b8777d00fec57173ae2e2bfa36c8ada3f687cd88e18213b1d97bdd756362e9439256771ea5ab0d760a	1	{}	2017-03-08 00:18:49.133694
ad73c628a9028a441e87e7bd4b2622dde7dc350a82bea2a611d5390310112747bae46b137945f5877b675b1de6ab0654c12bf5614377aff98d5a552562353e64	1	{}	2017-03-09 23:57:46.809868
eff6ae7fb5e64aef9ec496d6f02ffa6758dc5dde3627962a10d50bc5a2ebd42004a87d96905ca555378814002a0bfaecb5975fa00f3d3d704dc6a9dfd9a27625	1	{}	2017-03-13 02:51:24.836586
ee127e16bf555253b8a3c3351dcff8601994cce025f46f17b91e37e37a0cb9767e4ab4f92f6ee91c245c0e170d85b3107942e485095b3da59993fefd1d2c5977	1	{}	2017-03-14 22:39:40.237511
c8ef764ea96656290f2152d5fe2a12368120ff462873755c94ebc26f6b37e6dc43b670c41ed1bf5578530a6db278639d8d0c1786bf61c90130b5329e2eb81c50	1	{}	2017-03-15 01:18:32.502596
5498d1cf2b963fe937b3577b5f3935e095cda532c8a633b2b62db4b85af310b0f3272b072f41cd1c6a9361fefd41d946b2f77f0e67f277e4074c10908107188e	1	{}	2017-03-17 08:26:24.969593
2c1f6a3e39deaa57e19aae56e42040f123b532cc831149a8b70569a3b8c6527e1d7ca3e5c930503eb37f837a5865e0547d046d610a6700c515a867ab3477a8f1	1	{}	2017-03-19 04:40:59.654278
3036447d0d62a92d18728e0a3920e8c80068fb6435de37c404454f5830ec529dd47e28553fbe2f4b429291fb223a7c4437a1b486309762c47277ee1dfd5be3e2	1	{}	2017-03-20 15:33:24.474875
60d072a7ff2341ba84493fd61df4b8ad0f163e1107b2088da2799109d37a2ecf69bd0b592e89808e34245de433c564de1b593a83a55471fd985a6b0e37618eaf	1	{}	2017-03-21 05:15:49.543459
09f97bac500a1053ef8c9dc2fd6feecf7b52edc4d645cb2a2351fc6a90846966276a84bc3beaa8fae1cadfbd73d91267947670dac56527ee1b38d8739961a5d2	1	{}	2017-03-22 19:37:28.435989
fb69228d6ba3358ab4d506acce0b93af4ef441d05ed9c2817c678069e0de519dee2767d93777d45431370fde9177fdce2db9bc5d05be7f8d6141ef3d7de756f5	1	{}	2017-03-23 20:04:36.683917
375d59af966f42c2d9c5b5479de94cebf0a7a14bd74329c9682b033fc2b54b186405133564d8406a61aa31c641aaf4e01b47ac97c33102c9a97469c501e36716	1	{}	2017-03-24 18:43:28.098485
aefd2080bfb40e50ea16e1e73ab6866f53215bac91ab1a14deb2712856e467c15f6e194f27c0f364d90d5bbae895eefecb7c714daa1299ec0ba8e1df5b7b0c8f	1	{}	2017-03-26 12:38:04.191687
6417e9a1c38750b19b0d862dd3adab4b015d753b1c65be4ed36b6f3831347034b53a95afea4b6d7422547951284fb32a32a4639c1a9bfbc223cb6af5ec3f3f9e	1	{}	2017-03-28 06:03:13.735219
fa63706493dbc2a9c080806bbc287d21bfc0d52a7ef771c8307b3babc400f271be812cafdd1134dfd9cfe8521f21fca504496b4c30b7fbe8ab6a37edea4b3ffb	1	{}	2017-03-29 17:48:58.927514
e96247285eca9539c222d1bd75ec304fdfbe674655814cf1f2582908765e7b678575a43980397e8bfb84bd5c0f74423f9b0d0b4c09d1a7b504a539cb97c2aa36	1	{}	2017-03-31 08:10:36.124684
5b9f6f1230d5da08201dd1e994019423f0783aa9c1a8422dca2c379e64024fb378fb64c880e0396139792b56e15a15f6026e68ff825ee2a55dff8b21fd813e90	1	{}	2017-04-02 23:38:42.322459
94878abc228990628694c7e0157bcaf6cb6a43fe3499f28a7964675b6617ed3dc64d28707e9cc6e1f51563f4f0697bcd68385938e9913e566e3439a1b135c90c	1	{}	2017-04-03 00:08:38.382212
41edaa919ab14470f82e10f0e8dd95b90cca58108e0c0d7bf48dcd04606b44da5008bb586b18d13e9a3bfe4004ed99e93f2ba215cfa04a96d3d32c8075b51dff	1	{}	2017-04-03 00:43:00.492196
849e1a5a12f90d02dfee959cba23659f96395287094ef7ecbc15ea1d9179cc1038dcf6687c39a6c26c827c6df3908594636cdcbbf51f9c3149986e99cda7680d	1	{}	2017-04-03 01:22:53.741306
47ea5c373afe17ab963d838a3d3af403acfbba51f6fae6ade8e6c7fe3ffe6c3cbc84d462439983b49780bc8ebebfe773ff576ceee2c27b36262b91dddeef902f	1	{}	2017-04-03 02:05:38.188543
105a77f2ad7bed8d1986b91da0f694afa1af230de29dc60ed0bb7e63668ac224e8897ef2e752bea0aa2a0915fcd84b9f175ac0b2b01db83e044394e7224b8d70	1	{}	2017-04-05 15:15:43.58533
04d30ed3765ef6fb1f64bfcf8a84a8a03a1f50626b80354f19e01d423e842eff5780924d50adb69570dd6a48ef0725e5d43ff43a666252381da18a6ebc4df276	1	{}	2017-04-05 15:15:43.95225
ae0a5288130b49d53b2632928ec72ce08c46741a68b2565dad8631dd43e576791467896a1f8a4fe5c66081c81b0d947ae845c21125cfc0c8bbd595decc5eccbe	1	{}	2017-04-08 00:17:14.854836
b7d7ffafbfaae72b9ae1b73cc5b5a3c4110ad109c456087ab7ee23a2b5ed3ef9fbf48d97896520b2cf7f731ea5ab932f543e22536178cc562605a5733aa0c57b	1	{}	2017-04-10 01:14:50.179459
35c4abdbfbaa140c7fab17830a6222a92cafc721799c94506cc40985263b76225dc3f631d611e9c97fcab2e150da5394d0c69860ee583707c8a10a97442fd4b7	1	{}	2017-04-11 05:39:24.794452
ec12584fbda4bbafefed03a74b2bf7aa4cd57a549e3f138f227f60617378e970e473a88713e1eb6dc1d1a5a4112204d829d5ee344e1d773a74b4df75ef950f1d	1	{}	2017-04-13 12:54:01.210526
340e8adc1103d4c79f49c5fd71f9e9c645d9717cb37c97737ba9c827e8174dd501723f32dbb81eb799cd8e74f3f8f4524e7755acc40e432830a744825b54e545	1	{}	2017-04-15 19:30:33.366141
f1a2f6b5c999b1d1391b1c6f0cabea872813727f6cd372ab8dd6d5c60feda5462c990b1df3476fe4c08d81fcac84556aefd5b97b347b18891ab99d1fba237b25	1	{}	2017-04-16 20:08:05.612437
e6be6deb6dca2e45ca9472d27fb5275696fa49c7390bdf7743f2a33de44f366881cf21e65b92962c9d5a08dd3460ef6a8254bcd9bf125f73efc9702432ae3ad6	1	{}	2017-04-20 02:45:04.427392
dc3aa323f9ae3d680d03672070d9a3ec0cf427fcf259b74ac6a1444da41d75cb079e6a6a8a95128966549e8595f9e6100985f9a5325e274067d9f95573d2b510	1	{}	2017-04-20 14:04:31.553879
96f355e7bb6f41520f957ac1f800e52f95ba04636b6ff94c39cbb9155b6671311af1930aa22ef950bdc16bc7c6b9d05d71b77f9c829e09a7ed89d462b42fc560	1	{}	2017-04-21 14:46:25.930458
b5d16179dfa502044e9605782ad2ff1d5b9d1abeeced94901b5fe5207618e1b18a06f847b3b5446b61108cb0c5485f1e98452d6abbabb4367a3e5c2ebd9967b3	1	{}	2017-04-22 07:16:51.427163
301819d4050d5fc0e00f454b44b630b7f6e5c798313fa5242aa1bcbaae43406bc9031c5fcd35c1549f70c7304a5e9568420236ea5ddf09c7d4a25a88b3d12ca0	1	{}	2017-04-23 20:45:45.449559
b7e7d083c0331f2322abd5d17bdc90070aabea760bf8b7c1891f5e33bbb5d4380a12848b00e466c348044ff8065af987f207c711c0b35b7ffb7141d24cc6bd81	1	{}	2017-04-24 17:59:24.425314
ce10d3137bf611abfc3ebbddcb6079f1637342ce83df2543eecd93fda7d4d02b6d4090eb55c9e83012955f6f664d62678a3e0d05765d3da6e95426a3f01a7297	1	{}	2017-04-25 22:17:29.437038
77f78259e3bc676985fe1cb423b9d63528a16651ea430155b3769dd7c54f2bdb58ec0f417789280d85dabb0c11edddb850384967ceedc0a58615c1de2e29049e	1	{}	2017-04-27 00:38:08.221998
a86e19f16a80318394c493f4597d45cb269d432a0d7fdd7673f4604fca272146b1241a601c22ae207efe577c5c55131b651d3502e3cc1fbd05c53b8fb6c52426	1	{}	2017-04-27 14:24:34.363212
1acabf8b18593b2e0d32d072eba86f142f9f1d167ac385d5394362f295b8302fdea8622049641e6d72a94b160b4fa797a1509f8b89a928d6b9aebf75faf8af52	1	{}	2017-04-30 02:16:25.638356
4180ba043dab240f8a22f42ef0a5870e163f170c8a0a7470169a9b6f3122fdf7b990ca3df17886d012d5ec5b34bcbc1e91f267fed073e84084913e5838b21c76	1	{}	2017-04-30 17:56:25.595422
7da1b0a3e8fe18ee101110a2187c955b8daee207e558b65fb62e7fd9ed8c71213a0ca7b89a6d00cd8425d0086d2ea04cd39947ed78efe69ce032780cec844ec3	1	{}	2017-05-01 23:16:09.103954
47b9027d793ce67de99dd602f33be2267eaae0510bd285413a5df021f1a682c0cb51d61f92ecf3f8cab426b0c4bda9d107ebe50ca5886a13b3a06de0d756b483	1	{}	2017-05-03 03:12:02.955357
8412ec5a8aa4a37f68db18fc369dea7b56423de46d557fed07dc056fa2f153b35731d2af78a76a3179b9fca1286c514f5070a743faaf7c0f4d4e5feaf740bc17	1	{}	2017-05-03 08:31:43.853177
ae446fb99e0a434481547c991050d8f935789471c8ebf7254ca6c30c6434eac67dc8c093738468d6dad70c3b116b71a895721dc6ea8b1983700c133a4d48b05a	1	{}	2017-05-04 13:04:00.303737
ec2e4ea7e7c71d22ff49aa15a9949e0700c8be0b418ef93670950c490e59e66ca9d8d2fbbbe3a6b3ff476e87e3d3fc5f9614490c5653b0752a626e36b00df36d	1	{}	2017-05-05 09:47:08.19371
0f54d431cd7b031d0fe6d47828b39d8d33a5bccd4b6ae70ba5dba9b4868184c92278f81814802d181c805db79dc2baa223c838d5a655a77b353180f36a9aae5d	1	{}	2017-05-06 22:12:47.494588
d467e54c4b03d50468fe937ae2de8bc396ad1abf6224b58f934813d0476a62d978e003855d186e5d69aeb76894c1b99916d672aa82a1423b447d388ce412b43b	1	{}	2017-05-07 13:21:01.061198
7c36ead3e0bdc42ce4ffdd742b887b0e01af8ec22cddd78a9901d55ca0745a307da4aac58212c8027aec2846ececb816181a4d1692cbb49a0cdb6a7526b5808a	1	{}	2017-05-08 07:31:39.749374
ccca68340145ec3ea524c87e4580cf3a433a9c78535048825e379d1ed510a50ddecfef8efa90776f6e96db8b85d9e495c05f0aad42c845af558a0f678b7f3a9b	1	{}	2017-05-09 21:09:09.138021
085c9cce070db88cccd996990c7885c2866be59f9c5eba0e111a18e1b4f95974d6938ceddcc04cb20bcb6463858ef5893a36c7fd05e9f63e305a9a750b77a35b	1	{}	2017-05-12 08:02:34.870481
2ccc3759282b7a8b56b109a4f02466ecc4e9b3cc8595a51fcf510ace3340c5eea49305ba6354d7a588f894fe204632a9564409afa49930eeb9d605c7d2fa4d40	1	{}	2017-05-13 18:17:25.982445
b1c441b7ae55f317deb35a9eb1ed29a16510ad6c89f5dabd7d5c4beb539565ba7468fa14a12939077de09d3741b4f928f1354780830af69415ade41aa3f942ba	1	{}	2017-05-15 09:27:01.019434
53e6a560111f3e5ab7c7f05220453f9385a468e445b1de68fe6cc37c18c9891a35c310491a9d718a5e11965c40cd152ff2195c31ee622cf2629201a100fbffe3	1	{}	2017-05-15 22:07:17.073172
1d6959ad7a910e64039bed69091d153b472c9284ac16436b04bbab5d059e5ced3a10256ee20991e8bae8dceb042bfcad3980092a97f0ee748fde39821c698453	1	{}	2017-05-20 00:27:43.25784
36bdefb01c9c26c664790272c47d45ad683f9873677aad5e828c1d4aebf89180e54a4d94e20eb99b4d8c0074dfae629c4f20587285d5425c8d68548992724dc4	1	{}	2017-05-20 09:05:32.219882
df950e5dfade089e982dc95ddcba88a12cd0b8adc0773ac966e514293aa2f3c8cd3214363772762e11c774104a9c5b1d7c610491ec42740188ee477e2bf0a6f2	1	{}	2017-05-21 02:32:22.013576
0a0c611b9f60202a4fb1b525b219633b18da8d9e8491454a52fc6574ac76f360218a0cd1afdb9e5af87f858ad81310105cb83bd225a6f6e820a6910f9bb52033	1	{}	2017-05-23 01:52:34.402571
f692ab5ff77b6f2312484dfc2cc095dc0a5567a7b529242d9f4806655e033136f2775a7fa5acf3d984dd1146bd8d6b0f949612419c96a036246b68a4a2a1fb74	1	{}	2017-05-23 06:09:05.260698
09a3036174b58bc78d2a265408fe022a8b92f85a6bece5a0f7546a3d43d1b4020e7caa470ce880a1dbec34182e908453c1bbe0732faf4cfeb1f65462f71a9499	1	{}	2017-05-25 14:06:59.645039
514e40353fe33d0e7849f78dbd81f0af06e8a4e590012466102dd2074d1d1a5cd973d2c99f0f67fe50f5e55ceb855453644b71a0c68ab8809bae728f4cbced18	1	{}	2017-05-27 13:36:33.016845
1961a81ce72fcc6e1bcd46b2a2d3822b9d1c114b8c61f3b936d94569f429ba0b0e58e9554fcda2beaad697164e9ec6c0ca8250642e57e999c148c7705138b8e6	1	{}	2017-06-01 10:42:19.17042
d5c392e12e23ca137e62891e5bad0608b1a69a0e1a1d9c11b062ce5369a721d0f1c9eda7c890461f7c34e5e41bce02d2dfb028bb2196606b685ad1efb1ebbdd2	1	{}	2017-06-02 19:42:38.758051
1134da1710e2e1ca1dca7d6ef3fed18fd0ca8343f6004b1dd4a07e51326543bacd207e7317599c9b2ba515594eab631a51de3e081de182b47a24fb483939d347	1	{}	2017-06-02 23:30:31.048819
a3692a1e40d24387ed4715ac8044b59edfd4f8af63a403b63f43503d419051d4cbeb5345c680cdffcc0cfc7a004b1d6d5024b9f684ece518112250aef87c0d9e	1	{}	2017-06-03 06:39:02.40744
153385c0de4c98979439f70672c5524ff7e41dbf96cace7a52e804bb85e1853aa13214b0c5f7948b45556b6b2e81b7118c7a880192c68b18c4ffb5f13d320f36	1	{}	2017-06-03 22:39:18.574155
9f59dbe2ffa62d15bbf2518f390ce91fbaf097227b6916a90042a9f002fe51d3fdf5b93eab2e7fef3038a9a902993a10a498e37c7c71fe807a7f9a476a2248de	1	{}	2017-06-04 21:47:27.727884
123a7119e1bc8ad88a0576addfe354e3b2fc40e9af82d98e7517e2b04869bb4df4330bb737f6232898c605e78357cefcca939789b5fbfa8e091472d9789a026a	1	{}	2017-06-07 11:05:50.543442
ebc57ca0b91b3db0fc7a578d07eff21e395c24cbfe29a2ed8039b294c59aab5f4e1f8f13fde5ea61f46aaa6d858dc9ec396d5778f8df35b364a5814543fc77ec	1	{}	2017-06-07 17:41:19.029721
0f2f21639c62ef6f4189ec17faf721d70a024601a1a9a4d90244353caa0da680c792c2796eb86d2184c27d5847513247042113653292b9088172eb9c504b94c4	1	{}	2017-06-08 21:04:07.897626
d5f29134b8a5515878832c46f253deb6a4c9100d94da5ee230e16f5b4b1e4a8fb463d61d3ddba1e05fd5b95a444a2dc051e0d84082ee8f8ea1d1b332055ea64f	1	{}	2017-06-08 21:13:09.795768
f6d417315121b010fcf9d03883e265458df7092ac918f53ed9e868c3f85c25a21589e0e938567ffcb31d886837b8a270378b6c849ad6045682d0938c422c1643	1	{}	2017-06-09 01:34:12.284378
678335343cb98ce6bd1900eb569489899c50d45b914290e1f1bf1f2eff46c018ed830b1ca9ba0154cd25235bf3557c3f56036b2c8e141bdc25c2602f33a41afc	1	{}	2017-06-10 10:36:29.283547
b5d917862e05a9be8119820a7a8488fd72dd03de5ddfa0c081e2d0652702429111cdda00b1b573d6bd9af32f4c2f811a085d9a41a0dbf7f59934cb7178877e9b	1	{}	2017-06-18 04:00:04.738959
e0a410c1211bd1b5288d1ddafea39f4dd83fb8418fcfc029e5576040fd9799b4ecb8f00ad2d1c687f7fcf7dcbe65057a0eecc7a47cade8ac0fb13058a5e9ead1	1	{}	2017-06-20 18:46:23.193343
82a0592b225d5d9e6e7468ab5e40dc586c43366de3d33bfb4eabf291add894cc0dba89354f2305feb34b56f020a8225da1a03fab46b223e76e95ec58f4259b79	1	{}	2017-06-25 15:45:32.654046
f769b4f3d0386a121467334361d59b266177bbb4825fdde2b623b047eca5438cbaa6cc82f2df32e1aa01d315553443d29f96902a9e293b9902765e9d5be01af7	1	{}	2017-06-26 20:22:41.754121
78f7514ac584600dcdecfd3307015ae6d681f5311a4bcb2060dd10150892c213e64ee24d243a680de480ef7205f3e626fd0ddd161c9e813613fe15d080990e87	1	{}	2017-07-07 02:51:19.503951
65a530a27b7f380ac556bd8c20f3f460ce4fdbb4ff21e4d943dca52dd76a6ece8ddfd906eecab97f554d712d3ae87ca049cd07c7d6cc162da5c0074599fb9a72	1	{}	2017-07-11 06:06:25.517604
ed6b9fc7b774afd3e62920cd5db88a277b1bc792c7ba1c36aa9f2cf15fbd250f9437ee90c9f17c26a6d2bd5296b2da04ca4649e1c0fbfb08b60849d33ebf9107	16	{}	2017-08-07 19:03:10.933314
10f521aafb994c466117a0f9ed8f7a248eda4e18174a8088b9e47663ee09f3a59af3b613dd5b9d2000397ac7ba7f5b746a39eb6015d7d44ff41905f91c99e2b4	1	{}	2017-08-11 23:35:16.456221
14b1a7fc27b4a00bdf7a61eef108f037d639bfc595d10bcb94b8588111fc523ee906d90c16657d6f58aefe5fc20badb00ce8e89f6cf2b515baf0a198e098e9aa	1	{}	2017-08-12 00:30:35.583655
391309ead3fcfe6ebe810f2ed348194422d083e226b0f0c398c929c4e358763a60aa8add9a95a6a5c2413b4caaae88324d93a697ebf62aa25d859422b6e2df7d	1	{}	2017-08-12 01:39:10.8682
2956d009dceff57dea73e92668a4f4a8c2ce1d73525ad38c8e6f82053c07f2fb53433216c119cf02fea3f69cb307fd9c74882672a87977b1d24fb66a4e8ae0a0	1	{}	2017-08-12 02:02:53.454434
dacb3d47c3ef5d0ac77749c68af2b3b7bf6f9d82264861a6fdb2126063043d77773a123d8693cfbef6a3043beb76b9b99c6e69a0ac9c31698c4209732d094ac8	1	{}	2017-08-12 05:21:25.321676
dea8608cf35f0c4df5618943af22e1b35cf1efc5ded72b1752d80b5997d4f31f402d5259392246a9699e29115e8aedc3752943ffd6dac0cd61cd38f20b814c4f	1	{}	2017-08-12 16:53:22.213903
489b99032aceae3791e58a75dd34925cc4fbd41a527e5bf77f8ff09b09eebb7708173df12ddc91b05a9f37e59c3593d5f11d5cce6ee1bed14e98ff089ab23abe	1	{}	2017-08-12 19:51:01.950843
3fde295ca14e64b8f1acb6bd3fec8629b8d7908b6ca9154102079134e67dbece42ecb6034909c2eac347e2090b9d966f016e758c0ad72abc49e7645943be2cee	1	{}	2017-08-21 22:49:18.498932
aa5427ae8a66598313d778d80281b0f16dbaadd67bad8ce47cbafb7e852ebbb01b5881b9eab21f29664aca9d99856d4ca5d478ba80a1caa2cd01b0c530162ff1	1	{}	2017-08-29 15:37:03.257967
22050471d1d159c3501ed7817dde5993969e995b26b4049971c15c79c823b4d81d21c0f9fedea68071e68fba5ef78b912c22d52149f4804702225bc331310df2	1	{}	2017-09-02 03:52:36.258709
1facb7bdae5fe2a5dd53ff7cf36f46c6ca3f20f2801c872f920f6ec00da3bcd7f9e623d409b46133b8411620490b1a2a0d9dc2351367e00035789d21fc898955	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-08 13:39:15.696601
6972cd9dad0bf0f707a4dbe833085c589e0cfa86e982701ca7e3c7903ece62589ec0930d6260b7e1b4af93f778ef5a43e747901f94b8f2fc778ec39b76b4d846	1	{}	2017-08-27 18:14:23.216235
8434756c035805185b27607ee9a0a59a444cf908875367a34e12b21fc079fdeec064f20df9944934fad05937a58f44847e953224d52a8f9134665d08fa84b4f4	1	{}	2017-08-29 01:33:24.057685
0f8d8085651e87c3fccc545c467d74ac256966ef220378062a521af7cebf4f8b310cd5fb5a9f1951ab6b78b51b951f668b00bb13224ab6aa448c05bbe937441b	1	{}	2017-09-02 14:26:16.504609
95a3dac997e75956d6b11b6ffa20d06fd0386ed94099e404ce743f75e0fa5b6c44f679356729ef6a43bc103c3a74fd83d508797fa42c2db5ec1a5702dcf971cc	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-08 16:14:22.806042
939758c751a0732faf7f4a1f48baf851198e37e80eb1b370ce956fa0cdd797ec71be7ac8fdf333cefe88fce037e026a64ca7c7488e5b5f8051d7eebd1c7aa4a0	1	{}	2017-09-09 15:57:39.460022
ae2d98b707d1defcce928783e5c71f080ffbc2a011ece9a1fcba093ce62cd4eec231cc4026d784ef4d5f3f468063f8dd57019c1df6ca6910a1d974a9dd4764f9	12	{}	2017-09-03 16:27:40.445876
a23d01ea2bcc110ae6c80890e2e6b61106ea92a4f87612d3d56a231844b49f9609f5b7b641cc11457d80409598495566c9994bb1d23b7ddf20f8ba30ed0e49ef	1	{}	2017-09-03 15:27:49.83069
9004fc28fae47d5fed7f56d2f4cca414d01532d642da5f35d1018da2b51a167c8b276b13b9d1b48d5a06dc7cd69363130b8ff3b02fcccbe3b5ccfc03ea609c36	1	{}	2017-09-04 10:41:48.93615
4f825401c55a14735064fc2c6a05031f6f4259ba6b5c6088922e05cfa729be9ea68830d1cc5b16c0834dd7c6422756b3bb5f7ddeccb808375cf86f35b03ab61c	12	{}	2017-09-04 11:28:46.846425
69ff8c1db7fe4c7b4ff38420335267eda472cd8a3a0de4c9b3b99c17f6aa0bedb8662f0aaeb72a47c0b9bd6e3027d62e7812b37d32dd8ebda5cc07c44281d22b	1	{}	2017-09-05 09:48:04.852592
e96b4313a881be0805afa7eb3744b6dd09f1641de22c3a501b5e048970f4b69eac89511d36b0a1696a67b9bd66f27eb37dcb8a7c4cca79e4464f124ef210a8cb	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-05 10:08:50.520581
3498bdbec9cbe4111fb6ca9813fe4371c623d43b4a0ac9703462ef4a6c5383a1d766db8d421a7dcd7d04e4007bd9870c16f66c8c6b2d51f0d53b5ee522eaa2fc	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-08 14:14:46.938182
de2c4034d5067f944229db00a928e7b65adec87678e56db29d4faeaa78fb2344410c5e2cb104c8ab44a7ba80a868f7d2bde20e97e2e797f335d68684b12eab3d	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-05 11:10:25.275025
fb2c19a9ce4048ad333f000c39f7733503f5c6de05e9e54988ea5007f8793694f716636d29ec5396ab5b3648296f997622e7d16339cdc805546205c3411554eb	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-10 15:33:32.753723
d42a5bf6e6bde5764fe14c837ae28885c9d5290ec4a43f13fe2437d7164e13f9b15888c9bebb00d113b05c24178cb45fc09057a97f6e61666adc25901deed371	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-06 15:32:29.221244
4c3c329af002a1103a6c34b9ead18db8186651d402826aae929f48efd1c84c9750c1da399ddb0882824f859199d68f4da0d2b2a34b481205b7a5d5786afae369	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-05 12:10:29.276322
dfd2491a8c896fc1210eed8f1cbf69897bcdfe62d7aed7d337830ecec47e2d57212be00497d97af079844dc4ecdb13317f5cb0db824199789f1e5db0b67cb430	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-10 14:53:57.845323
2bc8c6adf260c9a9b6f085c48b07a88a155fd4542e76f3fee81c5c78642fe34e42a0a429d2433d4d45b6ba25711751e37af7249b8e1deca7384e10e9e93f57b2	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-05 14:25:07.16796
943af3822d02d9c20b1392955a4c24d9c01295c05f009c075e626e1778cbfba32e7dd0bcaa07163824a5c3730d57dd38fb2323c8af0679b2eb827618ecff4d5b	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-10 19:05:02.037239
52273ab55c2a0905bd59e8cfcad74a780a8056951b85e1ee81373ca3165134569ae38854a23f664f08517d9e9035c8b9b8e49a5eb74e4a04523eb553524421cc	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-05 18:15:35.437322
28226b4a8c1b999616288b178a74c77c2ea98261749c962462b20972ab5e7809b2d523ea2f71d21c0a9ae7be5d41de2824ed98439485872127b5f80b0253e4bf	1	{}	2017-09-05 19:45:23.167078
429abb346cdaa15e6771e24bef6e3412303bfc0583d7f541cf2ce60194d2e36880bc1435b21976c1f22f86d57e4737004298af6d6dffe80830f6b75574777165	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-06 18:23:18.896633
d4d2603576c968dc0a571490066332f178bbc104837eaab363bbf3d968f22145f784196dee03105df4fec7ab34c8299487f99752cea94949dacf34825b8cc6d1	1	{}	2017-09-10 15:52:05.278245
d12c4d325818c91f21aa146e16de267e937e299e1bff1beb557c3f6a5192df8c5f8895a886d84cfe9335b2caf33be9042faf989aba15f55e75c9bb2e30a88028	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-06 15:21:33.517386
d7ca0b6dad00a03881c726780b81f910bf139a6114f88c94218ecca57e54996118dfd101c5cc0e4c71f7e549b3aeb57b39a16cf6ddf90c6c18a1166111d2e8d0	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-06 16:18:57.88932
066d3d78343005199cfb33a9f2c9ffe03677a6c12ce995efdda2a8bcdc3158a68cf8ed8fae027a23e888c8ba092bc44ebce7a992feca9f5b8e1f3bb7402f32ca	1	{}	2017-09-10 15:54:20.090573
646032ff275e854249d740333d110224d94b651d4a1e83abc307c736776499c0d3bd0f7da31510ad5e321a3726e3851f7066f4fc8393dd23f7095de96f26e567	37	{}	2017-09-10 18:35:56.362102
53dede918a8cc3229357e0d0e2825ade9d914a9c5b4e22bcf2d395bbf3c789d6d942fb4b1a5231b02144648d4b6e35e2314c68e82e2945a06050ba8f2104eaad	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-06 17:16:23.702715
e74f6194cd8bd5adbaa00eda1ae9854366c99f7c6ab92d922d858e151b7379d9a0c1030eb1565052100b697ed34a4bda9f334c9834fa93ddd5fb0c81d434f0b7	1	{}	2017-09-10 21:44:10.663328
db3280c2ed4e228d49fcd72a788620c4c817fab689fa73c4f3554a7c4ee5429e4ea493b3cb67ac4dcfbbee91efbe53348af2382430b7aa8afea5bed9a8a8bc94	1	{}	2017-09-11 01:19:27.196336
7b241aec0fe4b1b17e9b95922afaaff057c28ea1e3e82003007e18ec67abc61f3df195ba9cc9b486d30095e5f39f1798774314998ea06f2880034a5ff2bee811	1	{}	2017-09-11 13:23:25.014484
2e399d3c717273c8734267f55cfa109e1779d1a48a620557f68673d321366300e4a324c9c99afb6f7a481fa2da5ad84bbb0f792775d6a4548a35967d71e83ce4	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-07 12:52:22.965509
4570f2ec9952be4518dd604de0b8056a0b3f2dd5c921488e6b886086465d990d9593ffcc7cb04fca3d6cff461b740705953fa7d37b39d69037ec85a49f37c953	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-11 17:00:11.079227
3154a682fd2ca28993782d7cb347230051b28fa35485288dc73be5704ecd52fce999cd81cabd214d99abb66df578ac205866d95c325a9425daecdea5f8a22c7c	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-11 17:12:03.091912
64accea6005ed873201a3b1210271abe861d5367fbc9571938cdb81247b5704c02cae804ddaf33085ff2bf0e14dfaca59891268bf18ee7e37732326ffc2550d9	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-11 18:02:54.977291
c0e2b9a062a020f8ddb78dbb0a35510bc95f54448676504c4527152d93ac1728338e0028449b5ce22d7fa27221ec0e9e2024f46dbca0805c5775795da8504cac	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-11 19:29:57.374772
8294ec4500f7adda831226df238bef7d3886d15942a06b95d74cff0d6c3c5c1ff1c227c26d98d195780fd4601256da21c829005560b00e949980e2a61a3cf77e	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-11 20:48:26.747445
978a36971c5c6d55444641621259270d7ac0af746d67a31bf72436a6267539a63794e5aa4b454f4b474055219b0d86f5894b45afb4364efcb9eae764d044bb5d	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-11 21:27:09.21868
e79525b00653cc697c8de596733a24c0315690e4468179ce281de0b511106f9c758d95698c9afdbc551d65f80375bd035376a9a62f8a5eddfc445ab6438d8286	1	{}	2017-09-11 23:41:13.002581
c536b9fa89068faec618342bb260880f02ee5fdc29056f5d212629a74699f093187b84b065d4323bcc6a3cd8750bac32832741b7af9d8ac5147d12e82070e116	1	{}	2017-09-12 00:19:53.844314
9db7d1ebd75c253ae3759a7b8c5a3f7f20bd70cbc56d7835b1f9d65b348e62913e516926de441c637959ed5781ae6816b135b4b99cf0b2b77611052b91edf709	1	{}	2017-09-12 00:42:15.698786
c5898cc0bd9cc961609e50a7021c0367641c67ec5adf15790334d5ab6a77a389955f2981dc49e03e896ba84ec28570c8f53a842cc74e612def0f6811c40f0266	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-12 01:08:49.837882
914f01698ef673bf501da27fef0588816211962b58500586f53abdfb75e7638267133e860b2e6a05cc25b2cca10599535e8b6614229199711df2870967ebda3c	1	{}	2017-09-12 14:58:08.244967
65e936c32e79b227f0cb9c8d96292f6780c94a24497ff6238ae0d93651a1f190fadda4b93276058f131458e7d38c66b756547cd6b5768688bd079412fe85cceb	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-13 00:01:31.36288
0ad03a568bdb10bbabfe852feffc0df261ab78b6ebc492de317501ce04639ac848c704741205d5f44979f0724a1e53d294c7907578fc094e04575c333723d73a	1	{}	2017-09-13 02:33:02.61119
62a70b0f21a74c4977ec5e26165bb2f6f84d19457e946aea187dd2c51b03ffad0edee096860d6e2993c4e6cd55be939b6f53e28df6219b0cb9b9b6efa09f0d23	1	{}	2017-09-13 17:13:41.27851
58501053cfc50370b08068eb22523d870adbe7da461b3aa712365816af6c38293f7723cba6599cf81f58512ac94d47e08d17ff90733984cce484990064cd360b	1	{}	2017-09-14 00:32:12.021035
0cf19bde9015c6066f5f5d0189ced6a6246382b56d1a42cd8803bf84328c47afeb4d42bc7f09ea12ede15277d8ab05f21e6479a1320f1422503b63da9cd40674	1	{}	2017-09-14 14:11:37.62288
856f2973ef45a5f4a65131896aa6d2aa51dbce9e9e910d7ecea02f34feaf3f1a2434119662f46e4545690527f9f81322f149b4bdb99fa6dbd91508123f786f7f	1	{}	2017-09-14 13:41:58.150084
e933490c6e9f23577c71236b6cdd03e60c6438d691a49a35f97488131241ef76c9d169256ce780577cc1d8f79da148783c318613b5da7e34d4cd0e645fbc631f	37	{}	2017-09-14 15:04:33.823146
975a47752c770d81e00d42acb0baa75fbedac99b5bac18f1b14fbfa06b738639390b0f91e5c021aae2950f1d595896836f84eccff81d8977c27b8004d17f45eb	1	{}	2017-09-15 13:14:28.61606
3fa43e1ce7f65098208bd3d85fb481157de0a27e3579a308f3f45bdf0a486a0318289bac52ff6667404555408ac8f5fc823608e1e142ad033b5527af45363a2d	1	{}	2017-09-14 15:10:53.555801
61ee1a8c2be64b354c62bc5bb947b9f18e154abfa444b38ba8f11d5040ba0a7b423b06e673bd0d77b8fd75918fa659e3057ac2d0168abbd6aacd110b1bbbb10b	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-15 11:30:47.040171
46315ace85d17a97d304fff571af7f04f36b1c73f88bb4cc5d4510fa738ea0bdadc15fae4e8d198fbffed8feeb210278b8f49a4d02bfd8ecde84be1d5da505dd	1	{}	2017-09-20 14:48:55.403553
56c671316b3c0a74549c87525bae5894e29efe8f81232823959ab1fab870d556e73f5bb3ce53b184fa5e5ecac7b487d84b582e76d77807dc3281a280d0332b59	12	{}	2017-09-25 23:47:45.371248
a56bd1b7a224b05251c0c8610a7d7454a4b0ae0dadc08545f2d306b49f3e8e517ab2c18e82f9143cb5f3e4102a0eee18bdda82ca602aa169f9f430564be77655	1	{}	2017-09-26 12:17:29.679317
739869ddaa184902a55c5724a04b95850c26b890f30c9dcf9b2d4564490e41c6415e5dbb2280776c07672dfd7ee2f19c2ac1faa396ad337286dea5ef98e073be	1	{}	2017-09-26 17:21:31.19147
c39bec7e372f8933d0c645a918a94f9f524252cad5d1683764e353077cd875aa29e5e92422b0345168e65147961599835a3a71f926951655e4543afdecb76147	1	{}	2017-09-26 18:23:29.575513
b54c3a29cab82791a1245ab024ead386d323929ddb558dd7a3092e7bc22cdc46cf0fc0479d360afcce31b07900a9856694799fa50c0dfaa64ac25371f52e1841	12	{}	2017-09-27 16:27:22.430382
5592dd691c68d3ac695c85297b07aa6f6bfbecc9279489e08e65e29415ddf9451267e106f2541aa6edba356aaa21b1dcd578e923f98def1fec9a7d6e0154ad9e	1	{}	2017-09-28 06:16:33.469844
ecc11bbd57c35baafe0999c4fd7168e06c8f171c61ce46f110c78fb2348dadbbd8a7913ef2f5c0c31a39f1798791bfd50ed44e0d5394aa7d8f7b40cee82d7d5d	1	{}	2017-09-28 15:27:54.989691
71500e2240e9238c9f3dd137defd9f1ef9ec386f1a7076e8c74d485c486212461278f7c609b9ae4701db496fb51b51512d950eb52925ec46632e49a777912dbc	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-09-28 17:02:11.14826
08a5cb97a094ce1117ab779e08fdabfb9b5841d170d002d87373508a1f121a60666d30804686fa676bb6d29b9a178913138037e95aee6688e40d26ffa94852f6	12	{}	2017-09-30 13:41:27.0979
ced44ce7981ef58f181a84a45a44e8f8bd77cb8ffbbaccd703a7bc595993e2560fd5a1508c8fa9772e53bcabf0a50a6e9ed871f0a27a2d4f9ab31c5470ece407	1	{}	2017-10-01 11:44:20.835755
640a1326f1e0dc136383d4ec3443f6bc581b9ca6645b35133e0db666cdfe35a77fdec01a305ff674a25926d3bf211c96d45a9d6766078b93d2d4b1dedb2223b6	12	{}	2017-10-06 11:40:25.990598
89bfa433f8b9d4ef2503958869621765ee01556bef7a0b75d3cc14e6e594f0003a76bb16985382e4d6633b0276be6f60538e6bf4ea6e855282e31d88b2dd3fe8	1	{}	2017-10-06 13:09:00.779833
f919aa258517dba48a225f157b1c01021f3882289206ad63fa24bc51df07bb83614de525ad3129690adbc2a9f6cf9d9a13ef5937edf22088a2ffe8bba7f639f2	1	{}	2017-10-11 08:44:38.106442
2ad9762fb3d9068d7405e96cd34061a828aeb5a668cc23b15970be719650487a86478517d959897332413711b62900060502ab8bea598af572e19c5aeef6cd55	1	{}	2017-10-11 09:51:28.434462
1dd10e2313e4bd3cb5c9aaffc6fafec4d72737e5673fb6d9c164d8a466f3e84f423796edc53de1fa86999f10c5ccf313401e6bc632cdb6bd8c6ad9c121f860f8	1	{}	2017-10-07 17:23:55.665086
1f1b1938ffa8ef4b1191bd0781491ee0995c801e3328097587bdb99cc871799325bb9ce8c3c9fb0887c4a155c6ad144f77452cf8ea60f27fa32dc48dce1a1297	12	{}	2017-10-07 18:24:18.307803
573746b0163f65fa113d327a95fb12c5a18c0e15b27ef4806bda49541efe151e1b71728ba129c25f73f950bafefe08d24556aff1f7cfc8d446546e685fb827d1	1	{}	2017-10-09 12:22:28.282449
2a88ee1a260f8fecce61c26a892e835eb02100009acbdf7ea18070fa97a02b09e3adda4c1d5498c72f324532a7b48b0bd6a45a59261cb8d092196c3192422e07	1	{}	2017-10-09 18:34:33.131491
7d60309effc1d6d586f6661d3dabfaa6c8eef58aabcc38bf2cbd39ec957d42f7cc1f564d5817cb1263f8da88f86236cfcf971b7f393c4e653fd32c8e6b0c1f6e	12	{}	2017-10-10 17:19:35.597896
03c1e5e76a45234a64691b9b9b81fbbdf5d8c23f3dd4aed71c551820a978cbcd1f3eaf2be52bee430b166fb811da7ab186d564f7582b7f054a358c5e2b6e2c8f	16	{}	2017-10-10 22:48:53.335674
7ec6bb2ac910b88978ea41bdbfc998d45a78e788cfa6cdd4c264f882c55606ee3c7289287fdef0740a2a0ecd53f240a3b64effcb5ff191d84e9f589e3861d4a1	1	{}	2017-10-13 04:50:07.30834
7313ed0a05e5ca54d8a0a29362ed763cc6a08d103f2d757d471ffaac596a17a80ad5a75b47be580b36949cd5329fa4978cde89b39093a22768abf8a07784c229	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-10-11 15:19:15.932657
864684c1baf4318c8f53906958570610625b2e77c54d4d7c34419f08630c091dc0f47e42a6f7419311539be8795344d85a0182389676ef910424ed7e81fc5589	12	{}	2017-10-11 16:18:57.626376
2de6956c2157fcf99d8eb2f5cbf0db919874c2963a075f30238b6f6d8a249cb0b8043005bce5530487c57253a2bb2c35e205a39c4df5eae13a2979356dfa84d2	39	{}	2017-10-13 13:33:38.94394
26575a6e0846c401085b479afed5ef5b6118eb3253047a2dfea087bd044c3c6088deabde9d84a7eaa71ad59ac9a0476ee5c3851e7b6fd53c9d65608b01f55787	16	{}	2017-10-13 14:00:26.780696
5b4e5c3d16437886143c809d8ffb4b29bcb237137a56787d0540622d6e5dc6813ce1bad1c9bfb0655982024db586e4a30974d51b19ad7f2f35a4d4ba0ab11f7b	1	{}	2017-10-14 17:26:32.789574
e004d0e84bd74d3f80fd5bbfa531dfc4ac9ff50ae941d603cd19fb653b2e2ff89350780a94b662008b098558fb2ce0b37f87c811979c89611b9307c00d414ea8	12	{}	2017-10-15 07:16:31.976826
dcba99e90c5a9a080c72dd7998f6ae09f7b716950a80d012f5086fb761ff3ad8f25417a8520b17bf93d8d05645706af7c2272a161257365aca907f8908725646	1	{}	2017-10-15 09:43:21.666086
721d7f9b63e9ebe182878f220d337f0984e8e4e2298a09cea47fae603d5ca2fb3d80f396dff4036d730389ed54c87c651f0525e0a49ce491eb7c8e8b23f867ae	1	{}	2017-10-15 13:26:38.155398
7dcb0cbb086456ff5e6be22baf0c5dba441c9c2d7a81203ac294265b69bb9180e6a92d1bd514ffb66c81662cf55696439309ca21def74c3aaaddd997ccca4f9f	1	{}	2017-10-16 12:30:08.448797
c3699b4bacd642cabcb5a33a2a74388255c549a5954af8ba65483c89ca7d8aab565d962de466a1ab8598170ba6122511a45ce4238b1fc37430194ff56d135c7c	1	{}	2017-10-16 14:50:46.094264
a0613af9830464894eff301087f0b2ce8240b27fb98397dea520af3790c1968ece08cf6116677595afc2d6703208aad1bef0e47be4726c9ce3ec2a72b1778492	12	{}	2017-11-28 10:16:42.841632
73564d0f793182fad13187e3813c1e1fb14fc0b01be64231ed2571907ef2bc3efb7a61f525845ae34c7214ce453734bb8799f5217a55278f827e7ef5f64aacb2	43	{}	2017-12-21 02:52:51.186804
0428755b83ef8fc66b01aadff8eb8ff52cb44ce02378c874c0461fa9e9da571e0fd71c4d6059395b2c383ff6c9abb20c132ef741cbef54a9103b0fdcc7568515	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-10-16 19:58:18.894873
a60580536c07731eee812e55bbf082e273c85c92344c0650a899a0b8ad050081b91b55fd9e3631983e0327fd84a64383f2d92bd5fcf22429653ef15a7dfd24c0	12	{}	2017-10-17 02:10:20.418925
f031a2b9fb6615f521a998bd6f0c5fdcead3a793789a788fef705fb4e3e2514703df6e21d78ff1ca8706aaad0205176e24a28482c4291fdb974b11e9c841427b	12	{}	2017-10-18 12:51:28.521145
27832a6976a7404dd87eb34b39c58b923d7d3c00192b378ae46b686f332ebf4b47de7d2e246227ae2d6e8835e471bb10d9630b26ec6d8f1c3818f0543f44dc61	1	{}	2017-10-18 12:57:07.622416
9e823ee437c2aeb5d1255c0c55a5c9cefcaf247834ecff950821a28eef30a881e8286880c2586a3022c9e63968ffd20a4b24d692f2ac9c4f023bd93b8e8d32fc	1	{}	2017-10-18 21:13:10.203573
940fa728c52ffef99d3bc296e3b362e2cb6946eaeb3da7acbd6f4c1fadf2a71a9b56ee5f0a97eed2ecc99334b224f1c35c4b8a9d5e99fda030328f620e782f78	1	{}	2017-10-18 23:43:15.998571
8f0672746fce8480eff894120362c0c337ea04c0ca690ea0cf4e2bba755c2a85016bb6209111eaf437d951b5e39e3215874b1c5c00a1a725d6a2e255b303d1e8	12	{}	2017-10-18 23:44:51.256317
35ee6650aa9ad8407db621c0108f1a3d7d079d5857ad284944936141a2116549d386e1507aff096cf738a63e59d42837b0724c1a2c95308161c0b77f45c34333	1	{}	2017-10-19 19:34:43.992106
86857c0b8a9bbbd38621e52d241b7de99ea92b39a42be9dc3682638f7461cb0c9af405d0e6e9e4a088451d13048c18cc387268583bebdaa5bcbca69ed45c3b7d	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-10-20 15:48:52.201384
22291171a44aa82095c64d313ae340d609a0c8192c3f0363e6c82137a32e774c0248a0554cb6abe2af4ef314953bf888b9fa73f372cfe47e8e310209946354e9	12	{}	2017-10-20 15:50:08.331542
312d02e8889838c9969b3c988c1c65ff120bde325d7fe025aec5b12d8811d067b9f0990c87b227cbe3ccdc116c9e45b291481a982ab4885a8becda39df74a856	12	{}	2017-10-20 15:55:13.101804
1a4dd5816df954d0ce116d86aa03b55e665e1ec269fe6730a7b85d1f1384efc983984ed96e5c37f17fa281b31bad8ba8e1f3db73e49fdbd9811b123664973b15	1	{}	2017-10-20 21:48:38.960717
408ab4c84df5252e4cda126aaffd8993268eaf1a0dbcc9d2bcf76b630f1c1f5c8d2b327c76772164bb16bdca11d028f0e6dd28ad29dafa6a181090eca8caabd6	1	{}	2017-10-22 08:15:11.168375
0ef56ca0d26c918b219f01e39e58f62406e5da658285f759e5099274a9e0a8de6738434a7fc342054b8d8cfdb13c72f3e7878416a3061358a88e706be81b997a	1	{}	2017-10-22 14:11:35.280881
4e3726a8afb51cbabcdfc32549d4efa21543f961165df6fc89895238298989fe1f1338dfc2fdad0ae4cd766f1107897f14d6998eda558ede0edcf15dc505b0c1	1	{}	2017-10-23 21:01:42.854257
3fc63cfe0eef5882942606b43fe6d888d88a3c14518ff455e8fcbd9ace8c022927d4cb32adbadab3be4123c81192aedc0c4fce907fe46083830ac5ebdde16f34	1	{}	2017-10-26 07:02:04.860495
03a8afe344ff8e55d40a542d0885c2241351993abd52868c853628e5decebf646bbddffc87f153b5883ca627f51f79a007bb9e870bcd7e824a23ced2d3cd86e7	12	{}	2017-10-26 08:08:02.649295
99871b26564673b4ef4613d9fef9d7bd87d0b1edcc3a7fc8b058e16aade1f9c30ef4389e020264b747b05c4bda45676c06247f524d976d5be3a32b3cd2b336d0	16	{}	2017-10-27 14:12:21.152831
2fdf75d1afd8cf32ecf5cf76c08ea5f4f2cef0c43cea5dfba7fc315b7d6f929743e2bd016b6b07a01ba4088ef9eba1b13db55365f835be2d6a98c29b4b2937a8	36	{}	2017-10-27 14:12:47.547101
c753b650686b30f587b857f76ce5381245b483c232f7dcac7d1186a9d8789e31c5d8143a7086e44487e642436ee20d070ebf634475ffbe6887a488d65431f2b1	12	{}	2017-10-28 18:30:37.095568
22c60fb09adf9c1dfada5eaa04fc98d89d0589bbfb0b68f88668ebefeda7316df717c0901bf005f59eba3b4f2c80176c16966baeb25bf605c2429c46b703bd8e	1	{}	2017-11-02 07:44:59.627108
9c59b270ffc25ee44b6e32ffa75ebfa3d61578f30ab85ce11369acbe9368dcd2ef62715e188e4196b40779931ae73db4f7e9cd776b8a1738d6989dbda6b41271	1	{}	2017-10-27 14:29:14.830905
513c527f140340b8dde3bb804d46a4b41819a4645dd36d0a016b3b23fbe89489d8165fba1c6288701b0871f7a5804c958c4a4d4b7e50eec0becec2d9622a21a8	22	{}	2017-10-27 14:30:37.060979
b49ae461497bffffd6f61f518059cb53c640934e21de1e3e57307775c55e94be212b94c56d47ed0ea87e667a494b6468a6c3b81711dc7d4a44579c5a6a62cd1a	41	{}	2017-10-27 14:33:55.893347
21ee492bc27b1e4fda4dbb99acf4d06df15b768a0ecb1d894f147b711e41e57b5afbfcde4c45f85e133f3cf4f0041bc6be69345ccfaea5c3c18ea7ff1e11f522	1	{}	2017-10-28 04:12:25.134638
ced5e809c8cd068733b7994dd9a2e51fe4ef4ba4e0a5a70d1fc19f71e92ed1835bae9ecdeabd9ce1ad5cf6726c1418e37047c4215b8d895a6b959f41c226794c	12	{}	2017-11-03 11:25:26.48905
2f1671ddaa145bf36a76fc6bef82a28e5662ad2e0b2bbbaca5a9d5ec640f5fc426902c3c4bdd7bc1592900f455e17e793601b3dd678e1048224650b740777055	1	{}	2017-11-05 22:49:38.413441
b094f52d4040c1f6f535fa63c71aec516baaefba30f9cedb47273b157389fde8a990ad777c2ccb678e51dc3f84c911e5545a60bd9a4b30bc884247aab8549a30	1	{}	2017-11-07 06:24:15.896894
d9b482aaba0044eaef7c5f31d0fcbcbee427e945ba22fb04ded8bd97c63799b4b9b2c7fbb21064b452d4081ecbb100fcf4e07124869ba2e3525c175e63f2234d	1	{}	2017-11-07 11:31:15.854757
c775092053ea06cb588cdb6dc2ff3693674de9212ec554a4bfa22b65b18d7bf7e5975049497a696edcf86f4beaf7f063a726d255085227d45a1038c22eebc3bf	1	{}	2017-11-07 14:45:37.226392
ba5f6e8e31f3842a406bc886ff5d4a26426aa9e5514c82e8a8ee11df26fd904c69460db0cabbf3fa9878b1e5221bd0da19bcbc41368f7fa401652944ad0efd05	1	{}	2017-11-07 17:23:09.031871
b04ab95a554a791286b41b8b6d6d9278a09310d4c5117df756e479f939f009f1f714c48b20c4c22f8f9082cb70a8db38b58ff5c38d8ecbfa407510d45466a3a1	16	{}	2017-11-07 17:28:39.587027
ea77f4a2a188a147023fef7ddcea38771810521a317fcff2e882864ea563f12e854b171b6a9d83a19a6bfb9493bc3796799426476a48e6c2d7f0de3137564e86	1	{}	2017-11-08 13:18:33.066272
c91f39bfed50f511c7f24a0aed9ba7ecdbd15a0fabfded64716bc6def765652cc01a6428464f99de4ed1eb9b7a94aa467548deb095599e0d9e53c4140082489f	1	{}	2017-11-08 14:04:23.734902
f6d1e7915eecef62ab5eb2778b070adacdd2efee89316cd79ec596d85d182fd13c5e3fa752e86917b7565d51dc85bbd8d16d8f78dbf2ce4b95e24b2176158317	1	{}	2017-11-09 10:26:12.997514
6e811f6469a03ccb3c78a933a5acd5d9d791bda18ba7be966d9a8528c81d685ad0906409f55e7c6862ac9702a75d2d22b1dafecd7d7700db8e87d5315082a63b	12	{}	2017-11-10 18:04:47.249241
c186926a515a181e41baf750d52bcee108cb25466d38b82a23eca8b909a7b2095cfdd8e4992473b189a18320802b03bd2f94613d01f36ab6dfaacd241e81ab37	1	{}	2017-11-12 08:54:15.084578
17de5e78edfdf46d6d20af6225a6e8a2aec620502c16e509d65ffe6cb2e566e4df138af3c7a85bd9f72ee162650e86d64980a7ec7e335b4ed7a36de5234806fb	12	{}	2017-11-14 06:01:17.581536
e5021902e53ab2e3be513678ee8ed65afc1951738b4b6ccf2df3451dfce93fc49572b13b88ef742e4052733e909935074b9399b5c865f384b7f0624e583ab1b5	1	{}	2017-11-14 06:42:04.476553
ca9b628a6e3254748b01db953b291adc6e324f2394dcaf80734ad7ac326accfe1502c4ab51ced3c5bf17a7895770577ad4e397f0a71a0244043298c5379831b3	1	{}	2017-11-15 15:38:19.451374
86cf7ab986372050ead8a5f1e702d8874d6d2f7952a02bb10c2d8d29cb035e41548af604286d90b5f366724e35373f2e0c3d85b0d955726bc375665dd98bc13c	1	{}	2017-11-15 23:57:25.381474
80f0e2cfbe361e46d9268b9fb5dc25060ba476c2ca81bb03f8afcde8834e1023d1cf5b45b7582e7a9f598ec9b26e66ef38de1c0c577b3b34f83f7963420e9abc	12	{}	2017-11-16 01:32:54.133598
ef12a419160ee10e7de7726b1140500bf0e38ed548e61973d2853d9dd6474a28f2360ce6c6c6fc57b1f78ba49b9c93ed3bc506de5a8c6427438a236535c72b01	1	{}	2017-11-17 10:19:00.861408
b19391d0b9348644c6a2eb9abfa2056ca5662ca932072b98821e1759f73cdd03fc12ac7585dae102130cd2a09b10cf951e54d54efc049c4293295fd1a2047a32	1	{}	2017-12-13 17:15:08.530547
b2e703cdd74d52064a4a17adbad9e6364dc6fe0ad315ac2d3f41f33e3246bfa743a2102426b82963796d8d77907b5101a0ec22ce16a0cbb35980d88c323e3cd3	12	{}	2017-11-29 16:16:10.149394
5c8b4b684d41fd2ba16e3e870b8fbe324b0f3d70135bf04aa4fd0d1cdcc324d70ef4d5586ea1c62035414f771e93a495b53501cde442922664e6d6ad8141565f	12	{}	2017-11-29 18:15:40.723581
4b20cffba0465ea9d0ed1a5bd6ce67da2943417c53844a9c7a0134026bf76b1c0083930db4c1973cfa115a86a95a201f2e6a37afb97f7037ebd3a6d41f90e9d4	1	{}	2017-11-18 12:24:22.32367
ba2eb4da89af0d06e2413fbdc58ebd1bb540682a72029a952ae156b624cd36598215b8005a923c15c0589d1676f820a5c3132c4bde465718183e3cffa656dbef	12	{}	2017-11-18 19:02:34.891542
c525c5f2eb295692a0aaf4d1a4267f46c10007d15ee9c427048bcbe9acc88a9859b6ddeace636a4c6c6554339aa28aa192a836f775c34fdc0ed76e79c534fedd	1	{}	2017-11-19 04:20:04.699816
8a8ecedd1a3676b8f7f1ecbf36b1328478f37851ffb73d2758da5803a39f86fe1eb27d04e188bb21f8359eaa4c4234cd1b798596c6f5777c295ad0ee5935c0d8	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 12:11:33.076427
a416942a5badcd32ad6e80967121d9ad5b8e74ca57a827e232ba20f939f99035ced3ee7c04af8de5b4a6e85580b70719a3eec2addd31807e18b0956e51d1a144	41	{}	2017-11-19 13:47:11.733521
44caf5514822690cf5244457b599047bf5a4c553ed29bdb915e908955e37c17cb2d860b60c7757139347ac3c739507ea3f64cf82632fdfaf3567f504e596aa43	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 12:11:58.180339
b22d262016c9d4a808a5f141ad223802d37a0f033abe7ae8bb2f275a2aae12e0f79de6c4a6e40515d9f0a70877c6f042039cd49cca6015c9bf5ae672140db068	12	{}	2017-11-19 13:48:06.756987
d40db1c0a700d79bbe5f5cabcbd75a02db549e4b233003de638aa2bbb1e4dffbcbae1f37183d8101ad2598b6a4afb09b7903b5d5592e6b8fc4a30bfe461b9dc7	23	{}	2017-12-01 14:07:49.558539
6e1d74eebb29467ef206509a7453b3c06922256b8b966f9d10b1ae21d57e062f1a44f76c76454805d113ecae2d72d65c088dc59df431eb8188e9652b45b7afc2	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-01 14:07:53.992472
0b21598fd183cad5690925cf869c4d719d088b6ad7942983535ff62ce9114666d952769c0e84f1b98a24fd6d811498d2683b221b3db591ba3151c433d91012fe	23	{}	2017-11-19 17:24:32.738251
afec03a247a11c2d6b88023e72a59eeca5a78476fa0c917c51e41c005efef7261a97f7c726ac0b0439f0ad593e97f9c3dab993084a20e81cb3b71240ea38d10c	43	{}	2017-11-19 18:45:25.909711
49834e458d1e8543747a14f310bc57c9b0902e3c77dbeb6f192fc3c8ad498c1bafe631ddd6fde8f0f0d52d35823f90e46457e05b8bd9b2138eeb2df74fa13f46	12	{}	2017-11-20 00:39:54.079562
d3ea346e5fe267bbf13cbbd3db375b4d611da6d2889fca6b03c4d0b4e88204b7c7fc7f7c8c96a4bae7870c834f72279b2432d833dd3f0d5146cdf3e454668d45	1	{}	2017-11-20 22:57:10.389568
5322437564cc40f4b952016a8d0e83c59ab75e6384b159bad50e08c18f5a2888c584e2de7816020e9049fc562523f48280ec3e6a661904183b432679786fbc8d	1	{}	2017-11-24 01:56:56.816126
cad68f278358fcfcc1625cdefdd76ad6464933829a20a7b10681d86147f2505416261903e314d23fef86c7891dd6dc0b82120aba9a437b78ae52156ace3918ad	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-20 22:57:55.413232
4c2e72c18e3bdb6fc0e35cee2e2e56a1d9ea4be7b4710cffe94f643e1080b8ed2a29886d22e1f787099dd42c5275e04d2ea07ee0405c0efb1613d1c4f8403369	1	{}	2017-11-25 00:31:52.389637
bc13bbb1a01a54f0f4aea8c3f8678320fb5dc5d223027ea5a1e09136dd6b8a8d3403839388d417b40c11394b257de68f4a92279ed3641bd4923a7f64fc94a6b8	30	{}	2017-11-20 23:47:35.418934
b7f6775e8e6e18cc5d35d53365ef7d923935ee1c5a116b24751f879f4c7e7186940473159bfca1a66e8a0e8203f51bdf3867994c087c296ef3357f5ed61f2b24	26	{}	2017-11-20 23:48:05.604594
25d74480e066d80242d650b84a7bdfb28d3db5e3f06dd85f034abdd11a23698ca7cd4a884dde7c3fd4a669f7b44927a53b738b2aea1b5b33052410b219aa50d2	43	{}	2017-11-21 16:16:18.322924
0015357c08f2f48ff836880c74d2ddf2b964ffa704d6d48471687a2a1ea160b935cd439d5e71101f8275e5e5445d4d91ba3c9c341ab6fcf2af127066740350be	42	{}	2017-11-21 18:14:42.742927
5812045b37f6857872b86f1bd247d5db5ac5f2ae188a214b935bd1ff9f9a4f7a73967a8ca3839ede7573c481cc6b2282d3d11316930e70d707a6b52df1c6f42c	1	{}	2017-11-23 01:45:57.890995
8714b1336ca76f24d093567805192ea6f5fa9c41a03e17b798c5807afd0fc6da9917c2c8389739556112857b5393c737e6c1322f5086313263b043873844bd0f	12	{}	2017-11-25 21:50:43.86194
ed6ad592e3b035975b347be7463f1df2d5ce486767cc1ef4c5bf987eade94ddc40db4561fae6996c1f9597f632392ae02fc17c68bd7e88dedd70873dff37b15d	1	{}	2017-11-26 06:27:28.94115
f98f1261d0445146d66db4c1fd020d10af1985e6677fbe84aae2762f4eb645717ebb15aea0d1d3a6dd3f06f7e24bc6487fdb18e102f8d842a38735c33fa21aae	12	{}	2017-11-28 10:11:53.308104
10428fe7625b3f6c99bdc485b2604c1597496b9bdfa9c1d79357461ce6a014cd4653114f25a4bf45e43af1028ad5a754a393642ee297980f785644cfb595fc6e	45	{}	2017-12-19 13:53:44.960509
fac5cf3fdf6d8e6ff9d673d4d44b5ca2cd675b188b095255a262aebcd418d5db2c8adf753af91bbdfc9fb1e3586646762b80c82bad1cf8281deead1999328a8c	1	{}	2017-12-19 14:29:01.986777
3d94bfddfebdec52577b61e33f3f0778b9c5b039719b7e95bf54776cae5e66b0048b3579c2799637c69b6def6854097b646826745d9b873c2506c5972113c276	1	{}	2017-12-19 20:18:13.64692
ce234d16c5654041244de28e0ad00e3b64f830e0083d86672e12af46da501e938318f101172e43c088ad74594710d025f1d7661bdcf928e3ec758d940856f70d	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 10:12:27.015908
e5779ba77cb9fb9c3d2df6cb8a0fd6a8cb1b208427924083c1e5de56c6db9113446f7da0f607b13acce70084bd3e8f64cf4f9b3b23a8898e71d491d9fcb5aedc	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 10:13:18.835861
1610a359d7ee59db6751b95f9617c0127f7f344078690b6fdd0c9d5a5bdb6986df8047c3b8c4b0e36b3b7d3048c18ef106a48f11c3fab6fa9f3fc3c64e407b8d	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 10:15:21.10506
0367e984d1f9e46eb6c9b19e5ed2386e8ce43432ebaf78f121f4e8c00a42b67fb598a834892496fda6f95b2942cb1b1e528cf02310c4fa9a1683a829b7aeac97	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 10:15:29.924159
6aec19b8d926f73d30e0870c9670e123c13f5c58ff86f9420b1af342a6ae0afcbe0c2551820255e45e3971928c5c343faa8566a545cfbe0eb9b71428b3bf029d	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 10:15:33.941688
8c10dc75cd3fd5393537780b87710f2993263952301aab9425efde80854b1afa1c1f3c283843487ee18d3744895828e9af820ebd469b0c6e8a247a60c2fee175	43	{}	2017-12-20 13:05:01.836096
6f9ebf679637cc73b0eb7d2a21d92e1bc7d1b493136a9dc268446ef621891d773518240b324a36f8b06569dede3b87da8c12d9401211d91d11e31f1321dec251	12	{}	2017-11-29 18:41:30.93321
b229e95f254f935b728d41d539f6ccd754a6e0ff57f6d8f0655c6f9477de646407664ec22a4648aed0e2529da74242ec0a285bfe0e130108389812ad1a66bd6d	1	{}	2017-11-30 12:58:51.245442
8ed6e7205b27ea35a7c33c0836239dc8e7ba994f062663bd119d6a6f3e8ebd888e9fa85b304b84959c291e24b5131ac087f702555c4d47744fd7e3580aa5f785	43	{}	2017-12-01 00:08:19.415671
163e027c259d3ee74dc47d2c96d29deadb8baadd9b5d551e017c700896d993f2c419bcea153896d58ae4f7687ea5dbb2165a7a3b2ceee3ec14c77e75e1d98a5a	1	{}	2017-11-28 10:14:24.811316
62dd1b4e0abf5c807c7177803d719000563c4453168b7fd174d5211d58697412d4e1608a31db90796a96367098d17dcef6b0dba5e0bb35f79099cec49d094e74	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 10:14:33.88659
09c272d997e92fc524d67857d8cba9293072b5a5ef76053488103887745d8da6e1e2adb00883f87e4a06545a60a35e8e3b94b3acf35ecb4171c95caf0ef61cc1	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 10:13:42.74339
8ccd36908653f1a2e058c948ee3538069ab8caeafb1cd658b5b66b9efed85a5398fa4ee08bb3d216c075b289f23dca43aeaa860ebfe11db253cf8fc33fc00e5b	23	{}	2017-11-28 10:13:50.465917
8382759deb1087a8d5f780e79388c7ee46a0e2490db15197909937fa614c8ba305a015c3ecf50acba263751f95e905c4e3a370b0e685e78902ce78a3038f6fda	21	{}	2017-11-28 10:14:06.226622
9e869be76836bd7ce7d7af600bca6c3e7a42fb61119c6ba0d31b6c906affeb62609a062d5f4e42b9529e92a576dfd3a3fbdbfb85331564c1c8b9d90fa360088b	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 10:14:19.117196
0f061591f99c6039e586ee7f53cc833108551e87c5128fba662182f6163f306f12f2fadccd542666ecdd5ceea709a273c90b9845e66b6966ed310b2f73a2ed6c	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 17:10:20.912558
467a5b3d701b57cc53635609e7d68b3a0fb470486603150294dc9f7c30037952859be5b4bfffacdadff965d9d1dfd7e2580bcd9e7e38b7f43b63f942a0fe798f	22	{}	2017-11-28 10:15:18.524542
805598afb7baeff4dceb9b4406664f75725f76a3452a13d13e69f72ef34871e8c1409928eddd78fc6151d702f7c24219a3068a25444a14746bbcba568df8ab61	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 12:12:04.894278
4477d970f2fbba6fbd7237955168ed6cc6ec169e427b9ebe5be6bd7cf87e79bd32312ef15bc0940c97a3fccbda6ad95763aa81e358b4be93c68a2b030010be43	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 12:12:16.097636
bf278e21f788da322309c931358fe4f0668f3d5dac6cd4107a414025c58acedbd11c0e0e55d080d14016239b72f02acbb04794bb432c153b938f07ba67ab160f	12	{}	2017-11-28 12:12:16.159013
21e96123d8ee8206dfdef5af0ede4f4a4008e476de466381b8f84fb74e4ef551298383f97cd25e5403d6965c1789c142f5f1b00382eaaa0913dbd9bef8a4fcf2	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 10:15:39.424703
518a50b46d3b8f1841ebcb26ae424baa74660d34106e3a08468fe21fff010de180b1421231e771a2e1c5dc2ed311a49ba334da08088da37fb0ac7eaf2716584b	12	{}	2017-11-28 10:15:56.433271
3c060a98de2c862b7aca3c5bfb3cf08fc3b803694aad48337af88fb5666762f12f42d5cdba55c09d37bb0dc23dd9929d0cbf1319da9047e7fbdd55c7c638e104	12	{}	2017-11-28 12:13:40.414504
f3b326a753102f1977bc4f397086a9bf95eabb6e467cd7cd4daddc95a3589f8b807a5a4e1dddd2054e3f4656b1742313df3a43d3a3aa9b64f5b047745ce1a0e1	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 12:14:56.225896
925737439778703eb261886b03fd9c2ffe549bb6ab8dabe176f2ea6a2887167bd89cdca0861efca1a7462e2cbcd7fddd54d8242ba30439c9e20bd60b6e8165b2	21	{}	2017-11-28 12:16:26.685372
96208a1ba849a27294f080b88b24527dd2339d82dd3d2b913a7f99a645edd9bdd66fcbb5a94e53285867181cc20b6d7d494d4155653f9d280aff34cb82e330a7	12	{}	2017-11-28 13:34:30.056689
d7811134d47bc6fe09ad9989a7de127556e745714c0fae8b941640b438d4b36152f1590569d48798dcb39d12d2662aa0382b733e86d835f2e0b4e60566e60337	12	{}	2017-11-28 13:35:02.322025
904bc489cb2753b87456b8997755e532b57fba7787a9c96591b09bdf56bb5e54fd05b602cdb28a3a1cd8b2cf6a0966d33f81cbc13def565134e0c9abe401e872	1	{}	2017-11-28 16:02:51.831858
cf8e5c0281c48fa1c678d33ece740eb7d0f8ed2ecdde6698b55719171ddf7f8a12ce5c86e42ddba9065831125545ffc102f6b5fbb4c2bccb45e85e1fb4ee5df2	20	{}	2017-11-28 18:07:10.958977
c4225d7207f4c9111ce671786f9c8d8e195802ffc7b5a12266aad2b86abe5586cc4a1adaeee232b18b696b13952ed48d47d7dace0c97ef3d6adc7c73cfe5afa7	44	{}	2017-11-28 18:10:08.674843
c3e0dfbf4b2e68526401115726efb8bf33b0d0acaf595705de3e3434ba839f98675b92538bbce4b8dc1e87922b2d99a8180b399b67c179f19c1f13e08cefd8fa	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 18:10:20.055057
d427076b1542a83d3f06305f7833be810348e5a28fef84184480c4c9397dc4d480f0abc850813bbdc9ad70a5d369fefb31b7a7fba69fe71d8983a646f2665e0a	23	{}	2017-11-28 18:11:06.736448
3bd573084abca20b031383d032a7591eb19beba49d19ef4303ebc288e20b2cf0947a3fdbf06d4866b35c12c3d016ccb40f12e203125254beac4009554055dce5	1	{}	2017-11-28 18:11:44.078693
7d93e610763466d8d6567badd3a31bf5e74894e45358e73556f30c35c6d749d7496c556d92e082031d5aa7565453b65e0541e79e2d4850eaff2ee0c2921b80e6	16	{}	2017-11-28 18:14:02.293844
e20045042fc8373dc644f80da56320ceeb75aa9c66f191b14486a716c7ef75d0d980cf6793f1177b3ce91e769db635b147f5de4f452494718c99620e33e0f143	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 18:15:25.400926
2de9b04f6900d14e990ce17b890cd456e60373ed75d615cc79e2176e07110fae8b43af919cff10d509d95523a9dd2a97568774d0f5d4e087154af6aaa9d5d6c9	1	{}	2017-11-28 18:15:29.526234
d60ee9ff67c8c8da4d30f47892bdd322f62e65d5d4cda05ae259ae7c45a2f85e90be6042b2bbe918539f260c5e4fe1d41338c700515332dde9a878ede5ab1768	12	{}	2017-11-28 18:15:34.55712
a15250b13a2eb120d93e55abd062834051fa4de7f3cc37bbeabee46f5d4ba1e5d8ae3a07dfacd5d9b8b736096677b1890392b4016a3f4b53ea8087816708a3d9	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 18:15:37.885262
9c36aafae5957c791115de5646e5ba9dd864657351ca7d79df2ea4aeaddc43c5535be07d83a3f9085f62a909c8f84c8dce056e75d3c326f0bef2c189c43e4bef	36	{}	2017-11-28 18:15:39.942681
a14fa87825b60126ad8959169b77e7088edbef26ab338f8169fbeefba8aca5b103f235ac9d009cb95fbb5fc8ca41c9cf1f43a07ea3b266fdcbe8d86cf9b86efb	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-28 18:17:59.959304
026756a7208a924df5b3054d6a82054bb251fe648035b75d2cb25d29fb96fcc6c048eb94ccd9c26f6462b9f945f8caa28ba49fd89cf4e21a38e7a3c199305599	43	{}	2017-11-28 18:26:15.902428
724121485002e403f3477374d132a381d662c33e4e2175019ca61aef60dc77254d0f17227f6e7b987b09cf17b5fbcc21c346c06214c2f3bd03f6805e75adc837	12	{}	2017-11-28 18:30:40.920018
f6fe5c658eeedfecc16adc6768dfd133bdcf523b6be4dd4e190aca01490302941c8e0bcd6090ab5bee791ba6660d6f0b410f9828fdac228c87975be43651d10e	21	{}	2017-11-29 16:09:45.428455
a7d8ba78bf832e9baa7220e881f8c4307b60e4d661295fabc50969c1bd42a2c742b7ec64d5e8b1fbd0dffc248e2bd677c0d52f08304ebd59bca7ddd0e4ad5d4b	22	{}	2017-12-18 17:53:44.019109
84bebed56911c179d1b2b3bb6b1e8a4cae4b04a7cbdf5175bb2f94c13e536b83c0b61f773774d497d34e4bf13a46cfa88dd0dcab017dd54533a5fd89c21e0b55	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-29 18:14:34.706474
aaf828f100b128665688a2051ca21df3c9e0ba6b724a52f4b5cf2c84581a1ca99bc089bbc2c468b91bef16e8a793db9cf4690aedba01655bdcbf19a4f7ecdf07	43	{}	2017-12-01 00:08:27.64395
f1f4ea73ca09423c951e9fda449653155e8a703ece979224ca6e7e290810d78c4898a01eb3fe34b31c77aba32d20e4ebec80b60e37f693463de3b3e8d32160c2	48	{"username": "est@ttu.ee", "is_authenticated": "true"}	2017-12-13 16:08:44.918945
a6c7c9254dd80b7a616e824c0021b00809565bba456bca9d28ba38182e00878f031ab954874c8e92c7ea9f8521802aa49960aea5b154bd9f7e0162e7eb44a505	25	{}	2017-12-01 14:05:57.847464
1f247b55a4594da04921caccd285c78eb4dd03a8cf8484166ce4ea93d6568ed78eb7f4fe6b1b461b3bbe9381605c2a4b4bfde0ac364338c1f1bf4d8644154695	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-01 14:06:58.824075
7fbb24d0a4b206d0fd1341e31653fc6a7a66b7156dcf391c9c0630ff1f61f70a170977c3a2db91a178136dc5c68290399184a17d1296b9e972d0edf5944c2da2	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-01 14:07:06.955963
feb52611f4fa958c95663ab39b543ec26eea362ff2cc3b72039081621adb8867c4b64f0be9d98d245fddd69f53ab97e62b51d305758aedaa915eed60eb4e8b8e	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-01 14:07:42.468317
4f0d14e423b3894ca612999d6d2cfd18451b0874e364acf27033e77c515ab0aa16a0a1a9f609c73e88de2fdfef6e3b41f0d0bfd757b08715d8eaab0cc3285a6d	26	{}	2017-12-01 14:09:43.956977
21d7c135fe694fa4dd51a977204b35200d1c791ed4394387602383b53e72cae060e96a44a3efb3a2a436124ea1406199cf927b9cca120e2a50af97bebb852af9	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-01 14:08:28.493933
998b31ed0c9e4fa8f6d80cf730edceb1ac45667b492a457601bc395f03c41057564a85de57dacf0369ae72051b46cb2c469854e0fe43556923bbdba759d8dda9	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-01 14:08:42.62503
de26eec49f9cebeb0c1aad358af39ace22263a6f2d685ea448a8083bbc25c784bb30171e6c36669c889db6fe23176341c87bf6d0097f135ce27e5d364cf5e6b1	12	{}	2017-12-01 14:09:05.398937
a6aa524160885e1db7a1b0ddd7f3384c27a4cf95060e9804b0d02a4ba2b385e0531d357ea582627fb36c4320bc23d447eadb3d90206cfe196a4082d1acbf9430	43	{}	2017-12-01 14:09:21.134737
b21f8008dd0848e8dc893c29c05c37d65a366bc93c90aa4dbf2dae75d94c482273bf402b96684124dff12fd8f79b489bf4839093914bdf6261874e98e0ff45ea	30	{}	2017-12-01 14:09:29.160518
623eb4a1937c8217fe65f489dae85f1f514c76f7ddc894861b82caa5b6e4c282fc99d1c1354313a0b652df7b87543381ccc077e67f9d4a7aec26f80ab5583294	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-01 14:13:32.712835
722b893e43706108281dd9cc9a4345929c3523db348793143f817f0d88d5c03593d86c752bd36b3775f4fc9542912481e0fc218835a372ee16d3fe016c413e8d	21	{}	2017-12-01 14:16:19.538864
e1999eb4295a0e7ee61706237e5f9e2b6fab062ea9bab75d4a7ff73a39285a53eefe531b038e42ec688ba9bccbd707974517a8346f09822e555b0d85d6a04789	1	{}	2017-12-01 14:40:07.032806
fc665fbc35e683f17570f5c616c613cb4d4827c65feadae978bf9a11581c0918c5060e21c24c1ec5ef6cb54716d9c4efda92d6b3bd1d8941fea3d02de373dcc0	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-01 16:11:27.691527
7bb62e59400ba168c8ae09361deba48c89ff478a50391378215e12423d059f3879d5abb0b8f1acd18fce01a2739c1d5bb6f722fe631e66cb5a363b5c163255f8	12	{}	2017-12-01 16:11:26.789594
ce15cca8175787e9f8437fb74404cee27e9743ba6ad1b747641d52397f7021e46128810735f39394910bcb0b8721c78df1f0029343e9117441b8e7a53a219ea3	44	{}	2017-12-01 16:11:39.044404
e9281c890275922de965717d58d34a50d66ec6701f7af4dedb845f6a60ba45dc1af3145b41d15097be4f12e30daa1b545aa0f8d76f70b8116539bc61c17917a9	1	{}	2017-12-01 16:14:58.942174
1652d0c5e5ccb5173c4d6bca1c30130e5957a8394236a62b1347fff2e5e8c97f80cbc7937d9fc0d327a353655e06fc6e5e50e1314270b91fda32c4db4f06f0c5	1	{}	2017-12-07 15:40:43.535507
72185316ced5a829e66a4294252fca94519d305e5bd40bae96d2804a5c6359d2f2f4af568cf86a2b547c41ded346070bb2f58e8c38eb59f4ed512fe20f7d61ff	46	{}	2017-12-08 14:20:30.91904
5e1202da386bb6984d7d9ae34681557232a83a1812e151590598ac23dbd7dcaba41827c758cfab8c775054fb69ab7574068c4663cd2a55d3a55e74b5a32cd508	47	{}	2017-12-08 14:22:21.780469
0b0038492127bac34d9aa5a9325ca821ff7646282f8cc36332c5b9cbb22480b9759a86a2953b37851dc300f788fafa285f405041c4b206f5e6b43af0efed79c2	1	{}	2017-12-11 02:16:37.540855
8bb9d05b4eefd88ccc5ffa590a848bb893b47ecc9e5c910b493f4169866b2fa76a0c517120aae494c0cc0c427c2e80cfaa55b8cfce07efbf1cf97d84706052b2	1	{}	2017-12-12 10:07:33.043601
94af74871847c514d703e86c281f3938e9d06bdfae575f9b35bde421e6a0f408897f62e9d04c583a8680d12c9a63e6c9b84a1d2249fad062de73141bb13ae62c	45	{}	2017-12-12 10:26:30.744609
034e1adea5726df818d1da86c65dc1e324463185604f9026929575fab7299b0b942e556b1eb17ab3c09ddb69402d53420fc846a1292e221217264cdd7b3769ac	43	{}	2017-12-12 11:38:44.339511
f7c962008f9e24d7eb7a97bd9272da06e5adc1f4b0bb89b316863caf88001a354168da45ecccafc9520515728748d9c143115784ee94ed695e7c3e6ac35892ed	1	{}	2017-12-13 10:50:09.283931
c7938f7e457098a7a07496832ec7e28c7f3526285edf36e83f80c7f1a211f592a87d98f22e41bad0a4ca6eaf49aaa03fdb784ce9b351654ea1c5c297857d53ac	48	{}	2017-12-13 14:21:53.205582
36e972c4d8ccceb62250788a2bd6bbfe00d40e22af2b6edf5356f34a7bff4ffea3ac0a62b7725e3d4c289ab7f2c1c73e3691ef8faf5698d4e93cf1f3f4f08596	23	{}	2017-12-13 14:22:11.397409
45f9e12a0bde939554cb071148d08a321a0770294a859ab16dc7b2dc8f20c99820d63f0e1c9639818ee5faa1fdd1496b37f767057737e0f001327c92d2f034c5	46	{}	2017-12-13 15:02:20.295073
041f1febbe3f752446681a1daff61acfdc737a6ede59677a16017edcb37f76dc5207f40d28fbe3b23dd777cf6d72570dd54f79cfae1e23b4e3c0d0bd4cff6730	20	{}	2017-12-13 16:01:34.15931
f6966960588bcfba1d1f6dfafca8472183088989ddada27069863f050c54f874a41a80eaa444f0ba62838e14ce6d6a9d07252ed570d01af7a1750b569dc2b0e4	25	{}	2017-12-13 16:01:36.6593
84fc3c6f642484b6d22e80b333d0164e5ac8f1881744e997279536e2078fe6cef0f526f8b8f03a6a4b18764c14d23b96c957258cb2e79ac8083271532c996979	23	{}	2017-12-13 16:01:39.101901
0f1e69ce54a8df8fed65df162582f982956a6abf1ae2179ad60c96afbe4e84b74e14f71d656da09f42cdabfc67a205f86e716919e156c16b6e5c456e944a8caa	39	{}	2017-12-13 16:01:41.674811
34f67aecd4706544e2c91c2625145de4a676f096c9be16522d7f7fc9d2b1f84bff385232a30fe8b7662bd6e0513cc62e01a4f0bc8f1f70006e041bab96c45dd8	46	{}	2017-12-13 16:01:44.368772
9bb5bf95f02f9ffa2919f7dc4b0a3aeb1a5c153ef9f4525b878ae316d79a073bada2b43b7ce9328417d7e79a0655dcc118bd2dcef05d4d402663a6dd60056318	16	{}	2017-12-13 16:01:52.653208
b3e05b7ebb62c3ee3e3f69537cdf2bfc2c75248ec2a35082c62a2fc8af6ec69e5f784f923badbaabd9030e5ee8fcedcc96f0eccb4919e49f1f4e3605e0a88b53	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-29 16:11:37.999467
b81ee3c2cf6ea82ca92b736fe5f2d9c86ede612ad529d526d867a4087ffd5b0cac472413dd11310c2486be483d8a49df53f412d23c73995f09a6afecd04624bf	12	{}	2017-11-29 16:10:04.156022
7001db5caa2d7a6af662da8f43e90c1a5f6a27e2d0c51eb06e1532f5334576592dec8ce70292ba092a85becf76a9406c717063291dcf08117fe64407a781edc3	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-29 16:10:04.916595
287ac6b944753f34945b5d785e333d8a5946ba8226b611771fe304e52de5255d7da20117ce057b7f6933e87cb46fa686c361438c72040ec7558767df577dcb88	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-29 16:10:07.523239
55237fceebe49fef9939c8abb18d8d3d5b33da93abcd31e2bda408e9a6ef2fcd4cbbb9cd3f8f124a639570555fbe9cd07c04f32a3d2b9964d17c21d327036ebb	18	{}	2017-11-29 16:10:37.446052
3d8f40d446d06f75d9aa2ac8b695b5931c16e500de1fb8ff67d163a13b5bda8740ea831ae8a13b3e4d27c18e4c98ac30c41ffb210fc38340cc3e6e67bc1f1631	43	{}	2017-12-01 00:08:38.037382
e5ab44f87ae5eafcf731d19944e43e995382cde92863fad6f118fb7b0022dbc0ffb2813fa53d6f1ba2454f3c9c8a7ee7611ab3326d02e9db482b801a56024754	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-01 14:07:32.605024
d1aef8301e5d7231af26a3e77ef67c86a5889b2128fe12929dbdcca1a3aa234a0814f4ee03a0308f21a59dcd0168e715a65133709ae22bcfff5743ce9021bc95	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-01 14:07:35.694034
a52e4f3e93446bb0f6fbe40d60eb6153c939dce8790cce5932721c6288883d392dfa655e8e39768c32e9f7d8a6734d1f5cafe25d48e8268f8e0abd24b407c88a	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-11-29 16:11:53.657242
a98ab1943699d2d5b7b0f12713782da35b6d4b883401ca4644b7b8906fb3f262f68b7108e317961d375c22181a0ff60f7fe733e03af5b6456fe691675b94eb26	36	{}	2017-11-29 16:13:27.555255
e22f261ec632ee197bed38af69c7802cb5d102fcf6ff40f69d67c2134df0e26967e858bda721a7b419aca9e498c0dfb7e2d85e304023dd2afde2f2d8444848ad	1	{}	2017-12-01 14:08:27.813598
5c7ab2551896be426c7f4e7f55aacb77b9f720085e7f1a028f7a9decc281238f2ce8163006465844c576b85a0b05e419dba5b0f3af85bdc3effae95c72d6125e	21	{}	2017-11-29 16:15:48.760723
8a3e304a866bff980847766e0fba96931edd8cb450956e25c16bf1bfc34163bc241e397a74f95120223af463715a4ab70f272586172cb136e4b988ad1abd6201	12	{}	2017-12-01 14:09:26.236674
542c12765fcd4feacc230d5be891069347bc1c2182f48d579697888b3b7ecac6295efba4902829378d106777eaffc93ccff734b51b5ee590cb1cbde79c81d245	18	{}	2017-12-01 14:09:40.867475
fe93be8122ee12431b613439ef3ab20ed7f6c08fb68e2ee68ff54d6d6fe91dd015fa9c76e1e847d4a25da391ce935cabf7c63105f1d9897609722c42de494df9	22	{}	2017-12-01 14:09:50.442724
c6e3e6fe6f76be3568612c29fa2473bf16bbab6fd3816f1ca9c619961d1d573995e66e154042dccd645ddc26978f8770777146cfaaabfa33f1c69508a3b3940c	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-01 14:12:55.083826
1cfbf7a8a49ea50fee0748c7747a1f8fdd0192ecdfa624aa4795ce1bdf654fa8a94890b9eb59e04e1149657fa03ebfa022cbddc0603cdc26e1516361f34de264	12	{}	2017-12-01 14:15:40.498477
5e2602ac14634dd69b7acc30f8dfc748d417eb826087a5960ef731610b61d1f4d0543c8ad65bd26e3d5c4442d8b31a3177f45934df28d536be01984d4d7bdb1a	45	{}	2017-12-01 14:18:20.121964
eea1574450f4e9197172ec22e3972d763d60736617e3ea780090d997766c6c17e00222bd3830d13b7326b7cead7b28b3783a5b724bbaafb5c909d7170e4ad1cc	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-01 16:09:17.329537
1ceef4cda5cc6d7d9f936bcd780440be1aff89f9d3a4112251f1e2614bb501844f62a4f42209e083399a4c1d34249ab6a88339b1aaa57ee3cd6c1705f35a5199	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-01 16:09:53.105619
a1a6e1f42c63ae4944a93e8202950c1085ed98385526408923e32560003e37a5c6d5adf8958f412a9a1ef652d73730cf62bbc1cb5dc61cc9aedbc5a37815a6a8	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-01 16:09:57.585347
93c8bc939d1e4fa4a94cb4e2764c9537d9f148f91b36b1710e041741d4505ae408fb4c7ff11ff9b14bec13c0c10d120930f4907f224c4ce9c3fc60d4a5bb5bd8	41	{}	2017-12-01 16:11:22.383626
e0014400f63ef4d393b91384349e92a4bd2a25054da235c93622b7480ce6f0688a5fbd5b54c3124c2f6014e791e8bf729a2b41575f39b16c9d5714a461aee30d	12	{}	2017-12-01 16:12:19.494546
8bdb708ef0b36c7c5f34bf38dca45c35d80b40f9e6616fff064f9ecf0a49d099b8fd20fc20fac28242d30e454c919659e8b3a0cecdc720d0196efba84636b00b	20	{}	2017-12-01 16:14:37.099965
2ee3cda89341fc7b02129cd01faeb07cff605435e85d5a50697ce5e0a05f8b2a26181c8ae4477618fb689c84ba501bd7008658b5f7a826e66934211d8aadbe6e	43	{}	2017-12-01 17:13:10.092202
0cb34826bc1489a962fa4509844503d187a1ac7a365eb70b8b46c69003fdbceca20f0c73fbfcfee3741aa3018dab93278a1b0c6e30e32effe59d195caac02f90	46	{}	2017-12-03 21:19:51.157406
4a1809cf4a99ca0351888a7525be4f18f92b43aee0214e68bf39cc06ab6463ad36d9b4a275b4dc37233329c6c2e03ff372268cd565d2f3fdd845bd304971b4d4	1	{}	2017-12-04 01:10:10.595518
ffb76ba80c9fbacc0d5d7614aefd4716bcea55d1982b0534a51cb92efe741d32377b742e2db399bfb039ca30248090f00524d7d09d7495fc656aea371b41b56f	45	{}	2017-12-04 17:37:31.640597
1aba66d8d3aa55fa902cea41ba643b548608170d7a1dfa284981ecd3fe39a5bd6d1d1f382c0c11be5f225443a9ad79a14cbc51636d0fd238306d51c71991bbde	1	{}	2017-12-05 22:43:18.32589
d5b9895712d278af1785fa277ae9d133093e673fc7682542f6e80da238bd5e0d3fae00c83051821644be583d86d33a4b78de58db8a20c966db46edb551e8b23d	47	{}	2017-12-06 22:04:58.118894
c6fde788a4ace201f8fdf70990c99fde3a97f335c04dce5e5853ea902b6f69bbe5106fa0bc6c2cb1c1d8072bef132f7b2c12cef5f2a175850d2ff02c420cbf8d	20	{}	2017-12-08 14:20:50.029427
dd1257e88b7b25943e9c7831159f069e2c2e6d7440816a0835c39da8db4352322287a2cf51bc9e38eea06b9c95079bbd72990c95ea4009e7f6927314af3f4456	42	{}	2017-12-08 14:27:15.983191
9fc00c83dd66fcdfd1adf64a7b395ecc655bb14d4f7e614d1871be3d74de3666d2c2c80544a0eea4a8b309c78acae8d9034a4334f1728173b2cb154c2177c646	47	{}	2017-12-08 15:45:48.571932
0908b50c2be4e7ec7cb02684156748bb0b03704aa186f7c3945fb84d2b42b0be6a208d5aeafb3d1a68c41481c3e7c27d1ab80dc9e5bb24e159331ff92f7e9113	47	{}	2017-12-08 16:02:00.320918
1613a4c80814cce8159f7bd0ac814077d39843d746c33b01f96bae30a9a159a9115a83b5d392ebe7b6e70faf8eb42eefe77ef6ba2b99c6295ddc2f1ecdfb2c4e	47	{}	2017-12-08 17:44:17.561068
9b43eec964cff2d2086a3dffe66d8896e9af5a79ec098fcf3ae25cd441261a18b4e1b8abaa6aab4b0785fa4c024a00c161ef2cd99fca08d4210eee860350732f	1	{}	2017-12-09 10:51:43.236
6eb0c158b51b81d023df4f6f635ed825cff1836626ce53d78bf527a246b0b1b7773cf0c47095aa62deec54da1326a64d7c8b9d27880dfa4700ce781da0ddfb97	1	{}	2017-12-11 02:16:37.181942
b900b973b7158e7669b26717c789196808494261e5b5feff5733d17d93e0dd1cf2000e74a3661fa8861628aaa499f887037fdec08e1ff03a8d9e825d0ac044cb	1	{}	2017-12-12 06:00:53.935978
3755ef92ad44a51040dfca9e6eb33130f7bdd0bb7a6974cc2fb483d53c921daea16ccfa14f12be623fa9e2b42cc975ffbf10daa3fc7614b402cef29e4f7c6f08	59	{}	2017-12-22 16:41:50.175697
c6ebb616137f17f471dedfe5093a5a4556bb5618deebc73d080346ced77633fad7f54d33edf15846e460f489b1592366337f5be62af75001462a56c93450466e	23	{}	2017-12-19 09:47:58.407874
1b5654cdd1f05800d007e95ed0449d3232720aeaf4944940a8eeec74dd3aa03e4db2ded77d6fbb523978493262e7bc35c002bdad3e0848acca7e07544c1a3f52	54	{}	2017-12-19 09:50:35.44287
62770512ef943de59246aacaa5fc2115138230ab7183ffcf93fde5b7077294236871b8b9f11ea9d8e84107cf418971c50b2e4f50901b221c87b19d0d9b3fb02b	50	{}	2017-12-22 09:08:08.992354
9e21bd7967817333e72d706cd3c36071b27ec0883de0f9913fe9de9baa25c1c83ea2414319b7ad336f2ca7e29431a134f3e215943bbc0708498c49719f045650	12	{}	2017-12-14 13:18:16.638761
6930f4941756c3a455e68510cc7c21503517c6ac1b494bee7167f1a0c42b1770527fd147dca6d0a031d02984bdaf01e9548bb6ee37769ad1c9d4382773795035	63	{}	2017-12-30 15:09:57.146759
c4f6f54a3355b97bedf5958e76d033578c5430d0934035104bd9ea1e57b8c3dbec5042946dd8a4c9cf093ac87aaac4e2ef2fdf9dd90f1d66dd0639b73ed2786b	62	{}	2017-12-29 14:04:48.056994
25cace0cc2e62bb1e3df80c23db9b664374d9976877354ed633a9a06aefec961d882432c40a8f7c53df0c538c9b139d200d5c84d580b6ca69bf145832593d366	39	{}	2017-12-14 14:54:23.355064
3a03ce572d563b11c8e975ea9d6dd31e02db66cb96272c1aa97e90e45590b287f80c7077c8a37494336430c5c92eb1f8e04331930ee6a7ff02a84af933c909cb	55	{}	2017-12-20 13:51:23.256358
c4026d6ca40156279c1aab6dd8daaec04aa3a095e6eeebb5a7085fbb94287a828fe5d03002725e1f74e735feed0bb9d719b9d95c7ec10a77a660e122e5bb8fc8	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-15 13:07:11.698422
d24d6cc5873d268545c7b45d975947e37cec9833a8ca7d12a70903790d087c0d3c4ce8d742c1956f89d2eb9f4c0d2438bf4b57f76d0d7d408a98dea9b89b68c9	48	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2017-12-20 14:15:29.876709
34f912d3808833a64113950dfca9856ec35b64b8495f0ac16cc12fbbe2984dffa7c6c5fd576cadb08a00fb0c75408178847cd03dc8d04e1ba294a779ddbe8f0b	45	{}	2017-12-19 10:38:30.661016
3ee4034798367717853bec14b866b5ccd16a036678cc10e5fbe7b48a1af2e4ed64b67535282181c2a8ad7c5340f4551954f1e3a629336f9838fb26185fad9e5d	39	{}	2017-12-15 13:40:58.972594
01415472730a2f98374357e9f4bad7f9f957d80e501cd4ff17075f58afe4f379a2052155aaf47bbec71784d28cc0869a8b498f463cd4a4b6a444ad35aaf83bdf	20	{}	2017-12-15 13:41:12.609425
d333d9552f414d2aad567e8fabe5fa1c07a9e7a32f6eb426ffb0f9b30511c7836614c897b7a01e1975f9df9103a6b8f9c55d4466378c260a82b7f429f899ef96	50	{}	2017-12-14 15:36:41.954828
2805d4d48e5a68c9d1a71f42ca7107acb7f3dffc410e524641dd6600ae41dddb5c8ab4201d1ab0668a0abfd1a8075e4bb8f00bf0a3f5f126db8b2b37755ccbf7	12	{}	2017-12-14 16:01:06.492259
06dfefc8c63a29c46f502e5df7526e142e9163b8ec71b9f0bbac603ad3e5fdcc4700382d765468b09d1d66bc4f3e122368a5e087e630fc700f617a217f8b52e4	30	{}	2017-12-14 16:06:55.395816
bf230785a9591d47f6244f1d162cf096c2a19baffcb929adc1c45065a63625f29c8cd52886b7b4fb50e23f69a8a0a9967fd53abc0dc6603b558f6c828582dbfc	36	{}	2017-12-14 16:06:15.224305
78867adc79fa6d424a38e20b6606b1ff2440a393313967f4aad849537b03b1d196fe23c65ce741a4562af6321c5f1d5d1f2c2d1924782b12e7664454d6ca1716	21	{}	2017-12-14 16:06:23.82104
f3223ff3f1cef887259f30346118248a9618e4afb8ba1c915b049445aedc06cda27291f24094018fbb2f969a3f3b51d72f6b84113e29256211aa6bffea945628	45	{}	2017-12-14 16:06:36.376769
9b96033800f1587b24311c9b0151f7c207daa5f5dab245711ed0e3a0783a6e34deb45e334bd9b83452669da3f28c5d53372cf0e267ae051d388876d68349b54a	43	{}	2017-12-14 16:06:45.051394
9bfa972e61b09d941df5241917903aa9d7a865b2a5e94f1fa29af45c524f4b95105f3c8a8dad366e24e455fff14a13708058bf80a22890146183e0d4e7174b41	26	{}	2017-12-14 16:07:05.084204
8fb46d03ea8e8df2ec3d63089ef73f3a273971eece0a730b71580d4b35773638a306f4e073f1a809eb85e64e1b19813ce2189007fcd16da76645c815519b8a29	50	{}	2017-12-14 16:41:33.278129
75891cf4c9f9ee00218d31441ccbdbc7deef8270f5b3078107d383fd6fbd2d0253c50f9d7af45ed88a93fff7dfb201098e6288711d82b6c046948f3ff9220f59	46	{}	2017-12-14 16:50:45.869738
a98b8e942109973da1c84363bc58730e19494ef74bd1f85bb763eee262cfd0c4531de7a89be198026c332cb94a1cf2fc9e348d0127d7e3b2dc8d45db6b9ea4e3	41	{}	2017-12-14 16:50:50.718062
9c69a51c8306e5ecb0c08361bc0acdf927689c98793afc1c3aac5ab834dcad92f0533dc0b2c0340388eb645f913c318034479feaf6c14c44364595742ab28e5a	48	{}	2017-12-14 16:50:53.932068
76747a0c7a691d5bc134a076c8305cbf3d8c80d5b51fde2e8ea7860aa2537e3549bde1154bea44cb9ae4813f34ac8ef4dbe40bbe9b3909edd2a31a2d983bfc36	16	{}	2017-12-14 16:51:03.428913
138171de27e1043d380b9b4ec29ebfdde794f6f047bc6a8e2d0eee4e2c177bd6edba4370fcb5bf4e7cf02b5fe155db1d3d665687a30eb8a29140237914128d4f	20	{}	2017-12-14 16:51:07.758946
f29a0aabc543a041cd5fc9ac83be5d82254bbf46b73f9a73d2d3f5e5c9dc812edc71fd13a4d30f883efe9ee282421f837271feb38575e7454f6b54dc0c1aeea6	37	{}	2017-12-14 16:51:10.49298
e0d66ba00fa3079f5d718ad1bea005bf1ab0d9a945241e20961f9066a1f69e2557bf7562427ceef8aa4eb621c4057a36655c0cc025b3a0c7578eb9f0eea50a68	25	{}	2017-12-14 16:51:12.568122
f990c48e1a4ce7233f7f8145ffad6c1a45a3dec294eb73465cc576df2099dccd007f2a0f5bdad6358ef480740f6d81fb7888c1195823efcd6daf176d94ba9f10	23	{}	2017-12-14 16:51:15.469134
07de5c152ca196dffe9897335a83a01b51a2b08513b0443b110782ce97ad62907693adb3a1c8ffc20f4c890806e7c0e7160bd49692646f367a852f7a9ef62d88	1	{}	2017-12-14 16:51:23.38136
f8c158fe35d5e6635267e42bc5fba9635f441fbb3971c86786b777b7ecce037fd4148770e6ec8d01476e34bc162c6229da0d97cfe502dc161294a90aad9003cb	47	{}	2017-12-14 16:51:31.926859
950e16b3f7b374b4f96aa87084c78808bc5cefe10d714e8f55a68393414150bc8ed42a254eb9f8fd6a7711c71dbe17304ea0800eff927524a18cee337023bb9e	22	{}	2017-12-14 16:51:35.705829
ee9e0b6895b45abc3a360ff6167ba31221d36594597b423378a9091f9cc06fb2644475474a2b955fe56bd13eb1d10d3ef283c17f3e88f9394c20e29178073f67	51	{}	2017-12-14 16:51:49.358815
fca5063f76e25c50ed12220417e04c21964ef38703bbbcab394b0a16f0c82c73db1f413643f172865c874cb23c81f314a67ca8bcb052dbf1677b4588d0eefe75	29	{}	2017-12-14 16:52:00.642905
062fd04881eb4d489ff05d00f31e6f1b33fb3d7bb80cd7086408100b4d16eb45346c593ed3daca2e3be19d93d13f9761be04471806380497d967cc5b49bf0b3e	44	{}	2017-12-14 16:52:16.377273
afb4cc159e130b4dd31bb9aead812a0d0bafebaf34e4858b1e6bc8b3707d93564c1541fbdf50f44daba24c38aa79d7e247994aa095c010d1c374cb1449fedd4f	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-14 16:52:24.543074
16cafc48284497dcc177622564179dc7d2fcf4d3849f2a99bd7e48baed4342742d4d819a72fff8aef0a569d1bd87be8b8d02fd3abac98f66d3886b0c5fb04195	50	{}	2017-12-14 17:03:34.906258
1c9dd3bd5747cd4b7704653ace288b06d0c3554d886f8f8edbc66b7d63d7ebb86d9df94b31696c77d398f24f5b53d655170e3edf9c426c1aacbb7f46512de2c6	53	{}	2017-12-20 12:48:19.9497
855f718a03e104a4e7e41d3453e6fa289e0255604e9cc556aeae1c211a265cccfd3dfd47a2de7294df182afad4605a34e06bec0455cc4a332ec72001be65e31e	50	{}	2017-12-20 15:39:10.823985
f00874fdd8a5714a9400354eab61975294954d9deb67dd633b4a7c7104cf452724601fb800853a4780215b296e274510df0427de97bf1db6b587b9a599d62e4c	1	{}	2017-12-21 03:29:46.93078
08f40d40adfe34f24d102bc288f1727ad7bca204111ca066b10b31c817694bf5c23fb78bc67bfa718860f614ad171ce7f71d018af807caaaf82999a305c625d2	59	{}	2017-12-22 16:41:50.722915
4f34ea7ac58f9027f231eb59b55d691a0526e1e07c8326e330badcf75b83a0f8ec00508a4c29a2b594b52b9c511873f32c455e71a6e9d7b51679545cc64b9c76	53	{}	2017-12-21 12:41:57.472251
0a689ef86973869e0e726b2c6a21c6742c89d797aadb4b182fb7d16f4d877f53a327bf78b0cadb8bf7dc3cfc5965e628801a9b2a47a14cfa2fb260677bc4415f	39	{}	2018-01-14 15:06:15.480333
4602ce2e9e0d8b15dab0a57fadfcdd39d925a45460622445b2b1d6e9b6f891a966d7d2e4654251d17464277b840c692fc7282c69e4b8ac3ed792460b18f344fb	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-18 21:30:21.986723
e7e21818308502b3367f1f1f21153ab6d413234abde445689f6b5b2e2a769b40c40f5ecd1a188bdb676675f98b50f1c1d6867fea252fa1e52a689359e92cb0b5	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-19 09:48:47.527902
5b39880d15811cb31f4686bb2b980d22dd65d80d7801f7bd29a0025ee179016e806eba929f0f9ebd7c22e4ca9fab711a7f6c6cfd5100252d00e510d97ec5dbf6	48	{"username": "est@ttu.ee", "is_authenticated": "true"}	2017-12-20 13:02:18.327479
1d5228e66e8b4a77c2497ffa85f2f0486009451cb03b37d88437542c1b1e02d77d23d54d9e8a3e4faf10366a2171a2a396c173864d527aa52e8fc66ffde1f45c	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-20 13:04:07.061683
7e3e9c4452a5d0bddb53e0b15cd7b5154a8c2b2cb9a3a3b7700798db22bfaac23d0d136c3284244633ac96feca084a4a8f81d88d0a99ced5b88174b2b0e07076	50	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2017-12-15 15:18:04.28114
33a01444de241788d13ba0d9438ddecd29a3d9f37005b5545e0614b3162aa9cb67f419173419f9225befb03d74a8e751b11afb81b18a0e16f29a5bf3ce707d6e	1	{}	2017-12-15 16:49:13.545437
eafb491922bc75072e093a6231d2ba83fa7f0dea4a1ac536a1cf4861470246305ff010246add2f286ce169f552d7c2f72cdd1388b03d56c582b0f66d0a7a77ef	1	{}	2017-12-16 12:44:09.836453
12006cb9050bd01ab80425d73146e1c0d63cc7ae49e1d8856b894ec4844fe383d8ae27b8584127a5d281f712c45bdeeabafb5de8248681ccdaacf74ad4854a05	50	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2017-12-15 15:47:45.015592
59f7a8196d7cd6a31989d74f67ec9b391fd5229aecb19255864f1de437a988a2c5a09e6c9723bcc9a3c02a53872842488117c23db4bc1707cf723def4d251cc4	12	{}	2017-12-15 16:34:30.443994
f9be1b703a2e3caf433553e14713f8056d7eeba3056862afa6f4ab0f85ef517e9d5dac0f438bc7f3cbe5d2b53ccbc7e289f827a078226e6e87d0aeb9bd947625	12	{}	2017-12-16 19:06:12.189359
21c020780631f0e1190c55c8deaf5f15951281d50f6a39656031f7c319003682f57000c3f1a0a7fbd959327e535b3c349fb3797c3e2dc1310db9aa9b2338f70a	1	{}	2017-12-18 10:02:31.956033
56dbfdf47d6c9f5ac00eb5f336b89d894eec398c7bb577a074ed061271328d59ea6d6921385cdf26b28f39f92463bc36043159dc9ae5fb300ae45723e06f38ae	12	{}	2017-12-18 11:01:37.270502
7b787b7ddb88d60418ce2f4890dd1aa0679b8f0afd5dd57a9393a4d004c326cc2a3cf8170cfabf6a417754bff113f7ab4e234eb48f550da51e76334bdd02a7f4	16	{}	2017-12-20 13:16:19.505704
6479111a963b4e889b242027b3f18df35a3edf2c4b2fe9200752b6666c21b82928163646c9739cd2b2321de1f233c743a7141fe4ffa8ed420092d213b02f2134	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-19 18:32:09.282527
ff5ed9fb9f1945d2f1e5bc7a23fd0a3bc5bd735506b71359f965524b406bb45d8356fccb974b08caa8f432aca464d379d1246c3a4d70626b89ff56055a93cc56	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2017-12-19 18:32:35.055696
edc49e5a0923ee9f2e2b4f514f96545ad5a958126674f46601ead8fbe65003a8e0684c378642ea878ae3e3ccfe98e5c67f0b68e64e965f341e332d0dfcdba703	30	{}	2017-12-18 12:26:36.207057
e37327b6b108e9bbe3ce8624bbba700e38f8359483d3d22bf9049bd413f47c12b1801cfb280602352b7bab1b6a9369abaa40ce33655744d850662f2a49b4eaf7	54	{}	2017-12-20 13:16:13.402221
8b35154cf10f129305841ab1360942a818dbeae77528329392463ecfbf0066fa0615a792d4c4f38d17db41a1fff2882b60917b4f33c21b8bfb6317536a8d06a4	49	{}	2017-12-20 13:19:18.466727
492b9c72460e5ba68ed83b94c1b8fa5227a358d80aac908a4d4335cdfcecce64ae60aa7ef68528b58c126083444cc9772f5596d4b7811581b37edb849d70d5fe	55	{}	2017-12-20 13:30:34.212082
03c595aa248a0c7e427e564b1b968ade129c02ba2b6c67c3b9ded101d586b7ba727569338460d0ec35d359f41e27662c93b336519019ce0549f8c6d7945e5d84	1	{}	2017-12-18 12:55:20.144188
8c444d3c720887d5ccbf9d73e0ea74955b6a4af16512d030065b89631e4fe7e087974ca9273042ae394c914ecf9814abb8970ffaebb5e2d0d470b538312e0849	12	{}	2017-12-20 13:51:52.820151
e180afc01dc5d49e9c5087adfd3159d11d438305091535ab5f94296479c123058ec4feafc2d27635c28554970eec4533560c5ac56ef6e2c2c558b9fb23f29dc7	55	{}	2017-12-20 17:25:39.623342
b11848c5600f870d334328f64e708aec7cb6f9f38e77b91ef4a4068067be0e4bff316f3704397259b105a82251ed59e0797579c2a382386fec42044506b70f1f	50	{}	2017-12-20 17:28:22.640304
c9f41446f2a339b8f3d56eafd275456ff7dbb5b7ad1035f72351127966f9ebd579dc1004398ade78f0d395b5ce2c82b5eb57a1a4671127ac0a47217d57fa317d	48	{}	2017-12-20 14:05:49.861472
70ba9231a1a8dfb7103af43f6e67028a8a78fb49ff57ece56cd936fd69f2b925c4cdfcbabc50cc469f6f25acc332625df7fdc64eafe1d12ed1aa80f403e92283	55	{}	2017-12-20 14:20:19.952332
6585f2100d8ed1f9290cfc474967e071224fedbc502b03faad92278fff1b6b32fe5b5e5373780cc50fc08c15aef702929f13a13951fd86a6d04910a3a1a13d60	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-18 13:43:29.741924
e0d701483db05a6c0dbc34cecaed074f71d5d46feabf303696c56fe59a4a1e935ae906e9fabcb00ab1d04b19bbc55333e590c1020f83f5ebafcb4411bed57ea4	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2017-12-18 13:46:54.794098
4c738bf775702b0c767828e2c9666fd490047106ed08188238a1d4583fe72fa9375572c4e83add287e665095993fbbb777bf01d81a174e42c7821599cea9f969	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-18 16:37:07.592581
840a5aec004816c2aa191c329e82a49848d1ac4a2e2a39c646f8a7298d7a47c5a8e9f7b59f86760cc7f6a2b3862a5bfe8a46cf6d36bcf91189d798fe90d92a1e	53	{}	2017-12-20 12:46:53.17621
2b84f174ad564519c9e40828836bb5c5b58278823ca96eaa251048a67ae05d1585ff50e4e21d180830ee44ddf5abb999e6d6a4cdacdda1e21dacd896474b0ebc	20	{}	2017-12-18 16:41:30.96754
5e93471481e3a565cb9654ad78302747d4152a1de14762aea76938846c32c1a4d10c86f1a25ec63f8ae70e7daa8e0dca36ef8d604e00afd9104a0f7ff76ab679	23	{}	2017-12-18 16:50:38.101995
a96e0191bf92488d42ec085ddb71e93db90259f3ad834801c7eb34b2fb9ec3a242eed19e5d60250fa0df3de10937a7f6663127f42a13b5b9f7a7e3b976033cf8	59	{}	2017-12-21 17:24:19.810981
e479a128f4e07baba0bd66f96e7644c7e9967befd583e2b097f0fcc245d4fdf3fbdada82cee059e1eada6f6d6991370418b9a8547258cde91b9e5b352ff79d2c	62	{}	2017-12-29 14:04:48.329944
e52ac1170d930645298c46abec31aca67c097de3de1d607cc25e1115b1441d89fd0fd9e2781b826839ac8331b3a83e2a42d2eeb19fda3dcdd260c8a6e8aef70f	66	{}	2018-01-14 19:02:44.582387
8d688f6eb5bd41fecaac8b561fe612f94066e1c6db7f0bf2312aa3a3d48c02ebb960cf7d7bc358ab7ca24026924c16ed390daff6f4b2e7cae29d7a2da3597054	48	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2017-12-21 01:14:47.027761
b4f342bfea64c4d1d0789d0bc0651a9a39dde91fada8a9fef0b3b6fc6052a0184ddd028968d091556f4be10d218189067eb25bbf12d44ab4f064c24b5c4d34c7	42	{}	2017-12-21 04:03:36.318691
5b7fcb842fbab8d6f0d941d247d55cb9ea385ff2d77573f71e1be64ae159d7205befd1874b2f187233629f6ddea4cab7b356d010b721da4c692f2dbe6b03e635	25	{}	2017-12-21 14:25:15.555655
cc2173587943187262cced253d64b4c32671febffa8228c27b4635932c38c19c0d0f38e6830e0175e39e961a07627134b7424f218f06b3e741d48ccb44c71a78	54	{}	2017-12-21 14:25:23.264747
f8e9846b76f6d68ceef0e306a76ff9cbfcff379ef4b6f9b2545c2d71cab7e868f4d925c95a4eff2a58831bf189f391098711f46370707b96cc120720ed007c5d	16	{"username": "random5@mail.no", "is_authenticated": "true"}	2017-12-21 04:31:49.128736
7530efe2662e4cf96d81fa1de21983782875db0755a90ae26eec79b3366382b8d13691f52285e428bef3f158407674662b0f50e73622f7d2f99a165117c29b91	12	{}	2017-12-21 07:50:47.142341
f2d0297e76d2b44e1f9c49de82d0f21bb191e08ce62f396c4417766f4e5cebb601334b7183a0dbdc39912c3c465a6db6e0ca34ee3b7db80279f2c59821f9eef1	20	{}	2017-12-21 14:25:29.123973
bab3770440be159b5cc6054192d79630fedaf00b1f3ff5447c425bd25132f61a9bb183292ded42180991ff59c910527cd2868b1da393b0b16952871cd0e23b09	16	{}	2017-12-21 14:25:34.993801
f193200d254a1e6ac9ee7207e6d30beeb055afa2b08513ddca9ad2791e95041a888020444787270786b48742bfe35263c53bf7e1f1d66ab32376812ea57df4c5	41	{}	2017-12-21 14:25:46.238915
f2026a2c61b5a62abdb4ec6081ad9fcef0383620a6df07b00cf91414f3caeb694a5d91698ebb180cb080edfb5581860a3ae548af2ad57fcd5b4e4051ec8982b2	30	{}	2017-12-21 14:25:55.711595
04f48f4ea4c4fffa2207bf1ac1c80670f13eaf075c86b3b25a1d02ac40f5caf7a7a40905a2fb35a393478dd1146881208ce35bc246a36f23c73423371be703b6	18	{}	2017-12-20 14:49:55.684558
073864ff8bc09975d0ef6a9779c5a8b7bedaf83c23806e4f9014f96055f49fa289971995f85081273767befb758061b791780c513fb9a9f9eba0a99a63170fdc	43	{}	2017-12-20 14:50:08.286204
dbb3241d79ed0a56141bdc3c5b0a8b233dff1869726dcef2e16cbf77b6249025949df838bd9fb45d47b6f96ed0853715955b03978cb5ad1077c1a06f327befbc	63	{}	2017-12-30 15:10:23.874969
6e3ba818087c638a365a59fe0cace63f7aae3cbf927b58dfbc62c5d100c33ee103cdae59d564c8497bed725d947bd3649baf63c8b0f191901a1d4f490dac2be8	1	{}	2017-12-21 11:19:11.929116
5fd5a9530d488aab1b537ce6769ee509fdaf1661d0c7cc7934e622fd5a6a072111987bb90114523bddf2a1ab075383e4ac5af567d8f0c0134c4b05ea14bc9f42	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2017-12-22 17:39:00.555911
1218c02d8de15b1d2714259a1e2266ae381eac4b4369267f31f2de976788369bf159b3aa92e37727ab4f8244dd6249498a4f5db34aa5e093902c6946f2265529	18	{}	2017-12-20 17:27:46.417263
7ed37798aca23d78a5025d815592433f505fd64e2f0e9523ae01b8afa1d2516851e0920ec15c7af3edc91615f446e5cb8031adec63d0eb81132c0fab5ecac252	50	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2017-12-20 17:28:18.282427
e202c609cbe5234a27e8321a0eb234f945cec87c2a7e1784db9f0836edd4e9aacc225568014baa63516f4d9fa64e2a4fe78c65d6cb0689e4bb8afbdb0474d768	45	{}	2017-12-20 14:50:49.482693
fcc9050f93e8ed443277b1dd9cff2de8a47c6b1405916a2887ef76be0fbceb6e476c71b5140a62b568ccd0268b7583572b4c7648abcf892b88e818694f969ceb	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-20 17:44:50.800622
ab5b144c3b67d4dd0f678ab9a7bb58268621cbcff27ebac48e3cf65334e79703a4e107a924e9da55b34bb16a79ecc03358e96913f2253dccfb6e0c644de12fb2	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2017-12-20 18:18:30.031907
114ba5121a34d8470a933393687a92323b70647b2058b3bb2570acefbe1185aab387001ecb9b2d19e79e6031aabe3cdfcbd7c6c0eadba990260c9ba27c17a812	16	{"username": "random5@mail.no", "is_authenticated": "true"}	2017-12-20 20:20:52.441641
9534f2198248ec41f14d0947ecaad0e4f4e6dbcfb3b1884ba9e8132607bfdfe1e4fc6bc898be9eab3ab10cd20a4ded893144d31b241266dc2b8483c145b80f17	48	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2017-12-20 15:39:43.434388
1bee0f0c0917c20a6e4fd95005bde710b4f15606bd7bc39586c12c5c85e0a93572287dc76c19ce80935169b6a8a495ed6993679e6dc2f8251a37642cba8bf1dd	48	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2017-12-21 12:40:44.785917
707dab60eb410e6ad3f5a67e434975a7c0bd5abe0d7432d049c11ad2a8b7980d9256c899faaa6830ba4ee2799b002ef6584ee60a587a9ea73c5f86606aee499f	20	{"username": "poe.juhataja@pood.ee", "is_authenticated": "true"}	2017-12-20 21:06:33.318023
11f7983972f2a537564ae18c82e0e5d41d33ddb7e6196bf30621027dae65dc353d66a47803b097b5d805c4b755f63cb2e80b0fa36cce74cd5950bcdf11438544	25	{}	2017-12-21 13:09:26.405213
4ebeaf8a4f6c09b5985023ab0ba9c10094d1c4c65f827b1a1b0e2981172855109d1ee135c9677099017480b4fac83e51287273dd853e488f668c7cb660b76591	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-20 15:46:27.099632
17dca3d2eb228abb0493de7b0c39f1b8896ee0c208e46ea0ec90cbd6d506cb4970d5dc3ef3cbe2e5eeb892cd13a125082bb75490398fe1f61d54b05dd64c4752	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-20 21:41:05.176521
5c9d11f4404ae3efffd6339f0ad6d9d8473866d7cd568e74d9018b5dabff68d6c6dfe208c9d8fb7d881817e739e3538d40bad97574188008d8481bf1ce619d2c	16	{}	2017-12-20 22:11:03.565857
13b11f4d3df11a7f85a2977abd32837b9afd8f8442b7de4c1f1d2af6edd793dc9a01595fcfeb9c3d5bbc77ad818d79ce0201617082b9f3ea06f7a09ecef85fdd	50	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2017-12-20 15:48:59.129973
ad350baf7fc92ec05e2c02331e573c48344c5790b7fd73e07adc01159380204652aa99140c034003a8e3e5a58bd46778061ab68f335e2910d3c3babd9930d056	42	{}	2017-12-20 23:17:26.6302
121df5504b2d6d42f1b5c3615a2229f8399f9e59c761d233e419698ed85a1f0ae7730016e666400b946f7f7221d1265b96bf928879fa633eff169075ac2dc0e3	57	{}	2017-12-20 16:18:33.605001
45e4df029664c62ca71561638ca5c933573696e4f38333922f6dfcb86020c9910920bb6b8fbf4f30a4f4a121474bbe84fb04a2b54b5cb2315d3566f41ce1df67	55	{}	2017-12-20 16:23:53.971888
aaf10993af828d4118404b3563d55894d975263c66f20b36bb047ceaa005f95a41969e957d19fb422cf51d47701b9e0d071f75ad03cb573b42dc2a3149c01f32	12	{}	2017-12-22 16:46:16.993319
14b551deea6f6d7ccae21b37083d8d95e6617d45ee4194feec6de4c74ed1175f0ac974092ccb8ff12d657ab55cdf8cf93c27bb15679e122fbb24c8dce89de94b	42	{}	2018-01-13 20:48:50.798612
fdb5ffd80212f07723f7e1dafbc55b56cbc3d3a783f39d7d5ad06ebee77e15d4595bfec67e0418be3f08f3fc06e06044d2b4b8958a02b5019eb9747907bc97e3	49	{}	2017-12-21 17:42:21.437412
6772bb19d3d1d615554b1f0ffb7f6e882d83ae09b7f0b8deee6196b57c120ffe09c4cae2c3a35f90244846c043b835a8c6f805b142007fa63ebba7b31b2bf241	60	{}	2017-12-26 01:15:08.577248
53c0fea438b918e537ef0f5473263c8fb6823247a9fe9a5e4ed4afe686879c71dac0804a3d802045955d1298da490460c07057fe30e807ff677da58cbf93fe21	61	{}	2017-12-21 22:55:27.965863
69b56fc8c14205bb7bbdafdd0d2558d09aa4ab4159fc835bd7550f30345d3fcaaa00b65c94652bc9aacc05e5e29bc732d832902c1fc7d9fd3127aaae5b573cf4	37	{}	2017-12-22 03:09:34.935449
969db567f4f6cbf07099ca7d5fea338605170f61000f19e2445e6176e9014311eecc34319fce5d6dca1431f2e170fa26fb7afd9464f6858d95f79a2b61026f99	50	{}	2017-12-22 03:09:50.013174
eabd046ef2d026afb06fc1b7c45cf42dcbba2cebc7cb9fceb3e71e7c615922e92eaf2490cf8a1b92bc926130f23449c510cebd48afdfb14eeb36eb1943573b02	55	{}	2017-12-21 13:26:02.08154
f5a710524ec09e48fa9ca071984a289a52ddcb77c47b09b1649730632aa30ef2cc2ef336b5c0cdc17a83ed38286f53e98fd6cd40a6cba2a98f920f66a9ce2b83	29	{}	2017-12-30 20:31:46.679079
25cf227fbbf6283f750ddcb6056fcf3af0f4715260f472c35a82e6098e69abe35a05348d0d9468de58bbac9967f77b906098485c2422d461c4d2a77615d80c9f	45	{}	2018-01-04 13:34:50.254699
16d496707e08984c00b0b053aa8efe3df643bcca506b145327d5ce3a004430791d7590795b3b49697b639e0c3d9d6524957323e89375fdfc64f5a141b111696c	50	{}	2017-12-21 13:56:00.410686
bb034c7addc44e7aeba6130c0b58a7bb9c45043269e659141645ad9499b42509ef4e0ff19bb37509f16d1f3a19ca01083cb7c1cf3bb1e9377b5f8473f9504215	12	{}	2017-12-22 23:37:50.217575
271cf9f409b24544844c9cd3bedb85a6cdfef9434cbd561cf96282ac7fe2b66dd7aea43fe2ab2dd2ae0270b209ad52e3a1b3a97f51cbd4b3248a904fea2ce4a9	28	{}	2017-12-22 23:45:54.986007
b6e81b65de2202d1e13d38747ffc02343d67f18f4bea90fa049acc04d62a587442cc5ba3f4a0fc63579d86c1e3e5d25139564f615fe432603db3e971614fcb91	45	{}	2018-01-04 13:56:12.101512
6232d65a2c8b294dd0b00dd9a7868b423c1834c6f123ed8ebf17675965f59c620b350e16fb1b078d10d6fde9c8c7a46487117b3b4bfe7790a5e95fb7349449f9	53	{}	2017-12-22 23:51:51.751546
863a2dec0ccf30d86b4799c9e8770675c4b298b0ac90e0870f9ece6c5c5e15254c42f67715ad33bf39bacd0de4e096364ce41787673230e68885c6045c66bbdd	59	{}	2017-12-22 23:55:29.978897
4dbe9644faa91c11b1d962d8e29aa07107a4d961b64e20cc94a21787737763c13359e5116f0dd7ab060ece11ec66e5216816463cd59e0fc6034784b0aa02b157	50	{}	2017-12-23 01:31:02.772874
d456501739237c50ab25c246142ac3b434710c40e3678a3279d2d33dad7ae47987e463a7673db657d1006ef95c634db372960cb2e817d93cdeae1b5e376a8038	1	{}	2017-12-23 04:03:26.786566
5cb3903561b81150b380a69248ad1f16c6d4e71e36d0345ff3fa7ac9b611702798bd36e46c57332646c1546048c99a33f0cdfc0e9c577e8154aa7ff3a07d19a1	1	{}	2017-12-23 22:30:01.169415
3b59a75f4b72d6b29763163f65f4fa047086c19b176e8a11cd6a0be63ce4f3ef1487f9f03f4c94499ec400445f1678d5ac35b3c31ffa0f840097b132ab05834e	53	{}	2017-12-24 14:25:23.017144
2d7454465f8c1a898934747896cef28f1804d506cb71caa4148fcbdd3ce4456ee809547b085c6c1e5fb6bf08eec8e1663b209c57b3d0d49b0cfd244f64e0d42f	37	{}	2017-12-21 14:25:26.538729
d8c2c44fc16e75a9d05fda0f36920c9ddaa1fe52267847705925f4b47c6fd29fdc068db7f0c6d95499fd9d4f56b760b16b77c5de545c2036851c00adc8de2c7c	27	{}	2017-12-21 14:25:31.585535
4ec6f2bd905883d68cf3203994036e8caf6db3e4a4cba8e535327cd4c010943c87b44ef752f578e72d671b0bf68dbb81a1a12cde60e7409e4591580dfd0fd308	48	{}	2017-12-21 14:25:37.87637
1f2e9a7200fb6c11fe25d1d0fdb95e7fa310e190cae4060dcd0ed3e3a667512c5f963a0dc8637038253646ae446f3ff92a77c5780eac83dc617c0bcd6d11a229	46	{}	2017-12-21 14:25:48.637461
c13d38241cc364f2c2e695fac3e979673f44d04f5c676e46e525b967e9a83b2f5981fa953a47ac145b82a2070e8b20d4f9faedb341966ee0bb41839852f5a023	18	{}	2017-12-21 14:25:53.000808
b475572fabb54e650d1a088c5814ffe0109ef90314016f8c422d2dbe1070b8d8583fd270f0c39d4165465e4cb36737415a58f7f470730df41cc272cb2541c248	62	{}	2017-12-24 18:08:44.263979
089584c8da014b8d8842b759b03681e7246e2c6a5b1806e3931a328d2401c79d6f76e97ff479395594c46e35d01d3791dfffce57e1b2ddb0ffc4304b8e6a7014	43	{}	2017-12-21 14:25:57.773014
dc1e310c167dfd28c2999a5e87746c328cab7a9970b6903f8b8bbd81994e54c32f136311e17497f7e0530b62217f9321691f8d9c4e629d7e1052722ff0dfbd9e	1	{}	2017-12-24 18:23:04.853945
812ccf53669a19f2cb30198cdafcde7d45f65ba30a18699e3cf088b205611bea1af4f9b48bda7bf60f30e07bfcc5bf9b7a5dce14f51ee0cc78ccb207964f3b03	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-24 18:45:23.55306
9539ffd5dcc5178a5dbe2faa6db8416d24aa8f062f3d6c76d21800d9b56e012bde9b2a9b728db463ebc015d160486ab7e2d7414a46eb8ce26c5e53f48010839b	62	{"username": "test@ttu.ee", "is_authenticated": "true"}	2017-12-24 18:52:52.533911
a36ae30420f6d76759f28c86895fca0a58c0d2422be7713ac93e4858d74e5b9dea9735d89025199fab51ebc8650546f81d7b68e53884eecb1d01d07d0f26fd5c	16	{"username": "random5@mail.no", "is_authenticated": "true"}	2017-12-25 04:46:32.327985
f46b4b98e06566d3bb2b893a6020b0e455b6f642f1176fd251f2cda7a16560bed4c87d190cea485928d7d76cabc67e17375876a97e2e1d141fc5968a45dc8fd5	42	{}	2017-12-25 05:21:29.099207
922ff8b7f7506877a0eab51214f1acadd6621a46dc5c877bb3f3a86ee294f135cae55a3bb7f0f639059963a6b5cc29b7ba90bce802540508d9559eeb6adb4bd9	1	{}	2017-12-25 11:21:53.751457
2f72b40af99e94327f1f8f86484be4e47001f424e652d8b3ac56752a4668c6d44363a0fed36f5609d56786c0027b4665258619de8a7b986ef3621f623cbcab62	59	{}	2017-12-21 16:33:10.646314
4c5fbff6da4ef9d17d51f8a0282abeccf0739089912b6b30a73d38a0fb9d5b45bb16a4c5f283d6cb68fd61d85c3c40f143899eb6fab97d50af98b64bcd76bc3a	59	{}	2017-12-21 16:55:51.378941
237cd6122c7cd48ac6c9b5619f34feb75f1a93c6adeba3f86d6d1111c61fcc6388914a40a4d5a1efbcfe010b0aa9deae4599a1360fba2755d22dcf3fbe9cb771	59	{}	2017-12-21 16:55:52.240017
846c32c512cf6dfcc596f79e8da257e5e522ee3a809741667f33568678e2c6c04582f5afae702256ff686d59c2730feaaea0b85dde1bc30a12b1a01200e51c68	1	{}	2017-12-26 00:48:26.676864
1c214fb1079c3bbfffd1c277f1b4600172542e2a13960ab0710cd61175dea566ce48035533ff897b0068dd7ec6c9798990e3f4f394e617ebdbf12fc3efd19597	61	{}	2017-12-26 01:04:40.364186
1f57f26451cf2c76f70c6f9e49af96690a3698e861088f05986c3ccaa655f9b78e3163d3110fa26a0e06c71dfedfb74841e4b3b060dff7534bbf04ae68759e0b	46	{}	2017-12-22 16:46:46.557785
6b0acef23f7c380a9ff51428f1d6817cf65285a4d9b46868be4337842f49aedb11a3bf16f98f5bbed5637a5e2509ee01ae2b6856e8a0ccf873dbe0eef11dabfb	48	{}	2017-12-21 22:50:56.075674
19902a2ec2b0a32a91e2ce347960b81c40fdcdcb7b669da612d83bf29b7d7623a71a495e8ceaa24ab51fc397969602f5d342a9f25fe487df95c6a0eaf23af703	60	{}	2017-12-26 01:15:08.825869
a3f71a1e256fbf31bf1f058d3c60f6d9a7d71dcfb69b7da8d77a9dd202145f486eeb0b94d2bf826f5663718fcb1963aeb424738e0ddfd87c0a1955ca9dc59766	54	{}	2017-12-21 23:24:14.751297
ef9e145a4df1abc3aad782ab83af496c74d9a07594e226ded9b8d0398b3b5469664532c28aac6b10dc05b9b25a4917a1fc919b47b7e00d604883527b1cadc4c4	63	{}	2017-12-26 01:41:19.076623
5bbfe11347ef1b5f3cb862c85e2ff91e7131476463af3522cda553780dfb14b4ade331b377008c739956c8b4e5f7c0d0cd5ebdc82c64bdb483682b00d5dca726	60	{"username": "martin.m@gmail.com", "is_authenticated": "true"}	2017-12-22 12:19:17.368259
8da8cf891a60723ea8aa2cc574a3ca197804a34933ab97091a327ad5f4ac2a24f3581347a5a53983ecf1317aaf52b096b77bb0ae35bfe62dae8e4448debdd247	28	{}	2017-12-30 18:18:16.858929
6076850a45ded6dcfb69394fc71f053a01bcc84481df76f54ab38884ac3e6c7d0694e1939989e9e3bed4284a386a300105f69e42f7022b3110315f1ec47d9ef4	1	{}	2017-12-22 02:46:54.218835
cfc81a35a9c4a8b2c857dcd9847fd8d78b6e6bc4e79ed99b8e061e0445f0148d287b975254d83fe916d38024f4479b63fac980231d122d75e6b27e8b62bf1b0b	59	{"username": "flynn.combs@neteria.io", "is_authenticated": "true"}	2017-12-22 23:56:34.745832
4566f2d71114d86cd89ea6f9e3b5635b2306dd331338404a2ec6bbfa7edb0a18c492fb5e80c9b32e7c43d658c7418a489b3208cb7e46bddbca502b931de70dc4	23	{}	2018-01-14 15:06:17.125818
b6b72ea81137a5fb317bdfe1dac879b7366c3f21a18a4da27ccc2c8f4c0bce1006560cd4bf180a7b573197e1f4c1cb1aa9594426066018ab9bf89537e5d4c7e4	29	{}	2018-01-14 15:06:26.415092
340c683bc7829d44f549ed8089f6df69a3af8c8d01659152d402dc8fc414b0743d2cc70918700b2aa09daefd0fcf9f4d763af52769302e04ea7411973f42cc1c	45	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2017-12-23 01:05:43.2231
79f04ea8b0f623af11b751b5ec0be639c5df991427a492b695a029c408cae1972c847e62848d024813265a7d3f3720872d03442ee88d776b7e2c14cc83f2d8ad	62	{"username": "test@ttu.ee", "is_authenticated": "true"}	2017-12-24 18:08:57.549247
9048c0b1f42e5033f5d68368b0ac7955709fcdac880c7002944bbdffb19382a3ced850372aa8212103133fe48c3b99f64acadca5367a88dc1bc4784cf826175f	54	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2017-12-22 12:16:48.805239
b3f9e16b55d49ec161a2d8a4fea01cdc63696ce61462652bc1526979e47cb19de7ffeeeef623dae4b5c76ca18105266fca6d473b5723993dc79d2ecba465227f	46	{}	2017-12-22 03:09:15.674559
274615c570bebf3b8edcc601d3b9bd15ac62a06f7bf12cb8556c7d5f96f1f3f18154e3c7899f26b5ceab47b970bbb17c3a282584afedc13e2ea778288007b66d	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-21 19:14:49.033439
5a1969127c6667e210dee403acfdff5d2dc447f6d406df49b34cbca86b57ad5d24411f9bc9723b63193189a8137080442f4c2dbb87b9ace300d72ae4fbcb5b79	48	{}	2017-12-22 03:09:23.412891
18c795ad616442e7566e57dc6d71bc3f36810b240790a649f447959162415d5fd26b0485a52f4530f722b3f18da2777b953ccd80ed210ee417e10aa1048f3a2c	62	{}	2017-12-25 22:14:03.249593
59560e14edf70fdb0bbc87d73bd75e8bdcbea5fb9c83c33e7e3cc6843be51ebd9961bcf19926d604c64c2c210e03d4b49ce69c4fb7b0cea27c5a5b2163784108	20	{}	2017-12-22 03:09:31.967074
5c8d0d1d43f917ae1612ab08e39a644e1c7051904511239abe5017358e8d3dd754bcb59a8307e33a55842a608217e7ab38fecde97e7a2d35e86ff89eab554a38	1	{}	2017-12-26 01:05:11.645472
670dc75a75d7893ec84d755e05d4ef279d622788b7c752495029498966dcd3b7f4e769ffc8700f8b04c838649d85b4b76d927d8ff940f53aeafb1b8990da7f8a	25	{}	2017-12-22 03:09:36.933047
7bec7d7452dec4e669c9b51ceaec7507732d0ab3d721693359cfc16a18f275b295cecd9094a3aa1c57ef4be5cd31783a3444ba8b646e3d6c0a252dc3e0c1b3f3	36	{}	2017-12-22 03:09:52.591385
d6b2ba321c84f6f48495418bb5f13ae8d6db43c72c911f8ac09eff8da3b1df622fa662530233b0158d59709c13409a0fd433ec22861e51c0a4209286077aa426	59	{}	2017-12-22 04:58:49.989111
c318505eecb96432dc98bc267938e411a0ae44873f14b7ff9f0c264e159aa05b9fea12f8152f3bcd34d041b33e1ab7f4d9755582da954a9f3271224c02955094	54	{}	2017-12-22 03:14:16.592492
261a00354dc45fbc33b8fc2359dee6f2defa9bc2ea9a8bb3661f94a8437b334cda7f85b677105086713d1a5df3cded00454ca7a3cbe3cbc807665bdb51b2d79e	1	{}	2017-12-22 03:35:21.543785
d51543bea19d4fa18d39f573abb34185cf4c29c727c612d280a20aa94a0a7c5e9436e1bff0d25118c3924ee84da9f2cc1a49803e9876949fb77713679397c6db	48	{}	2017-12-28 04:18:02.303792
579be468c378764be50bcf290c04b8a679da3ba63adb53b26c7080a7cc910bd81f2270641982eacc6b97f56ac82100174947884b6d3139e360e3799cb6c0efff	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-22 05:02:35.372881
5f72540c8cd8dff81db27dba2be5f6a1bcfb57ec294f6b0fc49c6ac280c8c7607365c231267bb9577b521df0235570ad19d5820714a10c097ee9754cd8e27690	16	{}	2017-12-28 04:29:04.78058
096de751138d3677e98b80c8bc18acf8878681940ecb144d425cf398e309895b893841bab43e92dd8fe21186a8c5d34120000bb625b671c2809045acaea9f56f	46	{}	2017-12-28 04:34:00.509803
6bd61136bfb4d644888d1fbc7b5ad3d5e440d1c751815ab77011d38296eeef5ea1ba2b283c2ef637111a2a8171a980cb189e00fc610185187812400385c2df24	50	{}	2017-12-22 13:34:43.479896
8f54253d4cbea44f443e60e26e0b7fb703a41e1c626ab74bf9256b2d048831211c8ceca5016aec27787dbf16b7b19c681a28d279c734d9160a2853e01438520c	12	{}	2017-12-28 04:52:02.396285
c271fdeb2b44b4ab172c2c09dc1e4a508219f00cd68b68b574fbdf061a134b294cbb142dc740afdb87d8f9254f5ce5c2135175b599c9f7f69fc6627c09bb4d49	48	{"username": "est@ttu.ee", "is_authenticated": "true"}	2017-12-22 13:42:48.506675
02b0e8e3662af5176235a96d90d582980b763b8b4cc70053250d2c3dcb9c3a526bc1f145607a9056c7b2c0cf772e025db2cdfee5b0fabef42da0074eb2fdaba6	47	{}	2017-12-22 13:53:56.667261
8c920c8f645e78629fa1ba25ee2c0f64d17df20cd2fa61bdb9260eaff216d03291694fc61260f7ea47e5077b61a43a061fdc7371e0eee6455925cc6bc9bbceda	1	{}	2017-12-22 13:54:06.595469
39668775debf39966d0124f5e2a20ca72fc87bc17352c9d024ac31119bc9ec8d33bafd1e9471de80204c9a4a18d37271f4e07b701f43c0e25e87023f95d09fcf	50	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2017-12-22 14:02:58.254107
47e130fce43a37bc9cb40f699ce57f22f23d2e66135cf5e7db37b0562c353c55bb3883c51816aa3b9e2ffd7113d983576104aa2e340a5ec5d11c0dd7f2e6af66	60	{"username": "martin.m@gmail.com", "is_authenticated": "true"}	2017-12-22 14:00:55.56164
346ddc3c63c8b499708bb4438fcb6c9319f34d4769a734ca923d8b5ba8ca4e6328ae27f5748152dcd3608bbace9c175b8480c8f0203cd7e33cd354b8b082d8ac	45	{}	2017-12-22 14:33:59.60188
8530eec49f9c915ee277db677f6ef2822c111a2df0283d262a7ec03fd31156b605486bd01531417154ee72a62c821b67a43c397034e1a6b6a089960541b32505	60	{"username": "martin.m@gmail.com", "is_authenticated": "true"}	2017-12-22 14:48:10.605459
1b81462eaa1bf79cba4872924a82e4c6a92bc447334c78123a0935e7f46699440735ea8ceffef3bb52b642d043459d434b10f6938225c2d1d4b8f20f9492c436	41	{}	2017-12-22 03:09:20.865221
ca8c5aa2d7eaec8641acda1639fa151f755eee2edb70867e4b5b8cff03b82cc0d3c71f26604805085410f6746f27af56bdb1052d173e4fddb804dc55eed8a25a	64	{}	2017-12-28 04:55:34.493271
88684415bfbc9e66b88a02bc4c265b522362c621c87237bfed1dce682207f2fce99f14177a7ec9021deed8487b8f7e7575407ccbc4bd197d263464b15d6f25b3	55	{}	2017-12-22 03:09:39.381211
c826adb76a57e7e147c9626eedbc50f1ee0cfa95d1eeb784baaf15c4336eb3ad24214a7e318afab502cc75ea8ed2c9ef63058d4683df0e9845659bef1923b577	1	{}	2018-01-18 19:55:57.771869
7756f8e5bf12c4f6db5d1fc00c603648aa985ff3e65bfb0cf1680e0fe13818e952659d487fe6ab3dda952a1996f7e42e1bc4d50b6888373f147e46dea975bae5	12	{}	2017-12-26 02:02:46.63962
e5b2a0b8257301efb79bc5956f4bfc862785cb50e96cd6587d71bdb77b88d97211c8feea244112fda26afc1eb955bfc17f4a542a6d36f71a7183931c33a2ce83	49	{}	2017-12-22 13:54:11.51579
69e5b6aebe0aefdcfbd4450f8831d7c17053ec760b615463a76e0d518e9183f6451100f0909c3b7a1576ae87c6f1ee6dd1f7b3a5e87bdbe9a288f17979d261b2	55	{}	2018-01-15 18:41:15.583458
5521269eed9c29af686acf7843f46c42233392a2e7864adb014b6ce1998e23d40538c817cd75b2ba434ce3fca7e2bd28d356421804a3d770803b5632794d5c56	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2017-12-30 18:58:25.14914
db62a7826cb9c431f233b0145dcc4b9b67257e5af8e0f2f8c49a39e45dc35e28df42ac0636abbc1127d80299f2838428f3448ae9509ea8eb2e63f2b9efb41563	45	{}	2018-01-04 13:34:51.929384
99918f6246c0c2027c02aaa56c5ac64b8b6a8b77b4f55464b32f28cbbae94cfa27ce69deccac2affe144c1bcc0f56ced848f3c5e8a1a62abf908c4adcccd2fd9	45	{}	2018-01-04 13:56:17.164367
89008106e1829dbdebe27257e27e281d1ab17114bb834c68d92392945fc2b2edf86d84e340fc9fedcf733417a727075fc6b35f83f551a804f443981bb3190305	64	{}	2018-01-15 20:31:35.134673
f4140acd98e1133b82eae7c3a77676857bb935e8ac54d2cba925e0fcd62b041b64ed23adf15e2076284f42ed0793ce31b9afacad7161ff64e073795b571665f2	62	{}	2018-01-15 23:33:00.60094
8f5ee5b3780c578687bcd40cef87e825165d7c3d0c0cd46d649bf7878fddd01e99857c27c1c50846ade16694f8475148619b6c2ad133382976d97cc2d041068d	1	{}	2018-09-07 20:21:18.673191
e95a3ba7e35401a3f03dede613305876fe32f25061980af2c07eeac6411338e00493acb06dc144358c094324288d265ace71c30626c373f69ced40b340032962	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2017-12-22 17:32:21.102948
1961042ddfff83850dcde22577619e62019fc0a849a5e95203c9d83aec98b5fe77a3727f00fb0d2e02852d7e0d74014bf1cb7285396ff60eebe4e6ca96c15d1d	64	{"username": "mapota@ttu.ee", "is_authenticated": "true"}	2018-01-14 20:42:23.0768
dd7e7a7ccf699448b0196467a1398517dd6b7f0d82fe934526d9cf5ead8857c055559330e37ebf6ca08d7fea68383e95d32a8dd5836adfda67b7295ed152d773	55	{}	2017-12-22 18:01:57.178924
e1d05622eb8f300a4201cf2712ff6b5e674c8f7aaf23fed51f40054f47e9ec9a7426b9ce4ee055e6b146fe9494a70103eb026e9688d09a7199d839ca15bc4888	37	{}	2018-01-14 15:04:54.50696
08292a5c80b27bab7fc690496c22812e8e9276116aef11ac04b7178c516ef1e08967aa3bf3e93856825f36dce02013d52bd76aa16e641cb05ed176e767d16827	36	{}	2018-01-14 15:06:09.109173
94781ab7d261d40729a464b588d36ccc064ce8015a526d175f01efc8b5d8b933478b08b063b6df1c4af5fe4f653a88424aa481394796d47d1698eaeaa461a9c5	44	{}	2018-01-14 15:06:21.315348
a2b56cc8993380f774b30a53c4908495ae28fd51efb8d71630267d3bb60baec3d836e83cdff8f0efade2d94fdd27e857304054d8389d63bd6245e73bacddbf89	28	{}	2018-01-14 15:06:28.102936
c2e8ddbaf196b05166c4ed3c852aa8a98623b45c19f0d6e39faabb43b4e2fab96dcb9169d5ff0203b0776818268a92fdad34e05794adf7879d73f0b86d8149bf	60	{}	2018-01-14 15:06:32.248535
78b4dd4d4abfb522f4f799b84429ec306cf00498c85b501729e74d232022447c3668b6e7d838bc6b6397f80e820e19606f8d475466d947a22d2d6362bb4f2f41	61	{}	2017-12-22 18:48:48.461883
605e825c0f5f614643954537ddf1f5fe8a311aa651f550f88b7012d4e58beb02693d0da375210ce150c915550b9f7ba94f1f64d0071cdd8ad3a7ff8d2cbc4058	53	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2017-12-22 19:41:23.046583
a71a55a9687f7d03ff99adb0ff1d8b559ae577b5e985af5e6178e8691c7d7a44081995e8ddb835e089b4c607663308cb7e0d94bdfb5f420e2ebb2e8e6074ace2	50	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2017-12-22 20:04:21.646477
fb98b8819f095a090fac98c8f70835d5eb57e2505fbdb9451a3bdc386116e9b7012934543c086716b5a5334ae3097ee60b91c5e12e40c7be077b215060a475ea	55	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2017-12-22 20:42:07.882037
cd7bf7fe0512e7cb6dd2509b1e73a44a39fb4df1fb01f2aa43d1156380c8e7e05d2115f416f9a437d24235ea9d404ee34d51ae793e8f5eb39a014209f1a0768f	50	{"username": "wArd.riCHard@comvoy.co.uk", "is_authenticated": "true"}	2017-12-22 20:21:46.012877
2f87109c48c4517df7ccda6114d4c9ee279d5efbcc488aa7e12169f50bb18f5c7d3fe9191aa7ebebf6680da8d2ffffd0c7b5909c37c536d994dc05b9232a28e7	60	{"username": "martin.m@gmail.com", "is_authenticated": "true"}	2017-12-22 21:08:27.439734
af09fad133a8b5a24c648fc0f2463829a7af380d2c71855c725ed1366b9d4c39703f89d24f3e4eb12db484f8191d4e804bdc27f95fee567cc33ae3e045b777b0	45	{}	2017-12-22 21:23:01.129627
02b53d1c483bd21436acf0606907971746e11f32bc1044cb4de55f92805b0bd00d7113d80f4f81e2e12ec93edf4cb3ae4af91cab12a26fcb54ff822c8e35f12c	55	{}	2017-12-22 21:29:32.710584
e90d990d343808961f32886fef5496694b7ae90ffd1887988084788d8c7e9e5b31dcb9edd9d9aefd39b523ac1e74e193ddf4cc7f6056735bc6f541a086832563	46	{}	2018-01-15 00:37:37.821679
5bc45a555e45d352753ae93851737b9a8f63ffbcc2eee7b85dd043d0c7f7692018fd14c5a03063db1b4edcdc3afa0b5e2bb1e71c3adea688b896d1e39557ec29	64	{}	2018-01-15 00:41:23.926938
1a6f7ea37ac5627285cbbc1373c86af46a1b991405e0abe8629a3be8cae172f767e6fa0d05ed76befcf9a626260184e2ad2a525912893f898d081daa366fd63f	28	{}	2017-12-22 22:56:38.47179
94a220a30b808b45ac9f84dfdbe57b4e916c6b06d3d099057099a4bc8398fa35aee33385ea0e216151ce31752f2003c858401742d608c8099d21528c30db138e	12	{}	2018-01-14 17:10:21.666488
b7a3dacfc1ad25fbcaaec5a5d8c64c310a73c436f1ba5d866363fd80368b25dce715cdfa243fd1adce8fac004127e3485bc55b09c0c20eb6a5670c027543b65e	42	{}	2018-01-15 15:45:01.759963
d7d539f03eeed7d8388e6a8063c44f051004d7c1c3b46576cadbc86210391cc85edff9589ff58cdd0bbcbf79bc559c55afdfc844c26c5d3ed648444b815b5591	67	{}	2018-01-15 15:49:23.368447
b61797a72a1ce3332be690349fb5ae813d84f528b94230bbdaa7ee6ee1ad6f90f711a3e7f1ee90336625884337be9e53af15ec67eef77e8455f09845aba1970c	51	{}	2017-12-22 13:54:14.917246
ec3c82c9eb25d7496cc347b0b6d20325f415a4d498028635d7037498778fc31576b7130969747dc381fa8ff78012e6148fe11ae67125517a8fd74133c327a236	16	{}	2017-12-22 03:09:25.755972
f726996962b6ad783fadc0dc7062abfc2201def880b045625725a215ea0fcce285924b44bf0608e526a625d1cca67e38d15d0d3c947dcbfe88906be43559cdb9	23	{}	2017-12-22 03:09:44.734151
a88f559b276a9478d8a0b405598f652a2358e7970d176ddce46668d0684e74c96863bbecbfe56a6ae792e19688320d4f04873f5599d7cce82d87e5f3f434147c	49	{}	2017-12-22 17:32:23.71693
fefa426d30dffa3d84c6d8b7305507c8a833b53a920ed7986dfa6c671d64275443dc6bec2efbd6dad12d41da5ca63c6946ee657a2cd08b8ad1c7afa3061b2ab6	1	{}	2017-12-28 10:57:08.041025
f8c882feb1b0873462fb14186ee292ed5a1992de47d902c5258487ee5b19ad4438a8d83cc3933406823303be84fc217bf40e914a701cd1f916d20b494db63274	66	{}	2018-01-14 17:10:45.195276
632f63858e3d56831f4b21713373477651759953644e859a96c01c8f351293114ad11166bfee32ea0afc5d2bf91825ed8e492c26dd3adb93ef82c39ca26e5fdd	50	{}	2017-12-21 20:11:31.977657
ad955347a0399566eee324fe1766733a812427a7cd79ebfc7fb43a310cbdb14a31a8414b0a7fddc9c3a3473105e8b9970c035fb0ac56bb0ac1ea1cb08c333d89	60	{}	2017-12-26 02:36:40.890311
398e02c1a0e5e54861f02df54fd8b03d7808b439edde2f6a375574ca612eeca052e50f5e940bc6b1fae0951334d3df926bb27bbb0901c25774890fa990fe1be1	48	{}	2017-12-22 15:19:09.330822
949377a7ddffbb79261f404bd7bfb12a9a6e881ec9e8ca9ee6eb0921407c44a000a95080021a408539280fb17b4d6911647d596dea5db335e6d2720c8574485c	55	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2017-12-30 17:19:43.355412
accc4c727487b25b4ea8884c543f816ee229fc154ad355381fcfe0fe67bd007322dd4db62d688e368e92672cc0b9b93e9115412b6946bbac253b99a18400019b	59	{}	2017-12-22 23:03:45.119254
f334fb0e7bed775f9157627790db38c77bad3ef0e56d4acdc047cad7309cf27115feee1fe3c312ad416296dc959d01f8f6ef4e6316d41c01c89a3231ced0971f	12	{}	2017-12-28 12:52:06.421769
933dd59187e3c4cdfb2c3754357d3d0389d14382bf877938edd37d6d7a1117831294ac1d2f66f5710ed15bfed177b491de230db4e7b4c8969b3f6b86dca1eb48	45	{}	2018-01-04 13:35:01.884319
a3fc067331eeca45c485cee3c51b3b22e959bbe69d55a5b14b2fa20e1530b2f3b41ba0618fa05861b12efe75e97bab2a98a7a79b40ede6e593e39f20c0c280a0	1	{}	2018-01-08 23:43:27.368859
5c329dfee190e78235041ed21edd33cfde0f7516163cea587b05f747f5324c06449acccc32638b792697766a3e112d9a82e40451e8d3a34122c03d8bf985b3ad	47	{}	2017-12-22 15:43:08.195456
ed4abe43c2d115cdb1d6bc7e8ecce5ec4cc46a0e5ef9c2e7f046d2726257282d41bf784744f5e1793a2259e9127dc51775175b7f0927f98c80e2124a31c9b2f2	16	{}	2017-12-26 04:07:32.982454
17b3ae50c76917a1a29367cea98e47642fee0779e06642f018e326577dba6b3db82930dfdd2253710c129b69af11db86761bad32fa38bd1331b894ff8cf90a90	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-28 13:39:32.995802
90da6af19fdd6d6937ed594053c9245a5bba54c41ab5af69e712621c5d8af435d25af12eeb3ba394ec9406d4d0ec2c1f1bf9964ab1d0714c46e69cf3be1c2af7	59	{}	2017-12-22 16:31:43.611102
b63264308950aa5af1f54ed06498016dc4b14f2315e9813080d7cfbae9a3d21375f591be00b377f4addd093f446f455bf456ca63d550ddaeb93c526978e44d50	59	{}	2017-12-22 16:35:22.188465
700269cdef2cfad3d88e8810fdfffa7d3721179687787cc477f519505a5fa2ed778dbda26219419ca9824adafd87b2d151ef025b0cd3033d05eccd88c0a97d2c	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-28 13:40:14.437249
c7fbb584e6cf98d32234dfe4874ba8a4eed8870d309c8abc7935b7096f690935f1b7c155992ad3303aed8d85c8fe67f252c980ac1fba00f36a434e91e693c368	62	{}	2017-12-28 17:25:25.464355
1ce0d22ebe82657ccb8fb95dc9b6a96aa4fe90a2cb305630d803dd40d5d536ba43d1223736ac817c2f5e59a233903254074541ba1a4df695a33a38393ae51ad4	62	{}	2017-12-28 17:26:35.208663
0322c60064a20d080688f2bb6fed57efa8af362456eb27fdf5e185fdb9689ea0844d814c38a5e82df2e23c9fd948616f253fcaa278fc41a5649d508ccc606ab8	42	{"username": "test1@gmail.com", "is_authenticated": "true"}	2017-12-26 04:50:30.630271
0c9d11ddbaed717526fdde7cb995f2b183d8c0b5074fa3c4db93ba17d2ae14141f5cd57ff3c5b1cb9f80a0013a3e1f0000e944c13be92a455a010688417fb356	48	{}	2017-12-26 04:52:52.317972
12f0a4c776e6c57ff661fe6c4f0c0df2811f4ffd613d0d1b7ef19cc08b976e0051703f591d7a2bc83e35eca9bd69d5384de9e5f7af87b71a9d96b0802a3292fc	1	{}	2017-12-26 12:59:25.239001
1c2594de3d05e6f953815d889c63bd67002236a9e7824e2a33a417bf41bdb3e8e08da618e49b598c97069187eaa318a98764936ec6e39cdf87a21412f2d84edb	12	{}	2017-12-26 13:13:27.525728
1a4d5c62fc26888f82bbba0a874cf395ce24c88f8b88bf91612d1b82f51fb8a596c58a9e5042c8ddcf5d636c5de85d72f68ee955fd17717cdb3c3a39a703f50d	1	{}	2017-12-28 19:18:04.834478
3061e2d5a280c3e984f4091d9e4faca7f87c61fc53a49c96f255e59fa727ad27b029b36e7f6f09e2eaddc5f85d185ce1f9e3e9b4033c4e89adf8258595a6c08d	48	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2017-12-28 20:22:10.862061
c37b288bfca723baaf769325fc5f4d0020ca091256bb588c336eb61d55a0096f1c73b31011be7cea706e49d9895dc4dd25e6fe42d99fdde95b1732f3985ca09c	45	{}	2018-01-14 15:06:11.850335
804ce2a44a62251ae30be8f99e71d5c5537aa9945b57de018f3cee9ddf194d6ed24383b127752066127406fd514911b726808301751cf7adfc898a85db9da997	62	{"username": "test@ttu.ee", "is_authenticated": "true"}	2017-12-26 15:12:33.528563
cdf1fc70b44fed495b5aa2a056373b1ff79d4804025fbb6bfd326686a0a8ab135687cff6c27ba0beeca4cd7773c4f242d1985ac14de31d03fc46e02fb6919765	12	{}	2017-12-26 15:17:52.437423
6b85627c2fca2aa120f60f8599b4e64fb4a5a521fb10e1c5b69356e04e65a0d3abb2c4b6228996d400e9e32710dc7dd8c590bf6f9c16445fb09d6ff26dbf7dd5	54	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2017-12-26 18:51:22.513155
d95331e9a6dfc97270ff04c553696b02e75c1d59d08915220cbe05f4a34d47915b60f26d426393b8fa95d521d631838099f9b51335c06019416acaac33687fbb	64	{}	2017-12-27 17:19:16.902567
df07e0c621f689fe3ce31eb6a724ab3367f00df3eb9cb5454e0fbf39ea1442da42321b7f2518dc0634b53d6936485acb784181adcb9858258fa6e67bd11e4419	1	{}	2017-12-27 22:26:44.925108
d4d5000829c9d6501587e531c403d570bc74228258a02b51388f8fbd90b769ede35d4831b77133e3f9b71e2280bbfce85d31b97542d44695eb2870a53836f0c4	42	{"username": "juhataja@gmail.com", "is_authenticated": "true"}	2017-12-29 01:35:12.936467
868732314f2b33d6a115e79a12006cb71aff3b1ff4f456c25109af8c859337aaf9a6c867cde6ca49b18e8c872e47d7b850f3030328a1b6657f0f798498abf47a	25	{}	2017-12-29 02:37:25.086095
3910cedab0f96dc12adde61cc2b36fa6799b4f3e829c1aa499885a41f6955a64aab17a12fd2b5e58414fc1da0961e43c9fb08ef4e3575c2a79de1234d77a5343	45	{}	2017-12-29 12:28:27.748812
096b41bbed4032e9e263a73886389b9493199db6918426b90058319073fcefb9b653bb549841c65a9157588aedbe0d06b3f354301637e273e2cd4ed2b6e231ee	62	{}	2017-12-28 17:25:25.854358
212afa8380eec6c855382a8e4273d05da61e853105e39d28042537e09d02c35c3f0b61d47ad6e15f1977a4e1635dcf54b9c1379353c75afc4efd2e3b29ef3f80	16	{}	2018-01-14 17:11:16.803001
9a8658b9ca6526008c3527b530621a12c15eb04ec181f3136d875e6510f6ffcc1c6ca6319578951cfcf3b9232aa0c6eb3b635b72cdeaefcf17cdc292fb53c665	57	{}	2018-01-22 17:17:33.714939
f18da3d3f50220211da8413f0dfed8177fbbf20755c49f6422386f15eef95d99b94af5d6984680b064e6876b0f4acc1b739365d3e2b0d17546f82da4869f57c6	45	{}	2018-01-22 17:17:43.612836
0eba9b7107b95ec8c210fc8364f367efb57ec24e3ebdb021e78aa3b7ce65f4c9cd20d1626b35680ca8eeee45c4a20ec692470c531f4ee89039734219291ac9ac	64	{"username": "cole.nichols@ezent.biz", "is_authenticated": "true"}	2018-01-18 19:23:43.951717
24503e91175266bb4fb6186b379f1ad99c1d559b8d09a6113d0223beb44a796a85418b037c313be92a4a738b87b97ab796d7547a669fea768c694b5e62562173	1	{}	2018-01-02 17:54:56.453831
fbdd27ff1266a625975431a1d5f5b2fe6fae91abc75689c70994dd8d0e5278e2720d8c6ebab503518970c6263ebaddc2a0a7775918d06d5eb89b427362aa2221	64	{"username": "cole.nichols@ezent.biz", "is_authenticated": "true"}	2017-12-30 20:03:57.824611
0c17dba447fb6f9b6309d485233e6c09ce13e103f67cbf1a86f043abe0abbee76fb0821bf0f9a48de1e018887dc59d2e1a72c769010c0ff008d25d75096d069d	12	{}	2018-01-10 08:46:27.955807
b0aad9d40d98013e3020cc1748f31d64f08557fff1e20edff45bf0114809576b08f2cf2f74b99dec61e4e2692fe637f4c979be8339ae0f04fe3b7f02c2675de8	37	{}	2017-12-21 20:42:23.029762
f4c85940c0ef11f26b7924dc4dcfcf6dc3354d5136107c968e223294c5ed7ec24d127292a9da536ea142107bb0a2f12b54da46cd29874df61549dae36895945d	60	{}	2017-12-26 02:36:41.082552
3c38c0cccdb3828e59437360eb20bf6a04f718e9e5fb810e49ec25e2b91a296977a9339db13895fb884a61a348743236d8440728c965dfd8d58aa96638241acb	37	{}	2017-12-21 20:43:13.647205
f8e85ded27b0b705c045229ab59fd200e0cf91646d1fb54d3bdfad6aace5cb5a729278b8e1da8dda2ad26a8cff568291925c8893ed376dbd7a3d19804e96ac32	45	{}	2017-12-29 12:28:29.197152
a13d0dc1d278d687208714a43f8b545a3605b6b431cddde45847733cbe346246fde322fada5e040089509dd5eefd97b11b7ba75a1967b5b9611457d0907e127c	62	{"username": "test@ttu.ee", "is_authenticated": "true"}	2018-01-10 23:19:27.680319
477876602588e601fd650465ffedd6fc829cc0ae0a4d7dfdb7ca0285672e7bc238add9f38ee5aa596464361ff58e0e918b6547d68ccc1c7eb7e4482e11d2cf43	67	{}	2018-01-15 18:12:21.187622
75d5baca3ddb5ddc439c4f63bfefd407857973fb16df3ef3e0b8156a166b00a5add88d8a5ca2545ed96c6b7d4bc32c50b04539c8380cfd832d70066fa3b65b79	53	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2017-12-26 02:43:22.448127
74ad83060ada7f7038cc73d3da336f0b6e265e627f19f62de1f586f560262937de665f773020885b86224c2b0d229048bde94a4cd5388c9d77f0d2d1e316791a	60	{"username": "martin.m@gmail.com", "is_authenticated": "true"}	2017-12-21 21:43:11.459636
d03922cc6d43fb81c6659ef37c6dd9b417b29bf07be9f30e92fec6cca23f63842102962d5ccba9a9a496acaed40f88f085088a06ab0c4e79e9bd1b06c57dec97	59	{}	2017-12-21 21:57:36.219653
8660cca067923c2adb3aaaf555a7615311d953a192cb4c0398e749d3459c042c5bb069c1cb1710408c502cd7869b06d7e017e6bf153cc295bfda5999a1a96ff9	59	{}	2017-12-21 21:57:37.013591
3eaf2b6159b416d29faaf8e310a3d7795b3f339bfefa7408e85a665921236a20e71c7d4dc2fb82624649e016a2a6888218364416c8000e00ac963b190eff3204	59	{}	2017-12-21 21:57:42.010819
a6cd6e77417cdd80ca0aa32a82ce85400e5de06452efb984ad63842e2e374e358adcfe743f4da01028ba859bc864e95749e343af8ba49dce1817d5469b9d00a6	65	{}	2018-01-15 18:43:23.041035
84fa38c5d48f2cfdfcfe63db726ee0c1f1fc36d1d03610e31fd41f8e9c3c5755ec73b3368a9ea3d6bcf1ec86d62da6b2c173fc79078f37fa6b100dbd66a5f345	66	{}	2018-01-11 01:47:34.910815
907da37a1a287ea1b4cf31ef8616015bd869ef756872391f5a1441c62db8e9a00f1a1197b9e7f20a38bf0c8b52d180215a198a20190a8fb81be584d0b1eefe37	1	{}	2018-01-11 05:14:53.760731
eefc7cfc1f7ba6795c92e595ed0f27ccfe6fee6fe24d63a217d5a09dbf41d16364b30b9d88981ec73cd15035d0c0010eb037bc335e4fc112d5c5388720c319f9	66	{}	2018-01-11 10:25:52.557567
0e3b5e067dca103dd2dc7f2a94166f138bbbf60a3f982a83f7688c428c87ceb842be56879372a34e45b51d04c0ac5bffcd94a9e82057f7adf15352645747f6ef	64	{"username": "mapota@ttu.ee", "is_authenticated": "true"}	2018-01-15 14:39:14.182474
e2ebf65b9501abcece9100f16c64124ca3fdd058f991336f5d1c7acc501b880bd36f05133ec4f8a80161be493a161413f190e4c2268329afeb98002216e9afe6	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-01-15 18:43:45.002522
c5d0720ec96543d583d227a25c3e15ead0a605e73483cfab693f610374c70f72d3024da4fa565a44af9d1bd65085650c9aac3e70e7187d51c03daa1ea0d2a0be	66	{"username": "juhataja@projekt.ee", "is_authenticated": "true"}	2018-01-11 13:53:27.01677
965b2ebbb0db0497d91ce3c2207321ace152b8a0d1b12a7df175cb2d28fc8e5549d9cc1f74875bcd707726ec9b4e80de031039659f190e8805a35f21577aba10	12	{}	2018-01-12 16:54:41.946557
40a60f6e4856fb0b0b396c2610e4d1a19a84ccd396dd4937075dc8969e7b0b5fa96016f7c9e02c2da2b3ad911b884affa7bcac0d7af9d7b117733b1cea6bd78e	1	{}	2018-01-12 21:18:06.939951
264914406569fc2ef901be07b604269e52c4607fd2da533d6a97e9d2df63da5183605d30791c94a0339e7d56b734f61c34fecc3576d2de6fe4e9cfa11c456484	64	{"username": "mapota@ttu.ee", "is_authenticated": "true"}	2018-01-15 21:17:55.769045
742d740c2f9dbceda4f83b7399579608fe8ab6329f9f1e1b4d88524cdba52e6499d3ae77440ec44d173992ebe13e1b0c2b2814dcb4b07d3080920b3dd08db53c	66	{"username": "juhataja@projekt.ee", "is_authenticated": "true"}	2018-01-15 21:21:47.025731
ee11d7a0852ab46967cf64c88bafa82ec7c51c674045617dec20c5df396b481e6ee840d280c2296a47a52ec711aecd3a02e1b0edc5474bfbc3d03ee336b21589	64	{"username": "mapota@ttu.ee", "is_authenticated": "true"}	2018-01-15 21:30:31.558181
8576e703bf63697c807a2726e1ed8f7741686e0fcabd1265566bfa466eb811ad3ad8c4ba7e0dab6870d7b481227cc95094a33cab3a67a27484cf60bf25305c78	64	{"username": "mapota@ttu.ee", "is_authenticated": "true"}	2018-01-15 21:30:37.723103
e2106c524519708c3978bc7116bd508886530c85939d1222f0cf3f67c54cecfa1162611f100b5c9c1dd5c6fa1c1932e05e9a2eddb7c31c7b89b414ba07847375	49	{}	2018-01-15 23:32:48.592946
ab091ccbc0ab8dcf0bc2d318d09d62de1049adba51a2da5c1759b7f22c9e7488c3d245c402ec5c18a7f740f50ae5e977888ef6a19682a8944777d965620c8e34	61	{}	2018-01-15 23:34:25.676388
64f6da05811337ad54e9230f752cb03e2734afe4e1730a4de118c62e9927a6631702876f02bdc33ca9affb456150d7d59c7eeef0a063b759e298c8f2881a7659	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-01-13 21:21:01.695812
ee93e4d628aef25df2c76d02735fb3995aa3288ebe3e22ce37c3ca155585b56c781e5c43af7d13262ec89a5eb0aceaee3409f813647ad3044cb0ff1a42ad12a8	21	{}	2018-01-14 15:06:13.495841
9a6b358449b16cfe84ae0593d4fc240e114da5e8e1218de77173efec424fcf98f97fff73ca97417b43c1b9c33af13ec9b2fa059eec8b565158003216577ef899	26	{}	2018-01-14 15:06:41.420069
f4a21ba0c09a45cad370287304882b3499115fff45b97053ad0577ad62e97f1b91763463a37bde11a5e938970349a7bcbff9de890b7595a9247184ac2ab8b6bc	61	{}	2018-01-14 15:08:13.829357
4d400cc66524cdaaa6fcf1c9d2d77a3c1a7f9bb2844da0fbd0bd212dd35f9246ecbb72b0e5d26dc30164d248c952af16ada92464a0e1318a44631ca33a11b9ff	60	{}	2017-12-26 02:37:08.884076
09f6387bb9df293838480d14f742ac336dc17ba065c9a163d04108c5ab65693d5872dfe7dd42c44e1a7fe33eab48c24effd56118f31fb8e26241082b5c51e7de	61	{}	2017-12-30 20:31:37.809547
82fdf1146828c4f02c73c3d25375065370b6577429c88d06aabde1d560eb14415927cc1a1171c7ce9b5d24140bddc05249f7bf55179c93028aa22ec6aa0a322f	12	{}	2017-12-31 10:27:48.119427
06f8a39a361b54e39b6c7342b6492534e8ef59dbe2e7300eaa7960f0bb05bf48e872874de0e8c4bed9b4e43778a5a4fb792d0c6ace501efd7b38e85da6b913b8	1	{}	2017-12-31 14:37:05.837368
1d40c0d6745da1049bbafe64fe6449aa768fe98423272dedb8e1e06d8292078c55b6c4de6c49aebec41b78e7b711b57b521c6080d98997925c035187d5d7c12e	1	{}	2018-01-01 15:07:10.910825
f83c25c5cd72548bc31c1928cf5785fb9a2753678ee7c11a8dd837891f2dc569a802df8e6726b64f146071f841544b36cd7939e5a8cce58e52744b034b3f5430	62	{}	2017-12-29 17:40:14.773335
d0da9df06d82ba0e5de8ee2e62f0148f26ea2dd9bd5cbe47001415952cee3e1034f4b703e4e47f52d86657c3aa37ad1c4cbaae6edd6830f1f72d9f651be161cc	59	{"username": "flynn.combs@neteria.io", "is_authenticated": "true"}	2018-01-01 20:17:36.147938
bc4094f5ce2780e42ad1062d826b52d350c959cea436bc1fe8c0abaa089fcd5b8bce17a44b76eb968e68e05439c4ed618a1402cba14494c2c36056bb31b95558	50	{}	2018-01-01 20:17:19.279694
b7bbea636481fe7225433061b57a1adfba8549f9c790a2187e43097a56e6b41e2b81d077410b82df1d15853fc63be33711f2907024646dc808badf97f8efc901	12	{}	2018-01-02 01:44:36.102085
df146f7ad810eb16effa0d4c233e25a23b3bee829f11863c6c18a3c64116c400219159736d9281b8e601fa3c01fba471c2206bd4f75cc476240a9c0bbc64f9c7	1	{}	2018-01-04 02:35:13.909758
5acf6d48f4443b6d116399f2cc2eb55f1eaca736496c4735e02511b09d68937b8994c51b70b3ec09066e17e9f05482f539288df77f2a6131b51078e5db0c8010	45	{}	2018-01-04 13:36:04.16122
b4fbe4b77f009c93643fd02849fbdc29f443f99bba7007642adecdb9d26a417da67f830b271ba426aab0b2389b7d55139dede5daccbaa08fe233eb8fb743ae9b	16	{}	2018-01-04 13:43:17.546354
3d917da82b67ea2b7a41a4dc4cf01b0c0c039cb18306fe4da72bb53f7a46f805767f388474e0cb855cef4195d4c167ee8251eb18a4cb3f529d9a29d84d5c2fe3	42	{"username": "juhataja@gmail.com", "is_authenticated": "true"}	2018-01-04 15:30:48.413049
357b02c4f0021c7b03c875027da79e809894941cb5e586ff98c9292ce9266396c6f35865159de0f7b00e9d1d21b885b3dc2dae2fafc52a4190f81ba62b7aa7a1	45	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2018-01-04 14:24:02.760263
86568bbff18a04a37247c5b2d1ba6a5d11b8514e5b18f21992b4055aec9eecfa7868ef268afcd6aca2b1ca91d617352c36bad2507fb5a21b898bd4db8fa6694d	45	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2017-12-29 18:21:58.876161
b43cb6ddece0129f63b8d32d4b58787cb6b07f83b7d31fd7f3795eb3d4440872bc1e56789d28c17db742b8fe6968ced1490bc3f9ef9a740f3f196cb61cd5fe1a	12	{}	2018-01-04 19:42:35.460935
a4b676e30c9e59354d637fcdbb7d12a37657d072920030d17355d0fa634ddb862481a4ac34b35be8264df66f72693842dd3640b611b1c28f75dc5efc089485af	1	{}	2018-01-06 00:16:19.92251
5c9e8186e4cfe80037d9db0547a8582da69d6cf99d87c9689739ce9988a306d1ca3764635887848a471ea39e1a6083ebe8d3f1abd2bd617ff7ade0a4a9a479fc	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-01-05 16:36:15.568387
e84d2cd51c7f60758a26d7df2faee8e8b7970b80d397d71913146e7c769b3185b7d0ff290316ff2e54072cabcad1396a4817c4ce62ffababc076c3f01051650d	64	{}	2018-01-05 17:43:46.584171
3b9f4eafe2e4eb9c2e2854a6ac60b6b243dbf8a6da2641236797c9362ca33076b38887763b10d56e957bf8701359b45ee747e7c731b564276e98a97170bfb936	1	{}	2018-01-07 04:01:58.768498
fa21e7938be3af9c9a4561a70726204581291e4a725b6208cb40061aed9c91383db1dd76ddde1add9e6aa7399c4ad796fb6cb9b57746e8f2b05c72af47d54645	12	{}	2018-01-07 09:00:43.336429
61997cf4b5bb9a8f38c1b993f8f504ceea2f9abab5bd2492533df061338af6c7201ac2ccf5d5a7da70165e99151c51eabbdfd32ca08c8f9fc608bf94313e249f	12	{}	2018-01-08 10:26:04.257739
570ce402b2af8c6956c676f14cf67769311ed13925691d91ea1ff0f6c3d0111f9ee60ce5869e2c337f8707e3e6ec00c9bac3966f47e84956f8f4404fa377c4be	1	{}	2018-01-08 23:37:54.964228
f0ef3f794308819d5afccf2e3035014612eba1af7b14533657107f73d5a77df22ad6293181fcab716e123a0dab375e6276af1ebd82af8399637bec38bd5e54f6	45	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2017-12-29 19:24:22.819274
fe373160e0211cd191f726d6d990d97b3cafbbb04409c2dc8cb1f22106406010e677ac8366e778d504e518b9096725221c3c5d8854ef450bbccba1b0e58e7935	63	{}	2017-12-29 19:24:48.371845
c5e4d0ffa60d7141a0ea2d6be1404b12c784f2dfc4c508d81b4df2dd135bb3758bb96a65399b1c3ef8f6b0ea2786bf3f738c157bbdce05e1ec40d8af01f2ccf8	66	{}	2018-01-11 01:47:45.253897
4699d6ec76b97521daa4e9d989fb26740dd77711ef253bd9503cc19f67d9aee4f0e92b91f7707a82e06470e2d8d255a4905307596d43dfbb7b715b8c5e4d506a	59	{}	2017-12-22 02:08:28.552842
539d03b55bfee16893cd3c3cd9ce51bff61664cfd5a0950f3017a0db0c37adee9d2c84489c2f2d0b3772f69b7f24b872c9fefdf6d1fa4a2a6c28273edc896d63	27	{}	2017-12-22 03:09:29.060526
7e7c6b93799a4235358a2e8ec9b266a0a134e4de4b337771c9715872b97752348aa831b3081c1105815c130a64df33e0ca1e43329f7c756082fd6cd85be6909a	39	{}	2017-12-22 03:09:47.031018
b2353c7dc24a77ae104ef6b5bbb179af557fda78e81fbdea5d8ede9bcc46667cc4382ae2e4f661e5664988c1f910f69dd95035febc515d120b38320308a80384	65	{}	2017-12-30 00:17:56.845703
b8b0e3f5b9f82fddb3c17c3237c450d2e75d896227404040df7ba38202c1fbf84d4e48e0a7852547a4b3c784565972749cc04666d73b24d39799a97b4850c920	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2017-12-30 00:19:36.195958
d3b7aa17edd3e03909e5b2ddb98f7ab5fdb197b7f44bd6fd764b5028c6bfe7752c24efcd275fa837d3d70c6a8e2f23c174a0eee42c4a505bc643c8b17efebdff	1	{}	2017-12-30 03:19:31.453362
daaf10061123526dd436a7a5717fb3a67257de88636d827bd84bce82ad6d5121245e33010de8b549fbfb83b52d448ecc5ce4d9ab016221ae4523ef599948bf6a	48	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2017-12-30 13:07:06.528605
bf6a07be0b2fe7edac12ff0bbd32810f3aa1647ad0e9ee5b613137ac92fc40f25c98bde2635d34589e91f29f6515dd87ecd5a21346dea3b265db01927d9914c0	62	{}	2017-12-30 13:09:19.496039
9fa745e38d73268b5f4b10dcb53bc4086876a8e9823957fcc1ba0e107e19f96d05b6cc2f9fa291cfb3ea2b11d534d5bbf7d0fd7d12c1985f5191f709fc1cd3fe	63	{}	2017-12-30 15:09:56.87892
17e38b57c7304ff35b01d342e0aa6b4af837e58995990da28d38786fb50fba1f3143c7796bfc64d41724978267e6fc874ceecda3b4046097a284e21872dcbd8b	64	{"username": "mapota@ttu.ee", "is_authenticated": "true"}	2018-01-16 00:19:18.77626
882b15bd82922da4d08fa186cf103a196fa0399d4a648c2b43ac5839c9dbb7d256e871c6ceeb69f2a97bf0138b7a060adf8046a0f3e4c635999acb14e62e3d92	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-01-19 12:08:19.002687
d130cb44d7a87516201c7af8c966084d14ba6735fc0767c761062e27e71869ecf8fbc70d857cae93989815f330be3cedb907ba9c0fb5b700f74150a8fc74b40c	68	{}	2018-01-22 17:17:35.573541
9f20b5106f98a92e158780b8b461bbe45fc0f523f3d83050c6b02d50ed862211debc7b9d892fffd6e7bed97ff1d69db04f8048047b7e53597258268c46c340b5	43	{}	2018-01-22 17:17:45.498684
3c975a525effbf08cf5f6714657ced8908f39dd311c1a7e234bb11436976f2394177023c9570d120881dc3306216542120da4178abbaae1e7abdaba989cc690f	57	{}	2018-01-22 17:21:05.132635
94f50f24294d4fecb162e847e7a51d6309dc606ce45ebc402c6032106533e467e8f8278820fe46efc69ad587ca5fcf467191ada8d2bad1ef8bf7f4bab3d65cb5	69	{}	2018-01-22 17:33:58.656911
6f8f68419354f2f42f4529d7be80d174fe170f8718b64a3b537d3caf12eeb43c9cb759d59ed35bf3eddd1ed6fe0e0c1a8c480d0e1318cb3dcfdf3ebe14ca5d23	62	{"username": "test@ttu.ee", "is_authenticated": "true"}	2018-01-26 21:56:42.103459
da8486af7e7eb6f469ce168f5132fc61847cf5ac8ec884deecf147a61992390a87848669cb4bcd1e4efa73a0130e8228ad7ece90ee0e2091e3302bfc3cfa9cf7	1	{}	2018-02-01 20:55:50.199165
8ae6a5de61c91375500ba501e010a22876af31de4965bb9f6ef7f26d47a6924edc6f4c0de878cb8e5eebc02559def927c8052e137f63d752426c19968812670e	1	{}	2018-02-02 15:24:03.915068
0bf52e05a3a9c40ee240fe047ad0a5ebe62e731027f7619507843f503486dbce3d4c1e4a9c6cd61d29ac3fdb111df72194b4cf4f1ad9a239f4544b8abfa9577a	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-01-27 01:28:05.621883
c29361454c1550d9f2e28eba3d5e086a1e4aebf9eab129e9c8e05b88b043019d4728b43c1f631601fbdbed6ea728c7ce6c2bfed35ac09efad9dd6e6d8c8c57e4	1	{}	2018-01-27 09:44:44.481319
a96ff0c032c7b4812ffb9f855789e92e1aaac1760861e7a219a9a359f57b727265e0f173b82a147ae4a208be2c68f4d0a9d0ba54c6af919969987aa86b4d0ef4	12	{}	2018-01-29 07:33:57.265213
184008afec1f6bfb052ba589558097866c7538870d4a646317efdf52b8d0a2fd3feba001cb52be06d129f58d9b40c56b862ac2c9ccf78ac8550a6b95d50f89ed	64	{"username": "mapota@ttu.ee", "is_authenticated": "true"}	2018-01-16 21:16:05.933244
0ad65a72bd275da6920d839d39299b4ed880388352e762f785a2bd6d7944e749599000de91d4e926d029b3b654a52b8d26ccc0d1d1ab9adc3dcabb0a50d69d25	1	{}	2018-01-16 21:16:55.990163
ca8b726dff66939364c3a83440a67ada1d46e9f0e4e46ddee3a5656eb1c7f0dadd362925a4fc3eccaafb414d2ce1cd15ae9e396b657ef64594a0a83f94204d7e	67	{}	2018-01-16 23:06:35.733411
b0c560921f4776280209c985876fa334bda433ffa95217df725546a8184f10622beda713434f899e52ceeb7994da53448f9618383668dc5eaaeca57467de8f6f	12	{}	2018-01-16 23:48:27.054808
d45929f670d117fb15df704f2867de2f331d854ed39c91d3847e54f867095374258afb7af2148b48a5cc4d434d5532da8f1818ece1665f3f2b560643dda60bc7	1	{}	2018-01-30 17:41:20.472851
abd971ac5bf16d9dc2d9c55b8593b0b240682beb9f447ad7496e136c1e2bcf40e7398c6f0607e6209f8d353431a4d7d83a84c2e28aa6877cbfd38bd5b7a9309c	12	{}	2018-01-30 23:15:32.448111
83a9894e459704e576ec1a37f949fca0a355a7761e04694adcd73e1fb2bcfe46020009dd903eb441f2e584407490de66ceec999201844ab96685eb9aa865dec1	12	{}	2018-02-01 11:55:40.788764
f9aad8cf5503bda972c358fc940479eee47481ff7371f5fd36b0200dd8de3b0032e3adb033a92c7fcbd73587e50e5be6901e3f6e82cb9af339bc2f131af526d2	12	{}	2018-02-03 19:24:41.258543
37ea8c02256b79567a03a7ceb1672acd605eab886a5dc15a997f8ca258cb023bfd113e98b4c8b4b6babaff55403fe771171e5ae368c09c2d5e394670fa1f0d07	1	{}	2018-02-04 08:49:18.22947
62b6556e4af4198528e42b41f5c3ac27c23d65f0325a80b186c08ce6571eb4a6d6873cd5439ab8f6303d196988dfc09c188f00f30b49f28b2c4bc6fc37b68db6	64	{"username": "mapota@ttu.ee", "is_authenticated": "true"}	2018-01-17 02:28:24.260172
bae89134d02813d07a6b5d877ce07d10a8c405c5e096b40382d39c4325c1a10783552c5e6c3a5a70f6692ceafe35244fb42e094069d8c3be910b0924b72ffe65	1	{}	2018-02-04 08:49:18.544244
3ae97d45774baeea82cb59dedf0952a2ea70f765bafe4204cdc1b87506ac0399de37d6d8fc71c772854d1d358129ab0320b13187b64e79706f1d14716cce9b3b	1	{}	2018-02-06 11:39:13.474425
7178624d6a812168ca8628c5f7d4a21e6c4147dceebc994e1f3e3621bbaf84071ad01db5bf47f85f903204874fcc335cb00e3f48f8593ccd2c04853a22ee2829	1	{}	2018-02-08 20:52:43.972671
38bff0b09da3f467bd824751b16f3ed280122bc3acf5d1e216130b9a1ecf4d62052b99ed6f05bad6255feb24a9a48ad11d1e43f1fee1e98a7ba5dff6d815e8f5	12	{}	2018-02-09 01:52:52.256754
2669f9af3306c733b5576201aa5edbb97c473e76918450999feb5a0b289281464a6ff3b07f0010f252b82975637b97b9ed90221fdefc9d539144e12a636b3da1	1	{}	2018-02-09 18:04:48.783827
5f39742890adb544e9317d68d5745f17550c32ba4e0ba1f9393b86b43abbdee0bae44945095065442b1420c2b13524fa8a53564dcf27b29f9ece37694d5b10ae	1	{}	2018-02-13 00:13:00.891181
04989d18a153496ad2c3cad36e0638c9431a54c04a4464b5aa919908420ea6c0e45d7cf039a34dfbda220fee9a651a6b39dcb9cb1c7035718d82500e342613ac	48	{}	2018-01-17 14:00:03.032198
484c0568a1a34cfb28d36762e69b4136ad8e12b01b82f82b1e59d3174d4b7d1cf1d6ec601487e8592edea5cefd6ff4552d9305c53a7ff3735a4cc7a26e6aa36c	67	{"username": "alkond@ttu.ee", "is_authenticated": "true"}	2018-01-17 15:23:52.054368
2fa558777cc3f2cb39c8c2db32a6cf71004c6be32aa9cb7cada87a937a3c6c8650976002fb05ca632210fad35d11ec6168150976281a5af87e116c617665c3aa	67	{"username": "alkond@ttu.ee", "is_authenticated": "true"}	2018-01-18 16:56:36.444015
544826c44273bd0603864da67fdfae0ec680f4b7ee16c09185b36e3c5292e4319ec3a3d0936d1b6badbb96801ee336da2d8691b5b17b2b0c17ddc2f4aa2df5e5	64	{}	2018-01-18 18:41:13.369478
db4c60c1205d45ec10227bffd4293911281c353733f61aaa1e8b7d1cec58f33558a38cbfcdf009a0ddeabf6f3bf2f13530d77ff5c3cfbbb9df41e9293db1fda6	64	{"username": "mapota@ttu.ee", "is_authenticated": "true"}	2018-01-18 20:38:35.882599
c7c003882f218288206f096a379089c5d3742cb7835ccd8b9f02cfc12bb78241cbc52116040f07d35fff6e6322e33891d5d3e7dbcbd45e6644063df756a1404f	64	{"username": "mapota@ttu.ee", "is_authenticated": "true"}	2018-01-18 20:40:17.862061
f4b20dea9cf1cf7d33ead50dd8cfca6c7178f0e00a752f757fda3a24896c1cf7a3c6553bf216c7e74e93bd31929b098596983ce11069e8df2e7334da79ab22d2	64	{"username": "cole.nichols@ezent.biz", "is_authenticated": "true"}	2018-01-18 21:33:28.707312
be72cca51d81458748229f1c15efe373ab2800c12dfe4bbc7ec25cf02a6612c4b84e364576787cb547fabc7509fb7571e50377f678b6c3b0deee29ded60638a1	68	{}	2018-01-18 22:50:07.004811
95b785d65ed6cc80a407228c6c897c3e47b1db10098e0d9b9be23e45aee1b44d1ded4de5dddde1dab55ba2331ed0de0440cbc5997157159141325fcb0e772cb0	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-04 13:50:31.008189
0707c0ebc8b790d3395f0b7fb4ecb4cea214bfa5479978ac7b8b86480de50df3bdf389a11af31cc686f09feba2a79e86f2b212fafb422d4674ed2d097edb02b1	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-05 13:22:54.24117
e492174543676be4bb896fd7d20bc69dd46fa0325b4ddff09b97206cff96ca5652b5f49162b75dbb072924d07756f35065d93a2a9f99eb714f2288d1ca570742	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-05 15:10:24.886082
64c72a24815615fdcbaaaefba5ba77aed57f557870476ae45c66fa6e6539d4337fb63cfc31a0279c981d650eabd0cd71f0dd5735422e706fc604ace3fddd12ea	65	{"username": "test@test.ee", "is_authenticated": "true"}	2018-01-19 15:27:29.463399
e3902fc39ce3d9fc3608b396a4b76085e5bf4fa91b88b69a7d733c38de89f29ca1415311806790311a29c70d154339900904da1f8fea8874350ca1d277f8a5f8	65	{"username": "test@test.ee", "is_authenticated": "true"}	2018-01-19 13:11:49.529246
a2f704e26c886f6e11c66c36177e40513b99f978b9734f1538d79cb5c4df69380e17c71076ad5846baef8b7df5c352b84d21aa13f4c14d8a03bcd684f63e386a	12	{}	2018-01-19 18:49:34.173412
d176f77e23a6c2b28988ec57b2e3215e83dee8a30dc19c21583f460f89607b7cdd84b0e4de8d8b42c5c678e362781146b22147175e783825bfae112049a68897	1	{}	2018-01-19 23:06:38.796611
91c761be88896f9dc553bfeba7bf677b7ca01e7293566f97fd33d9e1f224907f0f208df5e45b7c7d9da889d3705f0a132a2bdea5ec2e545d07f5ad7d0589e755	1	{}	2018-01-20 00:51:58.042332
332e7971ee472c2b5c1bbfe84b7074df4a2f6bdb1775316460a134edbf5cc5c2963b79af33559795ef5eaf7c4a851529ea712be5ff75796759747a1e2a2f07c1	43	{}	2018-01-20 20:24:57.371027
281bc5e4b615c75299251ef59ba0b95030b8f92257ff97068f21267de310bc2f61c24ab2cf7e1513a21e33a6c2a297abbe469b9072d0e35f46040dd141eb342a	64	{"username": "mapota@ttu.ee", "is_authenticated": "true"}	2018-01-20 21:18:38.190398
ca4382e8d53ef7941c21efb9104a9b84dc59a7520a74dae85e24e9a294472880e03829e265aacaa305177b919423871dfe8fd3e675e6a92c037526288955effd	65	{"username": "test@test.ee", "is_authenticated": "true"}	2018-01-20 21:49:52.638506
61a5f35895b8d150c01a74d20a531d10734cb66fcbebdfac49c6cbb1e2c96c88d985471a1039a23959e0dea5521e5461a3aae97fc81d84e54e75976de311d90c	64	{}	2018-01-20 22:27:46.391942
2692929558a6b969e25f0820bb28eae5f1ef59666c562e76a386d3a5264581b5d52aeb7f143dbaeaf371721feebac7167b017a2933c0f279eb5f68872737961c	65	{"username": "test@test.ee", "is_authenticated": "true"}	2018-01-20 23:36:18.991112
409d4e84c0ea9970e75d37fe754a3b482ebe263dde4a548753c1e59fe43a6ed65fc889aa40828325407b572f1da77a8cac5c28c4463eea0e652df7f62ad0756b	64	{"username": "mapota@ttu.ee", "is_authenticated": "true"}	2018-01-21 01:43:37.959374
049ad9cb72514b22d62a1d1d83a2bfd8c27d69a97ce117c2dc10bb5e81555159721bd780c095ef8b12a1963f5b2d6e539fe75bec01e9352ae9e4d202b7155ed5	65	{"username": "test@test.ee", "is_authenticated": "true"}	2018-01-21 14:09:19.335161
a70a5a823c3e73bb7419b7ada6dda9bab71d7aa9bdccf875f13259f7ea6762f4d25611dcce9b5dd66b122122526f1328b75c46bd63f1215d9503fc74406ad243	64	{"username": "mapota@ttu.ee", "is_authenticated": "true"}	2018-01-21 15:13:39.108781
82a3d9d50582c098ed2e65999758299c9cca197d01ba37adbeaf5bb385ad3ed27d7d2bd8af78fb5537106e913c12ab82a922eec283eff835e704df089b04c613	12	{}	2018-01-21 23:19:57.566261
ffc7d010de9df3ea69e7b9b4d3a98d00dd0c0fdc8b6d20099fbc2c002422817ec7f270003e125eef4667ac0a8250b0e3d431dfd532eecdc93b684906a0aabd9d	1	{}	2018-01-22 00:38:57.205852
be472345ee50a57129753d93152b38ddbd898ea34dd5b61082d82da7af19859275d7410549e5c4793636195164193d5dcde325777caa2c2a6135bb46fe662afb	37	{}	2018-01-22 16:56:38.963723
a2861d12c1e0d0960dfdcd97737d8b6c83c78daba49d452794e4dfb1d5f91674bca40bb2fb0d006152f3c8707da7a76d309a28583d9b520e938af88cf8ec8563	36	{}	2018-01-22 17:17:27.788086
3cab72626714dc807bb5b261d238625c24635f6eb3a6df581a78e2aaabb1d9867a2f829c7f31115a99954339b4c1b4ff0d25f16b37bc5bbe7783036e703279fe	21	{}	2018-01-22 17:17:41.609448
4de1aa658798988bb331aa822d78c77b2872cf0a514a86cae6fd35d18133ef2b84a0e799092f2c6731065a51c5b20da94d9f445455c83d12992c6f8f2735e898	39	{}	2018-01-22 17:20:56.428983
298410e257da203dff89ee078613918f383cfc2b8076a164986e0895f159f26dcd849478735263076a4d673800ade61957f672c46ec9a81519b8114cca742de6	69	{}	2018-01-22 17:21:01.241991
27aaee56bfc90b04fdfec477e82a22eaf151795a927fb9f8bd948eea28e2c7c606125acc53a9b2a0ea0106e2163946b7f34b97c0b81e22a09202b1d5edc2167d	69	{}	2018-01-22 17:33:58.441624
8528a846264fce914118ca51e094c4e7e779b17bcc91e9aa46b45323c7148b38b46c7721503134fb08970bb716850c1d61b956e5ec863ec670b91face065cd23	48	{}	2018-01-22 19:46:37.325156
2b6c797d9c1e26fe906fd757d7c42069f2019db0ff2f7947190abb153bcf6aa9f0e62c716173716539d5bac785ce05fd27b234f9e21d1b7d781c61411ee134e4	69	{}	2018-01-23 00:47:31.867962
7839a6dbf345ff6039632031497f645a63b8d5f8865b78713654eac2a9a62b427e82b99dc615e58258a79970b71b82432a37b601688301e38909eb54e61ba61e	1	{}	2018-01-23 07:10:40.041012
185f63883535339a98e6da0655a1db0d7340d87153c68c6174ae6ff0f2d3daebae0658cd8f077107b68a7d8013a117b9fd0fc7436d7f7a599d78574d9b8e956a	69	{}	2018-01-23 12:16:25.821044
803b8af6dbc22ea49690412a47fce78cd71f72b2283cdd699cd1650453d59c4bb5482794243a4239387a27d4d683a85c7e24bf629f72e99a3c7868cf4c999d08	69	{}	2018-01-23 13:04:31.227014
a02c2871b4ef3dfcef428f7b508b9574bfd68035fe1c617619d9b62a0e3e6ce92330e14d7706fbabd814787c7cc0881471451dd5e14f3c5865850b4318520d11	12	{}	2018-01-23 21:09:16.753311
3e6f6c197e1c12f3ff8fdbcfa7980245623038fbcdd0c952fb0d3a00fef2884d6e60defc2ae83fea8eef78a42dda4a1f4ec936a4e7e7082f00f23dd98cbce6ab	1	{}	2018-01-25 13:57:56.628979
9f02853f6b8ac0e08ff1b7ec57d3c11c2ce454961c22fe0ae6ca0a4dffc7eb0f27b9ceb1c56124d43cedb30656c16589284e83ee35d936e0a4539af27a05a1f2	12	{}	2018-01-25 16:46:59.262926
0fa62f686f3bc20fc239ab38fc9ef349b3f9ebe4af12367c411999e36a559f3356a2e5a56ab77090f9f0685f28b44bbcd5909b030ab77f5a43ad60a04c4b36b9	48	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2018-01-26 21:56:06.678615
d4ec6c34fed18c4f4b6ce503fdb9ac2c8a8bbcde06a8cf245090a6439faa1b85cd30749f90cce25d1d2c4a90bc60237a92aff51e6af6ac5279b80223fabbacd1	1	{}	2018-02-13 21:33:50.481969
3aecf59b307afe3fe9bc66f64c5d3344e423a5557943f8538b24c47806a22335d34ded525c5f97e53c3e295313d1f6fac7468ba95942291cc83949a8c36a464a	1	{}	2018-02-13 21:33:50.87946
72867e184e2e0f79c8c9a0f155c6e7ba643d067e3874108febf5f91f4b30076a8e87bb81aae172aa3084c81dc37a6384560a493bc396a373376da9993f2bf459	1	{}	2018-02-14 03:17:09.503929
d260af050cb1a2d66a9f568562a8a209cd5e97ecf4acbb9fb16db8dce990493c8fc55f37e47f803ee11ea3489da154df96a7e56249e65f5f293690cfb3a40693	28	{}	2018-02-14 06:15:01.351736
1380092b09207519099044da1f7d1557a3f98afad591253021c05bf3c9e7741d2d56afbd4b73d3aa162306418353b9e761d832e39af484bbddc72c7cce1f464c	12	{}	2018-02-15 14:12:29.275819
f3defb366480cc40f0f7bc88a499d486c551a857b10756223bf4157e76ad89d61d308344770de968d598497d25721baef7d7a023ff6652cdf0a23452c495cf17	1	{}	2018-02-17 02:23:40.137822
7b450b515ec6496e6b514a7412dd20872f0243e81d290c52249d38e0089616da2df49e2ab33385f87bf7379832d0c51e39fe1ec4f2feb24fd949e3ce2db99916	1	{}	2018-02-17 02:23:40.496544
91745b8b3e576fed27dd794f8a7a70842b45e69f4d776489a0f995211221e69dc185063f5ae51be3f5c38fe110041a9bf20bf0daeaf4ac6feeb7437608340830	1	{}	2018-02-17 10:02:25.409939
0eefc9ba659717c9b1e354de4b8580856f79b9910da1c16c3e013e6b691f723cac646384b6c26b2201dfb8b71c6b0e86cb73709445d717fda6adf1442ce55e0f	1	{}	2018-02-19 04:12:47.562048
aee274445c0ae876e86886f22ef9a00848de8c42f1bd77de2ed289fa8c86b5a67a439849ac5c9c98b70b0889fdd0700540d98233d0f45dbe59ec2e6d6e0c9fe3	1	{}	2018-02-19 20:17:27.86559
3106dd164cac7e705d3eb5946780af6c6c4eb2bec8932cc0ee62a7d57547326fab75aa9a348d1df89550eb3a4a97be30c8821d3c32ca6a18426e21f3ac3ad726	68	{}	2018-02-20 14:03:53.80382
71f40ed4bcebd6a267e56bca8f63a2b256c424189ab7b06fda1b90b39ab4969170c2065e896c86928c56fe5fe3164ed6e1edbfdf6a5a218bec5732809ad99f22	25	{}	2018-02-20 14:04:07.504028
7b6b5241329768d404370e6642721ca3a4cfce593beb42daf3c95d66a8168106ba08b899a2d64e3f34047f28e3f6fdb3a8d91d315cae1c11117f1d9b3b16d4e3	1	{}	2018-03-12 00:33:45.413725
c877cf66c02e380357d4bac4cea9c7bd7c4308234b94e0a175dddba5f442c2c1e75b4f13baba3279ed312a804e7e255e27b1c6d4bdc58bef1c6c003bd2930da5	12	{}	2018-03-12 17:31:17.087722
3e5acf5b8b79401d45111ffde033d797d251442a5d72c266b9fc1e759eef8ae063c6e0dd298ca7075d994fd779d9b1fd9d1a95fd5ca7bd6b32ddf3f84308ef4a	1	{}	2018-02-22 15:52:22.844368
c22ddedac1225d4b31ea4f1fa83dd023dbce85c8501e946fcda12dcc307b34029254cd031e4cda676ecbcb443e4aedb5fde199369842ac8bd088d311b1243441	23	{}	2018-02-22 21:57:19.517985
e0264e23455104260fc40bf5ce70b828f96f8a1cb074dbcad0c59da9196249e64db67e56636ab9c284537b554617693fbf2d29cd4eecb1b6926823d67799fa70	1	{}	2018-02-23 01:38:30.900604
c900c094b7a728c882de34709d245b3fd64c0b8b1c5442fdcc0fe73c4b4c2579cfd3769e5853d1d13ac358dd27a5f2a50c37a061fd332be121a2ce8a8d519210	1	{}	2018-02-24 08:01:12.355593
4f48ad55b31aba4be527717a35f385c246107282bac506d3b8c8f8a829d790b38bff24a95da7dc7171e8e27bc6e0dcbce6f823c4fb67c8bb96755ab46426ddfd	1	{}	2018-02-28 08:18:44.050465
2dda325e14df75681fede35952e5449b4557f1975a1887fb84a6636c8fe2619d8fb2a7a0ae5396c2af3a2f6e60ecfc251377beb22c398c93de19756aade383ff	1	{}	2018-03-01 03:27:29.065466
20c9780783c322983338326d8120efa2b659c14971189bdbff323f470badc6399bc46e2692b7fcbeb1dc95970dd14ed89cc091ed5a2d22a24dda829b583c4fae	12	{}	2018-03-02 07:04:04.749393
aacc43e0c77e4d35a90709c77e0a620923739502de3764bf0b9c26ef41f4658cb9ffa8b5cca66d139b4a8e1a6943aebf49eaa3235e5cb4b5723aec78afc22a93	1	{}	2018-03-02 23:13:38.339418
a91080d6316b769b1ef25efdc97959465971add725ae173ed76b6ad90305f7bdb3eb2e015eaf75892966aa774ecbcc275a72233ba4a0bacdccb580a808a64955	12	{}	2018-03-04 08:22:00.088475
f975f7138af0d55bb5e7ea76ef443d0731f0b043753f41db828b5e1799db358ad42a503e9929e3dea1149f03a94c602e776f893c4c0c913512509f8317e7f587	1	{}	2018-03-04 22:40:58.724128
2a4de5cbbcf70f534ee100b8f149a518f042670a90f080737986cfd139111d6ab0dbb3a4e21ac90c2fbac900eefdf6d2eaeae8e13f92e43f054add1646116519	1	{}	2018-03-05 21:23:21.135212
0f63db0e3a0cc1ff9344999ab716c8ac75b4dbf6b612433a58b7fc4caf1fc77f1f330f704d7c8c71f5507a58d5b60e0e16e47e55349568df8b9f5c23c0bc3d47	12	{}	2018-03-07 01:42:54.364438
f713ac8e8b3b17a50d1bb27824f8994efe5451e007e8540be9c28a8b11a0e26726bbc7fcd0480ed91f35b57b3b9c10ebf9b0e902cc94c61f630d4f996c51ab77	1	{}	2018-03-08 03:27:02.428456
bf11a1d822a56a75290191f3b420e5b788a8ca1ba58b57f1a3b8299638582dca26400ee2523a112f67cad198c38aff5f3161e8fa4231bdb4362498abf1ff2d9a	1	{}	2018-03-09 14:35:02.411019
af692a2f7504a00e5e638dce371077bbe2faf784699f8e923c759caf86d3d03fc762dc6c1d53aaef2b89a5359072f9fc7d92531c3a7c0bdf30d9461c31e266c8	1	{}	2018-03-10 10:24:02.700922
35841a77d5eb1bae58d40aeb67f5990c1fb0ac9fc8ebe76973422fec608f240eb3376be94b5122e2d350e48231330f28c86f60a3490f711dd0fea3ac47cc5d1b	12	{}	2018-03-10 12:17:49.570095
3576392f1d3b93032c334781320d4564ade258b45a93cd0f3c4868e02b6b6b2418d49fa9592bd1a6ae64b74d74b9bc2cbe503a9395dc54b6c4f2fd9e77a227cb	57	{}	2018-03-13 20:49:02.364859
98286c16673157c4a928a3f5e88ac2c78eb717e1fd2ce37a817c1fb2feb917ca48ac9853065b2dfcbd78f49ceb50ffadad6c88b1a33f85bdf5437589634db763	1	{}	2018-03-14 01:29:41.836185
e14b7046994aeb78276319023797582b79d893716118b4c0c9b12554a8eadf8ce04a6c837b926fe9a9f3570f2ca1aab70060ce46a32ec280000cf0df91474204	1	{}	2018-03-14 03:12:33.841319
c7b86edcb3de2ab43ab29178a6c174153cea6245f8e499a1d4dbd4ffe0d515c176c1566e12f8d0393c049bfc196042b95416e982ba8e9374b4c8ada2c9920016	12	{}	2018-03-14 12:26:21.34529
790d6038b6031be10c9518da4c23b06ed6245ff38cebba92ec4a37bd68c463fcab096e30938ea4d2a1ad296d0d7dabade461a9ef32c67d736fbe767cd78e61d6	12	{}	2018-03-16 04:02:20.456144
a6502077567fa6204886f4dfa59ec4d9614bea630e3beb27cb374c2cbd4333ca95a1fafc3b1296f3f04ffd9bf5e3a97feb787870f3dd1ac9b32bf826560442e6	1	{}	2018-03-16 06:25:16.760725
dc2563e363cfde0d1686cf2a0ee831e23e3ebeb0afbb03b22308bbc585f15450165bbedb0d1c24daf5910a19a0c8d2ef64964d689493b2a12389826a55c073b0	1	{}	2018-03-16 08:23:45.780851
5d6dd429ce67dbafc141c3a5e338e1ae43cd2e02c409c0c943e9bb8c7421b9d16c98a3761fa260213ca6e631d1feab107bd2f1e758a11106ca827688282ec007	12	{}	2018-03-18 09:53:03.558177
d772d47f6a33934e422c8ef9dfa44e1ab47d89c6d7ad6a08bdeea365eac274c2cf186e87c298d18eb16c7df23bdab31accf66d94fff41a0c3a4121bb727d6845	1	{}	2018-03-19 10:09:36.355287
868013774451e6df6319354af744fb1a3fc3ea8057f1244cb4d8239ee070ffb5d459b0058f535133e759ee985edbe0110aac7682306adacb4a3750ee2017e275	51	{}	2018-03-19 19:53:32.994452
c58bb1a16b54fc95ce103ce87ca0cc68fba30a61b6bb617f40106b9cb0fdad4344754ab753f39d88a2b6f038b8e3fd0aa777c278a7b2e0c2546f3453a68ec067	12	{}	2018-03-19 19:53:45.049219
2099b1e112651dc9c69cb5a54debfb916c5dd8982f42b033c88ae7fc27864006d0054f5aa8bd78ec57ff5784d225a98028afbe8f8db43499a3a155bf18d24c31	12	{}	2018-03-19 22:03:41.475085
2b77bf85aceb3298de7f0926ffc416ef590dcf00827a31b081a1afa3d53cf659677856a518ccbb4bde64c68ff44a755b8cbaa2e42602b6deccacdfd2aa3b850e	1	{}	2018-03-21 10:29:18.046966
9c80d0dd78116486cacf8765ec2aa79e66c6be3b4eecb56352e6f1ed315aa125f203c3eb0205f856153cb4ff5970e47440c3b33f3631d484621fcf5b4068248a	1	{}	2018-03-22 21:10:31.950896
e4dbdb7c7e28c544e2bd78e710701db2f244fa5dff69ba2ebb72d5cb431c54e236fe99b38196ed66e9af3d34f3277722d59119364f222d862445c78c83c6f958	12	{}	2018-03-22 22:12:52.157442
35a76959d77f34a9c03bc5d01ce835e868ef8b1f67825ae3de8680df8260d047058a40d4477e197063f752f106fab23ab487e428392b1e981d8d9169b266861c	62	{}	2018-03-25 18:39:14.547091
1a7f947e04effaaf1637bb7ee2488969a3e0e8cb6db6b28101decf6d401a2d6c3f911b5422ce6b3e706d612a6aa03aaf6fd87e5c2be0826009856a7876502724	1	{}	2018-03-26 17:27:46.628439
17b45ecc58384e7414f4bac430ebf94a378a0c03e25a82ffc7b0b4e07d56945c0631a34f8105ef253b497d4561518cddf54dd12937b66caf6f192e9c7fad4ad8	1	{}	2018-03-27 01:48:11.732845
6e4eecaff2a911b1c2d51ae72721b705ab56adfef023538e40f071c345a2cc919c81ca152766a02f5ebaf4d3890198aeebfcd3c1ffcad9e763d519e1e94ffe26	12	{}	2018-03-28 02:36:53.744319
3e1aeb4f0157fcdda79fb05be0dff861f82ddf767b11e1138535a8e996ad98e2b3277ff793f1d4546e7484c16ab29b12d4de7eb304878231a220f907e27a164f	12	{}	2018-03-29 20:05:18.521067
0137065cea83031d5bcffae198c9b8f7f76955b958b998879227b965bef54aba70edb2264c742fc8a1ca31d012d6ec125fe1ae27a9ce5aca25b574218cda97c2	1	{}	2018-03-30 11:44:37.580555
55df894a5fc4c042942df806bf734bda51d6896e68aad59c9eb00d9d9e9a58cb3314d713c2cb5e12bd3a448c81b5c080a5d592906135b775087ccfac4090419c	1	{}	2018-03-31 04:40:54.402613
138e1427d03b823c6cbe63b41f6bcb3287c4cf468b4f664543b17139483f55227d77c4109c88d74d20f8e2ee4ebfb3cf6a625dd241319b67b9111e6bca709a17	1	{}	2018-03-31 04:53:57.782382
38e366c67603512857bfa8e1d1a1c469c7ddc0643a5fbefde20568327a3f599f6f988fed1e9a73e9d546964c28009071afeaa637f5a5ffde8e5020aea191fa81	1	{}	2018-03-31 23:22:24.519483
4dedb0b70c498745803ff6a2fa3fd1205b9d400ce0d2bf3bee57ee024101362e6851d44113fe2d2deb2fc95496bdba067a9594f3cedb105fcd9f6058153bf386	1	{}	2018-04-01 09:00:22.382912
8c4776dc2aacc890dbbc429989644401990ce790be56d5d3493e09811bff92ce9c298307793cbeca5442e5dad7824bc2d82c6c4033b6ad2e20813fbac2dcc502	1	{}	2018-04-03 10:48:07.758546
0823b53715df6974800fb977f054aed521e2b1e2c1d09d012feac45fddd5f0ab266670cbe9a416b9a132396d81842588e1d0cc674dbdb237f5422f2c63293075	1	{}	2018-04-04 00:26:00.065085
da6507e927bedfbefab7f61caa5881d35032547d3678e6fd9484b1bb73a8fde07f07ade1c93dc6ae55d8be4048ea74a0306e146bc8196fd2efcb10b207694ad1	1	{}	2018-04-05 20:45:29.863081
04357564c918d46ea8fcd08d0475d4a63799eb88f05ab448b1908d1167969fe2453ab080f37d08ca72b3193940e3bc8afa5a0f89f177d2dea141bcf9f7167f06	1	{}	2018-09-05 06:27:08.815369
9fbbd48f6325037f30893b40679b2476577d027c66309ab5eb4b0cbfc4b0a49dfd622282b4aa8a476caa2d1684bb123d089af8096d34e3a4a75c34545a96a05f	1	{}	2018-04-05 20:46:48.256327
720ef1a5120921fc8cb6ae3cb45844053410c2f17a8900afd3721efedabc17cb9fe5a400ae93d1f2d9bdec90360f60290cdddde8c65914755d72121e24a9491a	1	{}	2018-04-06 01:48:07.834875
2cee5689452df72df6dd5043033b7b88150c08f198c0f45486bb68bb4fe4cf6b9c68024482170337312da1060c1f23fffbf7ea8edc682dd91378072ea648946b	1	{}	2018-04-06 05:01:39.220354
db396accd0053ae83c8c616b8429ebd3b78256ef74908dcb4a98945bf6c07c35ebaab52b544b8e47239c192a39f2a22d18548aa67f539fe9e2a48125b77978f6	12	{}	2018-04-07 01:13:07.250132
a3de847e346e5c64975f5e3c24f0e1e8711c4cee0a443973f770fac9d68173680162989af411e81f43403d4faa5184f4efdc97acba6d7ce84d77440ba6c73a0f	1	{}	2018-04-07 04:22:31.332074
fc9bae65c94a0c172d51488b16072a885b46f6e3f6a6ff5c841569ebe6bbcbb3db07a4b2b266b6e671ac061a74a0d67add3a2cb9ec2f6b65eb31cd7858d742d9	1	{}	2018-04-07 09:02:53.314417
82b29e420d4ddcfd0820f08b5442af4ac91a2b55381978de7dbfb8e753a910d03a13e91c4a592aa514e35eed99c0f5002e8c7d6961c90b4664f6c643f9013f69	1	{}	2018-04-10 04:20:41.309838
13773a01e6e43a0a22018020386d91cb7562d2ed97557ff16d6b36aa1e3e678a81119e806ea2c559fecd3835621cd29546c197cc969b8666ea3487ff53a5c489	1	{}	2018-04-11 02:57:23.59177
9f6dd81fcf59d11cbb9556f75ad6584a7a8f8b466927b139325aacecc94139f85351cbbff060686991e3bd0e13f12d982d28d21eccacb06981dcde3a57b5ac8e	1	{}	2018-04-13 12:03:53.311205
5f79644c6d8a2996062350e9f4eb1e6e47d7d87c45d2ce72d602b8091ce2e8b0968e81b74f3f889db47a6515fc7b70b58ef4889d7fc10012b3d26c09003806e7	1	{}	2018-04-14 10:51:15.386653
3aff82972950107b108ca93b7575d10289828ecf9a11fa48ef72b2245ecdcc98a3129392c5c5044b02a1b7b4850325e92d22f2e13ac9f65b5bdb35a5d25c9e6d	1	{}	2018-04-18 09:01:23.885432
93954b8e0d0d751614eb43ff6c092e42134634810b8e56df73137b28f2e530417a73143851b620884b063dff0886f9f586a9ce57efb06d18952c4da9f40992a0	1	{}	2018-04-22 03:03:22.475213
269a86bb89963a91ebe9ef0c470347a4d7226b3453b86f41aa82d69d0e5ab27eff008881f7a63a2edbb4c194721a965faa14fd64a19fbe6b383a2469633f2c51	1	{}	2018-04-23 04:47:18.748814
924d0c7f3f2530cca19e9c40e9c61a673e739271d33e041538bb4635d22342456fd3abe5e0e9584eba2f9623891283d0c69c6d8eb7bd3428e4bbb9f82bea9f2b	12	{}	2018-04-23 23:09:36.585508
8b0380c35410641721866bbf42912eea592210797577b494fad79b3006f0947246bafed37f96e3beb55e579ab1ef17c5d35b858ebb10ef8274b6222562a6983c	12	{}	2018-04-29 02:37:32.232784
17dab5732b72582d38264f4af2aa7066b73657311a52dafd47c8520e6de69d8e392919497953d9f5fa85b47e6cf6d0de59906bef3d858d33cc89bcecad2b4e00	1	{}	2018-04-30 11:27:27.126553
b2ef543b900d0d6ac98cdf9a0ea3513b41c77c3b0e0545c62ea0248a5e47fa958ca3390d28af48d6528fbf42ef330279a74121c84bae40e3c9643a12f5bd8dfd	1	{}	2018-05-04 17:19:44.792577
3a6485801841711c912992746ecc1e4d12c2bf9951593f81cfee5486c8da9e9f16a525b8e3df2fb2bd781b97368bf0806832330ef2e8cd58536c2e0b60f8103c	1	{}	2018-05-09 05:43:39.904649
81dfe3d82706760fb837ff67cbe43cd298ad9b4b64b569842aaff85b5cf42b9945cd12bba8a84df48fbb859f2f8e4b4bc5d2cab1d006c24bd239bb8ba1a470a0	1	{}	2018-05-09 15:19:03.259536
eba8fbc92422c6abd8ad5765bfaaa7a73792b0f96fa3f99f52ff876540d5c3eea6f8e5533713f5e21d78e535c2d281c4fd593e1d0e763678abafb70d4259615d	1	{}	2018-05-10 23:44:24.17051
ea737bbc4243e9e8cc2232bd0619803e3bcfb2fee566a0e35a56508106dedc3dd776097b5ff7bc770c4a531c55d679f3b37f88af7479f11c92834a4f014f41a0	1	{}	2018-05-11 03:50:00.053319
d490bc6f218571606fdbdd9200b9ec71716033eb8517e129e4d304d902fc1be8e6bc92f6f42c0a934508c0cae96ec612274090ca98ac7391919b7af6130b9ef0	1	{}	2018-05-13 21:56:51.677033
ae7820499bdb796abdfb7c8f4b5b9a6141bab2bbaaf1b7a2d2ee3c6c86c5118b99b62ab1bb2bca5555b50c3c75cfe029ed935243e8306e5c8be2710bc30c3485	1	{}	2018-05-15 06:11:48.465974
fb7d91982320b2d139f6bf841a947640df3b5341d71474e5a144cc1ffa78cc4cceb0862f70c9893ca19b69e6b3c508af6f7a614bb0186d7f9211269f78e258c7	1	{}	2018-05-20 19:58:12.28802
2a94a45fc0b279af4623722c652e08cca953f3f21869c6d3c1b015d4ebf4ba64364cbd937ca5ceabc509096df1feeaa0239c909389e8f9f049c49526015ee972	1	{}	2018-05-25 17:57:34.02009
926c5c486eb247d066079ef319df8e5c062668bfe830acaeec85ab7bbc04eb6e28192851563452bb244d8ecb731482b25d7acd6ea5610422e2fe1af29cf0e4b8	1	{}	2018-05-30 09:01:34.678559
b1d9da91fa98496a678cd9bd82f40a4f6d4308ecf6ad392b35131b7c6bb229fe43c6a61fa05620359bcc5be85cb2dda19bc25e37cf7e43be594f742f9c66b4f1	1	{}	2018-06-03 06:30:59.896057
e630f6446d97b8c0536fd0c5e056a9e5b52b8fcc45e3caa4716d250231b948397302a6bbc6f793635e402a5d4f0b2b5cc7f437bc0ce79dc43ed79784c8125a72	1	{}	2018-06-05 07:38:24.524544
526109f676e7768af7c6a78df783232af59e1b21995f98648a63a83b2a33752c4a8328fca6b4cf207b8cbda52c063fed72918400d678484d8f282713d5d088f9	1	{}	2018-06-09 19:09:38.610658
6f630f6419bcd088c9591490a55cbbc9a5bf86e11065e0a679c1a292a8bc2fdd94fae2e94629a032e10b392248f89586169f2e852e39484e1a57bcf3a7906f4e	1	{}	2018-06-11 11:47:35.095434
6166c390cb4f19c0f45bbc42b7c8ceb7e97bc175c7370078a64084e66017b73f4db8215bb790db352509fd29e404ec0b134e57cdf670485504a112e4fc6fe05f	1	{}	2018-06-12 15:16:12.312708
fcd05afaa6db7879461d290eada6a8aee40cb02543f250cca3fd10dd35154964c58c8d78f1f84f2149af91444750789f8ba5e20cb17ee5a3753795ef697962d6	12	{}	2018-06-12 21:39:35.711154
9362d07d3cc49404a4ce5a47e1e9ba1710d3f8b2f8d131100d3460637d1e3c2abc55bac1ce9e2dc3ef7916f1746e333ed2573ef9bf94a096887fda4b23e27465	1	{}	2018-06-13 06:22:01.540879
6b9047ff2775dd4e5a8ea2a8c2c70384621122d6706a8686c3149c7bb9147f1facad31765f334e54c238fdccefa6ba1b1686d80c3b58b253b1350053535797e4	1	{}	2018-06-18 09:44:24.181582
d61114b062d93489043fc25cdb77f31aaf8f4b4a1961d747a396066504d4678fc6f8881277c61c990309b1b33b7af04ec36135db2ca17c515971de2eff051fce	1	{}	2018-06-19 05:09:58.40291
247411385345f5e24c96ab73c81a1411556a9ca637539c781c897f85f4fbbe318298e287c67285ec0736c6281112abda334bd2b975cf44b874eb4e934ce0f38e	1	{}	2018-06-20 04:46:38.702004
5be48c9a5d0d53f3280bd644220df922960b8672053330ce8056733bb571ca8093defe184064093056eb2a93504f50878cdc32b34909e8ae491cb7361393156a	1	{}	2018-06-21 00:32:27.798037
803fa7479606ab066641f7a929a0a998418ca63539250ad28d56b5749057d452adb64ecebb74849cbf68c22d40e0a3e9457f70ec86812d9a33e484170b2858f4	1	{}	2018-06-23 04:23:37.400617
500e1440a45a9116a1bef79921248d0dd63a5d3cbc78f03466aaaa1666f7089fbee5425cfe82b1ea56294c3365c4c284c7f3cab3944851f4fb5e62d9f5f63ba7	1	{}	2018-06-24 04:59:18.585341
2d854c0611ecb540cae81ece533fde8cd0c52a3dc5277933f9f9968c8582809c8b6732ace34674f238a69be467c53d2f679d84ea32b6e15cc97f2f4587edfcb4	1	{}	2018-06-25 01:48:17.361468
7db0ff24f39852ea09daccf97d66bd4de2cf37468588039c76ca68c1a0f23fbdec319abe02c1b5fda157d288e8e5ea980e5cdc749f47c020c403e9d09b0adeea	1	{}	2018-06-29 04:47:08.566899
9240ae768924c07219b80e6005ff1bd64d8df9f2ec4584d5276862ab8832d1e59205435b27aeed35162fdb6d2120b897ebcb11366a0b97c2b75a62ee7837a0f4	12	{}	2018-06-30 07:46:57.005066
81853774c4b4b10d4c7fbeeda7fd3bbc7481809a4d6c31b18d77bda18ebb86a25428c6dc61aa90330c4fc68e71321a2f447ca1b4292865ee67339f111ad459d2	1	{}	2018-07-02 22:39:37.695255
f6f5c1995b9fc28dbba9db45da9b4645135eac0ccff5352ef332885244e0191aa1802a003aed5f92359b31fdfa80097c8f91c84ab60e4f91c728e2f527ecc304	12	{}	2018-07-06 12:40:12.965143
0cbee4123f4596f579505ea9ece3c4057536732077a6f7063b86cc8a5bef3618d6e2ea62273728ad142f67e6bdd1a9fdb43fcaf708e651305cff0162c260b494	1	{}	2018-07-09 08:52:55.843651
dfe284ef93b2431694da43fbd26f63058e639767ccf9e9116b0b30ed6bc028a4e881785e42a98b0b99164b08a5c91a078fcffef95a3fcb5d376b95ae43cc2074	1	{}	2018-07-11 02:00:06.65733
ecd094e0cb25a5636518b57667099d5867fce7142de70df534ffa33662251e0946479c7c27f939f51a913ba3263eb273a7aaca1ac375272e7b7bcca07a494aa3	1	{}	2018-07-23 16:28:50.100422
cc11a6301a3dafacbf3b23a0263a1a51d1311daeb67e876240222ec1b8f3fda5099c345b596e57262534050e9299fbbb7df147766ba4a14e8c678c08aed336be	1	{}	2018-07-27 16:59:15.19001
75b752072e440dcab2e0e749125ba8f6c1e0e1bfa4b0096351a9b91dda1ed1f7a2ff4181f88dcc464817cae7ade93599cca81b9bd97dd552f48a0fefbe8876a2	1	{}	2018-07-31 08:01:16.782242
04cf38099b4b3d452465b0c9bc7fe4aba0003195256690b2adf4b315d95b23f2a9c4dc7f58f2e33faf122f5d64b8ff55de04b410ec2d428fe9d3b69c52a8073d	1	{}	2018-08-02 12:49:17.705713
0bbb53786d9eeb2bc0b52f3d32c2ef67999968d0399c7d41a1b2be02a280d0569bc0b1f69b30ef9218c0f29a95535cf09b54707631174d9df92709f8f582efdf	1	{}	2018-08-14 02:17:40.256234
37c96e001b2bb86c7c11246612915c76de911bca421aff570b8f7368cf26e5021398fc25ec2b54e9a951748aa29c9250f3e8ae849ea28acd43eaff4f13b7f6e0	1	{}	2018-08-19 03:14:53.937398
3837f24aba2bce3f8ddb1edea01bb34dc12a2b2cbbc70ccd8679b0941807641fd39dda5ba4efe401d267691b5e88593db1959c3aef1905292b56065ae16cf2df	1	{}	2018-08-25 00:25:01.22804
7f93e6fb25f01e04d9000a2282be8c6015b85825a50515f1961576b3dcf259232ce7f03f0ecd8bc7df1b398e91fd3c18267827e4f3c1a7ba51a3ca713f406071	41	{}	2018-08-29 05:04:59.287397
71bc7fedd8f4904ee665823289a1d9a3e92c0debb5ade04b1edb12dd1b53f4086e017efba611e8361f630442469db0b7ceb704dca9db3687107b6b617cc24cb3	48	{}	2018-08-29 05:08:05.489864
d74a7ced891a5acbae5d71e97a8a14c073a7344415019aa8337a4e9fdfc667ebeaffd83d3f0923c7765cdd7c059cc67738f09e141e40cdc64554670690043537	46	{}	2018-08-29 05:52:36.867811
d2269f0ce68a4e880deaeda01cbbbb76432e317a3d1062f86d002168b9f9c705f919f29204cb9085f41692ab18142f0c43907ce25312a121b711494faa6be586	54	{}	2018-08-29 05:52:57.219718
0ea5610270fb9a85cf84d0d45f349db0ba18073c512742ada19a2d3010e5529b8da1a41927503931e2cb532a2dd7c26cd3146bf5c82484024420106201934a4b	57	{}	2018-08-29 05:53:19.126787
e190820170e7b35298efd4b3614389fd406332ca90d1711c3b8e16cde4fc790f3ea815ed3753c1cedeaf5c88d6fb0971bda1aef2817f84f841819492faa83b17	70	{}	2018-08-29 05:53:26.646534
5fe33f7d2a871ed33287952d5fb65a89adb2ad0637803615f33c1d725ef77f6df3658aeb5322ccc8aa9976ac66e3ca943cb88eb5656335e971db79b43964dda9	30	{}	2018-08-29 05:54:00.730023
654da7b32b1e962435ab15c736715128422fa5892a22dbd826b031d36a41df70a94b386c179e910b9efaf5148237e0b8e547d33ad31f494a7ae8c7e8f08b0008	12	{}	2018-08-29 05:54:11.96861
765a2a7614b5b798cce2c8078be7baa95b6e5b07c0a26832c3679ae3b6e62486ac341dd1d612198ec94f8ba6716fc7d0ce167d75977fb1c4335f8492cf1f839f	49	{}	2018-08-29 05:54:18.12445
17a15fff85cc3aaecd94c1e514e5185a1c2cce813e1b4c9d1bc2dc823b1c277fa1f3492cdad312c799ccbdbf0679df5342550a861ea9851c5c1c0d7eb69c6d9f	51	{}	2018-08-29 05:54:23.2276
d375001fd5677dc379d70fcbc172ad65072f14610f25952439dced9c910557f67ee943e40e97dd831f2efe932837d5d4de38dad44370fa28308d85c0292bcbe6	47	{}	2018-08-29 05:54:28.324738
033c21d5a75981328ab605ae6d4ff13da1db1955ebdbc24f05cec125ee1e91462997294d73004d9ffa999599fa6bb736308fe4044f1cdab0e6f9b59bd74486a1	66	{}	2018-08-29 05:54:37.664609
a3e120f5196d5e11e09a8fadb41e7275d492e36b667dcaed5b57a6f1d33affbc5a5da567ece9bf5d342908f61e774ad81ef64a9192df70df6ecdf7f5e02baf6c	67	{}	2018-08-29 05:54:48.274245
2570dc8a92b1a0cae1a14411f62fdd6f4c16bfa22b30fa015842d4c08e8544b041bca61ead47b8abd2e4dbfc0f28f56ee85bc38c24c766301545f00781f82a32	63	{}	2018-08-29 05:55:47.684825
7af4a1eee18d179d911a109327c25d566a9eafc3bec59dc0a39f207fb3cbd8cbf49d5b72d0a03a01cea9ab0b2b6074b55c73cd69c35f0dd3d5097a436d540407	22	{}	2018-08-29 05:55:54.441569
e599229ba6a5fc74f5666044cdea1cd7dd801ede4680ca5a6c0ffa7dcede036e1a5dd3be915eeec556a8fb699cdc764b3df970caf0df3c412ac9a0969fb57ccb	29	{}	2018-08-29 05:56:06.561171
acdcfa41e5a5e134f921ae4965c39dd731d82db8d3876a576900a2aef83a96494a722a874a1cefd751b6cb67b0520f9198d7b235455a1f04874712b4bfd333fc	28	{}	2018-08-29 05:56:12.148834
4a6252a12c362936769c5989e2a4f9b73fed4085bde6658af896a4298af36722cdbf3c126f463c095d956b3d6147db333ca98102bdd5955f699b9f261ac69ee4	45	{}	2018-08-29 05:56:26.062025
6cb232aaaf1ac2b984e381b94b84a3c225ddd9637c3eb282e9f03dce1955f686edc02c989e1e5552a930787e8eefdde9f750b4a5fa3240226d6580ca234261ac	71	{}	2018-08-29 06:19:03.58231
ed19450d87bfbe67b3a8db828023ac9787eb63bae10bbb32f4d7facca6e729c5b01bf813b3dd47da0092ad76a2095eaa095d9f43b6813baf5bde015115f5bbdd	41	{}	2018-08-29 14:01:36.15868
908dd8c46413a35deeca9c11fcd14ecdcbfde4d3ec093ba25144a0f17a8b7f13d7dd68ff301630c99cdc52b7cac947da4e83bb1824f910f839e442ddcfa44077	48	{}	2018-08-29 14:02:52.027341
b592db6baad2f35c1498b6db91c43d875995a3409c1d0a32b4ef9f17ab688f565c4a8b6b092417092ef5c783ee7838bd36acc368d43ea82f0b0121fc81d30cbe	16	{}	2018-08-29 14:03:23.427817
fc650ef4ba4522362dd69598b4e08ec0100d11852c94b3c36ffd3e8a0aab9a0eb2afc292b239bf49251d64fb4cc4dc540df34d5848b925553d9bbec187ce2e2c	1	{}	2018-08-30 20:02:19.299357
bac04c6bc647c7a16220a524f7997f5271da60e5686145f03a9ee6fa45b5df73cd23b2aff7fa4d1ca7aa39ff09dfd80a8902ea984f442d82e5f4a512212f3a6a	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-02 21:16:53.399386
268da626c096b4e1a1fd5327dbc03f58afe8e6f8c73054c5687359d6e67900f8153c97d59d8d46daa35e690a1b5862de59bcebb9a0edfb7c27b57c14d5a6c93a	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-04 13:52:57.414503
963e1408b9e05e2650062a21de5c531553a66623baac68354cca5afdbb3675b0fde0ff5213a6d4c0a929f82773400d8ffbfc86c5681e0fa4a5651387fcf578fd	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-05 13:57:20.885967
089c3b33320c223cc13a06a590d77a19b038e7356c7520ca59732f22add90b63082699e58bfdd2f108c481075d39964fdc909a85f6b964e15db8a5767f8f4ca2	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-05 11:58:52.715506
9e0c134a7786a187afd7d402ab7a1aaeef7c810d9ad85c74184cdfb34779dfad6541268ecfbc72d174fb4e46e7988b1ceebc0478dea9dcb1d2b46086605272e3	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-09-03 03:17:06.733215
acee452dd8ddb37b1cc6e205b1e64a57d107e51131498fcb0e0ce10cc89246f3423829d8ecfd9e06d90b668d425057dc7ee9a9b4367da1884f79e3d79632510b	67	{}	2018-09-08 23:25:41.429243
8b5c4f8b90b187fee88b4e5d36ae6f00097711801e18ac2df56f4471ae0f352786aa756931915dbfaa39b35a480a350dbe8c032fb5febe828390a3989ae0828f	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-07 15:31:54.914722
e911fde16c1c787c5fb9c1215794766f27b1731435bdc71a5f43a848ed5b2f6e7e8570ce18d7eaf2d1648fadc5b6b887177a5b34af6df76459375e3f73133a6f	71	{}	2018-09-03 04:56:59.872736
894d8188d7d95d0732730c70b4b82c9dda20dfcdf9b14a493c629a4caa1d8c2b15d102e7628b11837b7b4df1d5915d7ba4649853a912df9f9a24deef6b781119	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-03 17:46:08.528033
b0bd2b825b4db57fd0f10cbe8ebed246f3d4fcc09372c762b21e9d2246175605e7460cf333aaa82a9aa082287c63a60c368988b8961a97a09147f5909e8faf6c	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-07 02:13:38.168993
1702a0251afccd3cb2138272e33a9808280e2501296d6f3c00001bc9fe12c2afaff6e192581e40aa46433525a26987f7ad6ddfc465d0a71beacf234c652a2ed2	1	{}	2018-09-03 14:34:37.668009
32d73a19b7d18878fc382e5eab1d783ed811e0244987117046240c636f0fd43118e56cdc5400ec4924370accd4abc1e8f969522fae6bfe0b12b75e48a9de3e9f	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-07 15:53:38.091977
d88d9c1cc0a121d89d03b2c4e192a24808dbbd115a6548540ffd4264cdf8f5754eb28629d9059de031ce866282c1cddee4cfd56d83f03f24c01095a2e9d005c6	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-07 16:23:32.873498
8a0e0fcf2ea1fbcf2e985a3a98ef5e2175a7b7767edad821bcfdd760bca477a967524137f01acf02c052803d0619097e2c34873e989b570664c8dc175476bdfa	1	{}	2018-09-03 17:47:20.241166
4c3273314824bca7b765b22174e034a30ab42dc4069041173951aac52c571cfdca144ff8ac2937d7b87f14fe43fcaad4ce18908e981d27b37d5a4b603e8c21e3	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-04 09:58:04.462057
c4e8f71bc49c43e581c2eb6c3a1531c1f8d03b37809fecd949ff719b1341f6c68424ff7112841508b0a4f48bfc09bee71d1d1fbde3bcff9f0e1a2d8de4294818	1	{}	2018-09-07 23:15:55.132188
09bd1d9b147a496bfbcb0a5ff40c776fdaed9638080144ffeb3455e5df025eb1488429f2ca80448a7e48d50ef23227e2a2a96dc267110432ab28150a351b50b7	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-03 17:48:26.940936
84f98d29c6c0f17e008fe2d85f85364f8de976ed56848b2395ba58573203ccd301de960ace1a1093c66c9b598ec0baa69e211c10037e6deaa97fa6aa3f8113b7	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-08 14:02:12.080831
a1e38043d6449c85db4c00780afbe5cbda9730ce2ed2a3f4e8d4619654b8e43ea16b311af8dffb16567b9a3732bbceaa33efd8746cbcd0e4b3bc2c703ab93a91	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-04 09:58:20.357147
f1fba61ea00167483a8b5da31bc70adbfebda99a39344f93d7755f854690b22f6ed603ee8f32a5155045945d1f65a21725e4c8e22825f4758c2534bf3325ae45	1	{}	2018-09-09 00:41:34.998118
61e544f3a22a5183c293945cd7ec407344e637b6589e2171fa2fe7d1da03a3cfbc7f363fb908246a1a67be3abff28513469f99e918fc4b1baf427c2b69991b1e	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-08 23:51:55.285846
5a1353eefc3f90b7cd67f3f36ffef391e6bb323876f9f6b05c92d9008875b2be7bad7bca34f9b287f16268736927bd4c7843ce2515bbab798e780872659763e5	1	{}	2018-09-04 09:57:33.923468
b31546d621fabe2b9d6a9265ecd5c5af41cffd7f21af554d2637490189c44307f85808061ec595119a0d7f158e8489d6d9ff83e21d8ea0bb12f8450c052721d3	48	{}	2018-09-09 12:06:03.39904
193dc802e0b1518c6f4fb53aa7b2ec6bea4243c73f9f6e389b50a9b56ad650e31d2c001d93e63f494c2b14fc8b885d6db46e2adbf269ad45b6a713abb51c6a14	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-09 12:37:55.67003
302cdd7800959c808992d1bdd6b7c3f6e7645d5ed3259a6ef1add9573ed875ffd4b3880176dfef30d6c44f32e6cb19f77c936cd6d2832f8313f542a30a359d5e	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-04 09:57:49.974072
21d231ee3389f6d6849870ef8d684bfe2a0823ca3194df89eb1d58cc6cdf45984c31003452369de4a5050b36474c317ab1088c55a4fb3ea1615097ddb423ec30	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-09 12:45:38.101949
96ca284544e3bd010eea302a619bd5655421064a2501b25d64ec719fd8ff2d889623a3cd14a0c7273e06087ee8df8eba18a97231d16f3fd994173c63145ccf77	1	{}	2018-09-04 10:16:59.21043
b6211ccff58c2a639449a87b19ee104c31b8787cf68e528af6cd9d14a67f4470aa8a33bd08d5b52241909fba1221c6f393bb1a9718db48c637073b715546388f	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-09 16:34:06.736609
7b5220c8202e0578f0eb87d3ac79bbf85c33a8055e68db207f928bd107ed8fcacd9877097837a851e4e1b1dae41dbcf1e1911a04a0b7952ae4655146843aa156	1	{}	2018-09-09 23:41:07.301312
5d13251aa11230b126bc16469fcfa54950e78a12e9fdf50f3e37ff9cf6b3bfd55a991e6ed143bd904c77c9c64b5684618ed05a2de766899254e818b6209540ab	1	{}	2018-09-10 00:00:52.549774
0f3d098716721a089ffb44dfd57f791a413947d39a439b2635cf1ce6d7c6aacceb81266b3f766797332bf1e3652807aa5f26d703fdebf0aca5b870033213c6de	1	{}	2018-09-10 06:55:21.714476
699b73ff264ba4d6bbca3827235ad42ecd6c2fccae4f33698701b9971bf8acef273b09a30e5cf9ca31da3696af837ba9a42afc262481524ed8205e2d06232689	1	{}	2018-09-04 13:48:52.076503
44f00413c3aa05767b89b4dc853315a494284fac6d65aeaab3bef39552321d44bb4204e2af793ed5cec3df708995f2dd1332ccb5ee2d5a6ef43b713a7fb882d4	1	{}	2018-09-10 11:07:29.964873
81ab9995c0b7c415b19979853e4cf9585b99906184895aeeca9d192455da178026a86eadd0f5ed127b56797926b987fc9c761fdcaf32c65c4e4a82f42aa59edd	72	{}	2018-09-10 12:07:43.572036
1e802d687743b5022c89277965d701009244ab532f7f69cfd122743cf4eb538b2944be0ef57c895fd354a21135946668e7d8cdeeaa1e44c3118340bc5274e098	25	{}	2018-09-10 12:08:40.852629
1b242edfad1ac4fb5ad8a8040149dd431ac174a27cb2a4a99b57b6782ab1fd862f891e81a4be0d405aa2f4c7039fe05cdc58537906b48f74e58d34fe2c346851	72	{}	2018-09-10 12:08:52.578074
50ad9f3e26198185933d9f8681821ecb5c161e51d33374fa884fcc40b09a4c47e85ee45f922406c86b1faf251a0eb1613d0cda2acd40ff1064b962d67a50568e	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-10 12:14:07.622721
8446dcfd94f2ebdedff56281066dc782ee4450c9bc6bfa53061ec214d8074bef34acfd31f7d2ed7e94e7bcd1529860b0bc0234ccffb4ae7e609f04eb5371c69b	1	{}	2018-09-10 13:05:01.343851
841a1300bb7cd238866c3c5d960c8045c3b4f7d41335868b6ca9cd3235b39e57e6449e0d91f70c7b8c929fcd4b9a8b8b72c863d3bb33bfadec060697fb463bde	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-10 13:35:16.072735
242201ad44c1a7b20c9a5017b8aab61aa661b9c286d60e74bff165db83c78a124f73afe2a3895ad92b0753dd045d42017662ee674bcafc1a3860910ddb252223	12	{}	2018-09-10 15:30:00.377906
eb4f7384278e3962b3cddd84ab16af80fe4c638d4d53191c6f04c298777c9b28127213a2f4558b400beca0098ac8733079000463894cffdae7fa3831ebfa0ebb	1	{}	2018-09-10 16:46:30.247398
06c49ad5840273de178bad8f306d891fcd57b91f69d7bec0860aa8baff14ac9a7240428770a3af364904448fc1a5fbda1aced62df8b84ac8e1b9e69393ec3378	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-10 17:04:43.133162
c18ceed9d66399630b1a0b9ee263e30c759c5736c6cdeea09763a6d9858770c638dd0e11b949dc9c1ea33d4e75a510f8fcf277990eddda616080fb38cbafd20b	1	{}	2018-09-10 17:12:09.055365
a8abb9ff4b220005eec033540c6e4c376b4e6a57d5d0c0210d028e384b98efd34e0006bbe5f717cc62910752d45519d3315ac3a741e2d9aacf2570cae77862e2	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-10 17:16:42.776112
544eaac343df301e1f3bbbca50148c9934ee7334dae23c8899dc841eebd4e76ab8f9a96a410f7276689bf271c8586369b07a60eb51073ac5f31c99d40a86b8f7	12	{}	2018-09-10 17:47:05.037736
0e9691eca5df896693906eab162b4358e5c47c042cfa7fa6fb4d4889816ee985599a2415d295fcf9233a250fe3bdb8e62166ee39d2672267a5bf8092ce7a2c79	1	{}	2018-09-10 18:16:49.01948
3f8985b930e174ce693558ae9971e01c4bb39a50522cec15e064d15d726c35d1f065c5e2f40d9959c81f855f0e9f4a8281cef51cf48879a4736eaa6e7785a7b8	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-10 21:03:43.923948
7590b1628efe0704c30d9e2d4a4551bc5a96b91de47fb3ad53e06c8192a30dcc70830833c8ceec7aad680e6f7e00ffd04a5d281e55074b1f2df796e79562b990	1	{}	2018-09-10 19:13:41.120062
822fcd81922a8391c8f51759cec03cfd45d64b05d7c47e271857d334956cd1e096f74c18abcf1a7a1ffd143806f294cc9644314b45199277bff5dd1810385d1f	1	{}	2018-09-10 22:07:17.312917
f9292daf51309172d401463bc8e53e9505ea4193d44b8d4bfc581d83d17226c85673f9d5341f1b8d2fcc4f6bc0e5c4422ec2050053f084c06e2f657c89fa7036	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-10 22:18:23.3055
55252b042f53c171f970d3d1a677ccf18ab3d796eba4c3c17260cfe32adbefb65bb80e509c22ca0111a0febe5375b63ef737c8198238739448f3150ba4718bae	1	{}	2018-09-10 23:58:48.952411
8bfda5cc0d7bbb7ed260674ac23d4fd90ad6194e96ab8ce08bdbcfaf8b0f1dfa912fb651e43781bddf42f337b033324e03478b90102c0c88483b7da01f538107	1	{}	2018-09-11 00:16:50.307356
64f80c8006eab9b38bee3e00eb5a10911c2ed5ce1f3ec11ca33995765f89363ac2ffef62f1576c4a3344c321e71213832408c4b6fb599932346a3795f267c312	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-11 09:13:57.177493
fa40d67eb7ac0e0df23052dac00289b6c18da0eb2890cbcc6296f001acb4d4a73d413316748ac37494480795704a835611818edf54f364232eca8117fc8b885c	1	{}	2018-09-11 09:04:52.659586
cfbab14fd2d84986f209c39d89270ddf9237b747d62262fa5d2b5d36c9a20252e18fcaf6520a5b890991ea981b6c0333057ba86403846a46b2729d4268cc95e0	20	{}	2018-09-11 09:11:01.615032
faa1a2ac20053d3252a703cb6da8d0f8774656572e12011f560bf9af5cb392db70bdba442b43b220765a731551a059718926697de6e57888de7fc8ea7e83e3f4	1	{}	2018-09-11 09:15:16.243175
90616f4bf1456d76e50b43d686d6429543d6e30ff7bf5d84a2c9b7507785f16ab723ba42414381665c209302701d0e1d6c5f8e6b245800999bccbd9ddff62b0f	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-11 09:19:30.618718
05365b774ceefee8526318ab9316ad8efc463da7ee2394d406899a769a08c00fd97ed2d607b5ffb4be5016a9f61e65b9abb9fe61f80d60cce332aca27a2fccaf	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-11 09:46:19.230431
c68127091f96a1d5f570208f88c264a2238a34fed4064e6de67a2226d898fc5575ab19565a5f8de5a345288d400745f875d11152c41bd7a1c8ad0a688c565b1c	1	{}	2018-09-11 10:13:10.485751
5f8a296d8c661eb5e2336f873dfe74ab49737d3461797af81797a592d782a8d58cc9963ac428a82bf21e8f88752dbb61a3da6a6037defde1437f08cec1c13a93	1	{}	2018-09-11 11:25:56.978645
c8eb3b610e75be49bfae928b4db4d3fce20b9dbc6e397252a3e014468f7525880a643bde155928791d20567313c86501e0b29aae4a47caf990a9035ca055da5f	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-11 12:33:14.521957
4a6afb3eea2d6d3004b45ec4644035093fc816a29c7cc957fd7f60d1d04b479f439a5f2c2a708be921616d898a590d13f40de134e512d47042539572c4fdfbae	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-11 12:53:48.349557
a716b58b2c1cda37fb38d0eb62fa24a75c8ee9099bbd89c07791a1e79eba3b42d06d8b41fab59daf55d4ab208b58e5432131cd75e84481e8826673a94e43e85b	1	{}	2018-09-11 13:24:22.716373
6c2c3ce77a64a32c37f857649a40564029a63ba186145fb38af300afc9384fea706ef78be649387969d11a8f117f8948a088058eb00b628c012f8db9243498cf	1	{}	2018-09-11 14:06:07.596459
1a4b5bf7d72653ad48023437afeb92ffba8959dc6591ccba1ad26fa589ae566e9cee0a16112ab94e956a4ece0a5d236f873be40bb716a839c36abff0b0b887d3	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-11 22:03:19.389722
5107b07bbac93cad1fea6e3db0622af1fd47352170538dcf78f49f6a55a5b9a0aff27050f0b7ac81364da136ddd38645ab7dd3652eb0839b1197eef165803d56	1	{}	2018-09-11 22:06:45.229599
a664e471d9e18646189995bea0f170a2222e3b379eef663f1b5260aa0b5d0942bd8856d9f90727b08aee8d519bda1330fd59f83a2cb672b85a0141b8c7b3a6ed	1	{}	2018-09-11 22:11:33.636626
d1374a0caf2e5c9fce558b3035d23c306bec4cbd73e5f295f067cc9fcce7c6bbee7c6fdb6789cb173f118cf1d7c096c8da8b04cc1a2b7f7777067a18c7d9f02c	1	{}	2018-09-12 22:47:15.453195
4617e2aef6f4f32429443c410715d354e7046bcdb06e7b1c0a74275284d728c31622b53fae403efd2b87e3b28b71eb96b1011341bc8d35e72beb076be38d7d00	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-12 00:03:26.714753
9b2fe203b6c03757afd67b1ae7238940e685c7b6422d188df0e59d96b3418bafd48a890f28166141df93a0fe05ebdd8d424949b53fd95400177f6a4d1583405d	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-12 09:47:12.637567
4c8320e90e6b63f7b3480dc6a4df165bfe9ad07249a83a48ab193384c7a3f22a0e8f9b4558df5218d63861dcd3068d4fab1f7421e3b5fb819df0fb0691150dd6	1	{}	2018-09-12 11:21:52.631978
b3bedb6a7852f6abf44a0a73e35c89ab2bc3efc018c50707944d4725aa255c3625f66da922bcee53cc775ca557b3f1747d08a0c2dfa66297438f4138533e0086	54	{}	2018-09-12 12:00:31.181768
f4a408de147d013a0a703e0864038d7ea2b44d4e29f0ecbbba5654923d2b3e43632b4ad6ac573359f3526569cad6d0f244f45cf28019439e292ef22b25dd9140	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-13 00:27:46.543127
1676f39099e9084383cc4b1a6439f4ba1223ebd4dcfbbeae7a878bc3c478fd2cf65b10180afe7ffca48f4cb5b21496dd19edbc6fec00ba46d5239aefff1e5207	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-12 13:19:49.349303
3cafcee2f0dd7620cad4950d26cc289754392cfaf8569a37d69bfbd9c1cd1b5a3a9c70d19a20caa218fa86edd1973f6c57f885fd73af038afa9b2c274cb568a3	1	{}	2018-09-12 13:27:51.922143
2aff79a2f4d858c0cc7c580d22369a654ab5fffe59008f031632742a21763519aa94d1c457158bb0085ea11001fefa4ab2bae2c632372a749bea2728e21d0546	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-12 21:34:10.700344
a9e657c8409bac2d5305395f044bf4d3a451be4008e18f703dadffeb850ba1fa3ef0440c7a8b477addd3fe21f9ef1b0d9dfef74422c75c0bfd4039dee5ddecb0	71	{}	2018-09-14 20:40:41.658728
233ca8bf5669e8a5db8f53f38910d334269a805c1f09cc01253e4c158ddd9240e586a62526d8e863595928e96bb88e243310f4f7e5c02bb5a45c09c4be4b9379	1	{}	2018-09-13 20:11:02.005905
0fb91c8e5cf51fd205be6b954e268140e7a3ac467eb24b865563dd27b2f4e7a40105c090170d40a17cb7f39a2eaba2689aa6c1658edf7d3edeb98388a97988cc	1	{}	2018-09-14 03:33:29.34177
859aaffc6b71624aede7e6f8281078d218414c7af9f88bc3e2922ee0362d5fdb5ed0f4ae246c47f0a3520dba85bb7c6a0e1f9edaab159e02b66b3255065f898b	1	{}	2018-09-14 23:09:13.983632
eb22fa08c0eb23c0cfc36ebbf815c8720e39ee85cb166711c40e32b9b8a95c1967ff74ff96726beee28050707b8df557f71440dcf3bbeccf0adae1219c3581d0	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-14 14:01:44.983763
ab4d710f30b9161faaa7ffb7db0f63c5c8b8bbc84f39312f6731fa080b0bad5c481d698418a406a387688489cbeb7ec143f1dfe0b7aee9d7b6ff6bd9b718a5aa	1	{}	2018-09-14 15:44:29.350185
b6f845c8a9f89a6f919d3946fb20ad83d5f3de711151fc156835802177df207ca1b6fce0cc7c35b569df802c31aca3e22307949502e36fabf14c15e0f21fdd23	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-14 23:53:49.013265
bae8d3dc18d44182c35031fca3726b569088747101c67f0368e4e5f6fd28f85bb49355813044b2cff23d4e0115a5542a945b3275122e698d2cd9e93d5a207654	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-14 15:51:28.538816
8465079a0a9048ae12e1c8631bc9cdfad74350e2e9637cc59a38e7380807b5f4681e0a636880021dc61175d1cde03431ed803e9e21bdf866b849475c4ae05ccb	1	{}	2018-09-14 23:44:56.7585
f9e894f3c16d9f4504a4b4714d5b1718749d2b740b4d0b297d0e774d1be048aae3bfa387cf7a606ff85538900479656706625df7c79df42c253a25ac1e30a3bd	1	{}	2018-09-16 12:46:26.957443
7a24b23cd79b7631efe4d447d1f1161d584b2251198d6da06a23f186af02b75a0a5f228914f7af315a3f63148cf8bfd166b201d75a3583038be3c4c454546ec5	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-16 21:08:53.520022
a04ebcb8799208502be9b789e1ca6962e09943dd950d6b496ef0edf468804b40cdaab5fdd4b49c29dec3a02361a1f2a21d9ba72034e3aba723a945067bb01f2b	1	{}	2018-09-17 16:31:32.181277
bf822835d75de99d383291b7d6670d1bb37dfd762093cabaf123b8d60bbd3db5586cfe05bd24f1dc1407e31eb153406458fd918e5b6e7fd2a0c4b8d60cd340d9	1	{}	2018-09-18 09:04:42.567065
1a15da975d36dcde6a712b34adda92d9cb5b975c215b77f8152905b08538de60b6cdedfc7951abbe7fc93fa68575d55d9cff6ec8e967a85b40b69de807efc256	1	{}	2018-09-19 09:50:12.657611
3dc8436f4082b9eeb25444ed836bd3b792cc0891202504ce38fc780c6e39acf6636e9d62fa3e8d80570b0128400bf28e9e68dcd50bab78a93c7808088e29a164	1	{}	2018-09-20 00:54:48.959321
03f79100f2cce060d2fefcce156e52d9b55e793e6f46aa622b34ecd1ab03cb8534636015d7d57b71247bee4e55ab38d312715020d690515a2b8c10a1f14ada62	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-09-21 17:52:44.77663
a8b797adfc5f5d29c598ead86ec59253db9c3e2fa3a23869770d3a3a5ee90d0e430d56a95f6a73ecdb1148337f6b061994432374af05af9a9762dca56a161e60	1	{}	2018-09-24 12:01:32.074452
8eacd073629ceab1ab36ed3a35a970e64e5cf4b687edaf40a8171568310668ef4b5ed620a0839658dade0c1d447d509a7d624f9604bfa6b529570e811402168a	1	{}	2018-09-28 11:44:01.29934
cbb5ac83a1f74c257ad6a03c9f4eb40708c47fbef4162d7758929e36ae5c84688a0738b7753bb4dfc21c40a4789216290850f37f2aa533b1e9e6f4d09238b7ae	1	{}	2018-09-28 13:56:16.924545
e77289faa8fc159dbb07c976c656890691926f9d6b8d9e560ff8db3333d5646cdb90414a33ad7fc2e11d622ed121f4155a63b82a0f2127f70c8ac7e7b44e8535	1	{}	2018-10-01 17:24:58.076428
a03c797b0eb6cbc275fcc67b1da29d5eddcd468ae1e7fd991f0617c17f0a55429042b2ee00085f846e9db6eca7b769c03282e4bbeba8413c15d22c13156909c7	1	{}	2018-10-02 08:27:52.054976
583711c3076384190e864167bb5d17198cece2d2f1aebbc2380d9c420c00a1e909614208a32e37df79a8e397552628be619542310833af559d70c0c43c44f5ca	27	{}	2018-10-02 09:54:53.014236
aced3f36b0322df8f654051ff4ee40cea308fc7e0a122f3a31ef05b94c478a181df33a99aa1d0e537c04411c736377e97ab030b05e88fef3f6f178ceeac78c8a	46	{}	2018-10-02 09:54:56.548308
18b6880eb6be2f4195a842b4c131dfb77d205bbb92f69947f1663e60b1cb913f4284d224f8d6167417a2d03f0f29ab1565edb0b83f45f5c5a11f0efa9c1b8459	64	{}	2018-10-02 09:55:01.602303
23ab833cf7d754c50aac8647fe3d3b478b18493c024a05afb776e661e314c67006041b1375f88144cc2d509db282c701f3d8a895b60a88464950c7ee9e6f2177	1	{}	2018-10-02 13:28:12.446483
197c8a5e1cf301f8a84f052eae5b80953120fb4a9b1db90bf833244ce3224a5226125d7f6f77b28ec27277a279531697d435dc6ba7f88de41ecadb8028609a15	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-10-02 13:43:15.993016
d94e7092d97798e9d9fb4a72020772e75db3edce1c4a850a12a095c50c4c32841db5dd2efc98c34975918e511f9b76373878ef06f01a35aeef2f4acd6ee3dc1e	1	{}	2018-10-03 14:12:27.522255
937bcc9c8f15ce8fd3b67cf9647f9aff0f54f8f9e274b002ed0d4703648e53f8fcff894953c593395a13b41f4adfcfe22e6329b05206e2e2cea1027cde8950f0	1	{}	2018-10-03 15:03:47.690903
ee8e6efee176e7e9f311bb116ae8d1537c9c9233c4171e412b07dab07c8d6e30b86699f06888ccd2e63724fd6a3a386b92fb9440bad032026fba64e984838918	1	{}	2018-10-08 20:45:53.362931
bf1dcfe9e66ba58be4b5784e92e05c3b75afeed1c498dbcf1e3b17fc56332cc19b69a182c994b862d8344f5450d78517e08113d3690cb2c2a661a39db39b44be	1	{}	2018-10-09 08:57:31.669763
b731fa8d9646305ed8ee6d84a99f87c0c1b86fbe53da8cd6edcebeb6ac9ae92fcec6f74ecbbda3f919a3e6e147dc728688cf6fbb29beb088ca097f33034f9bd9	1	{}	2018-10-10 15:56:29.450924
1f034cb7baa480c6652704a94234fba356466ffb0e1b8898ee843da8966d4c0edbb8ca2e90a27783fcf71d0ef6af6ce736f216ba99dac69805fe0570b25c04f0	1	{}	2018-10-13 22:40:46.883403
c62f31c3b24b3d638710a880f4df3a4237f0f62ae639c3916457466180f610767567b09d0106cb01046210c26ba198ffd185a06b0cb3183196e7fc1f4d3214f0	1	{}	2018-10-19 07:05:31.54808
6afedd1da309cc6f0b12c2b920dd27b260a5b84e7d75bb48c5f415dfc81bbdfbef40e13ede4bc4640a7ac3585e0667dc31ea60bb5201888b330fc5acef46fa60	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-10-15 19:50:40.062564
64b12c526e2b4df8130e98889fee42fc7483f3763a6da55b8d090fca467001328989dccf9784568e38e09e55d96c20a329875b4728ce3312cb121a532806ed50	1	{}	2018-10-16 00:57:54.675854
670b70182cd9badf76feb10fd18fa66548a0a09cc64bc17fba664e203b3082769b8619760dc19cfdcc42083ccaeabf4ba7fdad29cf1e812ecf2bf391a3b47080	1	{}	2018-10-16 08:58:15.638766
21ea7bb67eec7fe475c3a17cc17d8f160257fbeb9e02e2d06e83bd461116c9c6c8b814b768c10832ad75b08a4e9245da747396d6677442cde43012f69c9f254c	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-10-16 11:38:09.392055
51a0aa936b2133a6a1df3afaa63e74fdf8ba29854971eb30d2740a6719114467f9deee9286eda40028bb58b741e002c8a4755ad09f9f42754b69883a4935d952	1	{}	2018-10-17 13:09:16.181632
2714c9bf42fb8dd88336ee1d6d812e908dadd6175a4b17d0e1439dc084d3b674fd0f0188e86d72ae1fa4de4ac92e1c51a7fdc899dd374f241349f581afa5ab31	48	{}	2018-11-28 20:04:37.315028
d89f6a9bfc6b586991c02b58aa86a392473807135728a5988e6641b37f4631fa87a0cc2196cf4c143d23e7a6d07fc321a699a98b903a7940ca36b60c0590ab27	1	{}	2018-10-17 14:04:54.557388
4aab390f05ddbc87b3cb6bbbfe9396f8aaf30defac64dc957df6939316f0b39318c228a235abdaa037e3f704dfc9f2fbb22501c8353f647b8e28045b0b8e80be	1	{}	2018-10-18 04:44:35.591007
bf05d06c6db88bd2daeb1fa3bac653b79a665201926b18417f6d91892c3fa99393cc8094eb98d05c23dd578a7ea5690b3241b914b7d974d390c037e32052170d	1	{}	2018-10-21 17:01:51.883574
04af5beee0454c03bc6db6bb88304d037a0a0fb53f5c8e31c5f6b946e5648cc5c97bd4787980fb419c812ecb95a3fc0e2cb6dff2a244870e694a1bad1f73e327	1	{}	2018-10-22 02:44:14.725315
6644ee385d76d662334caec19c7df92b5597eea9d53075e4fe18e305eb24e00d65091d8a3202a87e629b95ac82a2d35282b1176c4410919c140f031b60e7367f	12	{}	2018-11-29 08:39:45.443876
b47617eb79436cd2453e9b47311406b1187e62e031bcce460af91650e51e858c3e24dee84aa7c491922ba5e3c1537a574ac6058cc11898986a19b02dc11328d0	1	{}	2018-11-29 23:41:15.605045
3e5bed96e22c662a06aff0de157df2e9fcb79a68ba5fb09faa58c168d1acd0ac13fd8e2c141451c5d1d31ccb626a71d9e2867d5a1ddc006d90b5410667fff5ed	12	{}	2018-11-30 03:19:16.43127
2b2ef941835e9b7bbbea4720fe8325ebbefc2a58bfabf65c0b96809eb1cdf14da86f171a720440e19aa437b068a1b849e97f8ade14480de2230e6ae3c391d6e9	102	{}	2019-01-14 07:20:07.9916
54e736a84a6af653c4df8c23f05147064aa194fda6fbb6c801cddab0259c75f6a070077bc32e1f2feb310d9bdfdbecece2603f492b8904331fd5827f6cb5d26e	27	{}	2018-10-30 09:30:01.461317
20855ae09774e2742b25da670cdbdf76437340776885e255db46c6b133efbb5d5073aeab60c0ee6f185e9070bc9d3b45257d5d8d16ca979de6830d6267f52d0d	25	{}	2018-10-30 09:30:04.927323
dc5489ea41bd68d7c073a35c2f5186e23a8a9999a6e488393324017d973f925675299893ef644ecbb3240e204d72b7a2dd2525a005c8b87346f2415d12df95bd	65	{}	2018-10-30 09:30:22.524227
f85581992a988343d1a72dc1f2e11cf2b36fc70ebab18194b10f34e3e229518debc425761387e71cc01770f2fbb90c302be45af4da7420cf4583cfb207488c2b	1	{}	2018-10-30 09:30:25.856906
56d72f77136573b44117f3ca36707c280ecc398f7003d03e64f27def40a9df07c1e29ca69b83315dcc4ffe5ab3a300f27829c6dd51c32a1f0fa3ea4d55fdad27	69	{}	2019-01-15 03:56:21.271801
108272a389a96daed29d2c295d6e03bba095bbeb975d24bb155caded8cdc7b8ad9e6b745d1a20c66e8b09237ad7eec0f6584c0666f6806976c23cd8f031336e1	16	{}	2018-11-02 15:50:29.093957
25be5ca176795fd882178aef9dc999580ecff0f0b2440302eabb2f891d6fc3534eae766a73e6dcb8327a9a402a95a34c702335540eb61804bc2b132581b373b9	22	{}	2018-11-03 13:35:37.68492
c21e3cb244b3ad9402f2d47105e3f23281bdfbe23b2a815024d7953c4faa278b79a53606a1420e4d59ed7150cd050a4244f2ab7059e1f264b15b2495ecf5d44f	1	{}	2018-11-03 15:02:22.120581
274e461054956e094b91f2561caebd384831b6552eac93acc701261ead835777721819263909ac9ad2bdb2d297a25c0e0411e6d183d2bbe71a5c050cf2a08770	73	{}	2018-11-03 15:09:19.156083
3f0822d724a8bba1bda51eab526cea8378d01d4a1caea06c3a1b7f2c34636b7cd75f54dd80566e8063d89135d6eccf575b9deffbf238982c0135b10759131595	1	{}	2018-11-03 17:22:39.689143
d3ca5082c7f35982d1b5cde230f85c8bb7694d0056175c5fb31385ce95da464ae62af1305613ea7612ab9c6d130c6e7528e95190b39eef4df09bb5655cca1b93	12	{}	2018-11-03 18:22:50.801426
c373f412bee2d91382981f3dad358140c06aa067206e527c09c9cf30ba23bb3c7d1ca4ebdab2010be970cdeca94bac438386e3da4777a575db4a1ba45c2f8272	1	{}	2018-11-04 05:46:36.053367
cd95ce6ca8f9fce001ed083bb8bb1265a1ed4db297b8aade7c0a8d2283fb08a308ea29a38724716e82c47104b6e8f4de25fdf09e91c6f0bfa89ec7b1ea8a28ea	1	{}	2018-11-05 01:37:38.162455
a0fe7f0bea50db0cc5195a37bc955b864e7ac9a0c9d42f3d4cd19479f4db5a5653daf40a69efe2a1b3dbb20c9662ed9f92ddf1bf15eeab07bc6df49d7711f33e	20	{}	2018-11-05 22:50:48.970623
db74a520b0362fe480a6d5b359c41bfac5c78fe57db238fe98c720a7c06144183b2add047e2d1bd5d46ebefd81e2db524eec9178202f7724f969fec545f501b1	1	{}	2018-11-06 09:27:10.163375
372b87a1edfbdec5a8d0106978cb215242dd6796dfd277ac14436fc32f09dfae69b564fc465352ba9ece1803d0347f039ac959bd5db4b41f440452b412915415	1	{}	2018-11-10 03:34:29.734411
3d76b20663811bec9192606f0aec5925db815625a3d34eac8d05a825d0729632ba527d14ab183cc3a6a4c10cf8f4b2f6bcb48e9cd7d24e7a610f8bfaf40876bf	12	{}	2018-11-08 06:27:10.353482
b0ec50f69d85e84dd8ca12c0a5165d38d0e6882ddf2b42f00789e8f80c309c36330322b19a49fb537df49f06c9a89f9eed4f008558078029cf0a8f0e1c9f08d0	1	{}	2018-11-08 13:49:23.540509
f89862f8e8db9af39de5dc5a2dc4824ba7a5191095ae01b38b347f5fd703611732cabd731742c1573cf0e04d20dbd21f0422663f3b50a8a47275c4f3959edb97	1	{}	2018-11-08 21:49:40.603274
a90f630077a6bf9e3b963c123e6d08a449ccf7fafbeb85933e6e13d937815ec4f2f6ef92dcc6e7952c0deb60a1cc849af456d7f291abe5fa22c2811d7c968af1	1	{}	2018-11-09 15:09:39.184687
4e854a48d3c4e3baff7e3ed16555f3ae8a82029fa4212cd04298cc4d5a22b764e4a1bfaa76c6125f179b42ac3a5f01b7122f82bbd45c47f918d40b375f0f449d	12	{}	2018-11-10 06:18:32.636198
45536a14a40a9fd03ce1492eae65a3253e9cdda7ac067afd81b6cbad6e15f10d0884ea022f8fdb796e03d4dcbfe218419bcb027d398372f00bf019af5bc6b593	1	{}	2018-11-10 23:01:25.185667
9db8a14c3394830aaa1aa32a9021cc5151189a864ae974d2a4fb4913ac95b76b8b91eb3b18d594ed45aac87c1c098a4a372342a85b90d23e48ba821f88bd98ea	1	{}	2018-11-12 19:29:10.433825
b6ae1223c276d8ab6696d9ff520f4fb00f3468a9f2f255887e367889886e79266cc3bb2117fa9a5902f6f14547d4979868c89444e6f4c11fa4bddcc64dad9f60	1	{}	2018-11-13 18:42:44.674175
8f2ea3ecee597c2298834f58193f629c7fefbb2284bb94553e2690e624b3ac80ab2d3267a350725435bb92fa0d62e63bf941625a629086f78fbf4f2b98bf5af3	1	{}	2018-11-14 13:56:02.190554
5435af6cd6522399a1350c576764adb02272b5b59666ec4469ee2b8e226c35b939970f30861327794fbf84c52a3dd6328c13a0ca18c01d130cc7af3034687e7f	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-14 22:55:12.813626
b6021b7c79a9b37c9489dff660115ed5794e15022ff40b210e47a32339867ee824eefc353c673ad6194ce724d04da90212953a9ef9e6c19d2ea0772ec4dce9d5	12	{}	2018-11-30 03:19:29.125712
77579f63ab1e38e7c1cf9c1d6e4ba7693382872715262e5048de95fb80a90c0b1858d4f0076b018a7a32fed0d6cfc61ae47a94c4ef3d2d29a233b25798394bc4	12	{}	2018-11-30 03:59:04.017055
448df98ba5a373b5d2d4c29967e8e5122c89e0f5f1502127a943caa59414660a50923773790d49dc4e4416919d5dd60e7617f303600bad4031b006a097f066cd	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-15 16:51:11.505236
a2cd8a6c6cea1c36da6255349cd4643d05d4fc9734de224e14a30a750574cfe9c9118a5ac3950eaefa5d1ed85db68ef0bab57311e3da969fb7be754c882f993f	1	{}	2018-11-19 11:11:05.759582
0c36c461ae9cf250d22f32b3ffe158a51446a4306fde3d563dd46eea19025b3b63fd4c54efe2d31fd9aa7ee13058a8915828e6f84dfa49d7bb4dbeb1c2058a70	74	{}	2018-11-30 03:59:15.872446
844689a7f500091c744d5b16eb1d200f7a05579cc1253c6ba6aeaf60952d61ae78dffdf5ae3a7aa6341605f71017c498a30323ebbe902ef4cb3749dfd5a77bf6	1	{}	2018-11-21 04:12:15.727587
b17e34c75022e6d1ac592010c66def3dc04c4c7522613afc5eff0def3cb6a7b1a9c1ae59019149d29b2bb62adf85d23dff711c4f05b3da4bb958304bd0469e1b	43	{}	2018-11-22 14:08:33.893176
03150a62acdf33dde03969f7f02a04f9899cc88152a87155bb6c75aed868c8b6a3df244ceeca9b6377245e3f1efbb15dfd1fd02fc159063b09677c57051cc602	83	{}	2018-12-07 14:09:28.809898
a87c158ae2c814292147210ace5b86969a19e9fc0e5fef7b431141da22581bc355596cfc8e9eb73ee0cc19098d6e44749fa18fc4f49d350fca65e3a97376d5b1	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-22 14:18:48.999413
2d363a734631c1a44df42a0a5c975a0552b6a34eef1ad0abf28297fe2ab0a093fd2f092a473d2aca80f01478affaa0f093c071c6c642a009ac8a57aaadfc5a9e	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-22 15:50:44.896556
d4b0f36e2ae417d70fcbf1e6fd2ef6d14fa44d7a92e0304a874e10fdd4ffd17f46cb8b53d8a2e9f26fbc7bdc5953101a756fd354adbbb0e58abb45c593c2be50	49	{}	2018-11-24 10:40:17.575009
e6b3c201f167f019fc1d01b35b928e896239914cc8f42a414aea871f2b013f3ee173c380dfa4f61b24e97f745fa0a62cf71858d3103f98684e5f1f5ab5e22985	1	{}	2018-11-24 10:40:21.244648
5f9eea8a641e9fe0d772010440dbbd174560fcb560ae99264341e71367ea62d51010484967cbef785bf8b6479135576d8753f01393339ccfb6a96aaf34b3bc9f	12	{}	2018-11-24 14:28:40.914839
4e32a2ae847c91ef7a5a59add22fd16172b1909ea7870d3e8b39899d60dc9e5724caa00d73fe717f63cc199df25322c083227b7e7a72b8f2ee4961eead759be2	1	{}	2018-11-25 01:12:50.758058
5b1fffc2a1bce1cba0ce0b87b729bdeea65313587769f19b975648172c5366abdb8088079674719c23cd3a34abe31f3ce7564320694c2162cc3cf66cd29ab980	1	{}	2018-11-26 04:33:32.27643
85477029e83dccb1af0abfb21d712e3d6f07808d28f8d565ed500d56955d41eafc7b8d92c86eb29099afbd6e75b61dbcb60471f7c4d3a192d103d303a91a7764	74	{}	2018-11-26 13:44:16.452208
d7fa98f6416bb1dd2ec51cd915589c478d56d26b26b3a44f98937559b790d20a365418f5c80b941dd91e6c346033bdda52d1c3bb9d58bd6792996def7ed9a9e0	12	{}	2018-11-26 13:46:07.304111
7a5fa54e6d446132d00ab6e6eeacd7f8a6917e58bd2a6d65282c59168c58d9589762d6be7cf696fa0578f702daaa526730f2fbe18b63300e935158663866d997	49	{}	2018-11-26 13:47:57.151493
d5cc4a42cb05c99072819c0735c7eefdb3313d526f7d5b12a4c80462cc87958d560a9efcd7e7d15359cf3f86ea06ef8c81a8ec08deb8b9cfbd5e00fcf4c96203	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-26 14:03:34.81691
ddac745322f804826130a02fcb2812912a6734ebf2d4a8e3b3b6481ac100877f40f92029dbc67a4cb1974134010250c2bb161804e914cf2504b1903463421399	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-26 14:16:08.562724
dda96b6109407cb7f2e590596863e1b589043caf1a0e7620b645cb21135fcadb3d2dee2fdcd1e86e51c29e98eaa2eb3f3d51ccb97783655fcfdcb131964a6fcd	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-26 14:05:09.086408
88dd86431963a7903d2bb4acef157e932adbfd01529b3d0c69d4f030b4391512e90954dc41287e05b339bd6bb65191f57a64716b8413a489466b7df33d8c2dba	49	{}	2018-11-26 14:31:00.124877
de25cbd11da5bb6f109285399e5c322417bd1f64901d64348c2dc006c03c4c82390e04233c386530547c16ecb2029dc4647e53280f9392d20d46db1ac34e6647	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-26 14:15:51.352337
e2f16787689729ba42e21a5f5e62ff0a49ad0246d66da7dc695830e72ad68ac1367c09cbca81383f861b15d704f15b91b6068660db6bd7b0d9f795422dfaa64e	12	{}	2018-11-26 14:31:02.259074
21e4fcb55db429348ebcc8eff948d5cfd18c2c189e2162b8f9d2152dc2989e3edf84e23aba3185d916e726e42d2a2d65c106b985ba083385d3703a3ed1eada9b	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-26 17:57:35.08571
6dc1bf4a4bd0941d050d69430936aeca71db7ae60bc1f683cd10311aa983f36955c6f664dd3847fb965aba4288d6e58cc03cfe975607fce0b9c1b5e7d26183d2	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-26 17:57:40.273323
71a3259feb5688bef90d3917932de28026b82254e08bf8581c8e05cb0e53ed45333430ce214ed55d7ae61af4e9ffcccc7776ef64f6f103ca950bc282f672dd3f	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-26 18:07:56.357587
4f554f3bb09e84437bc590180def945ecb896c4a530894b403ed2fcdbc57e7c8e0f5265e0131a4a0bb67b9109f99a4bdd6eab47244aa065dde87cf85317ccac7	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-26 18:08:20.472338
2c2dbd838ef966a5d0987b8bf65357565ddf996da145dc83d6a4078e20cdb31759222c2b48927ac7b8b82bc5bf099befb0e2aec2ac2f331cdff68bd96ad5167d	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-26 18:13:56.721982
f9bce3d619c4ab448d69ca013f22bf08d76854203b8316ed01b00bb6e5550b0b827a7fd41622731ac3c44ae9aa8ebdd783250c24f8fadfd663d25706cbaa642f	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-26 18:14:43.086128
f00b248f7286b9192e7a29ecd0b11dbd9b109fd9964798c4ab11c88326a79ca53d5dd064208a32606fd3b17fe7484a475d9abed0ae11dd5a2304e7f091bb01d6	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-26 18:16:02.922512
8d0ae61135fe9ec3c82f8f8977282925f453bd400e60faaaf8d97472b8307d6b1873816504bb0deecabc6a6724f4ec57c7d4e1f44cfe2b3b2f12d15b60bfef8b	49	{}	2018-11-26 22:18:28.895207
80addae55e4181a6fd79a8b1484287d587cbbc5faebf1bace822f7df746d5ff9dd42928705a9357707bb2cb8d67972aa95a3560dbc294128655a7a8c09f0f935	12	{}	2018-11-26 21:09:32.727932
7e61b41f51784f8e4178ef616e2932f0383c0ee5d3166476a4e64dfd65ad14afd6b515c1ec748772f47a020ab6309d2ecd1b87eb5b32415121fdccc1aa1af31d	12	{}	2018-11-26 22:17:24.405656
09320844d39847bf785df57716c11c66ab078eb2803efdcd4ff135e27c8eafe557166be88ff98600a9ab2dfa4b11e0708275e86e41d83f0a7c628ffe08badce3	49	{}	2018-11-26 22:19:33.446719
bcb237c43c2bef7e82180f42254d927d42b20bc2a8ded4d277ec5922e4e415a468e5506561e9cc9f2ff1a7f3ab230aad19d9d963e3acc6a8e1580eb39d0b91d9	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-27 10:08:08.582634
da8e4c5c04902f683125d169635041d7cb656d633f056f911d06228698860ea4b978dd1b77f41d43492fc4a6fcb5218fff00da724ab1ad89d84ba6bb33a05b7a	12	{}	2018-11-30 03:19:57.176008
859b01cc5652cf18c852b3ecb0094c47dc2f75bd4258b9cbe90707ccc72db2109880626c36b78c43621d76ea4024f88af48869147bba968ac91b776c1e6f7e82	49	{}	2018-12-06 02:22:51.459469
a4d140fe5bb750a04ffcebd25d6db343eb971ffbf2e86b5f3c67523c725857e9b96ba3ed0ea12c173249e3ba642607270fee25ebb1c8f5291ca4e01fcbd8b6d1	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-27 10:07:06.433267
383b7938af34a18a2025f5e532ce65e7c977626a22d0833425a158ee786cc0d8cbc383ce99e336cd0df545909c72a24e724fb5f0d23a8fba12d94081622d6e59	43	{}	2018-11-27 10:07:13.565561
114507e035d379c59f8c0738a4d98a13e42b6ee3feebe5ccf91e024da250fb60d0a10e502c1d4b85d26946786c594e359666faadffa0835aa9688b005f69aef6	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-27 10:07:40.543125
28a9482bbb322324ea6104ff43c2c87d882723b565c2690fe18517a142787af84de2523be5ad372ac09c94b89efa2fa8c38e337b7f304e1527d8824d6ac3d5ca	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-27 10:08:39.639209
43a10bfb00849704ac2a81a2210917147f5d391fb6f97540d744caf4aca689060df343155bb1a0a23d1258ea7b4a9da76b8c22db8ef5af3fc1ab9b4240c4c6cf	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-27 10:08:02.164494
4ca37d94c82103822bae9498613a2264af191600e3b8454910d7b886564a72478f7b1f5606cca8525c2236367fd20f40c8cae690cf1c6157660b202c55bfcd18	57	{}	2018-11-27 10:11:14.772358
0f8eb3da756938c46528b0fefe7b59e04b70011f7f35b84d5168c23bd24f9a9f68afa8bc9276d4520b42f9a2f5fe3d218aa87d16aef79d86a4b2d8f1d4c5c5f0	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-27 10:11:37.317481
895200e1867f89cd15bce9168a82e52c3ae5127fb70379602be704d2bedeb6e991f79c4eca66f45913b5e897c4f21e6baf86a341ff79863aae70df947071ce94	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-27 10:09:45.756307
32b79ae765ada85069531e4a51b3f402224488e8d42a9f9d31d462a991f868defb4a09d92461bfdf68a0ab2710f4e3f85314fda9705887cac5b26b740c455bb0	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-27 10:18:28.867814
31347ff25f6e39b489c525127dc3697d197bb839aec475365b8687b3be36081ad142106cd2557589db36c47a6d7335b9a41817b2a84a99bd815742ec33823b25	1	{}	2018-11-27 13:33:42.365881
e4e9ca81d239c863b8c26f6c414bcea846307f95163990e30d19c4fc27bbd801601f00eaac9012393d2c074f2b3c155e93a9d6bd0f7859784553fac111562911	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-27 10:23:15.852478
a5133c65ac79b2aa976a2bf002f52fbe31b78b51f225e3a72841068d3488ecf7840e3fba4287febf5c2f86a518ba5508916ff66797b829273063962f2fb1a619	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-27 14:09:37.981844
03c5a31a3c544ed3308e3c4061d877fcd8a99ce071ab61a94b6e164208c3aad5f40ba2c30f1c80933c1fd7591f265d450ae4008fc9976f1d805947697e93fd51	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-27 14:09:48.430637
6dba34e5ecc599ab6b2861d1790db9693056378c0182f467d6791aa50ebb599ec4b8eb933742e3e6ef96bcadf44ba430f7601d24566aaa377bdb00bf5c3e22c8	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-27 14:10:29.39319
0fd14f4bce6188ceca63827fc52dcba02deaeee6021ed2c608c2195c6104efbc37bd690919e866f56a6731eb9ce8277439f20304bc98541df7fefc3e4409a012	74	{}	2018-11-27 14:11:03.659891
5b5ae1e21bfbc86fcf5ae28add678c665023835a4345f898a3c378ce0c8c301d4032065f4a9887d28ca03da3e1ba3eddde38969b62cf9e82838d5d13ec875113	62	{}	2018-11-27 14:11:09.565144
65de61804c0d48c3a5c2d2ea77617f14c23dc05531a20fc44ad3e6046135c1806de1efe87ad2f3bd83d24b8cd3bf701533c2341be23e72e51cc304c1835b610a	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-27 14:11:28.432671
5851500c70329cc05cae8732ecd941feb2ffbe5c94748476fbd432e7bc364b847db44aa5e7d79580963f194ebfd082dd0c40cc85fff40fdd8b3608158b660e56	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-27 14:12:26.342149
56d3a6e77a2a0b2acc83d9d3584af8a15cca9cc7d3f66aa65bb858f711ef12ff0f322460494d2900c1f4f79c2c0f1d24c1704b6d94207277d81e0a33883ba254	37	{}	2018-11-27 14:18:11.934708
35b14e3aebcb965bef8a2c3811dcaf3d878083ef4ebb71df90a7738d3fd48260f115e9ff08d19a863fb8595755aee54758d457233ffaac3a68d2e8cffd032ef2	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-27 14:19:55.521986
90fd509ef0d8b59af0f9792908e680b7e8c43f71e34ddaa26b39e2ccc209890e13a8e5940c7f8bfb32606c1df4de2bb13e6d446dbc991821c077efd0094010ae	49	{}	2018-11-27 14:19:56.07689
8bfde7d88d382d54d74065ce13886a4b05a9ea789d78838fffafff80ce7e98de8da31e93c86f20a677c1259e850254cca5a5c323c899012de0f51a4009e7d94a	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-27 14:21:41.243125
dafbf8197a08c2690a4b621d42b4abd267b379786ef171146a08db4e5d69672d9c712af7a906c5aa7793e93f52d2e9a6db0df8dcb5710ba176d1919abb694f0e	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-27 14:23:22.949344
9df5a952f132929994b9254c687eb4ad8b295bb0386058baeb0ae88625a45829535be5f4d97252d5c687c3812dd95f3d0e8ee2f61c83f11d04c9d72c7f40bf67	49	{}	2018-11-28 12:18:17.454288
d05dcc78a1ae4387c1bec47c9826075e47d3ede6eb5b8e2591234e6abd4b8fa255330acc4cb0065516a1b659857abc95f26bbcee5e8c969a1b668b5ff342c491	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-28 12:07:46.219465
2817887e3325df9a0ccd9b8ac10ab848dce352d28eb74200d614454f9b481730bf093f4155f2420e30742cd956c936a41920f958199cc98a495f26bb88218a3f	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-28 12:18:23.137341
6a9b2464943964eb7106ef1519168e20ca8a577a82f500c7d126fbf91de2d1322b1afa92eeb3a16dcb7ea5bb76b4d61bc47129c379312eb4b27a74110cd4ac81	48	{}	2018-11-28 13:21:08.155928
9ec1238d41a1dab855029df0398f5480dd87d23acec2b420e25c0543882fc3c3a159d38ce3867e05c9ff2c81f619752beb31e877455a012f9337010fe47e60b7	26	{}	2018-11-28 13:21:30.406839
3c5eb8c778dd3adbee31073b62fc83895b0c7637c24b23e65037dc2ecb806b619a1f3fcb865cd275378ee6a6ee023a8e9b042ab7e6815a0a350e972cbebe1c9f	49	{}	2018-11-28 13:22:03.372246
c11799ac722cfbe34159a22e1073e87ecc6df3955d30deaa50728de8e1320e38d3c76ae47a547df5f5d64fdddc02afbba18a7986112ef816c6df001058f83e41	20	{}	2018-11-28 13:22:35.660459
4e9978de09a1718b6b38156762e1f5d54ac98e97d7822e203065d522cd442bdfac20723780485f48bddafff72a75f79c979175b5c1b474d7faea50bc15c1be47	55	{}	2018-11-28 13:22:42.352324
f2c71028dae3d3dd9f71f46d96560aca1805f5d38c7571ea820d468ff94e7c8d2067f0390239791a53117659667030833fff0350d02dca403434c9d20ee7483d	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-28 13:43:23.561028
a9bbb0bcd5eada9c38050879a7b7ca4072723ee41fc71506a2bdc884b701f29df8553923a329bccd1f49dea099b50a63a2e3b68c951d7ca0db7604966d1b3843	76	{}	2018-11-28 13:25:47.099681
b348e5f29cda11f9b10550ad05ef208e9062d3912c4f559b068efa23ee0d35585c981635f18bb8dee6f136f68faf7ce2a1f9c464e10bf5166e89f420efb1af6a	81	{}	2018-12-06 02:23:11.573655
3d410b94ac66a207a33e110a5301917f504aca2c33ff588c4c3834c441392406066868e2795f8260f22b507761d5996b25a69039887690b9a248cb21184c7aac	82	{}	2018-12-12 17:10:08.945403
b05abf4003ebaf6e422f9fd297d1403943fcef390e05d36d249f28ad6dff412c653a31ef5bec8c2b59ee8028d935cc3473d56829a93c69eb940296d0e82a87f5	82	{}	2018-12-07 16:35:45.146052
faa8e5b674b35cbfe30e22387be0c6ff560493ea76a4577c64b5f12f3348702f5e880af61cf927d8c5f12070a84831c015b239a3b727a351127f89ff8587c574	62	{}	2018-11-30 03:59:10.882678
6741e18937a15c944a7314e73be069342b86401f148e455c31a2dd42491c42443489ca26269aa50049c9df38021d92aa4db514d9f1ab6c971dcd5d7fe6b60b69	81	{}	2018-12-06 10:21:33.05365
de0e14a41f50d6431fe706cbb818303d8b98269958ae89be6f58736e34f981c0ebedc708c9b8f8f4be65befb9479d0feeae334bf8d788a7c3834841edd5e7a53	49	{}	2018-12-07 17:04:56.993196
2de6da77789eec40fd4e95336f257ac6ba5dee811a1996a8713748c2e47126b10f0240ceade2776a46c171ba6e430ddceb1caf1d019d5619ed70d1cdb3876333	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-28 13:43:47.757032
7dfdad3316b3b59fa00ddf5222dc63d30f07d07df7f8f47c205e70a3ce4f8cefc753493ae234ac96966cf71b1259b872cf460221d0e96589a29ad51d5047be6f	46	{}	2018-11-28 13:55:47.498937
62debef358d3edb5a18c2d0aaa1489dadc9d65a835869c8083c8731018892baa431ee11490cc51259cf42156a0078b9fbffc31909119a24fc2f232710be4733b	48	{}	2018-12-07 20:54:07.203185
213a947cc884d36d89f23aa30659dfdd407b77251283e685b7bf0d2a801a3eb0008e4288fd288badd5009895f8c10cc5772950cc89411753bb717fcf37b1c4fd	16	{}	2018-11-28 13:57:05.966443
bdebb5dde96dca9858a4403eca321006dc5700038b8c81af47a1dad265f57d66ef27405770dc439cdfd7623692f62860597ff5ce5ffb72f0b8ab9313e71ae5c6	27	{}	2018-11-28 13:57:10.834262
f4528dfeeafa9c0d96358ae4271286d8fc946da304217916ee6aa2a8b596b899467a23c778d717d93328b0a7b8082885086e34b875d334c71af0174ed1b51f06	48	{}	2018-11-28 14:01:47.684019
2be047819c606f3416956ba196c53fd6d6bffbb25414ca2cebc4d4042286b30920e427abc3fc1b0a0b36c25afb489cde4501c07e58a5d325082dcdbeee1c300b	48	{}	2018-11-28 14:06:50.631476
abf849db75a765449fffa2ee6b829f81f4e3beceb4c9528d856dac0ae79e73e4c15e885396715df83a823e3bce0ad85513c97184adc962acffc69a712767e97c	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-28 14:18:52.172335
0fe2c0deb0027131a1883319c1a044d754ab364559fd5128dccc76a8c20dbd1c8e22ee25be622260bddd6e17d212b8f102ee4f2b886a99cf4b38fb7c6b9775fc	48	{}	2018-11-28 14:19:14.584726
3b57ecbb47e1a4493eea9892e44a6565d574b1f6a029840d692ef559021fbad92634f59e1c48c7fb7ddec2677fc0f5d38adc74acc891c5123e60131047549376	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-28 14:09:22.558882
d6a288e2d4bd1f224b1e0a7529be208f32df4469e34b5e23d32308d3b9b053a535c5d75630f33cba3a8a6fce4621609e905a60ceba4e8679361f93298caa7714	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-28 14:09:27.095687
f7c97a6367b26463d621c3bbb694d22ebdfb1d865e5945fb94c100838b83959d942cf94e76478bb317c159cd5211c163a6c1c10d6403426a0e4c0801b28add0f	55	{}	2018-11-28 14:19:22.194614
ebc6c86a7a2e424055e7eb46ddedae14459ba77a3fbcac56413d074d92f11e205a35b1a28246a6a58a72149218278ff8314244cf696c3d11cf255943a562fb6d	12	{}	2018-11-28 14:10:19.622075
35505f660b5dcae2cc48b659af67f616c8c8e948a6873917b38a8e44e33cb27191454cb4e6c4020f5aa3fafdff8f954923c15bd35e95e6b7e4f415a871b5b3b1	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-30 16:16:45.172467
af5270e75d532b8851b114f61059fea7e2b4fb7c8c18c439c4aa6dfe98911e2fb7fce546809a0da1c2404a4dc35d2a644e5434d59fa24274e158e01b436f25ee	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-30 16:18:15.715694
d238784aa2335241dd815ac262dc48bdfb7645b1291a657e96e16e43d4adc89280c0f4908c7ec692e4f84feddc6e424afde8cb263e3c985553776b051fbd3414	12	{}	2018-11-30 16:19:26.31148
92c35c739318b9bc6631338147206555ff27e272c899506fa443a26ab5c5f26b9be8aad2b05c1f1ba616a624a9f4abea700f420b26b10b4441bae662c0e57026	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-28 14:20:00.966861
72d44704e820964735b384ad2b747ee476089cdc388e0955d39b63a16768b43565345c09cb8ee3f30b2dc4dedf070bb213688af41c891402346e23a0966d0092	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-30 16:27:09.987674
95ba8f295d5be7c15c9fbc6a571ddd4bc65cc2aea6eb2e6d1f92fb59fbec675464b478108a1100e17c1d174a144bdbd5beab49cf2d330c3ff42aec957926e3ae	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-11-30 16:28:47.075045
9b7509516fc9341ef1094b9a67d45ebfbdcd3f43f0a25209c67adf59f80d7ab6a6bce84f2bce59ee067121f1940d140e65002e084de47183e857fc21dbc2ea08	49	{}	2018-11-30 16:34:46.016237
96e4587f210f7ab1a9640b368f80323ed794e1e0d2b4d835d2798bd50af494a02ff97c1f0ba7ff0d8b8bb7d3e5ab4eaa8f29a4a43ce8e9218f304f12a9318910	12	{}	2018-11-30 16:34:54.162306
91006cf472fc70a9a242f8fe31b270674f410f39cfa9f6ad18cdd94e57bff71b830fcf320d4e4acff932851bab9511a71729460867d599b11a7f5c092f518033	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-11-30 18:48:14.133522
f226c5d8b6fa2d9e92a6a805af53723eadf9d6770a09b780837e2190fbc8d15be21209a7aaf32e96ddf7195d7870fa0f31ac4461900d9708d3e70feb641831f3	1	{}	2018-11-30 21:22:06.654875
958a5d3ba6cef811b7a2390163124f98b3511ed214d26df777e34c1a7ef91624516b2e89b697665be21c874abf729630f8fe986b6153c9e659e1b93717e8764c	1	{}	2018-12-01 05:20:33.095913
b4337fd634f14e0a8f621a1ec459e07df5bc4178fde5d0b26f6631aadefd66145810a9165a295cda89b6eb4ce28fcb755df85f04555c97ece188e2bdb4741cb6	1	{}	2018-12-01 09:40:04.060988
8983aeec3e2a8cc156eda619bd1f2a775911573b9e4223c48619170734511fd0b233a3d8c48f02e6bfa1f1fd6337019b3772c69ed4d4c0df4981bd7464baffbf	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-01 11:22:49.107162
6ea0ebe59ef12438686ab3aa7c1a6dba23b1444e176b01700a683d5fe9728b3bd32a114b92e2e5a20b1f8fc4720155f3a95812ee220a0e25cd306adcdc720b5e	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-01 13:35:10.349058
f966f182fb8891168034b7c853fea6035b6334c2e0f45c528853e3a40e46a4ad7b01301c4d350bf3e74b2e3f2d53aee127ee7e4c69850d89dbb273fcd5ffa950	1	{}	2018-12-01 14:27:31.979897
00df4ccb08e9cb2ba9dd2b115c10ab01bba816470669faf54f3dd133dd3b73c9a99d1eb485297b602d2d72a60cf40c01186feccf8d5f25cee35ea17220230dd6	49	{}	2018-12-01 20:15:18.217865
ba17c2744dc24dda34989c0f15fa89cd6485fe14e61251c16e42c944ba42a05847037e88612fc4d0fb724e3bfd68352b03726d7d59f0d391cdc92b7f50397fde	12	{}	2018-12-02 16:36:51.370062
c5c6aceaeb041c09e674c98eed7f39d5fda9d2898b001ac45db4190d7cb4a183443819458c4b622495d4292ced204937563feabe76e12558c46783f2f9f3a328	1	{}	2018-12-03 11:25:40.210278
67df652a3c7d21ed986acd06ae39442e710e18a058cb8b5b808b69144efd962af8befe13e7e913719ece923455b9460dd137f5a06efec6b5c9569d80e85600d2	46	{}	2018-12-03 13:28:39.821273
71ff99fe16fc507e537c0baf338c864c1d116d5430570713341080cb21550f03cfdf1d3f52bd4a91597ee29586d198c93d4161b8ba0f117d4fa323b506a25f33	12	{}	2018-12-11 04:06:24.756906
f80fbf2b4146066d06600222eb6f97b6a261d6cd2d117b3cb4a721c8acd10440865c523d353ee30c31075bc9d177f4029e170816ceca789a9042adf715c3ea27	48	{}	2018-12-14 17:53:33.358193
8a222c737a92a19b9d06b956707821a010721ec5e4f616ccb39c79ece9982de086559999aa786f9913e8304cc219d28a51e0222039b2b4bd5f2df6eba8e559c1	95	{}	2018-12-21 23:03:36.942692
8b834138dea8f6d181fd2564858226995ab7ff00780641348227052708089e76e1448750986b0da7a3162dffaa32f426c16cb3f5799b3ebdcde36f29b9b68436	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-03 18:09:37.366904
2daa58cd46520202f0f2542783834785c3397c8974c3789bfe265713b485b81b27cc0eb578a4c91a0e19c87f0805f9e656a2f14c660a384009d7ba8d50ccc9cd	49	{}	2018-12-07 17:22:14.357131
3a4e35a5358bdd8353184309b78ee00493f20833c57ae00a715a1529db629d68c4fc298d57b0cf0742d21e2ebf76e4ddcd8fa57e300a864c5efe4fcc7c0da6ae	48	{}	2018-12-03 18:59:32.734746
04b7194e241dd683f38c34999a2b999fc8628da2cbbe63eb2bfe6b0510644618511e96fe609c3ca40f09dd28e65d1ce21abff0bcc92f9f90bdab908ba08228c5	1	{}	2018-12-06 05:49:14.709231
15c486c2aab7ff431bec20845896cb77074dfea4117b9f926b7d98051586bf237ee510632e6d3b0dbf68632e9da914f49248d44933b24f0fcde40cfb5f182aae	88	{}	2018-12-20 16:10:31.967072
b79402a904f42cb0483ab519b08436f49e28c0f57cbbb1a21c031e6aa452ac21d4ab9c05b790cc687463f4b72b2653c22a61ad761c03ef4719f85f57e20cf69d	55	{}	2018-12-14 20:31:51.999044
c11a87454fc9a051e02349d1931fc9d470fa53cf8ebe7a3c17d171f4ce408e9b4f3d6b66f366f0b0a80d0d0b47fee7e842347232990768ef121eb4ec629a9031	20	{}	2018-12-03 23:47:46.403195
45929c99c6b4fd806b35bd9403191686a02ffe640ba42659717b8c0d27dee7d6f6115b76421d1c0e0901c036a078011b75e1b85fc2514329b80db722fc04e84f	49	{}	2018-12-14 23:45:39.259271
94b2e499c6a5f696092730e4eb0c45251d5c85f5397889072d050fe0d3f002605080b4aeb73299d58bdf77c59a1c221f47b7814166b8573ab81ececfca0795ea	27	{}	2018-12-15 00:46:09.467697
56049914358c3ba26985639179c4285435eb091b43c4035b20f35f615c7829476230545e90c2cdb99d18152fa7938ab52fb86fa2638738de20c2ddc1c8142fb5	82	{}	2018-12-19 18:26:25.768957
3b246b6c8e06cd51fd4cf27d851d98353f1ef3eb7f6de97c00a5ac33c745687c663dd358b0b00c5664da94dd51c4987d7765079edf125ef0c8d98649907694e9	90	{}	2018-12-20 09:12:55.188888
41eaac53152308de32fb483649088f7821bd6cff839e46b4f3bcf19d22f2e6e59f871b2696ba6a6051f2de6f756eb33f33a8fcfd48343813368e887062efd926	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-04 00:05:38.369542
1b791768472a016a38842c2bb116ea1b20d74da137a2977555c669b010b045bcd912513d6c6a28fb0d92be97e6217ca642d6fb63318dd6a2821527779204ff84	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-04 00:21:14.063351
8ea70b969e7af822fa59657558161749628dfc7605dc761b9f84785d37ff551f04840d5b657faae53f2935ae8096495b162bd548cad916ce057c2e0cb8026dae	79	{}	2018-12-04 09:36:58.297768
684bd5b03a1ab3bc7172cae8d9bd1ed79aca2c968b88cf5e56933646d024948e410e350212df6776f3003ecf9120acf4021969010e859d5cca2f0419860655f1	79	{}	2018-12-04 09:42:29.490791
5a1df532486d0e30f6a76d72d46af01dfca99100bbf593c7eae9566cd3c5cecabc05104953019354da3bf30970275a8c98fafbbc4d06443a8311ce18b4828f90	48	{}	2018-12-04 10:27:53.464477
3238200e8fa1528ed094d4ae7afb1aba50563c59ec59e7d14f2939d1b92054e461ccdb033683b382b628034c0e6ef76e9c5204e7ac263b16b53cd636dd93720d	79	{}	2018-12-04 10:28:42.038436
c7c020c07912514b3473a7ebfd9a5b1e5282c42850588615f465b3b317a1f2577b9f4c6b8c75f735613d1d85fe311529a37a02ec3845bcf773628ba92c9b715d	12	{}	2018-12-05 05:02:04.49457
119ad19e13cbbb3bfaa2b5fe00d268854328c546c1e4b5ba0d3f753bbae2debc79d67b8aabc1e8bb93db7550fa7dbbf25b16370b7b45b608476006a8856b1052	75	{}	2018-12-05 11:15:02.525173
c6811a92ea40a03f37fe3d2b5548d18b45edfe00ff31ffcce97526683d99e1ff4c88417ebc16470b4593e4369eb825b13a0ffc37b1c24db1425cb446e1f9dc12	79	{}	2018-12-04 18:36:49.243084
dee8dba83698efeb66b7bef43f0be07ffa12b558dd58d8df3d2fff4220cf25a7b07ceb3f9baf9a1f8e00dbd0e1b130ec2a8eeae6f294308fbe0820bb416a26d8	63	{}	2018-12-05 11:15:13.362428
bafe1dbf3616a459ee504a6c7f6c89636d39dc44bcbfd15734df09de27a64a4721695fef62d85bc8f5a6739ffa6d0062ca0ef02dedac1433f9067372330fa402	1	{}	2018-12-05 13:14:02.524845
a554e96b18a0228379b09cee5a9268580b28f39535312a9349ef5dc11056885bdf0da5125973bdeba7b3cd2b09878d7cd6e5f78dab2dd80019094b4ed33db37b	12	{}	2018-12-05 14:53:48.70218
052c42ba154a094044a64bd3542f25ce58991b434f6085d2ebb61d2c5341bf44f84259340d27e19e4c6608c2b1c872e1ca6837320f9c0d92350061df4c9273b6	12	{}	2018-12-05 17:25:54.418002
f9e33c9ec9517a17b37edaa402aa677ba408c364deb9d6081cf17220f5bc6214cff9dd24e5a9200f07a336f50d64a5b83e2c4edd8ca704d4379eb43fbaa89a9f	49	{}	2018-12-05 19:09:24.209946
b04137e1b328e1bb8dc474a587c43ccd6990f533e18dd6037dda57a18d0d33aaa37c094adf02b881f2ab01d35b2a6ba0c6dbdba293b8334ec9aaf1c632eee556	49	{}	2018-12-05 19:39:16.634439
30f7895264c1120a88402641f5e2624d230e59216f52914df93db4893b539191e45af302e0055e2cb8ccbdcebcde302b9137e51d28ba1e0c968f951f398f26a1	12	{}	2018-12-06 23:18:12.478284
5186cf8e8fc40a28cd14e776bebd96c6ebddb3d149cb3a8d114686a3fa83270bcab3d7d812108893450d288518271d4171eccf0e52dfa449482360092cf1ed4d	49	{}	2018-12-05 22:29:26.864308
9679c5ed335e2ba1528998f2ae0fa0eff725b011127a8908fdc0cc90e24155cb7faa4194a1ad2288ce581d9702611921eb4e41f48d948b143c6e39fc268fb76f	82	{}	2018-12-06 23:25:54.436857
f435f16dea1b3e592a986887053dfd0b5f1c4181e1aad4102047ae3b6094c9315628c79e4fb3be1af9015b11f4d546f8ca6edb2aaa9ddd46331a1152f9d402cb	12	{}	2018-12-07 14:13:24.025422
34427928526a56071241bff3c1bdf0af2672182946e7f54421d2ba8a39e0f0ae48b7882703af3e6388a1724d99106f94315dd65b2602531afb245bda16944d52	65	{}	2018-12-07 15:13:22.843487
c3d85e52bbdaf8e7bf7f8acf72c23987f2ac944e9f92f44c6d457f5921c67c5145115ec67b81d920f17a41f5ebe070666b17990ec0e9d7b6df436ee464a8432e	74	{}	2018-12-06 01:08:54.103844
4a23a95fd764691139c016ff49edb466f1ca45b85324866e2ed851effc2d18cdfe40a7976f04c9ef48d29aad60bfc3d88ebe62d1767fc0b1ba631bc7a23bda44	72	{}	2018-12-06 01:09:02.884006
f044438a1b2d6823299c719267fd05271105518a5e1a2eb03fe645a20b43fd8ee41df126c447af52837355e3a288ae2ef64e675176d308b98ce572676905f24e	76	{}	2018-12-06 01:09:07.894279
a13225e3eded2c870e6bca73951ae0b40444613a526855fda663d6f57810698632d4d525724cc1f9fa3f32f811c7a1b30b0a8a2435ea2d5e2bcdef3ae68411d8	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-06 01:26:38.685215
f392cbe281a4796be546970301df122a85a4929c8f45177765cc1c5e8581f321237e8a0b731ff955b7b9973426adc60fe8ba96b234c96eeb5e20829b15388d4a	12	{}	2018-12-11 04:42:34.733955
0ad33223399020cc8d48d34304738a9bd4f68735c76dc7ae745fe39b5a304a33a952c2797ffb810d531cfa6c97de3674ab77f5f08356e38c7326f77b703558d8	87	{}	2018-12-12 16:08:10.591685
795d170aac6f0fdd0e203ef91fade8824a1d1434088fa55032b62d338b1e3de40fe7800b40a0a22697878958e5db1061f6aa8f9554c4baca33ed43dcf8a103e0	74	{}	2018-12-12 16:23:43.621627
0248ccddcd3fb84111f68898a7157f256e9ce9cf9496ee078a241714b4621af45a9f89c9b69d85f2edce5cb7c1a00a36b8991a42212fa4230184a6a633d0cb81	82	{}	2018-12-12 17:10:14.068643
747f5cd9d5dde556078247f70a050da8b6dabfc75f4c30511cd35379cc3ad6b906769d25a9981d8f0e095ff5d2e89c36789dcd2fe98b4777113ce3fda6a8a5e3	12	{}	2018-12-06 17:05:38.657411
92c1aa28b5e6feb5250bcd7b1c9a7f22129382bcb6a719ec5681a54b6eb62567fa612837fe775af859664f5bac04f09dd6007df9c394b2c4b51ff2f33d20fbac	49	{}	2018-12-07 16:39:03.578806
7bc64f04eb65334617464dca2bde9c85b9440a4d2beb2d201147fd6c82ac6977cf8c9c514156f62c1f0f3446b7f9fabc5e1ec730a074bbf4a72f65c4d4ebe6bd	81	{}	2018-12-06 01:46:58.543564
b5e45553f8b92c43ce59d9be86b98fd403e553786bc7e76100682555b3d50fce7851a33c3b35fb12b54f68311caecfd97a258330df4cb834b473f52ccccabdde	43	{}	2018-12-11 11:36:36.201518
03c8c57e51365a41017592dd3f3f7855bb12b155f71b714616099357b9a734558525faa1654202ce4b74eadffb74a5e1682b0698e702a6dce74b30c7eb798d58	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-06 17:27:44.343421
9d6e75c19920c0416d3eff626e08ef8504cd0c7324d0032693babd13c100447102dd57f2ffcaa32bd37fdd943b815a46b6af6140083c676a8bda9593b4eb9818	79	{}	2018-12-07 17:24:48.497819
82227c19643b7f1c71ccbdb032de336839aab6e1ce042dbb8617415368f216f426521ac85a526fe4325be4d59fb366bedd365d569bc94216644f0373133bf9f1	1	{}	2018-12-06 02:01:34.237927
1f2b4c6bdcc45d64364c84d10dc0029c97663a146e8f6bc3e89900c27d076daaa7816550c57614fb2ea304790956b6e214331babc1b731143ccdb97e80f5c1fd	51	{}	2018-12-06 02:03:23.94937
d9857d816afa9f8146387448d032d5bb78f6ce991b38ca69c946b8ade903604359171b629313d44f28e376bb1a6e72b1b60376ab560e94f1c7d0478569a07c9d	81	{}	2018-12-07 18:11:41.953804
85588725781f7029835cc896a27e68c105df91381e26d87225946d731b68ac7c5fad3d089e55b32c96db93bbbf4384643c946dafd54becad19ded7b20cdaa07f	79	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2018-12-07 18:32:06.735406
5b3fb6cbecae2c866de223e6f67028c877b4b8c3c7ae9a060349e0687ebb40bc9068133318c8afd08dfe0e61e14da7e08429eb40ff2d986c075853a5c527cf7c	49	{}	2018-12-06 23:18:18.268125
f431a0dc2a3118206411b69983090d9901dbd184c9a186d5b0e7744722dffbe166b079ed152bde354e292290684d4f674f1a75d89a99d5b59f825c1b4a2d1275	12	{}	2018-12-07 15:06:31.981267
a1d30b4905f1196af7cc6ee7d16ec2ff8ed69d1f0cf7145256dc04f9877a3683bdc8e6fc97911c81eef939b7610d4f59538ae5b4e3c5809ea3f844db51116337	81	{}	2018-12-07 20:21:22.972829
d802ee3d61eaa9dfd533d6f1a5eb845345b6f27d10cbb3ade63fe27efb306fa34083a3ccf46754323d835d3e270b98b194731c877e9d98c52d94cca0dad2e87b	12	{}	2018-12-08 04:35:15.729121
4dfc2ce6be64851b90f8a90d5667b7fc72e9d5038b065a0b64ce49b8517b0cb1b9de78fe896e0a2d5ba347261c9874fe04f5a518f0854f19f20650b32f909318	48	{}	2018-12-08 06:42:12.426866
27239c82b2dabb3683eb9d66c208b475a8cf7044a04bad602cf3bc4992cd5a5bab6c2662a8f8e074f7b8378f6ff8f75dbdc6974da6b8f99cab8440f46d39656d	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-08 15:11:53.415371
524a72815ea5078286305adae60c3174bd419babb3e949a5e21c9ada6093b9c8a42127fa15bec74ff6eadd05221f8e64a3599d2be0cda58accfed8427eef919c	85	{}	2018-12-08 16:27:53.810949
c9e18102ff53d79edef98da727cbeb6c52101afe2a06ac27c533765345dd658dc5481c817519e00fb0454463f50e37b2255a5b8d782de7a7d135cf4165844582	81	{}	2018-12-07 15:42:31.828174
12c6da64c68d95c6f0080c1f69e2d5a74dc2b74a8b30c513607f01023f7932cad0a67138581465ac86de739626c9e68c1e7cd485b7fae82829af15b7818ab64f	1	{}	2018-12-07 15:42:37.558881
b7d4f0740c846ad9bad5c8945a3a039cb357d24d4e77547d44862a77183df3ff8283b79fca639f5d67be22e09a0307f8b38f9afcd2a3257ce7bc04d55a59d5b0	12	{}	2018-12-07 15:42:58.391133
32ad330ecdffa3fe7c2aa013fe33dc09d4526f147057511401300fe86fb551336b3c5a5be5faa4d746540daba6bdd6e7932486c389c8ea16a00bb24ee93a8689	12	{}	2018-12-08 16:41:58.821694
19a86d26265040ac0e4f396246e4a82c24ffcf3e8df3b2fee854a954b2b6e86d733f9ab771a97a04d58462f839d8bbd76828c0d84876ca79a39b4c74e5764603	84	{}	2018-12-08 18:14:05.4994
9a61dd5153936b407b121817678b3bd4871a271a08e337873956388c03e529acdff32899a6ce52fa6efda59f5f5ccb905f285999909b9cddc6671250ea4ae7c4	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-08 18:32:59.477989
72a4114820fd1a984bc948a0b7510de69b734e23b32b40f8aaa1b357315204b3510824e0a3a36f780cf88ac22bd4e9470591ce3ff43aa3cf46ef21973179f081	1	{}	2018-12-08 18:34:56.046506
418002f896f149a031c0de02301468878c4a4bddffe2b054313d00305e3daccc1b562991f0d57269a0b2080da6c7049c97bdab0fd6d601963c9dcace7415c42f	81	{}	2018-12-07 15:52:49.006669
544465d451fc19afdb5fcf09db0f7f56c42b886e6a0b2823cc88aa830b11b78217089c730143a7dd713fcfe1306eb0cddc4c3b3dbc0b2681e047cf440964e215	84	{}	2018-12-08 18:48:11.664396
4f2ba1f5c8ce4e0d507ab29ce1f8031bc58c08ea5a48fc265e0ddaf6f9243e5a419f0c65673ce967dcf0acb160abda965ace5bac601c3bb0cbed18e1da47386a	12	{}	2018-12-07 16:11:11.148399
5c3c8208852fd5acf8810dd60b32d4d9d662e42c17866de883511cb711094175a3a9eb8f0f32b642bbb867ec6bdc881057fca0e244f0f0026391cc342892b3aa	84	{}	2018-12-08 19:36:16.609996
0c0ba6dd20bb9f54b4fa81ed35c0d2dc7dd51287d6ce5701df21f7497b266e0a526a01cae397262bcfa3c2447c8350c2e804c4625a9f2cc2ac06ba7ab444a7a8	74	{}	2018-12-08 21:42:27.891969
df18f37a7b0bcf2d8c83e5f944acc89f411e99c9b14cf4e755ab4b80c16f4fea6a814381868c082b1de0a57e5cfb845cac806787a9a036aa4ff54823eee7c5bc	83	{}	2018-12-08 21:42:41.514341
53f40e5688a6a5ee74d0c24555bf246138906f84f2278b014790e65a5282688499f87978ce930353bea7e8c916aaec5712cf4d359e8964002185692868dc68a1	62	{}	2018-12-08 21:42:48.438687
e139938805f1040491fa024a0151cb76c3ffc99c2186b181bf20b42b6ab3f2ef2d0a4d9377a33da9384c34e0c2578eb60b997f99a5f4d6c90912c47552ca7198	12	{}	2018-12-08 23:57:16.455869
e334422db50730103abdc2816feec23d5939f8c8c28ccd17cc8aa7ade9b69639273c3570f6b9fba20102ed1dfc8fcf68e88944ffa847f8caacbfb5e6537cd04f	82	{}	2018-12-08 23:57:17.344452
db4bd75c9edbdc08ef5eab5f6d0fe9dc29258861bb8be9656b8e4bae8da0356ea1a4aa3db9eca1c42accfc52f70f3eef4fcf4fb9425257dbf38f3cfc70a83211	82	{}	2018-12-08 23:57:17.401329
961d2ea670c5babc7dfb9a433f935063cc13c9a56681494905dbaf1105793a6f4f2b9b4f99aa3f986bf7847efa15ce5892c3170681a056155fe7866f5133fd8b	82	{}	2018-12-11 04:42:36.303656
b6a826da7babf1bb5548bb5e1135f771ab09c38c1500a78bb691f52b0f5bbdbec9ea0c62c2b3be246622af2de65fe2bc2d333d91bc08c166e6749b8790c49f7f	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-11 09:27:51.31367
48699774a08ca1592346b9ab51cafdf056b5be095cdf6a1268cdfd817a2fbf0d45bb95f49e06c7429724dbeec8584b99b9cf8f52babc2fd0af048c16876f7adb	79	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2018-12-11 11:27:17.232252
18aaaed1df6845488552da904a82d8d8eaa0e42319b042795665fc01b376005f5cd27ec191e1c3e48c843fe4440f6f2ced916e2b59795d95e2383a200cec1652	81	{"username": "joy.hawkins@geekosis.name", "is_authenticated": "true"}	2018-12-14 15:43:30.678049
21b5a8b392a4ee52ebaaa88c3ea46c41fb64cf5b78a38ec11bf3a34e06abf9b3e91740db4420c8df7e5069076fa705b31018247c70adc0403fb5e95d88a045cf	49	{}	2018-12-19 10:49:54.899118
41c2d4620c2338375abdfe5a5f187c74692914cfdd964bf99a3ddcd0ccbe61fb4407a364df3852e2fb57bb2b8920e02d8faeeb2f499a08bac53b9079cc385c05	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-09 19:17:25.883679
949fa4ade48339217eea992b79eff41747ed9bca3b1b0c5eca7574d9e009717df31b997d7a087531dae0aa705d2b4d5e22f9100baf9c4f961822401954284498	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-09 02:46:08.724609
a1723c59f28458e3caf90e321b01c7482f36a439c0e9582d13c682b87fb3ccf7ac59922b253276bc480c461481f568477986c4152834bcfe129fb78cfbd18d0b	82	{}	2018-12-09 10:15:58.149758
a241ec452b1c5752fc428959e413cbf4f19eabf1d769a033e58d5b36e594e7588d862b9c86f4483d39a69281cc4b65b3608a98a06520752b28f83c913178c6be	82	{}	2018-12-09 10:15:58.239009
25131fc40f4d151be0c01a0138224a5e2abb0c9b22c2d999115ef68ddd8962681c899b6d427ce45a1a077a64effe7f02e1b5116c5fcf7230bde300b76b2f5f68	12	{}	2018-12-09 10:15:58.32558
ab6bf7c2a8d8ff2668c2af68365104edebe69360beea253cce4b87749e32024da2f1eb11758b14883d211750ef3e217d00ba71d5b2a11b2ad812fde8eeba3e31	1	{}	2018-12-09 16:21:18.394693
1ae64b121fa5393f09e1f428c482af6b4a6febf4d0307d9ebc8416632ab52341081373504aec3ac056e2b37adafe73d5dfe7f71982d2544f890a3a431bcc5cb9	73	{}	2018-12-11 12:11:32.308808
67b7385b908342922525425076e4d8ded2ae0d60efba05aa3d737a589d76d1c68a9d842e0c91e8ad6b6b2611e6e4f62ff0ffa9864696786811352cbbf40ed1cf	21	{}	2018-12-11 12:11:38.362863
afaa2cd0ce0a66360dddf72dd94bbff00d10fd7f8ab2d9da50e98d7f795c75406681ddf3887ee786ac05fac206e2dfd46e20fb4e9c2960fdc55bad1c63f91083	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-09 19:18:26.085671
374fb09a394d7fafac4a29eba6be4bc39b7a607614e63e7c41bb834ffcd34ab2a0501f21c251879277fb9ec2173c38ecfafae4dc84bbd3ccfeb9ba2f20197a3b	84	{}	2018-12-09 20:08:28.120543
43a772db82100ae01e3b4600f853d55c2ad62c958644b62bbefb6ee03636878393faa5dfdd6fa0e2701576947563f470c8d73caf8f7a5484d8cc1891b6cfeb9d	84	{}	2018-12-09 20:38:52.713007
3ee45650a1a8bb9b3117c1af3c5692c575872e64d1b58003d92ab779438cb61979e09cac8e63ca4e63bbd58008d8502fcbe6ade051b886a6bac106f50c9930b7	82	{}	2018-12-10 09:39:24.972479
3b72482685389ffdbf0424562770064ac88527b467f7f27f7ba39aac7f8f55517f5d54f05777645985d3a2fec688f023c61a9fd93d8bb42a05beb13030b8595f	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-11 12:12:04.135549
ad2f83a0cefa2837bc69776bae54e41b4e5580e6acae25981f78cec726e62d6a1adc832f9093d4abc3c3593e9d6ae36df31ba85acd220363f9ed55423b06be25	48	{}	2018-12-10 15:12:15.827545
f0ea8c0eea1ca9eff21c946859489e53b5a8604088464be617a7fc5498953887e5cbefac462378b9e39f6fa4e5a46e9b5722c6c205cc860ba8409b389842e967	49	{}	2018-12-10 17:45:57.936822
e80a302fc08a4a04b4db95f7cd19b290aff61afa37335999bdef14869a6bcebb1b2a3edda9d6cf242bb6998c252e3ab59d953510a12e086c6bc8c033959a094b	29	{}	2018-12-11 12:27:47.024146
674ed331676dae10b152ccd97cbbc0d097f1ea1379639224ff9e33aa59c3f02f6ce3b780e819fd62d26d6601264f6354e71ffcaf694b01fbfcd87934277c0de9	42	{}	2018-12-11 12:27:53.780519
85e92b34514734e9e4a0ecf03656e3983f2882fa4f3c797dca8d3a1aeaa00d95a3f9067fc4f1144aee19d9739ac09eeb4ec3f44a202178c8a586e87c2d0a6cf0	79	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2018-12-11 12:46:37.645771
bff4e12c70ea5cbd429c5f0ec97669084f1151a246344a6b6b8576f1d03e018bc61c4f46c4247fe2ea8853c8408218087dcea08a25c96571566977c9d42bc770	79	{}	2018-12-11 00:05:50.411264
6aad02d11b242ce1f414a30472318b1b824dbf57da960e393c9667c1559a277e3fc7d328ef1584820e96bae195f464079662a9117f1bc36d4feb3d3af1e3a861	86	{}	2018-12-11 13:05:13.154011
b193f29750d5663816472bb8565015e243164df538c745c96c116a5581e2fff24f90214794d2bbbc79acef89c6fa479b8e8924bfb56ff936074cc2733f939003	20	{}	2018-12-11 19:58:52.124411
58455f5fdf9337715fd74e3e45619e1b1bce2334e62d8c5fd8575b57df1b6e5a66339ba447373399a251aba33fefec5545c20621bfe3b7035c3fd1670541d6d8	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-11 13:49:01.107937
2cb6d4aa6144540d43b500cb17da09bde9ea1eaf41dd20fcca52d26c417567a76c43631de50f5d2819d76ab0022efe83e876c03a8a9eb1a5480529e3ada60b23	82	{}	2018-12-11 00:06:17.370329
67704c3025f3945910f6a91516657b214447f65e98e51ca6c5ef72d6784e208c7e236801d3339fe52758c912581498f5225593b522ca8d09da00a2ad035bbb83	82	{}	2018-12-11 19:58:43.267345
c1ea7e1c507269ce3b96a70e6b50a3aa96adea519d571efed9d8c43f37dd485ac81a8a7498fbf0da8c87563e4a05d55178f0a72fc9267014bb735d757974c277	16	{}	2018-12-11 19:58:45.660245
48c380b620a247a0d9cc239d89669013b8b1881b16550539423f129befec61c0151cc7d5a4dfba345d3beb888c98285a00194dc6ac49cfe6f7b4ef9cc1c361ae	27	{}	2018-12-11 19:58:48.578605
981c72a9050924d05070c0605eaffb6a000b8bb91f6dbd9f2a32e041568d16d7454f39a94ea910e2ca481de8dd94c05f6ce75339751f5ee8e0e18a35fbce08c2	37	{}	2018-12-11 19:58:54.508329
fbd67396397c7e265a66aed0bc377570063d51ec97ca0292735c67faf752ceab0e4483a015302ce0555758999c44e4aaf60cb59b5ae7f607725cc220dba78290	54	{}	2018-12-11 19:58:56.515434
1911c481dc2ecb94b70d847616c57b08471a6f7983fc7ac71a531b8b0bea0c8fb3e034588868d1592abcce56faaaf1592ce45073d032d0c9d994b872b4ffb9cd	46	{}	2018-12-11 19:58:59.504724
9fab6899cc749a8f1c86da445031a87025fe8d8e96777e3e4cb946a9792e640dbeb6bf99c8962f151d891a46aa9eefc969dfd7a02e0c522911b8f872fb8b5d19	48	{}	2018-12-11 19:59:03.316282
6895393662875858a4fc4bffae8de7b587248d1aa0f426d9da960ea7507b484ca18ef63a52712a90a84b62de0de32735de3e9d33d8481c10753f9eb767d576c5	75	{}	2018-12-11 19:59:51.966037
c0ae48f2748aff25fb61b0b6487c8f83c413f43fc536069b743bebc1932304adb5f099cf480fb8bef3b0bf539514581e57ec9e3105697a0526a42cadf4349bb3	60	{}	2018-12-11 19:59:55.962695
6a84a311e0ff7e9bfe6984a28bbcc6d0a505f92ecaab7e2d1f06d79197d49b728d5c671bee2c536cf3252a872da8604e7b6d837cb55acf42db39441a44444e0d	81	{}	2018-12-11 00:58:17.001373
9e1660ba2e139c05ad3eebe9a8ccde1e55f2513af1d97aae27ef0244f475a3356bd0052a8d706a035e46629d530f5b5b29e321ebbe24b1a77e658173978a5879	46	{}	2018-12-21 17:28:00.519396
fc1a0154f951a4413536bb2ba109ced26c1b9d6bcef9b90e2c88137686032a14ff9d32d4642128a8cbb0bdab99ba6552a412be2e296f1cb5ba97c551e37eeb97	12	{}	2018-12-12 16:06:29.898032
b3583f709c8fee48edc37c0c3101fbf3532f90791f99bfb8e109e32666c41a96c7b8864f2a220ffdb57ea6f76c199f378a56b04d4db94e0ad243226f2e89afa3	65	{}	2018-12-16 19:49:35.492955
680e91fca59b1af50dd311c35853bb41915800af1e00499ed8050558e2c183da4c8706b022c3f64bdf72dd071899d3c54169b68c7e1744e7cf28f151735a7dfb	79	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2018-12-11 21:00:43.427023
d6b4822717d464ee04b430efdf2cb6127e2345a6c1d2f263c709a3d35cf480a3c3378f43dc2eb8fddf649a306fe3d25704f5db7d7feab483ebdd5441f9b4181d	90	{}	2018-12-17 11:05:19.861505
aad5218cdf0d0cb76f7a04667ec0c20d1b6a88a2e3f3b4c5c74f1fb17791801f84c8ebbbe93664d287dcb82b529f5868df13c1a5008e004888c4432d23678c5c	87	{}	2018-12-11 22:30:31.43039
b43d21365d9dd57adc580c2c1063f223ce170a99f8a976cbbe49773bb604aa4ae9ff41fd28c3137c766ab490b614c4157f7bccdf0efd016c386d653734c8c6a3	81	{"username": "joy.hawkins@geekosis.name", "is_authenticated": "true"}	2018-12-12 18:07:27.374209
567ba9fb6c93cf4f5d4bd2fad924f5f9515944266d011cc0ea521a912366bc0cf098da2b0e57cefb78950402700ac7a00507dce7eede73c0284dee059fa268b3	48	{}	2018-12-15 00:46:01.612656
9df38825c43234abfba476d658c1fcfc00a99740d3e6000d456a25bb2090453b8687052e027fbca3fbcf33e5fe9e8bade38cac6f9ada54478d52042fd4720a19	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-11 23:55:44.661197
5dd93a7498d8728fd5bb14df00fe2f26316d325a6ebaee002a18e0e148d7a7bf9a8b1dd75aabdaf6da461c050ba8c81c2bf622139aa58039bc4691660b26a54b	1	{}	2018-12-12 04:14:18.395871
9fdcc07f63c70830d9cc72567b02ac98b0ac15e4a81291e7f1fb5d7a4124c23f8bb0cf270785c926f99eee880f54ce14a8d6442d4387702b7c04a27c13e5d975	1	{}	2018-12-12 06:08:52.552498
0d912178855b8de35af2b0e40ac4423eb8722e6bee3365fae2de8b8a8528d835e651f4d35d0e12435a4c11eb2178dd2355a4fef4b3ab50dede2f3370afe86175	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-12 11:42:46.052064
594858a30e5ba12d089c18b2f44a4b4ab69d2243ae0c66c9bad3d6ce223a33da9c0c7c5f52dc02a5420b189153126cb3e0083776120d50fafeff0a63e405f785	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-12 23:13:41.509877
cd8d62b0e1f4223bc835bd40c15d1bfab515f0d7e59c767c9a9164fe0947dc330e3d8b25468d03946d7e4a789cd08b10c6eddc40402a0834d1ed0b79188f6927	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-13 00:34:34.85868
36e45325ca7f1a8ac1fdd6d4dde894836fbfe275d8cd3dd79a98fcbaeca36f815405a92fbd6299235d1ca6087a9b5d49c6d84ca13e5948e06a9289212badc9ef	72	{}	2018-12-12 13:34:23.983513
59571bcc1909e92edfed26640a1fe986c7bda9e193fabe1b561eb6bbb2fe9be274fd167f351bd604349fa123fb170ee0e7988eda01938a1afda7e98aefe3d9fd	49	{}	2018-12-13 17:36:05.243331
c812f3b9c641fc70d2cdac2759e07a13d6ddec1082da4fee2d99d92c78eff1496b1c10e8053fdf8689459c0ee882ff45e947cb33fc11fa2a716dc3e4efdfb565	79	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2018-12-13 17:38:13.036869
c69637e10a60c712caaf66d22ea637d88e28a3b7861ccd55d6de912be79f7984a5eb29f0b36c2197d1cba1d7c33f88d205f74752e263f8172d3cda3599aa88b9	83	{}	2018-12-13 18:51:30.861031
21fcc67806f90aea3e595026fc7f9809602908f9f057813d607ab26a8a65e6cbe4f346403c671bbb84ef1ee44e7cd2c819b88732ee6a9abfc9904e67d757379d	87	{}	2018-12-12 13:39:54.656085
dcdb54cc5d5696433d99a9ff7a25af4f52fca69f1a3dd97598654930325814c4f5c6b2f32e488cf5aa2e3b3a7497bd27969122fecc87b37ca938aeb514d6b54e	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-13 20:56:55.551419
e92464740ef5b4980b4cb1c224db6f365fd578030f9957db5f1aa992ca45968401ae93be4135ad387ee23bbef43ee4a80b51c7e64e7900a842edae8a073f503f	81	{}	2018-12-13 21:07:55.551198
d8bd998c4f1160e28f40e36c914556efe0a0d2a93838b3e02658f7d62bb0a8cd1e467ce210b8e3f0e4e4876ff5bfc24a518497d7d31b0bd781f132f09a8eca5d	73	{}	2018-12-13 21:20:47.440351
8cefcbeba0e526773fe903eca73e8cad3e461dc6da376d64e710ede5ec4de1b4a0bd9043db58d0af2e487880b2563dd48e5101ad620ffea0442248f6b2c08b65	83	{}	2018-12-12 13:50:18.597523
25297b52c5392ec20f0d37e92fd36f28449622c3c1600337bab0d077acddc1a10089dfdad68ac3bc7f52153632ce3b51cd01f5e4373ece65e058710a9f805908	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-13 23:35:24.033168
6c0a2ce2a3924df9b116680e87e5358fdc52baea9af58f9c8faa33e020844a81676a787c546fc347d4d553e33ca05b82728e18431b3a0e3e5a1ea0d2c498cced	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-12 13:50:39.243481
61ad26f41f94cb9942d9e231ae1e07137df3b9f3a8c97ae473bc955b08dc7eb4d6cab759651b84da4fe704791a71f7e6a7020779dd08a89f0e358a4db5070e55	57	{}	2018-12-12 13:55:01.840847
6ddec5cc1c42a0170a247ad7e32f31c732f062b3a36cf8d5ea9aafe94a5585ffdd9fd2b6376fa293d751ef88cf0c8e0e9f14c9253cb2098b9da1405513e9406d	88	{"username": "peeter@juhataja.ee", "is_authenticated": "true"}	2018-12-12 14:09:42.27225
84cf68c9b56bc0e6b5f4fa800bdc90d8eb762b2860591c7350ab1e7e7f651b1065b5d71e3edb2709b15bb89c852d745f37234351ae9b726ae4f13f860bba9dcf	83	{}	2018-12-12 14:10:28.054543
d96ec283a6b5ea8d6c494a6882cc4f2503fdf5f47cd559f73dd5806634539276ebf9108c2a130b84a956c38a984a9302c6e37a22a42821e9c3b28623e12964fb	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-12 14:10:55.185495
30ab1d9eb881d1fceecdb8f87eed615a87cf78978ba5251ae21e7d705b49cb31a530a499821c1f35fcd78bd6e623000574f50dd551a1969d9dc4371dbe0cb0b8	20	{}	2018-12-12 14:11:53.601037
526db1cbd7827b9055e0ba93c8ffa7bb4aa057083cdab79960caaf08cd7418d364ef0f5adc55434ce947d4ebb3d4b5152adca9d2dbdaf4b467f329c5bb960835	76	{}	2018-12-12 14:12:53.921455
3b38153b782785bfd02d289568b1d8e1a147aeebc39e0c63d2c7b00f56a7647d36e3130bef4ae3cff0070c8d58c17d8e81b4e455fe675517becac7d573b06e8d	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-12 14:16:16.541407
0c64c0299fd00220eb7480184c150fce6d6858677d6928b0208e6f27e983fe62498fed50054d1d747128009949bf29a5ab01a28cd779e6f09a67a3d5ae97b340	83	{}	2018-12-12 14:21:08.283801
56f6055112a97452f2069cdbc23be0e3d33d1d80034f9cd991d388ffcc5e37606a870da1e318e3da8e42456118b5796f0bca740e557f00c8554c08234bc9bfe8	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-12 14:21:39.069828
d2b6183c3804b9278c52a73289fa4d3413fc70c2b3cfcee72881e0475bcc3d232aa279abfe6b175c71b25a45fef5c65c25c25575518a1ba40c0d3ce34bbd8ff0	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-19 14:27:00.076628
e67d43f19d0a16e9b0eb0014cb2012064d2041ab328d6e10926f495966ef16aa3afac6a7a666d448ec33eb9c92cfcf598c3ff5641b122c8f622a1e3f9a2beaef	83	{}	2018-12-12 14:24:36.104016
c4772b6a64d2753d976bb8da28f03ea0f0df11dff6dfdd1a284fe220d27db9a9c0480898630f59d366aed65aff7f0e1bc03b8facc40082f3e96364959bf1f117	87	{"username": "heli@hot.ee", "is_authenticated": "true"}	2018-12-14 15:26:08.02087
0b8c00014345725de4af172f9df17005223001b0fb96a366690e3ff8c791762d0f62a50f6607de3ebd0437c2bb8d61d8cdb7f433665a2d5920ca75d864f17c76	49	{}	2018-12-12 16:21:31.640262
193bb784500503811e1e4831f22a92754cf381b7820a3bc575e1f5c34025b4562765beced5d65687f952d27daca101b75dcab6ea615bcac554cddce2dd434ee0	12	{}	2018-12-12 14:25:10.712297
54685080770ce4f8f6ea2f0fbbfd63a9205fc6410b88730260a65ab667637a01c11b251e6033574d71170305ba06f4b656c9626d70cf7a4d1f061745d523e96c	51	{}	2018-12-16 19:49:39.288181
295abb20f8869ecf5501630c9e81ab3d0bae75a71a50cae3cb849eab0fca38138d2bdaf6b44672579917e693f74ef3dd1f6894554119fc2272357394e5a76eb7	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-12 16:29:53.649851
8a2db23907e8bb425a7c7cfca3ac6c88e5274e9297379c004d5712cd0116bf50bbbe47a5a3db0e2d5ee8424878fb031cc4d037fe1032627d45a0e50887555761	12	{}	2018-12-12 17:10:08.097458
0ffec56e45c8705d7285e90d435a21f05f1c5e02dcfc92a23ad5ad004fcb0a6bc30c09b745413591ab735f0695442254e997a6aded7d66aae30dfc61d0c143d7	81	{}	2018-12-14 16:39:44.356362
a1e998b27e5fb1f64a1ab25281b5c9ce2a65c0ffcfbbea690372420419d13ba08eec0788d1200d41d10b5ebf4becc55ec7d13ccb98aa0cdf505864b60437ec2e	49	{}	2018-12-14 18:05:55.160306
7f25fd3f17dd9ed0c996f348f01ec45dac21c2462fe316b41ec5ffb1fab7d9e1b3765d752977699c0654ba6ec8edcd80f79d8c22c480ef00eaba46d55745507b	81	{}	2018-12-14 18:09:04.63989
8b1250cadfb1949381258aa747db8f34923be5bc3c6ed0f91915918dc086926b7de55e9e389410726bee550830cf4adea9639b9d4e6701f84f287005f606ae69	48	{}	2018-12-22 00:34:58.079136
5107e5444cc861bd3eceeebb123da1a577ab833ae19729e41b5af67e1feb4e3d68e3be918f46d5aa881b2ab378320fd565320a359878a53ccd05a4576c373427	49	{}	2018-12-22 03:53:34.484264
1b742b7ec23a81c43aec088e73f2dc64a242c716c2deb9d1249e2368df0ba21c3979e2019bc4d569268f12f3b52c9ffdf341af4af4ee6ca7e72b4ea77e1c8461	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-15 00:36:40.86236
90329f4fe13ec3ccac6c3b4fa9f815562ae6295a232a2595adc069098b2b2f145af9c6991010179a70de5ee7d39454ec921b059cdfff8eba737dc9d47ef55597	90	{}	2018-12-22 20:38:58.282629
bc485c787ebe0986d9a7b7d502a11fc8df8d6cbade4e41ae3bcfc456ae2930b38c7058d4fcd6e62ccfacb6f334b3ae4488458f3bcd6a22243d677bdd8d71feaf	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-12 14:31:11.501709
08bc5d699b8df4a3d9dde9b5e3e35b5393627c7322280e6e6e412e4d98b7c2646725f3169f95c8688f4c3e593a5b0dfb1a2f59e2b18036f2568cc29a5be6cff9	16	{}	2018-12-15 00:46:06.448544
6bf235067cc3961b9750d309e935a8d107d2fe167f90c04e97c4e631efa8a558c81af9bda6e641d43506f4c9e4378dedfd84f0bec98b7bf5b79ca54753845bd9	87	{}	2018-12-15 00:46:12.565847
8267a3e9dc61ce65da637bde48061a7ad6c75305ee4b7eb56017e20e33e6c2d3065330f1ea0e1df89a7543b5dbc63e8a6f552726234660d82d1752f1d2aba8dd	46	{}	2018-12-15 00:46:14.94756
7d32c016c418c3c8856b43bd96661dc573eb8223b3a28c4e130e708e73e9bbd48f58d9f629bcda217a2f693218a9f530f3eda4d32a1804aaf5004c90920c8bf0	49	{}	2018-12-23 16:17:22.511896
02f8081d0c8bee5bce36072d246ebd848c59f27e6a19d187776c1106bef5db30ee1f308dc5f66875d536b98332203a568ce7ae81c34b8dd262fbb4976a02b34f	75	{}	2018-12-15 00:46:41.408424
a03619d7515f4ec4174bc7afd97bb024784f4360f30b53621050ad532ceb8b91be3ceaa688d37ab39530aa2ae199685151713ada2d2fb0fb79357b91afb08642	84	{}	2018-12-12 14:35:24.47904
e1854cb997b3499555e321049efa5d71470a799f8935b5b3107358f09d17d0c737cfc1e03a376d398c6446165c8f5aca63286764c1223bac91a749d7cfaa19a2	48	{}	2018-12-12 23:07:56.685995
fb7da765b70444d5cc9a7774b8eeb1003140a7ad5746a5fcdf673494d1332753bc50c821889acec5fb1418bf5729621dfd54585ebc425107f9abb60e539bd389	84	{}	2018-12-12 14:37:41.447342
2c24c5afad1fe5f42fbcd31a7304900e49938b40dafa2393c78cdd9a8aaff493246628e780e7d4bedf78f95162cd192e148d1a88849e07c09ae3e3379a0d21d1	83	{}	2018-12-12 15:16:15.925189
fad54bde7409dda9e6a83797a0e8bbdb1831472b35023562d6fcbc3b6aa63b06d3f976d2c1cc766f65b942dcfd8307c1e66620b7de51c8bbef9a221b0e316d93	87	{"username": "heli@hot.ee", "is_authenticated": "true"}	2018-12-12 23:37:03.98338
2db04e63812907fa439cb545100284a94184faaf693d36c6dbf9c84278ca95f7c9a78d4aa1abfc93024b5d3c68568f679c923a7cd34d14119615323506b8d53a	81	{"username": "joy.hawkins@geekosis.name", "is_authenticated": "true"}	2018-12-12 15:26:33.024958
e6dd20a1d8da50f140f8aa0175553738e52b15dd104720253b336fd298884ac1f5c16d9b46bd18521b4817990f0409f9ffdca56d3bfbd3ef095669ed295acf62	12	{}	2018-12-13 00:37:22.906943
b830498d12da64e365e5bf8fe86f70d076d3a96f64b13a5af309bb1c2a40685d2ee07d4c4e01f16e584125d0c7a3ad35b4631c605327784a41d8dce39daeb4ca	12	{}	2018-12-13 17:36:28.728234
7ab4039027b5d4559da355d6df8a2ed90119440b32ea9259223d4e61f1b0902c777d8e500b01293be7a24312f58cf1bc2fdb5deefc8dec1ce3f1f1a25bec2123	84	{}	2018-12-13 18:51:42.869754
fdecaab361bf9a4819678259db25b78b8aa7b3036553a2dfa5251b375e37679cb9756fa989b48f7bc1877cc29bcf44920c159c18e9d5221efbeb64b0f5e2878a	81	{"username": "joy.hawkins@geekosis.name", "is_authenticated": "true"}	2018-12-13 20:58:04.589914
be206a249611123370e502f43e2d73633bafda11bcdfd1cb0c80caf46f04e548f937fddec135d68f488af1daf3c500917d6a7453155aab4e7e0420f6584bb258	87	{"username": "heli@hot.ee", "is_authenticated": "true"}	2018-12-13 21:29:09.33748
b3c476bfbc3a7482436834ae4c308a57ad84ecbb10a69f4d3332419c7651945833dfd81dc3e55ce3703eaabad85f0aa9bee3b4d833f7164f27f3ddbfcc30076d	12	{}	2018-12-13 22:54:45.469698
5c2bab071a4f381806a9ad3b6980f4a6504519faef119680e8a0c10cc6ea072e3d569e90220e9b863ae5b8f92c4ef429aa6f138480e67570b6cf6c89b40ea1c6	12	{}	2018-12-14 02:26:47.913949
87d3a98085d29f950035eec45c36272694a0cb6e2f96a3cb96cc4ea1b85ce735dcc7c65d902f9ba6a397ff12a6e1fe14fcda9413c79fb80e479658c80b2db2ab	81	{"username": "joy.hawkins@geekosis.name", "is_authenticated": "true"}	2018-12-14 11:01:12.664587
de9f556ced34e33c9acd70b0bcd3dc6b349846f7cce9461f0e4c7a95d0187c2931271aaae6314f0897f5c0b96730ae22363da2b6d79e84ca9eba39b807875310	49	{}	2018-12-14 15:08:59.458606
22d810c32e23b68725157a2b69f6544724aa39f6ab92838b73c99ff6e1f3d1522f6cc0bd05b280b77246a220cef652e8946f17941d2a26fe3dfd2ffa1106cb49	81	{}	2018-12-14 15:11:21.001852
113f157db91ec76bf2055468d34311a5ed9b9d7bc67da150790e555ca102b8a5326895997158002030e5b64d9cb90650f7ed6fa2951c2f4abbbe818d97475a4a	30	{}	2018-12-15 00:46:30.757816
320a1b5859a6e16b12afbaaf54f902b84b4cd24831e9a752271c995b56491d663db0739cd49afcae07ec56aedb15837f6a69ead53fa69c7212a392dc64052ebc	82	{}	2018-12-16 17:38:53.882376
9b00758319aa4b6c1a6db4c5fe55cf116f8786ed4fc31c2f4a3427c978d564f1524b11e033ea09101d23088536364928d4156f62c4fc9a6f2beffd8aeac93956	86	{}	2018-12-15 00:46:33.527063
fd8424277ab91854a71b028bf37acb256f6114786f85bb9bd8479f8c9f10c598e3a17feb16ad789006b48841cfabf773690593b9031809a55ae0382449a0ceff	42	{}	2018-12-15 00:46:36.435067
e0e3c1d5d7464309b30a6570e68f71be9e20a752136d83e12dea55f43553f5364994018ab0437afd5c2f5caba4c523fe994e434b5f17a5206b8c5ff9814f0df0	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-20 14:48:11.073735
cf70845b057db9504d31337ddafe4d5f2ca9591f740d03050c10e36e245d81e764aff2875750e421c3823fe7d19d3ce8cf40ed802f188235469b7a535afbdca2	90	{}	2018-12-22 03:53:46.504543
768fd5315fc48ec28c6f3535106f3403682d8e1b3d1982cc181d726b2c669fb63247adb07ae9bf886173a5de3ef2a5894213a8e6f33ca9d41b1d4e44df654dbc	83	{}	2018-12-15 16:35:23.056462
ee5dfe55eac90d74ec74f74338f286907f4724dc13be15c6fc4eaa601b1729abe3d7cddc3153bf97f8ef6ef4fa1808ee13026d244ad5c0fb9ed91b37b10f4198	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-18 02:14:57.66606
6d2669dc1217b4a4529cdc6a8b19d8660fe0d95fd52ae3e0c1e6d128c38d81374a0334bbddcf963a4cc60879c341ae092a3894062347b0303addfa8e5f179565	91	{"username": "pets@murka.ee", "is_authenticated": "true"}	2018-12-15 16:53:08.736073
2925ca287f2db2f1f6ec7f8ea98818942e24268970c7613f96249f826f0526998a34ead5ee802268272289f79f083e80d06f6acb2a2cf2b21c813e725727a9af	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-18 17:31:21.987998
04f0d66000fec02f7b5937758abbe970437b8174414f32c32c45771a753e81d9bca90ca6bf93138ec34e02ec1c1e058670b9b5093f74009927b2f81cd835b0e3	90	{}	2018-12-15 01:22:48.415773
aa92e3c4d3a0b4d831d85e3ba8f0a007cb521700aaf8f0fe0dd6880de51cef968f7da343a2d072de530beeab95a40b59871122860c928d37798401bedfe49a0c	90	{}	2018-12-15 03:40:54.650408
23bf66fc71a96d58f97ddeb7908af376f786bc83f81f60a756209797477a01bfa2b36047adeef8e694952dfffe2c895b75adb795bdbce3215d7ca2158b89b959	1	{}	2018-12-15 09:10:29.967756
d6aee2cb628ebef4880739a2d1db04c05d5f35cf1bbd9419e34eb1cf1aeede70a1d264d81013fa1f29c752e664e9dcae7a99b7fa44e0c1c33f7857cef80a9627	83	{}	2018-12-15 11:01:24.060632
65b9e1018c42780a17d0af72f79169d105dd702a6bcbd1300f4822654a7dd8de2d163b5250ac4abe393b6f76c2745796cb77f4b28f960eb12f30de8d37dcf243	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-15 11:01:34.608261
d8426991a4f246a153bd65a989e3fb52c877baab3ed74c643d09e7baa6067622d7fd6f6ba2a8106d7ef80a138effc695a3e93cc7fe63b8aa8e3e19f6e08fc6b4	83	{}	2018-12-15 19:09:52.217727
3c2b5df4ce8e9cab45f57ca506e7e72c4af3d210a4ca6516cf5262885fbf43af7caaab5e5c5200dcadf63ab47e3cb3a74634ac910a998b7951de7742465fd2ba	63	{}	2018-12-15 13:59:55.681862
a7996fbf740e34dfb85de86e5ea7e253e6932fb63b9c4ba1c64e64f3c9fed2e37431ffdce090008d7ea804c576925ba591ab2eb7eb77eef980c06c7084aa461f	49	{}	2018-12-15 19:20:47.566698
5fd062880ccea375227ffba7eae0087fdfa8ead40857d2537d033dee5d34977a21de2c403a7889d24990e00885135697005b0c7a2d496cc5993c861c143ffb47	47	{}	2018-12-16 19:49:42.913495
2ce2a54a61ab6943b56e67b31dacc1d9846b73ece6d96a6939cd7e8c41497eb8a456ccb683913f8c9697775c2fa77833139ef1322cd998a935de911692a08e86	12	{}	2018-12-15 19:22:15.591349
61d869173088a7590933fa24dc581a688619fc958a846d692454154cc55a14eee12ea99b2927973be4369e28c11cdd43a1a4355907251cdfbdd8a823bb1fb5b8	1	{}	2018-12-15 19:22:28.190142
24a9dfe3d0fd7db9972a7138849d8a010d576db253baa816a5d0491ca97212f40ea75c8308131e8efef8e65f949cc8f3089025b81800b4fd0ba009bc96635171	82	{}	2018-12-18 19:16:27.390592
53c2adce621c9fcd65ceab2c2c4de5fbeb50896928323bd5e995fd8065e34f06f5a40401ad5102b24a85e34ef18626c7610b08047b961a7d5e1206fd716be045	82	{}	2018-12-15 20:20:59.180234
673d55a0b7b8c6861b6c0c731d10a9a3897bb910f12ccb223bdaefccc94895c4806745670a6abbcbe3da5adf08d476b7c3010530256407c2ee07e9efe23d85a0	30	{}	2018-12-18 19:32:12.52347
6db9f2edac7968b8be20b1699546f23fd75ae1e20fb290e1e34e42d839d72163a5c4253246b87cd008f5ab3ac30861198483265dd3b3715a39b66080695e4c6e	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-15 14:59:04.070665
eedc7178cd3a7214223e9c154073ed873c1914e7408b921fb7dc857ea03de4556529e41b0f9788961ae6a248a58d92ceb27bf71883a32a10711fe853233ccd7c	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-15 15:33:57.510991
8bf34c0457d5f566b25b88065db0fc2a896124ebe82b689125cd125f55227767b3edfaf41891679741d7332539958e814c95fc12559c82f067e73512ebe36364	48	{}	2018-12-18 20:31:54.014326
06b7253f531cb4fb3c79b7bac48b88d839a01cd114a774f045e2f15b37b888011e5b9c9e8b5037a02b7bbff41aac94205a6d14dda8ecbf3e50e91515e0851615	53	{}	2018-12-19 00:12:15.128478
1a18fe711dbcd72b311232e9dc9aa798a2a17de2fbeb79c4ab266bd5c01b642571c981f27e6462df05663ce84fca5e06b4ccce007a8e01e8fdae4372a9ddc54f	83	{}	2018-12-19 11:23:32.228228
66468f85b289f3e7f33e4369cebd9f50b1ecb7919638c165dbbe1f8e3126b120d3e38dbfd47cb15d679510f4ccde997a745674b3dc0dce644f193f28f0209cd3	43	{}	2018-12-15 15:44:08.051261
dabc7a3c1bc04d028590598cb7150e2f257290b9796d62434f9b95824b3f45f8be31ed6e393ea9b900cbe22881261f16b89e6b45a3134ced6134e31592a7621c	90	{}	2018-12-15 15:47:29.631074
9a03bcb4e31a6871ddcd766e31df6b13776c9621bfb7f6dfb1c8b8e55f19e68b27d66080941a94c81c56b67d0f5fcc3ab6cc00c7076d3ca89a153214732e13ec	83	{}	2018-12-15 16:00:12.812781
4fe541d427d062a8af46c0a2fa79281c32a59130a8f32b05c934bf5d09296fda3fcfca1c14529f2299c98646af089f15de1632bffe29dea33e453b12f848353f	84	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2018-12-15 21:02:51.772013
cac4b8a448eb2d3461e4a3157280e77307b37252e431df440d4470b14e9b91450cfaac3f53c95524fb2b98e9ff721ffcb0f3e3debe397478dc077e0868735854	49	{}	2018-12-15 22:18:50.913417
bbcd7d3128389aebc69a7115664f382915cae75da9e46354cf25b77bfc2eb010f05b21ef3c1dd4574d20331e366aa641db465f24dd60c92bdb1c4c523d8c070c	43	{}	2018-12-15 22:22:20.737583
8e7f749cba27163413c6ae30ae212ec4ca6127fa80bbdaf61433b529fe1346dd6fc1ea4881100c2352e65d2bfd3f9826012ab09547f4f884dbdfb97e8dfa016d	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-16 01:23:02.220326
6e93c5da91025e21631110955dd972ec9eea0e41a0d144d735e158c80ec2999c3a91ee4581446013eda1364300bfba10d2b9e7200651e07c99a65ffcd901e8fb	82	{}	2018-12-21 17:10:52.163361
9c736928ec96aef95e745e5174754fa722fe107fb2cdcc27c28e94bf24da9313e66787f9d32528a7423d25f5609af37f207fa967fffafc4adfc392b2c9adfcd2	88	{}	2018-12-21 17:28:06.044994
875704ac164fc10322cc649f8175abd6dbcf95cf45aab20add3e3326c4da6ad095ba93975eca64747808a6fc1d8d8bea602c922f50ed2a658043468b44d72f1d	82	{}	2018-12-22 13:20:11.626802
489e394b0c8d3911abde2a6b70e5c031bd317e693b48f5414f7787d452d7005e7cc06b6cbe377fe762b5d1bfb2ac7464cb866daf53a59818082a5e8dc69c327c	88	{"username": "peeter@juhataja.ee", "is_authenticated": "true"}	2018-12-19 14:27:04.773112
c46b04cb65a6975b8a49cb9d520c3a4da15f83b929830e890cbe0279530589dd3adb57c96ff0b3515a7279868217051f323308e77ea1bc965f44ee673dc94b88	49	{}	2018-12-18 09:16:52.025988
b1446da81f725ac85dd557a89c695eaebe2e4a66942c6c591f955a328b929cbd6243325e92d51bf8d8f24579124df54239b2b9d0a7294fe10d4ee9758675908d	83	{}	2018-12-18 13:21:09.350917
699b92aae5c1400fe2324ac1008596ebf1ca46058fc52772921541879ec75a9121109f45ed695f9cb8d683834bb14f859fde5d436400e71d76fd9ba341038a14	82	{}	2018-12-18 14:10:02.707184
af24472de54855f0744fa688cde055a97a7880a8f98b1d89b9f1f6bd3384ec1aba0ca90c7787571b9448cce8a2315ee0067f5f86ade720f08b1540f919c29d07	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-21 20:15:21.969573
d6b9ca44ff5f90d30de9f536e58a4225e4c25d2580e88efcba9e428f7f2a6d4d6c6e3c603afa50d723983f9bbd2aa0bd8ea4e1d34e8d8edd5a98a8d524af66bc	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-19 15:53:37.945503
1e3769ecc9334ca6dbfe609c98181d6788ef743666b5893e94d76ddc610fce72663d9e3d466b1bce8f221a4ec17616580d901fc49386eb9bfbdba5b45d3ae2f0	82	{}	2018-12-16 18:50:14.20932
7ccce2cbb75a06851e33895fac0ebabf009e12121eb2eea5ad0a5d268bbd37cf6e682d2c0afba75ae12c1f9a36f35df49a1baf261ac5653ed97db3de2c1ca1e2	95	{}	2018-12-21 20:27:30.330838
1141d39109a9f6aba5a50f953d07c53c5d51075a5ffc5101bbbf11c0eef09cb591722566d34bd9898efd28a74a7a4c3cf2ac0f15c37d3bbf3a5d1ec5c46c6883	16	{}	2018-12-21 20:56:22.666789
8181e895e5deca517bf9352fac8c31a48dd6dd4c26366e67570bd0c296b86f72edf1b5f8fa17203a8e4444a631b268de6d8757d0ebda1052f5849e89f125a4c3	83	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-19 17:11:54.014974
a8cb207fadd4ad14483c5eefa68cba0177f76ef4dad05695c3a53ccd97bc235993d1f642d3615a68101733b789caa7ba4408c5327637adeae1d28747f759b502	42	{}	2018-12-21 04:14:40.259399
159e86563b40bda41c4a060081e1c9d1067a370b01b343b05b675f70df889d7f1811b7b8d321aaac2680c18644c52fb1eb57d77b9fcd91efbce77780d56ae11e	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-18 17:43:53.515066
ad617ffac013a4ec677d24510287d214c8e908a050f0756277a8d6fe9e51ab254715f4be9b4ab6c7541d0686dd033b4301085528a2fce84c7163d06dc0483e74	95	{}	2018-12-21 04:37:15.811976
c78d24f7621d9850ec6271057150262573ba08768b7d17daa60afc315bf7dd8c60ad04f141ef555c82e2b1856f43b7277668b6d76620e3fc9a6e341897b4596d	91	{}	2018-12-16 19:49:32.630208
fc7f510d66536389bdc5823fd3279443b297c1b1f25bfc530c699adc50f6c92ed93f1ed9278d3ef7d5903301cbaaf9e25e399c4e71a975ac94cdc2aa9ed8af77	80	{}	2018-12-21 10:25:12.077064
cef27914a220119b2b8c6c7a93921ad0c725068165072b8d782ef67379a7f502c4048603bd05e7512bdf98dbf96fae5e95cfa07ff3902ec7bb4c59b210449f2a	81	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2018-12-19 16:43:35.063211
01b3d0f6cfce947583ce5f7ff0cd719393b8093e2f3913a57be2d61dd1411579458475dd43d53b227780f30bbc21d4f5780181a6c9d15ee9c3564385786d3e34	81	{}	2018-12-21 16:34:50.525906
c7149a0d6e59a76e258b37a51fa0ca0f89874c000097a04ec09fa76399c4c427cb553b14c8836f1c8ba033cf569f948c10f9df81a9fdfb4b523135e4d898fcec	90	{"username": "maritza.alexander@franscene.io", "is_authenticated": "true"}	2018-12-16 03:17:25.952647
8f07f99888a53cba7c15e8c456e37a6ff24ff294c1151081384509f9fe2c7e57208944369b1f316abe4bc978b066c68cb9491ff2c77adc78a1190348ce5cc10a	83	{}	2018-12-16 20:31:17.340142
a0679536f540063b00416ac4f498221850f5faa8340f58dd8800c5c55ddcd1e62e6a1e3314fd53c1bf2f4a0e0b026c104d37b6c6c62a8b55c781779f2de5cf30	12	{}	2018-12-17 09:28:41.650756
1aa4e2a4ee32d2aea38333c62f11f5132bbbb5bb21d25cd8828471347106e3643c5d40ea65aa3e3b4e4eecefb650765ea771369a7db2e61ad7d274397e1f4faf	74	{"username": "pets@murka.ee", "is_authenticated": "true"}	2018-12-17 13:12:49.908028
8182f4dcb87b49b2ef7deaa60e0011599415b523d72ada6e6b3c30342c7d69ccc2f6a6d94e0604c258d117f6d3a5499bdab4f84213bd97f172003dd9f6f3a199	84	{}	2018-12-18 19:41:30.421268
065c6308bbc966ed33abc206ebf98b04ce82fff80e0d61d00204caf56e253fcd1376455b13ee9e22d10baff75f3c606ec31cffd128bbb81d58f3ee70c4d57175	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-18 20:06:05.293577
7bef4723eb566be181d8ff905a543dc6f4b150e2c7e174bef7347a81619fd6c772e87ac8ca3734979aacd03bd78216294ee8a9549d92991f0e2a914e803ce85e	65	{}	2018-12-18 20:20:24.249233
5925e2d8721afa1e86a1cd00cdf85a1ba12724bf721b42ecd7284a9bc07aecde9bacdf69bba3907341d283b996ec224ca4beab1a7baaf3b1db78e389ed6fe49d	85	{"username": "HELLO@GMAIL.COM", "is_authenticated": "true"}	2018-12-18 21:14:18.243383
011e22d104434a5ec076833de100eab7dbedaa9c6fe0962afad2e2d3d6fe06bf0253e7e843788a98d07bc5d6de07c382ad95ac8d08896f96008c3680009a70c5	90	{}	2018-12-19 11:23:47.591534
cacb42ac2bbaddb9e4bdbdc9c0f411f9ebe57e632e5a641a2eac68de11aa7a0d907b21377a3472487e80b735b708aceed93a9fd38d3f2144f3a606b58f377a79	90	{"username": "maritza.alexander@franscene.io", "is_authenticated": "true"}	2018-12-16 05:30:37.545174
c4c22a0f17935a111c4d9a7ea84812b08b015dbbf21aaa6e14accf9a0902f24ddb22152338595fffeeb8d74d3daab7a2dc10675ca7467589c359c2619849e9ab	83	{}	2018-12-19 11:57:41.707858
ea6b4fa681125612d0455bcb6abb047b3696a85459c0561d7bc2baeab22f894555b6adc1b2e956050f17a8cf40dc458c50233f2c8a6415fcee7a1cc920cfe28e	82	{}	2018-12-19 14:16:02.930324
e09f2377fec85cc11366739c379636d40c48c91433b2161fcc9d8b182d3bfb63aaec82b26566b33574f09c13dcccaa7c1328f0a9b169b5d6748dd14a4bb685b8	87	{"username": "heli@hot.ee", "is_authenticated": "true"}	2018-12-19 20:45:40.795601
aacc858a3f47116ffa6f4cccc040127bfc3cdee4aa2f2a2703f49c6dbe9ac7c190b59ff3b52c62ca9a2690f5e2cc9a5212be7e51e6031fd9556364ceed5e5eae	82	{}	2018-12-19 23:26:48.779851
c30dec48b6d797e82f84d8478c0481dbdca3b8f6ceb7c6520360ba7a2908040e24956ecdc7db98cf084f9f0b9125bb001783df0e6559293def45ef1c58a55e97	88	{"username": "peeter@juhataja.ee", "is_authenticated": "true"}	2018-12-20 13:19:59.679744
594b1371d98b5bc39292987496e3dd9f51f736f9ce5d3f32fc63e1bb35d13af47b7f4d49acfc0632ab21137a60ca5945704ed8195057904b2a47458050bd0416	48	{}	2018-12-28 12:37:00.87921
5937706a1e83ad51ee98b717b76f5a11e555b1937ab7fc6a790e7f5d804e442df544dd2875e877a0ecf9187b75e4d25a02501cdca1435237b661bf60b48832f5	81	{}	2018-12-21 17:28:12.735172
4e1555ba137f8a33791ba85706f7550b11c253771118ab530d4c8baf45381cb8a92698c727eb7c0d5d3b0c65aab9189aec7774517a4373a3a9f43346af055ad4	100	{}	2018-12-28 16:04:54.175596
75a779fcc5b818e2925c5ca8e269e0522251c9b5b2fef45a8cfc887a070d78225ea479766cb66ba52f607082cd9c04cf8efbb81bcde3032190c3b9e83ac8888a	90	{}	2018-12-21 17:50:50.064676
2303c53c1176b0a807241bd856ed96f7ef26c4702b8ddbbeea978f821e5cd29848e5e5bbf6b60ddbd941b0437fe2c9a012e17ad48e3e673fb4fbe442ed2ccee0	81	{}	2018-12-17 15:15:44.882604
468bc7304cf95227c32ef3fbafc8781239712fc522dccd3bc0d70dfa38e4a19d24b530bba98698ab15d3773cca7d2252c6a9c5f70469761a68196a495d886ae6	1	{}	2018-12-18 09:17:02.04394
c5e14cefdb33b2b3317d386c533860d32d0295076f83d9a252527fabcb0f2affa94c6002c9d37d48b97d27e3ff442dfb21b5ba0be4c9a90cf1f934e0fbcd351c	48	{}	2018-12-18 17:01:30.944467
88ff1fc12ec02face1491b2218ed92d830e8b067dee9490d8d377f132e7ab5ac6ea1d5cbb0d47166929147359bdbe17de4074c427b1e5772b4b18b07686f6e56	88	{}	2018-12-20 16:10:34.032149
9906a000b0eeaa62e35f60e5ac40a2548f769dab4c65bffa2744a0d9c8fb380ac71880c65cb3022a17b1e784d315ce8c69d1471371e7652f6000173787b8895d	88	{}	2018-12-20 16:10:34.06293
a15fb2dd200aeeb51fc8f744e5f0cbe91af5643c87d2ee8fc213ad6ff94e573053af0f39717d5e4ff5b19906cb1a4b83d780e9224bf018749267e4626e451459	49	{}	2018-12-18 19:12:59.196182
c12bb3fb02513df8989bdee57987f91b1c31b729558420271f2945953f4b05ae937523231692142e8508a3d3db644e96e18705ff03b7078223afe36fa47db29d	74	{"username": "pets@murka.ee", "is_authenticated": "true"}	2018-12-19 16:12:06.849442
393fe3bb4e2523f23eb9e9268d085d1b5a448c87644bfc0dd11b2e2cbfd9291730a05ae48844bf3a2ab65a8e9102ef21a8d630659e628a865c4166ea72a063dc	83	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-19 16:24:44.903381
4ffb3c766d3a5717550c789b7903070daf891e0d7cf100afea0c8c2f8020cc401812b9228597e6a08eec6ac1b833b5c8d331cb868c8d9d7f444617ccf0ef1c34	81	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2018-12-17 16:10:47.089694
3b1205a6a1e4aedd0b847888a86c3f5ebf6398cb39dd9d0985cd94fb8003625b4ba05cf984d3ae874b7aaeb307a379f1e09b87dd0b8b91bf32bfe79cf12ace6c	83	{}	2018-12-19 16:42:15.654644
6b20346d7bc69c8d5edd64e43e395c88cb7dd47fa137744cd290f9d057bde5f09886d9cca307658ac15653492fae819a70d56bc441761ce7649d0ca9ae0f0055	1	{}	2018-12-21 04:02:44.366643
683dc73de5f376a2161127a719ff059ec634c066b87ea4215275b064224a12f2b79f8a6c2d39ef5af2b9e6c7522bdf504d9b97040fa07772cf75c5c93f7a99c7	81	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2018-12-17 17:32:55.216284
8a398bfa2b711b83183ece443682b32b25fb775bcb2801e79bc00e361f385d5f1b9fc3a7ebb5a70defa6dae74da9e8a1d3b48fd1c39ca7e8c1a2b3435abe0cdb	1	{}	2018-12-17 17:39:51.652448
232d2dab67daf3a362e90bb5a529be3516f59f346708d5372a913c449a8e4a8f6c98f8d42d46008ec3f01b4d7ac706d012e363fc8fda3da25cb257db92820742	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-18 20:12:48.633839
dc8546d4a9fac52d28907855d58b2dc292a63098ec008a08ffab6ea7217ce1ba6c0016765d86ffd8feeda271f1a9cec771e80277ff6cc75ccb2dfa95c57af6e6	49	{}	2018-12-17 18:25:24.928499
7d7a8fda82f6c90497a99407beb9a3fe3c29549a489260b8e818399206a4ada9ce6e386aec4e13bf8aeac585181f2a6984c0e333f54780d45b79f192fe347ddc	12	{}	2018-12-17 18:32:41.04391
a2130333cb548bc6695220ff309a44202415ca1995c376d8eed8272c459b46cc888d55a1509a4d753acfe5aa7f3879216a7cb53709ca64210d624fbd46716bab	90	{"username": "maritza.alexander@franscene.io", "is_authenticated": "true"}	2018-12-17 18:32:45.075658
a82c02607da2a4812625dac3270997bd86acddf3af01d54b6176113a9d45d00661c3cf9ea9f99c33670e5d4be119b701e9c82f36a2708607e4678de31dcd1af8	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-19 19:48:41.892392
c36f50984fdaccd81e52f0bdc726c54813fbc4df1ad6030ba29415f6777eba1caa6d27121d5e1d9ca0313369ea5a5a27a1e81792f8895fe71ece9296a35dcaeb	84	{}	2018-12-17 20:28:26.653275
d850e43189172a2c3606b3cec69485212e8d7b16508389f79ef7ba209e40552c5ccc9f187c67e9f18b107c395095875939695b094ef19ef1f63a165615243df8	96	{"username": "juhataja@susteem.ee", "is_authenticated": "true"}	2018-12-21 09:00:15.410894
e8cf53d8283f1e7268e24fd45c2b4ba7c15d5341e05dd7a9fc88079cc5aca65db21a2938e8adfb79e6c99be31f384fda07037360969c606204027536b67f7366	83	{}	2018-12-19 11:56:19.142459
3b18c4eaa250f832c7a28d21ea617b54c545441fb9e82960b58d5f06fbbd78a35cb894376d8a2d9c96920bb555528c422bdbd8d284d85ac8d838c14e0957ccc1	12	{}	2018-12-17 21:28:43.693312
d2f0982a64876827c6d7ce6d591d37b99e97ab333ab8b8b484ac1c5589b0ca2a219bfa59c66e203423bca9c359f12e758fe6f666dab3a27950dc062fbfd8cc2e	83	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-17 20:43:31.550543
72acff44305f30328e86d29e1875ad2e4f977865dc3b4a183f5bf3a17467a80a25f8393e58ed93ad968c514581518fbc887a254eb5021d1189909a52d0eac9d2	49	{}	2018-12-17 21:30:44.107333
d4185e000bbe74582517741c6ae273407bbd989b3a7e8158f80477890a67a429f731565522ba21eb00919ded4910de1e66543326e1510dc459a0f20739ecc423	87	{"username": "heli@hot.ee", "is_authenticated": "true"}	2018-12-19 13:13:22.381241
4fe8643c011ad84bb9da4fe1ee34270da9ebe540bc8d9fdf71157d03cfaf42393e940fbb2078c890bd900a5eb164bb3517dd46e45d0446a7e9915575d5ba4662	80	{}	2018-12-20 02:39:49.551679
78d79b2e1b440bb7b334d2dcea01944bb57116ae69b6d59ba74b6aecbd07c1e62cdaed146019ff4390244649bdd93faa9d0cd55b266bc34e431178bcda170d55	83	{}	2018-12-19 13:58:37.735283
fb6584bb93903167e6b5908847004228286965443d0c974b8d38c39668ef4dea287524d67fee34ba9eee6ea7b7597aa71f6b12e13a16974ef244e62fc90d3ec5	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-19 14:02:19.256908
be04dfdb1ef3c19c8d83e10272ba2fc0cddf00b32f8e879e823fc188362d58c9ec371c3e3793e28ece70031b6b7e2800fd0cec6978cd355bb05f04ca9d192b02	80	{}	2018-12-21 10:25:12.198637
06e76f2a4204a650884111f7d1f85b55d29d32b0733729d4b75a830c9945c71832823b9afc97b354834c9851f432a9cc6ec148b3f316997cfb1ebc336bf0d1e6	81	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2018-12-21 10:24:41.138951
0cc7ea48c7fe184c8dfcdcdbdbdd911c4bfadfc54e8318579d548456db0eed6802a1fc7748e219064e3940a4ae42768c0b0e37f51a0e953ced4534553e0b5179	80	{}	2018-12-21 10:59:25.092594
336750238e6ca13b8654c6740ad6aa8a357992904f1179bc7427dc0402483af8efd9c4022c9c2c01a029eb6dc35ddaf34d23d6670ba214842fd5be25e08def25	90	{}	2018-12-21 11:34:03.294989
d0a267a31fcf7c5a714e60d2b91682ed1b60a4dcad5a0d0c7ddf69abe2425d3511622b2abc79e3baaafecc99e7500c8b3f86a4a624512b34682c0f419f14037b	95	{}	2018-12-21 15:47:02.388601
791ae459d58f0bd2970d29f8b52bebac62596f64cc62f964102eca086366882d34091a55ef595f8e4ca00aa52e0eaa69496bea07f09a507f64ccf21f79d30c06	83	{}	2018-12-20 13:21:03.440365
4c9cd3dcded40f3bc17ed4df8908e4c0664097910f95864b7a06229631c3e0cd6dba55b10686509678311a874b19252f19d5b784b93d124a7e314c262f610925	83	{}	2018-12-20 13:21:03.742569
86dd851c1280e3b99706ac761af96fa21642053a1a8e84fa5a1845b8987b34e46c00fd04541a6b597dd3dec7226ba791a7a120bee6459183d0376614b845f7d7	83	{}	2018-12-20 13:21:04.357497
7da90bc96f8ae5d04d30546f6d6803c53ada79f76d27b1475929f8a1612aac30a3ab6fdc419d2561a24c72bf3150e2c3318274aaaa694319386c301827ada8e3	83	{}	2018-12-20 13:21:04.620147
517da79b82c59d42ff457433cf9397cab3dc199b05320363f9fbd388eba78b4f1b354998436f53321e610988cbc196fdf3e48e4f37e485f822ef5946126fa734	95	{}	2018-12-28 12:59:30.334048
8ae7920e494d35d90efea818ec5b78ccae7b090a0b1fbc846b3430b5a693601fb4c6fb21ebb3b4438e93c1ad8911f83fad7772b647d7da16b59e1d65f2f8bbda	42	{}	2018-12-21 04:15:38.239131
e7c85736589c9da1234302d66e4e90ced8b54ba098722dd567f49111db5e83c72a9fcf562d2e85f1491c467f118113d4cdaede9924cbb45a37eac6398df57b5f	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-20 14:13:27.944981
8028b2c9ac3d3c07b9bb4516763ee758cf675b53914365d72feea0b0a56cce98b7138f916f4fdb7fc08a64d1092d7ba3022817494e563b527d687d50a1be6812	95	{}	2018-12-21 04:35:04.796763
769e459e3d3aa85d51adc9f9031cecb3ad17475713ba29460dd0724dcb79bc1ae2d76e988074ebc2e5ccdb90625ace0f095ebcd496b8ca2a55f2dda09205c87b	101	{}	2018-12-28 21:00:57.774923
a8b058a7fe60d7a2b07815602d85264330666c39a7d25de0a3a59ad1658719acadb0b76c759168be972e85cccbc8434f0fe981ab3c161169ebe63e1016aaed4a	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-28 15:00:10.729226
cf5ff0c4801b6b993ece641c0bf94bffd160c8bdf9482914f1afe98255ce00510a2f7dd7943816bb2a8a4d511d76869392242261cf8a439f7165f9cc578f8f47	92	{}	2018-12-28 21:21:41.737892
f306b992a4c74b41924059210ff944b86b343f9665dbc90ef9d9274fa90b9311f403e62bf34d57b67c8cc9db5a4d7f2e51b4024f1ce9ca8dc1f5871ca2bdbd36	83	{}	2018-12-20 13:24:35.790486
bee8c40a03cd1275fa76afe355e99bcc20a96ec4fe882eb8e097f2ea8ed9fb14277a779adccebc8abfc89b6baa3140337d9884cbcb82a78bcbca5ca5905160bd	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-27 21:21:03.25372
f8d4861986cbe7593f990e458717a6b10d6073fa217cfa76cf47756136da75bbf6c772dc52b7cb65213153b161afdd35e205ce6a8445a799addeec7e69cbfa41	95	{"username": "juhataja@susteem.ee", "is_authenticated": "true"}	2018-12-21 11:56:25.684271
9314d6f471272fa9987376b6f4cd17b3d528068fa53b9c07b3806867b3b156406b298875b8c3f417f4ef64e8e63ddcbe5f72adceafb2f6d89cf5cb157ad66c1f	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-21 07:13:00.687716
d839cf9466c03d692296cd8c7f828b11a21bdb92ba5941f365016a7c1815eca25e0ea06c4e89808b76010c027a613e749c4d55667470451c62891a2be08364b8	96	{}	2018-12-21 09:03:49.981725
6d3bf39324a41015f36d422a1e4396af216652ee819755e76a3b68f0389c1501942d3babd9b644729d92bd9a9c1585d105dc7a27a77d9720f7231c436f2114fc	80	{}	2018-12-21 10:25:42.782124
87482320e964c61b3226f5904c46728fb63d5e3811087f924405528aae6b9bf4e4e9c369a1945579c36d2948c9b646326d61658ae7d0ffcfea48329364a18a0c	90	{}	2018-12-21 11:34:03.403524
97e7e232593468b97cd12c6a4b609b5428f427648015feaad47d878d80156f19cb4823cda6d3c0aada55b9094748cddec16135aace9693ace55ce4f29058f508	88	{"username": "peeter@juhataja.ee", "is_authenticated": "true"}	2018-12-21 23:10:33.842645
3a4278a846fcd29dea0f96cd9c12ae88edd4b81eff4d0c1ea677ffdc43b8bde8dc23eecefdaee8c1b763a4df4ba5ccfeea918c37fc106710dd9cbb0a4c2950b5	95	{"username": "juhataja@susteem.ee", "is_authenticated": "true"}	2018-12-21 15:48:12.695151
2cd0f800dbb738a869dae779bca0a24252a7f68b1f41759ca3154f91be30913388f5cdd8d0c1dc43bb078142fb9719e20de12b1df2a5f8449a2b39d143395f44	83	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-21 20:25:00.754313
550e7bd7e31061ebdf044ca508dca482cffba4fcecd00f95b7ca58402cb3f2d4304c3618591c51a894eeaa7415805ce864c512fb84a53507ef15bbe6dde616a5	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-21 20:30:47.013063
9215b50f0de42fae131b4d988bde11d5dcf4c270f39690f72d756f95dbe1993b303079ea5e12ea19a7ee25cc0b62c3fcdfb64716584812d94c10e5325767239d	85	{"username": "hello@gmail.com", "is_authenticated": "true"}	2018-12-21 23:34:12.302322
5916fb5260f69ad98ac4ae49738ab2cc66c01aae2520b4592278c3c2a45cc3829d46da52bc569c999a9e65b5ab01c6f4525c82a6ea30beeda4950bd8a0508e55	85	{"username": "hello@gmail.com", "is_authenticated": "true"}	2018-12-21 23:52:05.228774
2b4187e92daf5708b8ca1811db6c2d4231382e78390c4c44dd29d5040f923eef9887e2ec30d0389195a1373ff32fa48180085d5cc0c5a83a710fc1076352bbf7	90	{}	2018-12-22 20:39:37.42124
27618cb462cce6db73245c7e30fca3098119b30e5a7b13a11311031eb300c7d5937a4baa1bbc4f2b09bff013b62d6cd5cd177d98308fe9e281507a5ea2d9246b	90	{"username": "maritza.alexander@franscene.io", "is_authenticated": "true"}	2018-12-22 22:36:14.680952
37ff3097d817aae35388432004280199f76b64225249ad3716983895bcf228fa18fc9d68d53aa16eeb3d9b63d8bc9cac107bf94d8e70cccd4c96702b33d1829b	81	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2018-12-23 17:59:28.592291
7a473c3abcdee959a8e27c84e51f67d4b0f825a76d99992b37f8407c86c65ff37e61a76bde266b1040c744631445ebaa1fc994c7720aa57bbb14c8cdd499183a	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-23 18:35:46.908739
05b5796a6307f0984f747b786710d7a2196a3e6adedb43f88aa354cc4d3aa9bc780954c1d2062cc41ce23987bb7a265c6e770de01524badb87d97957d91b3984	82	{}	2018-12-23 19:33:02.132377
b6d81fc9e87acccca53c44d44b20c570c22b0c33f2f2aad4451a73b61a192e73e1aa1758dfca3ae197b4e236ce4f2648fb3a234b088332742a63ea1bc2c149eb	1	{}	2018-12-23 23:36:50.425708
a5ef1e45d89d6d5f8ce5351c12093cf6d5faf0a64320b7c96698629e42aa2919b5c465345288162c25ad9a791e5f153d015f0a8e9428a0e39510193d51373754	90	{}	2018-12-25 08:41:14.124087
88d62429942ad7415b362f23bdde96fcee5da743aa566a1632c820f1b45950de96f083cb02d432234a258b4661d6510b9e7c8cfeffd65de072dbd025841dfb59	90	{}	2018-12-25 21:29:57.875931
0c52b2f7dbe5d3b56bec39c3688af5fcacaf8afbf2677f6f3c7117f24823bf0a27fb541b0d93f1d2b0e8c892ac7d2e21f856060c578bfa554e1fe310edc70406	74	{"username": "pets@murka.ee", "is_authenticated": "true"}	2018-12-25 15:41:30.686314
040419635b9f31a8ec91b5e5195f577aaf51fb6811508681ad8e503af2df29ba0a2017415b54e47f6c58da3b471aa8c6c383cbe4f9d4ebaf36ce1521b81f9437	90	{}	2018-12-27 08:00:30.053707
ba5cceec5fa34f656dafe696d6e11e2050d3c7962542290a3395bb9908cb9d5d3896d829bbccf5b6ab4f399788d013a6ef659db89175487e59d5a73e61bd047a	88	{}	2018-12-20 16:10:34.082744
0d9c8458624d520ed0562e8b03b85555d3291cb3176bda796d50a8daaed2f2d00a59c95131d2c14897f6c90a71bb87a4eb05a08d3e1ed081fccced2cd6d9027c	88	{}	2018-12-20 16:10:34.136617
f75df0f664a91813de65f4296ab654fdb82206614d10d388a8491e7229cd52e985b669a10c292d222fe078ddafbaa54d856a38a80cc4dce4881e6593cfc3d6ac	88	{}	2018-12-20 16:17:44.482926
1f45ef2e581207bc39c048e672780952c7bc14d2a3f2c447de849e051250784e3647a288891d855dbfedc4f63955824af08fda49cf8b0bb788fccdf7ddea2cbf	42	{}	2018-12-21 04:14:20.440508
5dc8cf67ec266b71510f31812e78ae13f7fadb40dffb292ff974ffa3e450bc42c558a52cc122237646e39d0e8f75b3c5f11cb8782d0ea6662ae8905605e2f52d	95	{}	2018-12-21 04:35:05.087716
44bc30b7e71541b33f8db6749aa1c2b0559f9dd771407ced9d87b8d1e0314c8eae66f54123ee159ae2b82da028b2ab0adb206c8246267573cc3046d4f1dd4bfb	74	{}	2018-12-21 18:40:27.52856
f90e2981a481a7489ace653960b387796f20df57062736f866af41b123e613ec8dde33647a973b0957d9cfc648eff7dcb1521335821b6c3ca888a5be44bbbec6	88	{}	2018-12-20 16:18:03.926086
b99f23dfd0cd79c229590608d3be81c1dd54a94f459ff3bda899493977dd294eb112694877f173b4c99bb2c734c8640ae63a380ad991c60e4b6c4ac07c2304d0	95	{}	2018-12-21 22:30:10.709461
c16ef75acc1de4772113036592b1ba1b1a2c818114e77910ac5f6eee77d9038ea326a61a2365e4b6bff98e494e61d1ad6345226632983ac83e9877c4f573932c	87	{"username": "heli@hot.ee", "is_authenticated": "true"}	2018-12-21 17:25:53.808252
b6acc14112fc88d03e43e4162d90588ae50250dbe20c5984553dbeb47c68fc595b94dde8d192f3cc7ab6981eee0a54c91608f717fc33c5e1f970ce3726539274	96	{}	2018-12-21 18:28:31.009644
fa933ffa2e12c2093f63281f667973ef1ea86c80ae4398251d0bfa888c574cc803bf2cc4eafbca9a3ed216e5d02019a0a85b378614e909eb6cc749def845ce83	74	{}	2018-12-21 19:03:35.358514
833e9a73243fbe2944b8e6473c0021d12f4dff9f64254b9a3de64c81afedff8f3f2c090e533411986e6a81cf6e3d749f26a2a4303df3fb2798a4d62ab00361a4	95	{}	2018-12-21 19:21:18.117488
d5828173c561d289827a06a04cf59102ce5488993f7d6c8355cb8bd1437e426b687a5a491f73a3b97b71421e2f2f3bb8de4784797bd97f877fc44e037b964c5d	95	{}	2018-12-21 05:24:43.845459
b1a2ed52a24db03333baba35935fa1e5b827d8e078654460dd007c936dbed3937717d3004d8f90860ed6beff2c45c6fb396c6b678220698d408daa664298f2cf	88	{}	2018-12-20 16:45:42.079474
8fd755825bead63dd7f91771c81e57c54258d94d8c95fc775e224f96964b82ff109167b642454f0181874640c45db7c3d7726cc9f108cfbfa06728d73b920f38	84	{}	2018-12-21 23:46:10.654487
993a4283e2908d19c37f45d07aeac4db6d667c63e9a31ecff995f685de3ffdd0a0752f0220d9a5b03d58d7ba4f5b85ac2d41ac7b38c2527836ca9b3a1e28a0fd	80	{"username": "villu@mail.com", "is_authenticated": "true"}	2018-12-22 00:42:41.947927
55adb04677eb90bcb569ca1ef740ac88c01b64c41a7716ceca59e62f9a5d97d8795e0858ad47e2348b2869be52f0b8b9e00bd89f9ffae21a4ad3631d6215d442	96	{}	2018-12-21 09:03:50.086509
87a43ac9d6435bd387dab379cf1b33b96fa7803fba99cf8aaf088c23d43f59b23c78c37208b6506b91ebd31469b761865388063133f37e9c5ed27ed2ae659d84	79	{}	2018-12-22 18:31:19.324497
cd675bf274173719f0bd564f61e53883e73d75579e6448deb3a796955c660a7f8208ab9526565dfee4bc9cca49f0dc3fbbaefc8f96f4472db6424598666710f7	80	{}	2018-12-21 10:25:10.584459
5cc749d70fc465a6f3bcd6493401ca80370c1ed39ba94baf7ac9a9d5895eec9ea5b4dfc91e53324396f116d35e9f43ca2a96e205bbaa9c17fcf39f880e421a1e	83	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-21 20:16:17.202007
3f55b243c967bd7bb5025128387a1b828c2adc0530fb95280c59868b46caa4e2ea2348e369469608ba316dfe5ef6c8c59bd489f06b50d3eb65025f48fb84523d	85	{}	2018-12-22 19:41:59.064146
1a9efea9b5f7658b8b226dd791d2c87072c80dd965578a6ee813cc0de38656ae16a876f1ed2155e7e3ff65f3c18ec843c6b0f08012a884e2229ab282e8297db6	90	{}	2018-12-22 20:41:13.760693
b12becff5307ed6b94d2628ce246dda7aa78fcfd5fc0ef46c6254645037cb6622101e4936fed8b249be5e34af7f7550a071c41fad4b11b88e3f1f2b1610bb200	49	{}	2018-12-23 14:54:30.931379
e2cdf82af8fb646dde66e65145fe149d268b01a7c0efcd8cc9e2f04782b6054ee27275cf85f141679f04278e11098982ed74dc295e19362604a8e040af370eb5	12	{}	2018-12-20 16:59:08.147363
c7a420c3a9ad9eeb8f54e8476433b79ff765f798f0f08d5e881153e2788a188d4e9f001fc0daa85caecc2cd9b032b4a0d359bad40b44122779e4a907f773f6ca	90	{}	2018-12-24 11:43:56.658113
e3771e395bfef5eb83dfe6913d77623f87451aac76906edb76506754f88b0c5a181f8e3f16ae64c05fee5d39d148a776cd419c27ec0e53e5c6264e11e0a79655	74	{}	2018-12-20 18:32:30.125189
f28569cee24d71007fb1926ba7bc79ef0a2268c2c857cfc03bbea6bf4a5301fd36b2ac3b0040f481c83947a25463953e5dcd8b4ce1ee36cd57e143b6599ca418	90	{}	2018-12-21 20:58:51.930343
1bc0c0571fc7f091464dd983a4b7ee8664f94f473af65266c803123e68cfa7d7c5b4c99fd6aee9b8fa6ad4ae21dc6f208f0c3cdf62fc5b5c0a1f5a6262ddf5e5	95	{"username": "juhataja@susteem.ee", "is_authenticated": "true"}	2018-12-21 15:53:37.767364
a9a0ab57f7d2cd8789411ae01cd8bc74c4b090a81c4671fc1dee917ac867dc7ce7aad4a2ea49dc338ebda801fc1616ff075e86d630c052bc1e8d7f6e6a277221	83	{}	2018-12-20 18:41:05.110904
bda4c61a7efca6c4898e6761af33e2c214e314021ab808131abdd2fe4ee5ff23ef60e6b2d8d45bd3b36ec829532b59a04134225304be5f9286d1e1448e431540	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-20 18:46:22.011934
e3256722c84c3e3db657559929b1ed5774ac0ac4bd90bd0f7442d4123e22a1cf04fce3ee57ce6f26cd49debf073ea8389979755f9d31b34092df1c4098b94612	74	{"username": "pets@murka.ee", "is_authenticated": "true"}	2018-12-21 21:14:18.242433
678e001c2bc338054356f5a40bf81b640da1293429901520df4111fa86e1959e2fab0d0362798306fd3a976421acf7ecc833fe94fdbcd7e5e76cdbccfddbf894	90	{"username": "maritza.alexander@franscene.io", "is_authenticated": "true"}	2018-12-21 21:37:01.961179
2ca42d18840de36d6b66b737b920c1e3f1ec311bfdc3d866ea9272f30636a6adc263d0972a4a01a2d4b0b26f70e3aab63de37fd0e537964571e5f40d3b6ebfc5	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-20 19:08:26.16
f8eb5fdc6d859b46289d6ab40612f46a06c1069674c98630bc4bc8ad2c934072690d35ed4c394e36b13866cd25e46d4d0df01a78808471fd5e604643c99fa3fe	95	{"username": "juhataja@susteem.ee", "is_authenticated": "true"}	2018-12-21 21:58:09.215434
dd06041849249047e3cb21fd59fdbee8ba71bbb26207d1d23eea2b9271092c64179c87da76ba7941f462e1847adf91d0856b756dd248b811f0cc19a303aec430	82	{}	2018-12-20 22:14:46.276743
a38989ee3d3a4b573a1685de733d570b8488069024c9638471904ae32ebaf34470616b15e909a8597564cccd49b196cc53c0ee4e0087c38e3e4541901c4eebe3	82	{}	2018-12-20 22:39:23.024117
8a325f94a54f675e075a505705f0d31ab8b33b517841e7e65bc3ace75c3f710096e512c1d4d3e6b8e4e7ae46614cd5325a0ed2437f49361b4a122815fe682464	42	{}	2018-12-21 04:14:22.672939
7c48107f84deb6c9d29b2919e9167fd24f030174372b0fc6f2017351a2b936da4c9b75fc8ca6bdb11892d58fd43de2fd2978f055788518ca8f48c7b3609ec032	95	{}	2018-12-21 04:37:15.697152
f3438720b40868c919d8c1840f4863c3a46fe1ae5d14d5e777d9bdd4505b93c8ce422992975beb86f8c82c51fcac20b8b6daf91777a5e4a55fc33a337c3b9f16	95	{}	2018-12-21 05:24:43.951591
fc441bae40eba155441fa1cd8cfc20a84e4a2d06b965f3ffe6a9d6bf75b27ba0fe650472a146b91f21fcc0e1affec23622bc3f4acbdbc9f8477dbf03d2c09c8d	101	{}	2018-12-28 21:00:58.079892
eab6c45fbba92d6514fa5939725519114a0b1bac768337051219b8b19617badd33be6dee86fc0ad804bd8a24e9130ba9a7ebc03d86f5f98d4e2853efbd4f6494	42	{}	2019-01-14 07:20:09.039953
13bb848e2bf095f8521bedf5d5b023b254cf585d0684bc2de9a7f83b64c7e673283ce55514d6c2800374d5d062add8a72485139e2aa980fb2b56773e45df4dd6	1	{}	2019-01-15 00:39:58.011054
3a946b8a11da14ec5995139ffa4e600111f22d98f5f635ca76ca400b16fbb7c74b9857e2825d8183efd294702006fc4189bd71f4fd74f67d54b31de41b113336	101	{"username": "jose.gasol@firma.ee", "is_authenticated": "true"}	2018-12-28 21:04:24.036043
d0d279fd816a5a657af14afe2723253faa9a6b3ff5f62f2730b04742a211c1a048a6d207b4f4243998dbce33e39ff300473de36568317b3606bf28caeb656849	96	{"username": "juhataja@susteem.ee", "is_authenticated": "true"}	2018-12-21 09:25:34.576211
b7d6d40683307bb592f24b3045876371104a7237ef32a5fb32204f4b6648f6e28c1a5099b1c45036492f9c0ba7577ef0aeac84fa959aec2e47d967f6278d6064	80	{}	2018-12-21 10:25:10.64322
7e09d7abffc2e4e51e7811cfdd4c3a9fb09b8c5734e4fded94fe9be21ba7c9502d3a38ac3a50858ab4a085ab24828c639215198111a2d481994cf6c809310892	85	{"username": "hello@gmail.com", "is_authenticated": "true"}	2018-12-21 23:03:40.029676
ca2e46807b13ab7978037a155b639f20776bbad2b3a9de19edba7e8b4f185b2199b208c5322a782b609bbbb6cad9bb54a4274f811d7c8e7f3829547cf9b87cb9	37	{}	2018-12-21 23:46:37.39869
abbf608bfe642d591f7bb3ab7efa6da7b2df2400317981db7919d46fa2d45a7a8f9d002d50d670440682a263ed9b141dea642b4eb39a062a1f1373671bb1f3f6	92	{}	2018-12-20 23:26:22.525786
73840f4b81a3c9cf7faf85e5dc71243ad6cbd83749d1548e517c002bb95aca3950279d47a6b4149c14ccad17427c9b0cb02fe067a8d65151e94cee995b8bc968	92	{}	2018-12-20 23:26:22.675241
6e107cbace50c40c9ef32eb295643bc9eded1b34f1eccdf89526f7dbe0468225ee1e3f145354b5f0b1d29190586bc4868af4baff4cd12a0ed66080d0c2c83bc9	92	{}	2018-12-20 23:26:23.146623
82e6ba77c7e7e16ad5477e9f089eb40d1f77f97feb08a76352b12fc3475e6ccafe7ef98a99f105b9ee69548997cc307bdccff2d4e117873ee308b7e5773d4495	92	{}	2018-12-20 23:26:23.531514
34cad33ba4949b8274474f6ed3d2b5c848d6703e2086b69fe84f32ae911c24023ee3b31e7372f2c2fd1f39e60980b6987be9ac0494ad5732a72188767167cc74	92	{}	2018-12-20 23:26:23.535629
d7c456e7552cbb988c2f29866212bcc2c5278ff74d9ae6ca3f6c7aa7b42de257213021cdbb5bf6e43b257c4d01aa3996092f9806cd018b976287ee3be9486020	99	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2018-12-28 22:52:22.703479
215f17fa94f7b500a3c8921ec23f83ba60d93f61a7a183c244c699185731962dcae8007031456d1ac76a46257bb9d674cdab20eaf435f70bef1bb9dcdd77ee10	92	{}	2018-12-29 00:11:06.479521
681a7a74a82d481ba0ef46bd9587630b50f12eab0b559f0a513baf382e90d360c6fbe9e239cb9992fd6e60505144a9310e35a1138ef9608904e9ef3f16c0f913	1	{}	2018-12-29 08:48:19.506747
c704e3e16332c79b481a04f734a3855f849954a5d8a375dde322405627dc4e0f6c94f107bba1c0196fd37eaa769b4c44b2bd8a5e5d84a80b678a23fa501fe0b0	90	{}	2018-12-22 18:49:07.975038
5555a89c1b7622cb1cf2141581a982a90d20f31c68fffa5c7b4f46a45917620ee93e52a68037401fb625f2102734735d01131047a4e1b88d7749797631391e19	85	{}	2018-12-22 19:37:59.502025
8bcf704d9065804968f0188c1cb6dc4eac256a3f5ec8c30ee52045c6d004d895b187b30e66796f77e5610c67e452a4e7bb4ec11f3a9fd5c0e4ebd5752c1d44e1	90	{}	2018-12-22 20:38:06.103991
dc41d59ae9ba0cdea97ccac801a10b573d7c2d7a2c69ecfdc2af6c7081f5bfe99de2171fb884ce1fb8458ef393811bacbaea43da0808d7b24aa571e21ad64166	88	{"username": "peeter@juhataja.ee", "is_authenticated": "true"}	2018-12-23 14:55:19.041296
ea6ab69423adfba0d8c632aa2c70af911f44aede8a02ed9c775b31bd9cf8ca001f17a0ff3a6d235c3bd7a4333d81cea378cf2cfabca69171cbd51bdbe513fc66	92	{}	2018-12-20 23:39:20.084899
86580763f9feceb088e21ba58c7e5afc6e6dc892ea3563ebaf4db0c89d4df577686e81a3aec0d85d1f0b6e500e2e261f0d584deb22c20aa2205e3f0eff9d5299	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-27 21:22:56.417342
12f8bfe25f4642ae9c0a4b0bc405a83ec1921126cd598a9189e38821adc2b5fab2dda37a1fc937e2b1ec92e98f9e79e25a592743a988b6e56dd1af314edb1cf3	88	{"username": "peeter@juhataja.ee", "is_authenticated": "true"}	2018-12-20 23:49:59.878821
d85ed21fcfd001e72ac7dc283550ff02ca3471bf2ba15a75d03fac7d31fe59ab3cc82028d6b268e9854c881d268dc92287512f59e1d877bbc192a239a9ff252f	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-23 18:35:08.808281
62e734506a2d33f51a10f42844f585d8d6dd29bcfbb0d01a94680c5602e32d11b1156130fc4ebfb1a2dd03d171cc5b2cb66c07fdd419eb1e7e4cccd872b1f4e0	79	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2018-12-23 18:48:07.312841
08664369515961bb5461fd54b0e8e483aa7210109aaa1fc60eb238d9f19e355adb4900a53a7e754284f8ae7e546cf4420748664507434c4017e5ddb86acec323	88	{"username": "peeter@juhataja.ee", "is_authenticated": "true"}	2018-12-20 23:55:58.021349
bd3a086720f306be300f525ea5270e05340a744a3f92e435435be6a4f9221ba5cc94da1f3abea1d1d58df1d1e72b7805aa335008094902db1936b46bc9f5d3a5	12	{}	2018-12-21 00:09:42.392104
d8b4ba17ffe377b16fc86d9a438e8829b4791833b04a25bbfd6bde3cbdebf739e403be2f9ea113ccc87223da7018fb1ec987922015b63822b8ecf8cfade57ef5	1	{}	2018-12-24 19:50:08.809269
e7235b40b1a538ac5d1c95d71de13f583a726e9503b1a547b6e939b30556a76dd867420f5ce2f894524b12742d0881515135136388b805d6ff0c36d025ccffa4	83	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-23 19:10:19.384489
21012679bb6444eacefdc1982d37d8ddab98ee2de97c4b03ca3c39c559153994fb4a2401713fa210619bfb7b25676ab587a51533f0386f2eeb64ab019512c9ff	12	{}	2018-12-25 00:16:35.197855
4d5ae36b45afdd7043b62f2ecda1677a2bec51a050d5476bdaa837ac547a59d64e6282a85c3d4a392e3618570778ab4fc927d2c564c6356f63b74618d650c953	92	{"username": "jose.gasol@firma.ee", "is_authenticated": "true"}	2018-12-23 22:27:38.207496
822abe367b55d673034d8d97a81884c5cf9cf16f2c264a94905e6e431c5780ec55bb3f774fe576266806673c7a52bcc5661d373ed6001345ebcde7a88c3d4551	87	{}	2018-12-21 01:20:22.505764
5df75b0e5563f94865f2cbfb039dfdb23db2d0e7fa82ec8a25d4ab31fdee7d9bdbec947082c043f8644a482da333a776f497ea6451388096f8650f143f13dfb3	90	{}	2018-12-25 22:09:51.127789
bdd09b9bf224b9705a4eac07f2cf0e36910c77e0447889482aa5777182e073e22abf80308b3037c65d64d5036c10b5efcb3b578ec200b841f8b8ac91c96d6010	90	{}	2018-12-27 08:00:30.060179
31891c922eb25d59dfe64e1f38ce3f108c9d868c0b64ae53b49095a3d0b7cabb7f80a941949365ef1d5e9d7f3abb0e94516ec642512af9b5ab27ac99267c687a	101	{}	2018-12-28 21:00:58.935328
b9f8fdd6132d0dea5670fd01efbf9860a2a6862a740a2c1a569b6531ec094fadca05ca19866510e8bde9864ecea00110acabc5ba691f1a130180a1dc55ac2b76	101	{}	2018-12-28 21:03:59.599851
df6998a9e0e07adae1f4dca405ca3a97baecd78eacaebe97b88bbbec8f20eb42860cc58da249dd632ced189ae8590b22e3669bc6cc54d33384d75f6a8d1402dd	92	{}	2018-12-28 21:21:29.477291
1a97c2ee5d2915382f87f8eef2f71d43b06a5b4446e1f903d0301a3fd39b91a106f70eaa090a75e65ab5a9b6db96c6869258452e00aee775b15da0a1d44a1d1d	92	{}	2018-12-28 21:39:26.561584
f3764684197dfb08f3c69cb78de74351f0c41828cd918db66b8a952a9e803bd2b82cecd506aab9a8582f2625eb78d739a3c07bed1fc6b68870eab1b968bce58c	1	{}	2019-01-14 09:45:38.222907
9c4d0f04eaa2cfc0a1e88ca4564b050e18d69d69ee383d7400bf199c42c1c03699c3d3a4f5112a3215a81eaf065a638ed675dfa6f3dbe7a5e7c23e9ba69c16e3	1	{}	2019-01-15 01:45:16.807835
36d498468c6b873c55fe86bfa6d5bbf4f0dd2b7dc424b09b06f5c469d40260d3ddb7b636fd528886c98a291c044f9385445a152bbb365416e668c50bb7039868	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-28 15:13:42.496748
f40cb5e3efd9b1ee1852241aa9856452496097a69772ad884e319fdc869cda4dced716ed8a026ef32ed969e235787a42508345598a009b1af90b04a56dc4e8b8	82	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2019-01-03 18:07:38.857173
2edec543971159522c6c7d866a695856372a9b793521a521e469d71e848e32558127b3382122b9c3b736ce4cf0ac48680992404c0185c3e481805797be3350d6	92	{"username": "jose.gasol@firma.ee", "is_authenticated": "true"}	2018-12-29 00:30:40.137984
e7399e54983489adcb27f679ca05a1bc7a23cb363519f58e85d3343bf5b17ab91ddd25f3bf05834f4143f431559c57bedd11b32d91e5891d7585c6e4fd5909ee	49	{"username": "lucile.burgess@frolix.net", "is_authenticated": "true"}	2018-12-28 18:23:17.347159
3b514df5afcd3904def7f7f9250b7c17ae7812964c57938905b9f4f3b722d0bc01dd620130bed5075e0f5d105ae794d6df6de89139b16e0db6c3a95bf68508ad	82	{}	2018-12-28 19:27:29.555839
c428e79caebdae5d08820bc3e2c37fb48cac4892f4f39c190f3dfe1f83b5345898ceb00caf1083d2e1c9d53962cfdd3a9d632bafdb645c95e14941c7f0d4247f	83	{}	2018-12-29 15:57:04.047994
d97738404fb50fd408991f2f3f148d98ef1b3f49175e869b2ce37db5e9f99b61e2d62152940c5515d08e7e427df3d46555c9fc3adc9659bad0d96dc51e3d9d56	83	{}	2018-12-29 16:42:42.573157
e2c536050db82b824ab5d685d79dea59867093d0c2c494841724f155bc653ac144457d95df2a7ea9536b759d67258ed768c12a79b860ecfc7b7dbcc27706fb77	98	{"username": "karl.tamm@ttu.ee", "is_authenticated": "true"}	2018-12-29 19:25:03.367781
65b981c48dc0015139db1c1b271c29a02019b6703c736091e5d33d067f317c48883efeefca2b0c1055af71688bc0145eb36683633e959207b55e91187a3e1ad0	82	{}	2018-12-30 01:25:26.965784
e2461ec0d4c8719600461511151d9cda77c090a943e4b9ad669d33057e187f7757e01278a97ce8236117d2e107f40efcb81025f37e546d31db95a27751d02ab3	84	{"username": "ward.richard@comvoy.co.uk", "is_authenticated": "true"}	2018-12-30 17:01:56.520394
9d5b53ad87f7c5944e52bbe951cb1e64dbf38e1a6cefcbc45dfb9903ca04ba3ee3fa87a613bce492bf367ec0c8976165c7124c72af36e8a930dc32253e08430a	12	{}	2018-12-31 03:57:22.288482
ddbc6f5fcd4e7eb2e42986f2233a9ed2e553f8196dac69c78498d5fb84788924cae737793c1f464eb70f10fd40c86ad3f733adb3701514cf4416ce8c9152c9de	12	{}	2018-12-31 04:27:12.90739
b9f95eeaae1de14ae1448b15d82dd422b6c83aade5efe2b75aae5b7c077fb0f8788e07461ae5412d7410323bfebc329d4b1f091b4ba849f4c060805438b56e48	74	{}	2018-12-31 04:27:18.233956
e4a260f10b3960ab68d1d051285508132dd7fb87f98efae24983c0d97aaa758461c3809188e0ca3883f540fc0cd1c31b0acbefedfff131286937b1a17792bb52	12	{}	2018-12-31 04:55:14.77616
615ed1090d787a7ad3d3b656ed5439f296cef6b0d0867e68550ee7b6db73fd86d09eb3d277bbf80150fc4d81ba76c07600b72cf04bdedd745c3c200c602986b2	82	{}	2018-12-31 14:12:29.637268
d7ebbe4b8a8ac49221cbaf8eabbd6b4eaa5df4c74cf8beaa226970510f1512911e49b0f79212cdc595942eab3e69b4df57456e5f7ec017a272609223da755f60	1	{}	2019-01-01 05:42:03.70089
12ff2cc390731d2c0ad3a591637a2a29be5dfb3471395ef3fdd0c9dfe4156ab8356e7ca9463253108f9dc3b283ef12783fd5040a5c0773057b13d6f8855afd25	90	{}	2019-01-01 08:50:16.90885
308890b8feb835d7d2e31f10dbbcd8168ff02b3df79581fa3dc7bd5569e0da8dc3ffe473c14237b621b13a69cac5fc36b602dfd94bb7d22f7f3cd3f769931a0b	1	{}	2019-01-01 15:19:34.792603
fc8db0c2d08cb25adf812218c44c683c98105c426d12e844479faaa9620141a48a1ef4b66223a2f3b3e7aa518f0aa57dbdd61387417fcf21ee7d0bd2b3335454	90	{"username": "maritza.alexander@franscene.io", "is_authenticated": "true"}	2019-01-01 17:22:12.87645
93b78c912cd4ab3d30e2b316edfa36339e627096c878520175f14ddb99f17a547cc944eb581ebe2fb76315dcb54dde3a8853c41cb9aadbe650212fc29ca54af3	48	{}	2019-01-02 00:53:55.933296
4d59d14ead10526392fccd6b19d4abdbd50e3247e470efb0a74bc1fed2a7d18b9c5ca0f7f9e804d29cd0dc3612c1d4a2573a040b04ca1be526f0a50713713ae0	85	{}	2019-01-02 13:53:56.29883
c4d00f9f74fa86143b7a3f789ba9414fb193c13d616d4dbc5fdb905dc44767de6caa595d779c9722d30f3b094a2292d8c7dad78427a7eef4d9d74ad28fc30791	98	{}	2018-12-28 03:07:33.588485
ccedccfe7af23f218c6f986832b79b55db35638ac14e2212705ebce5acd1674c1769ac4279295a5d9da19dddf8c050144fcb2fcde7340138096139c289370758	71	{}	2018-12-28 03:07:55.889275
d044fa58d06d6bc09e100eb3aef2c067731908d2842d6e68d7e29a40f26be380b0e939c1dacc1c2a69f1284ecb7bc3a521fc45c404e74cc5a0f61ae4e0d48b4b	101	{}	2018-12-28 21:00:59.348712
aa33d7c0da680982db61cc1c519ca2e0cab9ad2a31ee6e5b1b2caba4fd9827ff8d7e14a913ce719eec0bd77acc477944fe3a478610112adab3bfb0aa79be0635	1	{}	2019-01-14 14:58:51.433402
f7d2da89279a4267318e3392cfd40dd90ae9bf04e4a0c299063274a16b13738ddd24e506510f49c256787336636055291f5fe8fb2961e5f4f07324220524cd3c	42	{}	2019-01-15 02:09:05.125108
d8989da6658a1814b185fe2b780289c5cc2220b38971717d569caeb60a3658510ea46e91c697ea0f90033ace8396f8521967139cf809c9d2c09e3db887df24f2	80	{}	2019-01-03 18:14:23.407802
c2dd494db414249f80031c6c47dbf16bd6cda80fb5199977700a6e3935641b212ea8f694f716d80d440de4bb67b5e2d5d2ab933384305c2689c55899b1065c2f	69	{}	2019-01-03 20:56:17.375938
f884580e3c9d169e0edcc471d316314d44d222b6103db33fa135c1cd0ab619a6ef403e2a203fb74dc41bf0ae8dbecac4cf2ba195e16a741a0e9df024d881092f	92	{}	2018-12-28 21:39:41.690236
face7dc5422ebbc462fceca8485c5bd5a2156ea54e0b3aadc1b7770acb8e43766d233155113855f1d3d431bfe57eab210c419f868e8a88343ce3f0327af48692	98	{"username": "karl.tamm@ttu.ee", "is_authenticated": "true"}	2018-12-28 03:49:53.388337
914c8b7d897da4cba0517b1f0d1a6ce1f864967399600666cf8d4e0049d5bbedac4d2748f1fcbdad44315589ca95ea7419433dd70a7b674a316046413da09175	101	{"username": "jose.gasol@firma.ee", "is_authenticated": "true"}	2018-12-28 23:10:03.351557
13b44c3e487dd80245947ead33364b197301f4a86e9f4fe6f23fe65efdc99d03fd820d34fba30156ff0d77abe1a2dd98725eaa96e44b344a07ce4657a9ae3147	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2018-12-28 14:13:11.645589
6665ca5be24df687fed795dd4caf1bdf86394ab6b19d8e6f268e9758485034ece4583699bc71ddf7203798fe97ec0117cf285dbcdfce3da703a685dff5772d1c	12	{}	2018-12-28 11:14:42.297433
e5588b1cefe3950200b8e99ca54146a04a77e6ec72917e3dbfa4822f520f1dfea04cffccb85bf1d36851235c330de8f2e59348625bfdf367c594585db0e26375	1	{}	2018-12-28 11:33:57.005198
ab2eccebc985171021e61f0078a2e390331a92821f90c33bd98e3a81567983cc99db5f8b0c92e2a7da1d0196fd1b94faa0af7d3630bdeecc1d49fdc570842a1c	92	{}	2018-12-29 00:17:06.534261
4dd58edd1d63c9f7f3c3717299f50655a700cfdad507e9b85b6aec4f201ced22dfef62407e6baaa3553a012d0f0c566df387ea9e7adb09747a2300d132ec708e	98	{}	2018-12-29 00:34:14.511404
06eec7182a65a71ad5a71a7ee99bf67e381a3cddc920b13670737ee988b59fe6b9ae7f4311b81ebb74ffd82b88ee9f17f04766c74190c9e3344d928f0b2b6e61	83	{}	2018-12-29 16:42:42.262017
016e79276bffa9ac0924cc5584db915dfb975c784b34ce6fbfcd7428e42e16eda4213ce1c9df4ff22d21e9769088eda155f94f9a3b1eedbab78e42ce3ee54548	1	{}	2018-12-30 12:54:20.431397
7ba22e5547742e23ba0a3993705925e5efa95866763653bcbfdd846215d7f83c9c7d0a6d1ff8788eeb5cf1caf176f0474adfdaef77a0c71eaf453e33f5daad10	1	{}	2018-12-30 16:38:07.882377
7062da3579bad3ce6e5bc3b8cda524010783553a04d5fce63ad028320e7bb39dc203ba810429f8d6b600c10d48d68593e5833441948d57c7e643981f56db71aa	48	{}	2018-12-29 20:17:03.788336
be9ef969eb29f8297571f854ad6da6649e40ee48c6ea0acbc2e77f5556c5e8eaddd7c5696f66100a25cfeb861c8d65b1148521e50982b79df077668f1a436c22	62	{}	2018-12-31 04:08:23.051993
68e37b3f453c0fa8f154aa42cf966c5b22d246068b2d28932bc4e8bfde5976ca785620d514697c1216d050bead4cccda21d8250913f184b4d8359a68162d1b58	74	{}	2018-12-31 04:27:17.921949
7f657c52a71e6063a3a83b8411c9259ab29d5b7c1d31af355ece6b62a2885928e9560b28d4bdfac8aca786fd00dcf2e0e5092861ecc041cfa34c213baf74cfe2	12	{}	2018-12-31 04:30:02.774002
70bde17012c15e82cf2b8617c827d7b3eefdf413ce37ecf0e7079d6af83418128143a0d67aa78a44b2f9b83d55278e6aaf2dd3d6a3dc481711597076d588a535	88	{"username": "peeter@juhataja.ee", "is_authenticated": "true"}	2018-12-31 13:28:28.176026
38610bcc7ce5808d8a357b2d23a4029e3a7acb9367d55ebf497a5bb7310e91adac35c20abddf90c04d9d97218c76e93a4fc9d0ca81d6836fcface4ef3756a238	90	{}	2018-12-31 15:53:53.997519
178d384ac268529f3aa5cc29e73820eb9e9d50420e4821215544d6dfa622f7636d5bfcf7837ca8ee5c888c13bc0c7126bc7f51a31d343086b546b8fcf5449fa8	1	{}	2019-01-01 08:21:29.129118
710a05996d05e9a524756c3fb3fd97a9a980a9522718692b8a680cfea2a1e676e482a2c52f3bfb3a4b10953401dbaffa5a1dfb9eb33c2649cc01ad17eff50638	90	{}	2019-01-01 13:32:42.343537
816b4d4405018cf26a0c3996d8a788acc4dc5eedda00c5726c4fa55f8ef888635dcb7c1717154f659906bc191cb8e5a5a52af7ba6a8e66f4631a6263e0419e05	99	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2018-12-31 19:12:39.76097
f8853121eef89ad159601cb93d329334102f67364be1f5bb16f286f7627e67b2f58de26eb47fead83099c39fec4d831a8074f15b58423a8551839bacc42b0320	87	{"username": "heli@hot.ee", "is_authenticated": "true"}	2019-01-01 15:30:27.64822
77f09c70b723c0b3928516fded2e32f6c614e83afb656e806a902df249c73eb9b0f33170d82ca6fe6b63e622a5d8c01402d5e2b2db878e9df0ead1fbe9a5c6c5	12	{}	2019-01-01 22:43:51.369218
b865693fec6be843725a6ec6ee67d650e8fe1998b9538d2b8b631ef4d1d1aeb0a2ad95ad35cfb3b47c66cd937fc2bc59d15d7cc46c4de77ae3b2a0225fb131d8	12	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2019-01-03 02:49:40.05089
8fea56bfa097e165cc0e63c23ed809b72ba26e8fd88953e0409a56e9b807d437e876efa952fe8e0a30582e04754c34327143a31dd187d2d8089f82b532715f9f	90	{}	2019-01-14 15:25:29.240783
e12df444c9bf70f5427cfa07fa110f81713ef5129dc1a622a6ceafeec166194017f830b9292b5a5dd8be21f3204430e072518b82047cebc3370dc4875747bcd9	48	{}	2019-01-15 03:17:27.971687
7c8208dd5e2e4f0ed2235f567c8630ace1d925a099d9ed3123e593409e6ecb262f889751e4efcda7c0702ac35bca61c9115654b0619ba1dbd3a23ecd12636168	99	{"username": "louella.henson@colaire.com", "is_authenticated": "true"}	2019-01-04 21:25:48.533628
7b2529aaaa0c6d0e0fbffb8be0001d64e1150278431a744c48f1ef4340ae4891139dcf8f4fde39153154960627ea3b94f53ed2fbde7683afed92001921a1d0d7	92	{}	2019-01-04 22:58:26.62637
6b39d5119f7b2e14296447bd140f568dc3a25033ba0650aed80e2705fed44c430942076ee6d402651a3c624a7dfc14f9a6eaa1bcafbbc14af2d039ae78cef603	80	{}	2019-01-04 23:14:10.882792
37fd40e6e455e544e035a8f7a49b488e0ae9c1e1ec7de511b0722dc445f93f823f9670a962db2f2903c46a4dd2bc3daf9ea2e341a6e1d0c821096c6bdac173ea	82	{}	2019-01-04 23:30:40.726133
b1554d2a544a56fa7dc602c26a6dbbff151727b87868fb5d69a8479110e88a73614c5232291615e5ad8b4ddb742c5f47547d17bdd071ef6a8e9493c9f2ef40ca	12	{}	2019-01-05 20:48:22.739324
8848a01b6d342feed5dd18eef3d7c38b84fbe2e59117447261a5defd0d983081f8bb1497883debf8098094026a648e2c9221a0890149b738a8e642b6e127fe1a	90	{}	2019-01-05 23:11:53.926357
8a8d7b73339840b9a7850c335833ad4210a4f80829e3193e0bf678c8bd79153c907f7ba9ea9c7437166ceffad42c297262af87186780f197abd586a6d0e8bb0b	90	{}	2019-01-05 23:41:15.059166
6b7d9e4b1ac5d4959b33a24d16c28046dfd7c15acaead8a89e4e3fc25bf0298aba4de6240fac1a45c20d3d554fff0ac9ec0b5ad754b12b91f86ab845133e85db	90	{}	2019-01-06 00:29:49.089685
92e83bba84cf9bbce191d770d54aaab8ed3504dea4cd16d597b79dafc0ebf4e237b9631685cf2c813a015f3575fa0a2043752d202d66d12825fb882a36e42246	90	{}	2019-01-07 15:31:40.109003
d84d58c149182a8a80171adc6bd51314c1e9a09b50432af0e9ddf3e3ca0de75c9e5e4d2135a4f9778cbc661abfa785b3a44507cef5d76b0828f8f2ed2e924d79	48	{}	2019-01-14 20:18:10.496825
a4d4540e74563364dd8c00b917c58833345f900ea36ee3a043ba90038385ba9eb44d23f3a2e609d98a1d64c288e9d099e346082c53eb37dcd40b91bf3a8ef401	92	{"username": "jose.gasol@firma.ee", "is_authenticated": "true"}	2019-01-08 21:03:48.668629
5855f6e97ed040d8bf31a239393ca272d4c011db855ec140a700b26852b3f1d728ad5dc9e4d2437dfd76c5200e66ce1634a6defa8560dd53fc062f0e6d0019df	1	{}	2019-01-09 03:57:37.739627
6c6c539c226cf40d32728bda88d7bfd63a3f75cfafee07986ebaedbac642df3245271f10fbe90471f9abb4a4e5fa8c5b30eb738f1119f84a5b8262fe36257c77	75	{}	2019-01-10 22:12:49.513264
a84d9bb99d4d14f05337470d7621e558d8eccdf7809526bd842910090a1cbe8771b372eca5a8dae3760ea940800d856e08e55a6f7a3e6ac4cf0a0958558bbdae	92	{"username": "jose.gasol@firma.ee", "is_authenticated": "true"}	2019-01-09 11:45:33.941949
006841262829a17f1b42fe44ad3ef2d011de7f40c20bd0cb2abb1bd3af848c1f62e87047e4de98b7a7ed94ccc0445d5d07cc30df9e32dc61faaf9fe0f2b0be5c	12	{}	2019-01-10 06:11:17.504536
5bc88d5cff840c74f7412823c2292d74a66db5604170ab9ae63fe8cb7e1dab44ca62e69046bf354666889319cea8e91ec52a2d0a1255b2f3c24e82d2db2f58b2	90	{}	2019-01-10 10:30:23.013015
45fae2239b664ecbad01fbf8e9c5811c74d4723447642a59015c5ed30f9d292268f1b7b27b4e7adfc34c040cb0309ad4d97772219db802877577c8b700e5815c	28	{}	2019-01-10 22:12:56.642511
6033ed2857cb8d7b84cc01131ba740245cce70e6c2d7f7c88793ba4bdac199d44f3d36921c7444df990110931cab9ffe800dcbf19ad92d60f4ce8ef1a5137f74	18	{}	2019-01-10 21:51:18.163528
4b4540705965dfe9bea99c697f3b17abb4cff8c87ed439fe6a17b51ffd77d0a51a7963eb284f76447f173728706763559e76d1797f81ed40eb25bcdbcc3a6db8	29	{}	2019-01-10 21:51:21.662624
b308bd44cf61dcfade2a001e8c9043286a560c327a7a99800d9d46409e6ded12768966df808b0460b03294510eaaa6b161342cdb7b71ef8b4dd55b573823d287	60	{}	2019-01-10 22:09:24.201213
1a7e19d92b12942285a90b126e2ba093a833987d69bc18784803476058922ccf14d73ed6bc598543b8a01ade25929b77d307d017fe513a1370c51df8d2af20d5	102	{}	2019-01-10 22:10:05.833894
a796ce45311d5180b0938eadc0b0bee2f55239becb6cc26c05f08a4c457bcdcb35f479bf9deb973a584857f4fe272430c9ec32ab5337229177be3d0ed777d709	86	{}	2019-01-10 22:13:04.338233
9e6c1b8b19ff1321aef77ff88421f00314bd6f2b59d910b52ff929c4957493a4d7089d9a92e402eb4d83909dfe70861b392d70666a5102435c17796548379b53	42	{}	2019-01-10 22:13:08.994707
0e66e7f6a352e469f6e8f835d10a7dae21208c29b78c80a4807ed07a18c95c03d5af6abcf9b59fa63c13936f79ec76893c5545d2180f673f62ccaec68e7d3314	44	{}	2019-01-10 22:13:18.3992
72c4ea62c2716439d6614be63d8a2977953407bf5586d9a57e0a561945b9c27ce789e6b8175446b33acf07a3ef3d709755c1b95b1b92a0d56e1fb38c980d3ed4	90	{}	2019-01-13 12:04:59.639831
8bd06a24402e0a0e686430b06fed6fb244c476b02985a53ac4d5bf9563eccdac171220100888ab1321d39906a9ca6d4ff7f41a0ade887a36b6f2b326d9fc89d4	1	{}	2019-01-13 12:18:31.800241
cadca604348a4734bb290d7d8de4121e3f33d16d5b6fac8be9c161e4a73dfe068aa5e96cc6b2eb9e46ddabdff7b0daf22f44466c8fefaf84d0640049b509d105	92	{"username": "jose.gasol@firma.ee", "is_authenticated": "true"}	2019-01-11 01:13:00.086151
53ed75060d1088f3e60e8120e327454b16845bdfb6314d428fa9f883b70f303336fc6999bd57e13feb9a7233890bc37e30852e2c77af29568bc52151aa38ea5d	1	{}	2019-01-11 18:57:51.463489
205c711436e3fab2754d5df31ad693442cdbc3925c618fbdad4da865097e24adb6b67e3f43cffc4f86ccf1f034491cf5d3e6d2e6947bd1ee5efdf75c05ec794f	12	{}	2019-01-13 15:59:38.572602
e8b24b84f388a1dec5429412746e7ed4373017a647ab7fb093e22cd858fcd26b287d4f7157c7e53d099c42e68e9c7e542499f9b47090b5c7259d9ce4cf6bcd2a	1	{"username": "kask@ttu.ee", "is_authenticated": "true"}	2019-01-11 21:50:58.714489
dd6a21fd6a469f48dff704536331e200d2520d55d5c3d9e6e8f2a2e9559becec6c5b4dba78eb398b4dff53379f3276c70824b0108288d03a9a808b580d7fc467	90	{}	2019-01-12 01:40:26.749219
657a0dfa6d814f247b29f4bce476cc668d5c9d91528ba3a67b12a4720ea2a3002b158b283053f203996014d3c173f6f3fe90997040f494b1368a32e94ae9d8d5	1	{}	2019-01-12 03:43:49.013271
c4ea06e9ad6093a824952ce687c73c8cd6ba125be091b348586312f82657d4b8a057bd7c63c488bed8de8eaa5cdf4b309b2478e973fc1e20f424ec6d469ab54f	102	{}	2019-01-12 18:38:25.814582
4fa5419ecdd06c8cae003272402263b6e7268a1eba7b6118424575b46f30d6dc09c66f6e63db801e503bef0dceb784f66365ffed01eb61e8bfccc95bc8a0a078	42	{}	2019-01-12 18:38:26.019977
7cba7e73e58b5fc7b16f3f2b4458fd95ff846ed526ffa350667af820043d62c094fed9507d4f6bc4c595cd02e9977788ba35a58ba029239ac6e84a60217b495c	1	{}	2019-01-13 01:50:29.301213
880c723fbc7df8b1e61bb8a10ce694d2f9542232bacc61b0735fce46181662b270124c8a7b93b88bc982a14deeadc3e0019a26074b6c8fcfe34e324517ab3730	102	{}	2019-01-13 10:19:54.214436
95022101f22a195ba21e4cb4d4ef36c50f4a4366d6150df996bbacb531a4429ca56a7a9d73e9ed9586e7aa8f6d7e7d1b959a2b6d85892de0a1604bcce466ae3f	42	{}	2019-01-13 10:19:54.91434
3d39e97edeaffd27f13bfc931d4d03c02084f5d86cbf789c970c640028bbb330c25e246fa67c9d665fff716b7f58c581982178ff9220daaec8ab17c7cb206759	46	{}	2019-01-13 21:33:32.943531
6fa7c75e4d6554c2c9f39bcf7d540bc8f03bb13e4c632490c8929fe99e5ad4d5eba1823bbd7ceaf14a48b914995db173de3b87d1c7d167ba8b833e1362bdafd6	79	{}	2019-01-13 21:33:40.279168
04e0fc69657bb908a273d25d554c2229f644658cffa653df1eebf4a373a67b25508a206154db5316347f9e7cebfc1182675f5ccde07185583d3a3ade0c533692	41	{}	2019-01-13 21:33:42.263605
e5d2a30a902e078b2f8270d451927a392f7dc7aa2fddc0a0c7853f706ab2e229cafc161f453b64210f39a3c3571fc527074ef215e38f411c03f61aefc39b9e5d	48	{}	2019-01-13 21:33:48.407381
6a757d1694aefa801091794ca49aeeb49e794076bdb7bd93574bca303962de84ed22360aa058a58dfa6d87bdd6c7bdcaa64bb62049ea61168bde6577467ee4ba	82	{}	2019-01-13 21:33:50.177554
1aecf5d3d47ef55f8053b9575e53070031d51bb107994047a6e22f4fd61cc55c9eb145317180cd2c39dcc92f5faa1efcd023c87ace015f298d0b923f37d26a9a	16	{}	2019-01-13 21:33:51.89281
6103e19640815a8bdaf3d2bf6c1f34586dac3a6337c116fa4973cb85f6d4a1ca33761274a025b3f2f086c34ce68133acf59a9b1d7a78bf61136ea2622805ffac	27	{}	2019-01-13 21:33:53.343335
3309cfe43eb05d2228e4dec17a481917aa837fa09533e4c144f399461e23e1e1caa824dbf3101c6fba6cff6c353370e5ee4cfebb56b8aafae89410d3c44f88bc	20	{}	2019-01-13 21:33:55.738493
55147659aad237aa6913105d0efbe7f8136d6c911788d1d1412c53977f450a3117eb10c8a4ccb941d760ea7e0a1eec83075ba44b6e160a9be958012d61b687c7	37	{}	2019-01-13 21:33:57.557755
db9e23c4b46ddcc18082bdb2ef78f8a7a2b2179d5df8dfe64bb2481d710cd80e781deafe4136d5c6a291340e3a0e885d66bd3237baaaa3195bf6f03c0c7ff8fd	54	{}	2019-01-13 21:34:00.16653
ce149944f02e4f340d5dd9006e1f0df3dba2a52622f47398aae2215b999aa6dc7e8a30efe3c380f86827d62b5def363ec0fbe14cb4b7730c4d7909b1334181e7	25	{}	2019-01-13 21:34:07.824273
e360f43560390466b52af70e0ac4c4a3f62a1c7ad9337403fe7e1e5d86353961c8c682ef1e18285f7425276b4ae0fb32080641d629b12a2683a8b5d3dafbf289	55	{}	2019-01-13 21:34:09.648923
6722a1293b323fb0a20ff769e3cf090c419ab1359b794fd9f0ad13ea71f854de9c844e757e735ddf2e9dca777c87b1925ecb4df5156d6edd7e927b53355be275	82	{}	2019-01-14 22:12:28.630647
0c6203b784ac02efbda29cb3bcaaaaeae45cb53986721ec127c047debd267327d1dd84bbc438c828f9d50b2fc9dfc983ff38c6841c6cc05644ad53fd63112935	23	{}	2019-01-13 21:34:13.650165
db4b3b1706854d1ec17e630ed2ea16b23ab7918b60c34c5cd023f40185c29fc9d3372f1f64d9270d34525b7b09deee1db8d8b88fc699a2fc805eeb2f2b1aa8ec	39	{}	2019-01-13 21:34:16.602978
e1ee39d47361d26ac937c8e3b7f9eb3d176850e4af58080cee4001f1e81f8dc1b752cc28aaebb351f48f9afb70cfcee5eacea70a09f6599c1c69bae9af7ad74e	50	{}	2019-01-13 21:34:18.535827
734b9baf179cfd0824dba616f538b374c0b1277610dfca55e9d203e40903e39f0437a5b692e3bba5bc1d7c18e5f05f2e6d538b548c4f39e53b4dbafa347841e2	63	{}	2019-01-15 03:20:55.61703
62ba084c641d5aff3a6b587c1c6da13766751548c263c17dcac63b34ebe6865d2bfd510deca536af6181f65bf1abd7e6e6e8d816739357a4ed0ccb51705c94c2	36	{}	2019-01-13 21:34:21.607561
1fb11f5e17e664d00c9cbee38004b9477cc2838148c87ea8d01fe16f452210d03bc237ceb4f7cc2d3617861e585161dcde89816049153e0475e00880c59820fb	78	{}	2019-01-13 21:34:23.436514
1349949305eee7e4d116defe6d4554c2b0a98d9dca9018a91a4a2ce549842a587251b89acf4dfa2334833badd035cb22c405555c6d4b74561297ae577ac3dbd4	57	{}	2019-01-13 21:34:25.777786
92c0dda8a3546e47bb729a6699b2389d899425e344043cafaafd0bfbcaffdb2c98cdeae539f273751248f2938e87edf926a0bb9f0f55d07f7d33ece37fde4f75	88	{}	2019-01-13 21:34:27.758335
48c067778228384b041fca618afc1d41bb7b6b3a247ff6e1bf8a7b56ead83c652d729678f5e97d7ca1febd57d41f2af9b292741882afda5ac3edf554742ca764	70	{}	2019-01-13 21:34:31.580885
8dc1496ae762ddfdeab541b6a819b2d67e5e998592ee57fa356aab0e21686148765b35669588e979abd6497e0b1b7c0b4373eff744e7f9eec1e5e0cde6b86003	68	{}	2019-01-13 21:34:33.379386
c7abf8303883b329bbe4196a3a3d055717e4940b19ffc35ffe2ebbb2a52e003c46c4b3ce0a9d239fc8b17100e5783be2a1276cff9de4f7f28eb6c655312cadeb	21	{}	2019-01-13 21:34:38.508437
2dd9b6779a9b0fd43862ad02fa530403cb41e4550ab814f8fcb309cc8cee7f9c6fff48476635cb8e0ec55113fdc217a97dc7b454dd10ff8cdf6a0ff9ae44bc11	71	{}	2019-01-13 21:34:40.68059
de9c9203f5ec73c6383d30424e4df26f0e896b90d7ac579afc440c58c427dbd41af2b87be27087153d79fdeadb72181dcdcdeb16bb4314c0b0308b17af3a32a6	100	{}	2019-01-13 21:34:47.161393
9f7844d28dff98820eb526b39927ecc6a583c253467b4927241396daa4c43cfe0291b97e31d62a699a7319a4f75c2c96418452236e768de6addf14e865382afd	45	{}	2019-01-13 21:34:49.225539
0d5d1e41b953c354d9ac6cc0e3ae2cdaa794784c543fd8698e362530af3ce5876703bab34f929ece3f5c07849687e6ca1813d6c8a6bebfade3099ab53d1d9ff9	73	{}	2019-01-13 21:34:51.651616
f91322c3f3182ad57c79e02fe9b3773e46595db7e4a81e90670634d1864775201d739c2aed02a1e1504034d627a3b25829f6a1075d4625b0170c28da760bd257	43	{}	2019-01-13 21:34:55.540873
6abf2be5fb238c92b97b8a091a97ef7f21737a0992be97814c642a7b6ecfc631acc181fcaf2b8d13591a6c1f0f2c59b53d007231a34146f9c154e26c56a06b5b	80	{}	2019-01-13 21:34:59.222722
b8246c1b8e0568bc48dace44ab1391fd185e7633af96d2816265ba3ef9757f10deeaed140bf0258d9c56ad896988c670b5d648f8ebf5bca6602a1514c258bb46	30	{}	2019-01-13 21:35:01.803543
a372570d4d353232e5ff2991207295c9bdff7fb28e724a3110781295b817030982ef8cfd1f3b3cffb93da52be12e1de5ffd377d3087300401ac6aed76965f610	18	{}	2019-01-13 21:35:06.965492
3893cbfa0b204d55333f87f1761799fb939c09cacb092b656adbefa56783eeb9b03f63518d597b3b39808b4430fc8eae7f84005a3efd9fc4884ef554e9b50c35	60	{}	2019-01-13 21:35:08.775327
e5711362973746951997b5d28fb582f392607704ef6379f590f15c1c5b0feece1bc4cab4fe01efc6ec2e5276516218d4f72b32d4fd3ffc6e467f98ee03ab57d3	102	{}	2019-01-13 21:35:10.671408
9ba8ac94d37d23c8ddfdccd60d101a70742a274613a2e4c73b54b3d6e99ddd5d801e2cf479153f71debaf45f5665128992a5217bbbd8f0daf4b45afdff46f2e2	75	{}	2019-01-13 21:35:14.260629
e1bddc8573f0295dd0f044b7db7948ddb9deee4fb22df583c67352e272740d622dfa2616f254c8228f9805c004532718c0bbf60435b35f7c45f84f5732d9fbd0	26	{}	2019-01-13 21:35:25.68794
ec9a955d0441e6948f5c618ad9fb7f500a2cb70e54ebb25ea692f3c4e7b3dde915b5def08361eb0f8627c36f91ceea2376f6103ea02565a121dc5641de7f81fe	28	{}	2019-01-13 21:35:28.867454
27ddc626d3fae2b76d0d915a53e3e83b356762d69c9425ac032eec604ef151c452603a894bd95ee3a2330dd0dd2f86d2ac25812a5e0abb64af42a5c9d90d8f52	29	{}	2019-01-13 21:35:35.683179
d8e46fa2c527b7e5cf6c29dcc283fed5dc672777eb522ee58c24662a038b1cf12ba8d6f314682b413dffa8a2463f00a412284cff568b6aceae3abc3b1cf0c415	86	{}	2019-01-13 21:35:40.829255
\.


--
-- Data for Name: template; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.template (template_id, name) FROM stdin;
1	Login page
2	Normal page
3	Top navigation template
4	Region template
5	Navigation region template
6	Report template
7	Form template
8	Drop-down template
9	Button template
10	Textarea template
11	Text input template
12	Password input template
13	Radio template
14	Checkbox template
\.


--
-- Data for Name: textarea_template; Type: TABLE DATA; Schema: pgapex; Owner: t143682
--

COPY pgapex.textarea_template (template_id, template) FROM stdin;
10	<textarea class="form-control" placeholder="#ROW_LABEL#" name="#NAME#">#VALUE#</textarea>
\.


--
-- Name: application_application_id_seq; Type: SEQUENCE SET; Schema: pgapex; Owner: t143682
--

SELECT pg_catalog.setval('pgapex.application_application_id_seq', 102, true);


--
-- Name: fetch_row_condition_fetch_row_condition_id_seq; Type: SEQUENCE SET; Schema: pgapex; Owner: t143682
--

SELECT pg_catalog.setval('pgapex.fetch_row_condition_fetch_row_condition_id_seq', 77, true);


--
-- Name: form_field_form_field_id_seq; Type: SEQUENCE SET; Schema: pgapex; Owner: t143682
--

SELECT pg_catalog.setval('pgapex.form_field_form_field_id_seq', 996, true);


--
-- Name: form_pre_fill_form_pre_fill_id_seq; Type: SEQUENCE SET; Schema: pgapex; Owner: t143682
--

SELECT pg_catalog.setval('pgapex.form_pre_fill_form_pre_fill_id_seq', 29, true);


--
-- Name: list_of_values_list_of_values_id_seq; Type: SEQUENCE SET; Schema: pgapex; Owner: t143682
--

SELECT pg_catalog.setval('pgapex.list_of_values_list_of_values_id_seq', 348, true);


--
-- Name: navigation_item_navigation_item_id_seq; Type: SEQUENCE SET; Schema: pgapex; Owner: t143682
--

SELECT pg_catalog.setval('pgapex.navigation_item_navigation_item_id_seq', 366, true);


--
-- Name: navigation_navigation_id_seq; Type: SEQUENCE SET; Schema: pgapex; Owner: t143682
--

SELECT pg_catalog.setval('pgapex.navigation_navigation_id_seq', 114, true);


--
-- Name: page_item_page_item_id_seq; Type: SEQUENCE SET; Schema: pgapex; Owner: t143682
--

SELECT pg_catalog.setval('pgapex.page_item_page_item_id_seq', 1255, true);


--
-- Name: page_page_id_seq; Type: SEQUENCE SET; Schema: pgapex; Owner: t143682
--

SELECT pg_catalog.setval('pgapex.page_page_id_seq', 362, true);


--
-- Name: region_region_id_seq; Type: SEQUENCE SET; Schema: pgapex; Owner: t143682
--

SELECT pg_catalog.setval('pgapex.region_region_id_seq', 807, true);


--
-- Name: report_column_link_report_column_link_id_seq; Type: SEQUENCE SET; Schema: pgapex; Owner: t143682
--

SELECT pg_catalog.setval('pgapex.report_column_link_report_column_link_id_seq', 98, true);


--
-- Name: report_column_report_column_id_seq; Type: SEQUENCE SET; Schema: pgapex; Owner: t143682
--

SELECT pg_catalog.setval('pgapex.report_column_report_column_id_seq', 5164, true);


--
-- Name: application pk_application; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.application
    ADD CONSTRAINT pk_application PRIMARY KEY (application_id);


--
-- Name: authentication_scheme pk_authentication_scheme; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.authentication_scheme
    ADD CONSTRAINT pk_authentication_scheme PRIMARY KEY (authentication_scheme_id);


--
-- Name: button_template pk_button_template; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.button_template
    ADD CONSTRAINT pk_button_template PRIMARY KEY (template_id);


--
-- Name: display_point pk_display_point; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.display_point
    ADD CONSTRAINT pk_display_point PRIMARY KEY (display_point_id);


--
-- Name: drop_down_template pk_drop_down_template; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.drop_down_template
    ADD CONSTRAINT pk_drop_down_template PRIMARY KEY (template_id);


--
-- Name: fetch_row_condition pk_fetch_row_condition; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.fetch_row_condition
    ADD CONSTRAINT pk_fetch_row_condition PRIMARY KEY (fetch_row_condition_id);


--
-- Name: field_type pk_field_type; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.field_type
    ADD CONSTRAINT pk_field_type PRIMARY KEY (field_type_id);


--
-- Name: form_field pk_form_field; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_field
    ADD CONSTRAINT pk_form_field PRIMARY KEY (form_field_id);


--
-- Name: form_pre_fill pk_form_pre_fill; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_pre_fill
    ADD CONSTRAINT pk_form_pre_fill PRIMARY KEY (form_pre_fill_id);


--
-- Name: form_region pk_form_region; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_region
    ADD CONSTRAINT pk_form_region PRIMARY KEY (region_id);


--
-- Name: form_template pk_form_template; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_template
    ADD CONSTRAINT pk_form_template PRIMARY KEY (template_id);


--
-- Name: html_region pk_html_region; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.html_region
    ADD CONSTRAINT pk_html_region PRIMARY KEY (region_id);


--
-- Name: input_template pk_input_template; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.input_template
    ADD CONSTRAINT pk_input_template PRIMARY KEY (template_id);


--
-- Name: input_template_type pk_input_template_type; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.input_template_type
    ADD CONSTRAINT pk_input_template_type PRIMARY KEY (input_template_type_id);


--
-- Name: list_of_values pk_list_of_values; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.list_of_values
    ADD CONSTRAINT pk_list_of_values PRIMARY KEY (list_of_values_id);


--
-- Name: navigation pk_navigation; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation
    ADD CONSTRAINT pk_navigation PRIMARY KEY (navigation_id);


--
-- Name: navigation_item pk_navigation_item; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_item
    ADD CONSTRAINT pk_navigation_item PRIMARY KEY (navigation_item_id);


--
-- Name: navigation_item_template pk_navigation_item_template; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_item_template
    ADD CONSTRAINT pk_navigation_item_template PRIMARY KEY (navigation_item_template_id);


--
-- Name: navigation_region pk_navigation_region; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_region
    ADD CONSTRAINT pk_navigation_region PRIMARY KEY (region_id);


--
-- Name: navigation_template pk_navigation_template; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_template
    ADD CONSTRAINT pk_navigation_template PRIMARY KEY (template_id);


--
-- Name: navigation_type pk_navigation_type; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_type
    ADD CONSTRAINT pk_navigation_type PRIMARY KEY (navigation_type_id);


--
-- Name: page pk_page; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page
    ADD CONSTRAINT pk_page PRIMARY KEY (page_id);


--
-- Name: page_item pk_page_item; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_item
    ADD CONSTRAINT pk_page_item PRIMARY KEY (page_item_id);


--
-- Name: page_template pk_page_template; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_template
    ADD CONSTRAINT pk_page_template PRIMARY KEY (template_id);


--
-- Name: page_template_display_point pk_page_template_display_point; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_template_display_point
    ADD CONSTRAINT pk_page_template_display_point PRIMARY KEY (page_template_display_point_id);


--
-- Name: page_type pk_page_type; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_type
    ADD CONSTRAINT pk_page_type PRIMARY KEY (page_type_id);


--
-- Name: region pk_region; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.region
    ADD CONSTRAINT pk_region PRIMARY KEY (region_id);


--
-- Name: region_template pk_region_template; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.region_template
    ADD CONSTRAINT pk_region_template PRIMARY KEY (template_id);


--
-- Name: report_column pk_report_column; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.report_column
    ADD CONSTRAINT pk_report_column PRIMARY KEY (report_column_id);


--
-- Name: report_column_link pk_report_column_link; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.report_column_link
    ADD CONSTRAINT pk_report_column_link PRIMARY KEY (report_column_link_id);


--
-- Name: report_column_type pk_report_column_type; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.report_column_type
    ADD CONSTRAINT pk_report_column_type PRIMARY KEY (report_column_type_id);


--
-- Name: report_region pk_report_region; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.report_region
    ADD CONSTRAINT pk_report_region PRIMARY KEY (region_id);


--
-- Name: report_template pk_report_template; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.report_template
    ADD CONSTRAINT pk_report_template PRIMARY KEY (template_id);


--
-- Name: session pk_session; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.session
    ADD CONSTRAINT pk_session PRIMARY KEY (session_id);


--
-- Name: template pk_template; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.template
    ADD CONSTRAINT pk_template PRIMARY KEY (template_id);


--
-- Name: textarea_template pk_textarea_template; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.textarea_template
    ADD CONSTRAINT pk_textarea_template PRIMARY KEY (template_id);


--
-- Name: application uq_application_alias; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.application
    ADD CONSTRAINT uq_application_alias UNIQUE (alias);


--
-- Name: application uq_application_name; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.application
    ADD CONSTRAINT uq_application_name UNIQUE (name);


--
-- Name: form_field uq_form_field_list_of_values_id; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_field
    ADD CONSTRAINT uq_form_field_list_of_values_id UNIQUE (list_of_values_id);


--
-- Name: form_field uq_form_field_region_id_fun_par_ordinal_position; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_field
    ADD CONSTRAINT uq_form_field_region_id_fun_par_ordinal_position UNIQUE (region_id, function_parameter_ordinal_position);


--
-- Name: form_region uq_form_region_form_pre_fill_id; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_region
    ADD CONSTRAINT uq_form_region_form_pre_fill_id UNIQUE (form_pre_fill_id);


--
-- Name: navigation uq_navigation_application_id_name; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation
    ADD CONSTRAINT uq_navigation_application_id_name UNIQUE (application_id, name);


--
-- Name: navigation_item uq_navigation_item_navigation_id_page_id; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_item
    ADD CONSTRAINT uq_navigation_item_navigation_id_page_id UNIQUE (navigation_id, page_id);


--
-- Name: page uq_page_application_id_alias; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page
    ADD CONSTRAINT uq_page_application_id_alias UNIQUE (application_id, alias);


--
-- Name: page_item uq_page_item_form_field_id_page_id; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_item
    ADD CONSTRAINT uq_page_item_form_field_id_page_id UNIQUE (form_field_id, page_id);


--
-- Name: page_item uq_page_item_page_id_name; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_item
    ADD CONSTRAINT uq_page_item_page_id_name UNIQUE (page_id, name);


--
-- Name: page_item uq_page_item_region_id_page_id; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_item
    ADD CONSTRAINT uq_page_item_region_id_page_id UNIQUE (region_id, page_id);


--
-- Name: region uq_region_page_id_page_template_display_point_id_sequence; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.region
    ADD CONSTRAINT uq_region_page_id_page_template_display_point_id_sequence UNIQUE (page_id, page_template_display_point_id, sequence);


--
-- Name: report_column_link uq_report_column_link_report_column_id; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.report_column_link
    ADD CONSTRAINT uq_report_column_link_report_column_id UNIQUE (report_column_id);


--
-- Name: template uq_template_name; Type: CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.template
    ADD CONSTRAINT uq_template_name UNIQUE (name);


--
-- Name: idx_application_authentication_function_name; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_application_authentication_function_name ON pgapex.application USING btree (authentication_function_name);


--
-- Name: idx_application_authentication_function_schema_name; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_application_authentication_function_schema_name ON pgapex.application USING btree (authentication_function_schema_name);


--
-- Name: idx_application_authentication_scheme_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_application_authentication_scheme_id ON pgapex.application USING btree (authentication_scheme_id);


--
-- Name: idx_application_login_page_template_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_application_login_page_template_id ON pgapex.application USING btree (login_page_template_id);


--
-- Name: idx_fetch_row_condition_form_pre_fill_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_fetch_row_condition_form_pre_fill_id ON pgapex.fetch_row_condition USING btree (form_pre_fill_id);


--
-- Name: idx_fetch_row_condition_url_parameter_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_fetch_row_condition_url_parameter_id ON pgapex.fetch_row_condition USING btree (url_parameter_id);


--
-- Name: idx_fetch_row_condition_view_column_name; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_fetch_row_condition_view_column_name ON pgapex.fetch_row_condition USING btree (view_column_name);


--
-- Name: idx_form_field_drop_down_template_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_form_field_drop_down_template_id ON pgapex.form_field USING btree (drop_down_template_id);


--
-- Name: idx_form_field_field_type_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_form_field_field_type_id ON pgapex.form_field USING btree (field_type_id);


--
-- Name: idx_form_field_input_template_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_form_field_input_template_id ON pgapex.form_field USING btree (input_template_id);


--
-- Name: idx_form_field_list_of_values_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_form_field_list_of_values_id ON pgapex.form_field USING btree (list_of_values_id);


--
-- Name: idx_form_field_textarea_template_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_form_field_textarea_template_id ON pgapex.form_field USING btree (textarea_template_id);


--
-- Name: idx_form_pre_fill_schema_name; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_form_pre_fill_schema_name ON pgapex.form_pre_fill USING btree (schema_name);


--
-- Name: idx_form_pre_fill_view_name; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_form_pre_fill_view_name ON pgapex.form_pre_fill USING btree (view_name);


--
-- Name: idx_form_region_button_template_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_form_region_button_template_id ON pgapex.form_region USING btree (button_template_id);


--
-- Name: idx_form_region_function_name; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_form_region_function_name ON pgapex.form_region USING btree (function_name);


--
-- Name: idx_form_region_schema_name; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_form_region_schema_name ON pgapex.form_region USING btree (schema_name);


--
-- Name: idx_form_region_template_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_form_region_template_id ON pgapex.form_region USING btree (template_id);


--
-- Name: idx_input_template_input_template_type_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_input_template_input_template_type_id ON pgapex.input_template USING btree (input_template_type_id);


--
-- Name: idx_list_of_values_label_view_column_name; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_list_of_values_label_view_column_name ON pgapex.list_of_values USING btree (label_view_column_name);


--
-- Name: idx_list_of_values_value_view_column_name; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_list_of_values_value_view_column_name ON pgapex.list_of_values USING btree (value_view_column_name);


--
-- Name: idx_list_of_values_view_name; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_list_of_values_view_name ON pgapex.list_of_values USING btree (view_name);


--
-- Name: idx_navigation_item_navigation_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_navigation_item_navigation_id ON pgapex.navigation_item USING btree (navigation_id);


--
-- Name: idx_navigation_item_page_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_navigation_item_page_id ON pgapex.navigation_item USING btree (page_id);


--
-- Name: idx_navigation_item_parent_navigation_item_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_navigation_item_parent_navigation_item_id ON pgapex.navigation_item USING btree (parent_navigation_item_id);


--
-- Name: idx_navigation_item_template_navigation_template_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_navigation_item_template_navigation_template_id ON pgapex.navigation_item_template USING btree (navigation_template_id);


--
-- Name: idx_navigation_region_navigation_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_navigation_region_navigation_id ON pgapex.navigation_region USING btree (navigation_id);


--
-- Name: idx_navigation_region_navigation_type_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_navigation_region_navigation_type_id ON pgapex.navigation_region USING btree (navigation_type_id);


--
-- Name: idx_navigation_region_template_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_navigation_region_template_id ON pgapex.navigation_region USING btree (template_id);


--
-- Name: idx_page_application_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_page_application_id ON pgapex.page USING btree (application_id);


--
-- Name: idx_page_item_page_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_page_item_page_id ON pgapex.page_item USING btree (page_id);


--
-- Name: idx_page_template_display_point_display_point_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_page_template_display_point_display_point_id ON pgapex.page_template_display_point USING btree (display_point_id);


--
-- Name: idx_page_template_display_point_page_template_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_page_template_display_point_page_template_id ON pgapex.page_template_display_point USING btree (page_template_id);


--
-- Name: idx_page_template_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_page_template_id ON pgapex.page USING btree (template_id);


--
-- Name: idx_page_template_page_type_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_page_template_page_type_id ON pgapex.page_template USING btree (page_type_id);


--
-- Name: idx_region_page_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_region_page_id ON pgapex.region USING btree (page_id);


--
-- Name: idx_region_page_template_display_point_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_region_page_template_display_point_id ON pgapex.region USING btree (page_template_display_point_id);


--
-- Name: idx_region_template_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_region_template_id ON pgapex.region USING btree (template_id);


--
-- Name: idx_report_column_region_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_report_column_region_id ON pgapex.report_column USING btree (region_id);


--
-- Name: idx_report_column_report_column_type_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_report_column_report_column_type_id ON pgapex.report_column USING btree (report_column_type_id);


--
-- Name: idx_report_column_view_column_name; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_report_column_view_column_name ON pgapex.report_column USING btree (view_column_name);


--
-- Name: idx_report_region_schema_name; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_report_region_schema_name ON pgapex.report_region USING btree (schema_name);


--
-- Name: idx_report_region_template_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_report_region_template_id ON pgapex.report_region USING btree (template_id);


--
-- Name: idx_report_region_view_name; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_report_region_view_name ON pgapex.report_region USING btree (view_name);


--
-- Name: idx_session_application_id; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_session_application_id ON pgapex.session USING btree (application_id);


--
-- Name: idx_session_expiration_time; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE INDEX idx_session_expiration_time ON pgapex.session USING btree (expiration_time);


--
-- Name: uq_navigation_item_root_item_sequence; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE UNIQUE INDEX uq_navigation_item_root_item_sequence ON pgapex.navigation_item USING btree (navigation_id, sequence) WHERE (parent_navigation_item_id IS NULL);


--
-- Name: uq_navigation_item_sub_item_sequence; Type: INDEX; Schema: pgapex; Owner: t143682
--

CREATE UNIQUE INDEX uq_navigation_item_sub_item_sequence ON pgapex.navigation_item USING btree (navigation_id, parent_navigation_item_id, sequence) WHERE (parent_navigation_item_id IS NOT NULL);


--
-- Name: application trig_application_authentication_function_exists; Type: TRIGGER; Schema: pgapex; Owner: t143682
--

CREATE CONSTRAINT TRIGGER trig_application_authentication_function_exists AFTER INSERT OR UPDATE ON pgapex.application DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE PROCEDURE pgapex.f_trig_application_authentication_function_exists();


--
-- Name: form_region trig_form_pre_fill_must_be_deleted_with_form_region; Type: TRIGGER; Schema: pgapex; Owner: t143682
--

CREATE CONSTRAINT TRIGGER trig_form_pre_fill_must_be_deleted_with_form_region AFTER DELETE ON pgapex.form_region DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE PROCEDURE pgapex.f_trig_form_pre_fill_must_be_deleted_with_form_region();


--
-- Name: form_field trig_list_of_values_must_be_deleted_with_form_field; Type: TRIGGER; Schema: pgapex; Owner: t143682
--

CREATE CONSTRAINT TRIGGER trig_list_of_values_must_be_deleted_with_form_field AFTER DELETE ON pgapex.form_field DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE PROCEDURE pgapex.f_trig_list_of_values_must_be_deleted_with_form_field();


--
-- Name: navigation_item trig_navigation_item_may_not_contain_cycles; Type: TRIGGER; Schema: pgapex; Owner: t143682
--

CREATE CONSTRAINT TRIGGER trig_navigation_item_may_not_contain_cycles AFTER INSERT OR UPDATE ON pgapex.navigation_item DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE PROCEDURE pgapex.f_trig_navigation_item_may_not_contain_cycles();


--
-- Name: page trig_page_only_one_homepage_per_application; Type: TRIGGER; Schema: pgapex; Owner: t143682
--

CREATE CONSTRAINT TRIGGER trig_page_only_one_homepage_per_application AFTER INSERT OR UPDATE ON pgapex.page DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE PROCEDURE pgapex.f_trig_page_only_one_homepage_per_application();


--
-- Name: application fk_application_authentication_scheme_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.application
    ADD CONSTRAINT fk_application_authentication_scheme_id FOREIGN KEY (authentication_scheme_id) REFERENCES pgapex.authentication_scheme(authentication_scheme_id);


--
-- Name: application fk_application_login_page_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.application
    ADD CONSTRAINT fk_application_login_page_template_id FOREIGN KEY (login_page_template_id) REFERENCES pgapex.page_template(template_id);


--
-- Name: button_template fk_button_template_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.button_template
    ADD CONSTRAINT fk_button_template_template_id FOREIGN KEY (template_id) REFERENCES pgapex.template(template_id);


--
-- Name: drop_down_template fk_drop_down_template_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.drop_down_template
    ADD CONSTRAINT fk_drop_down_template_template_id FOREIGN KEY (template_id) REFERENCES pgapex.template(template_id);


--
-- Name: fetch_row_condition fk_fetch_row_condition_form_pre_fill_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.fetch_row_condition
    ADD CONSTRAINT fk_fetch_row_condition_form_pre_fill_id FOREIGN KEY (form_pre_fill_id) REFERENCES pgapex.form_pre_fill(form_pre_fill_id) ON DELETE CASCADE;


--
-- Name: fetch_row_condition fk_fetch_row_condition_url_parameter_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.fetch_row_condition
    ADD CONSTRAINT fk_fetch_row_condition_url_parameter_id FOREIGN KEY (url_parameter_id) REFERENCES pgapex.page_item(page_item_id) ON DELETE CASCADE;


--
-- Name: form_field fk_form_field_drop_down_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_field
    ADD CONSTRAINT fk_form_field_drop_down_template_id FOREIGN KEY (drop_down_template_id) REFERENCES pgapex.drop_down_template(template_id);


--
-- Name: form_field fk_form_field_field_type_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_field
    ADD CONSTRAINT fk_form_field_field_type_id FOREIGN KEY (field_type_id) REFERENCES pgapex.field_type(field_type_id);


--
-- Name: form_field fk_form_field_input_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_field
    ADD CONSTRAINT fk_form_field_input_template_id FOREIGN KEY (input_template_id) REFERENCES pgapex.input_template(template_id);


--
-- Name: form_field fk_form_field_list_of_values_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_field
    ADD CONSTRAINT fk_form_field_list_of_values_id FOREIGN KEY (list_of_values_id) REFERENCES pgapex.list_of_values(list_of_values_id);


--
-- Name: form_field fk_form_field_region_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_field
    ADD CONSTRAINT fk_form_field_region_id FOREIGN KEY (region_id) REFERENCES pgapex.form_region(region_id) ON DELETE CASCADE;


--
-- Name: form_field fk_form_field_textarea_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_field
    ADD CONSTRAINT fk_form_field_textarea_template_id FOREIGN KEY (textarea_template_id) REFERENCES pgapex.textarea_template(template_id);


--
-- Name: form_region fk_form_region_button_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_region
    ADD CONSTRAINT fk_form_region_button_template_id FOREIGN KEY (button_template_id) REFERENCES pgapex.button_template(template_id);


--
-- Name: form_region fk_form_region_form_pre_fill_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_region
    ADD CONSTRAINT fk_form_region_form_pre_fill_id FOREIGN KEY (form_pre_fill_id) REFERENCES pgapex.form_pre_fill(form_pre_fill_id) ON DELETE SET NULL;


--
-- Name: form_region fk_form_region_region_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_region
    ADD CONSTRAINT fk_form_region_region_id FOREIGN KEY (region_id) REFERENCES pgapex.region(region_id) ON DELETE CASCADE;


--
-- Name: form_region fk_form_region_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_region
    ADD CONSTRAINT fk_form_region_template_id FOREIGN KEY (template_id) REFERENCES pgapex.form_template(template_id);


--
-- Name: form_template fk_form_template_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.form_template
    ADD CONSTRAINT fk_form_template_template_id FOREIGN KEY (template_id) REFERENCES pgapex.template(template_id);


--
-- Name: html_region fk_html_region_region_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.html_region
    ADD CONSTRAINT fk_html_region_region_id FOREIGN KEY (region_id) REFERENCES pgapex.region(region_id) ON DELETE CASCADE;


--
-- Name: input_template fk_input_template_input_template_type_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.input_template
    ADD CONSTRAINT fk_input_template_input_template_type_id FOREIGN KEY (input_template_type_id) REFERENCES pgapex.input_template_type(input_template_type_id);


--
-- Name: input_template fk_input_template_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.input_template
    ADD CONSTRAINT fk_input_template_template_id FOREIGN KEY (template_id) REFERENCES pgapex.template(template_id);


--
-- Name: navigation fk_navigation_application_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation
    ADD CONSTRAINT fk_navigation_application_id FOREIGN KEY (application_id) REFERENCES pgapex.application(application_id) ON DELETE CASCADE;


--
-- Name: navigation_item fk_navigation_item_navigation_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_item
    ADD CONSTRAINT fk_navigation_item_navigation_id FOREIGN KEY (navigation_id) REFERENCES pgapex.navigation(navigation_id) ON DELETE CASCADE;


--
-- Name: navigation_item fk_navigation_item_page_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_item
    ADD CONSTRAINT fk_navigation_item_page_id FOREIGN KEY (page_id) REFERENCES pgapex.page(page_id) ON DELETE CASCADE;


--
-- Name: navigation_item fk_navigation_item_parent_navigation_item_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_item
    ADD CONSTRAINT fk_navigation_item_parent_navigation_item_id FOREIGN KEY (parent_navigation_item_id) REFERENCES pgapex.navigation_item(navigation_item_id) ON DELETE CASCADE;


--
-- Name: navigation_item_template fk_navigation_item_template_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_item_template
    ADD CONSTRAINT fk_navigation_item_template_template_id FOREIGN KEY (navigation_template_id) REFERENCES pgapex.navigation_template(template_id);


--
-- Name: navigation_region fk_navigation_region_navigation_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_region
    ADD CONSTRAINT fk_navigation_region_navigation_id FOREIGN KEY (navigation_id) REFERENCES pgapex.navigation(navigation_id);


--
-- Name: navigation_region fk_navigation_region_navigation_type_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_region
    ADD CONSTRAINT fk_navigation_region_navigation_type_id FOREIGN KEY (navigation_type_id) REFERENCES pgapex.navigation_type(navigation_type_id);


--
-- Name: navigation_region fk_navigation_region_region_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_region
    ADD CONSTRAINT fk_navigation_region_region_id FOREIGN KEY (region_id) REFERENCES pgapex.region(region_id) ON DELETE CASCADE;


--
-- Name: navigation_region fk_navigation_region_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_region
    ADD CONSTRAINT fk_navigation_region_template_id FOREIGN KEY (template_id) REFERENCES pgapex.navigation_template(template_id);


--
-- Name: navigation_template fk_navigation_template_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.navigation_template
    ADD CONSTRAINT fk_navigation_template_template_id FOREIGN KEY (template_id) REFERENCES pgapex.template(template_id);


--
-- Name: page fk_page_application_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page
    ADD CONSTRAINT fk_page_application_id FOREIGN KEY (application_id) REFERENCES pgapex.application(application_id) ON DELETE CASCADE;


--
-- Name: page_item fk_page_item_form_field_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_item
    ADD CONSTRAINT fk_page_item_form_field_id FOREIGN KEY (form_field_id) REFERENCES pgapex.form_field(form_field_id) ON DELETE CASCADE;


--
-- Name: page_item fk_page_item_page_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_item
    ADD CONSTRAINT fk_page_item_page_id FOREIGN KEY (page_id) REFERENCES pgapex.page(page_id) ON DELETE CASCADE;


--
-- Name: page_item fk_page_item_region_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_item
    ADD CONSTRAINT fk_page_item_region_id FOREIGN KEY (region_id) REFERENCES pgapex.report_region(region_id) ON DELETE CASCADE;


--
-- Name: page_template_display_point fk_page_template_display_point_diplay_point_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_template_display_point
    ADD CONSTRAINT fk_page_template_display_point_diplay_point_id FOREIGN KEY (display_point_id) REFERENCES pgapex.display_point(display_point_id);


--
-- Name: page_template_display_point fk_page_template_display_point_page_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_template_display_point
    ADD CONSTRAINT fk_page_template_display_point_page_template_id FOREIGN KEY (page_template_id) REFERENCES pgapex.page_template(template_id);


--
-- Name: page fk_page_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page
    ADD CONSTRAINT fk_page_template_id FOREIGN KEY (template_id) REFERENCES pgapex.page_template(template_id);


--
-- Name: page_template fk_page_template_page_type_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_template
    ADD CONSTRAINT fk_page_template_page_type_id FOREIGN KEY (page_type_id) REFERENCES pgapex.page_type(page_type_id);


--
-- Name: page_template fk_page_template_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.page_template
    ADD CONSTRAINT fk_page_template_template_id FOREIGN KEY (template_id) REFERENCES pgapex.template(template_id);


--
-- Name: region fk_region_page_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.region
    ADD CONSTRAINT fk_region_page_id FOREIGN KEY (page_id) REFERENCES pgapex.page(page_id) ON DELETE CASCADE;


--
-- Name: region fk_region_page_template_display_point_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.region
    ADD CONSTRAINT fk_region_page_template_display_point_id FOREIGN KEY (page_template_display_point_id) REFERENCES pgapex.page_template_display_point(page_template_display_point_id);


--
-- Name: region fk_region_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.region
    ADD CONSTRAINT fk_region_template_id FOREIGN KEY (template_id) REFERENCES pgapex.region_template(template_id);


--
-- Name: region_template fk_region_template_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.region_template
    ADD CONSTRAINT fk_region_template_template_id FOREIGN KEY (template_id) REFERENCES pgapex.template(template_id);


--
-- Name: report_column_link fk_report_column_link_report_column_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.report_column_link
    ADD CONSTRAINT fk_report_column_link_report_column_id FOREIGN KEY (report_column_id) REFERENCES pgapex.report_column(report_column_id) ON DELETE CASCADE;


--
-- Name: report_column fk_report_column_region_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.report_column
    ADD CONSTRAINT fk_report_column_region_id FOREIGN KEY (region_id) REFERENCES pgapex.report_region(region_id) ON DELETE CASCADE;


--
-- Name: report_column fk_report_column_report_column_type_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.report_column
    ADD CONSTRAINT fk_report_column_report_column_type_id FOREIGN KEY (report_column_type_id) REFERENCES pgapex.report_column_type(report_column_type_id);


--
-- Name: report_region fk_report_region_region_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.report_region
    ADD CONSTRAINT fk_report_region_region_id FOREIGN KEY (region_id) REFERENCES pgapex.region(region_id) ON DELETE CASCADE;


--
-- Name: report_region fk_report_region_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.report_region
    ADD CONSTRAINT fk_report_region_template_id FOREIGN KEY (template_id) REFERENCES pgapex.report_template(template_id);


--
-- Name: report_template fk_report_template_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.report_template
    ADD CONSTRAINT fk_report_template_template_id FOREIGN KEY (template_id) REFERENCES pgapex.template(template_id);


--
-- Name: session fk_session_application_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.session
    ADD CONSTRAINT fk_session_application_id FOREIGN KEY (application_id) REFERENCES pgapex.application(application_id) ON DELETE CASCADE;


--
-- Name: textarea_template fk_textarea_template_template_id; Type: FK CONSTRAINT; Schema: pgapex; Owner: t143682
--

ALTER TABLE ONLY pgapex.textarea_template
    ADD CONSTRAINT fk_textarea_template_template_id FOREIGN KEY (template_id) REFERENCES pgapex.template(template_id);


--
-- Name: DATABASE pgapex; Type: ACL; Schema: -; Owner: pgapex_live_user
--

REVOKE CONNECT,TEMPORARY ON DATABASE pgapex FROM PUBLIC;
GRANT ALL ON DATABASE pgapex TO PUBLIC;
GRANT CONNECT ON DATABASE pgapex TO pgapex_live_app_user;
GRANT ALL ON DATABASE pgapex TO t135041;


--
-- Name: SCHEMA pgapex; Type: ACL; Schema: -; Owner: t143682
--

GRANT USAGE ON SCHEMA pgapex TO pgapex_app;
GRANT USAGE ON SCHEMA pgapex TO pgapex_live_app_user;


--
-- Name: FUNCTION f_app_add_error_message(t_message text); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_add_error_message(t_message text) FROM PUBLIC;


--
-- Name: FUNCTION f_app_add_region(v_display_point character varying, i_sequence integer, t_content text); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_add_region(v_display_point character varying, i_sequence integer, t_content text) FROM PUBLIC;


--
-- Name: FUNCTION f_app_add_setting(v_key character varying, v_value character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_add_setting(v_key character varying, v_value character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_app_add_success_message(t_message text); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_add_success_message(t_message text) FROM PUBLIC;


--
-- Name: FUNCTION f_app_create_page(i_application_id integer, i_page_id integer, j_get_params jsonb, j_post_params jsonb); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_create_page(i_application_id integer, i_page_id integer, j_get_params jsonb, j_post_params jsonb) FROM PUBLIC;


--
-- Name: FUNCTION f_app_create_response(t_response_body text); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_create_response(t_response_body text) FROM PUBLIC;


--
-- Name: FUNCTION f_app_create_temp_tables(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_create_temp_tables() FROM PUBLIC;


--
-- Name: FUNCTION f_app_dblink_connect(i_application_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_dblink_connect(i_application_id integer) FROM PUBLIC;


--
-- Name: FUNCTION f_app_dblink_disconnect(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_dblink_disconnect() FROM PUBLIC;


--
-- Name: FUNCTION f_app_error(v_error_message character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_error(v_error_message character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_app_form_region_submit(i_page_id integer, i_region_id integer, j_post_params jsonb); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_form_region_submit(i_page_id integer, i_region_id integer, j_post_params jsonb) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_application_id(v_application_id character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_application_id(v_application_id character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_cookie(v_cookie_name character varying, j_headers jsonb); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_cookie(v_cookie_name character varying, j_headers jsonb) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_dblink_connection_name(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_dblink_connection_name() FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_display_point_content(v_display_point character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_display_point_content(v_display_point character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_error_message(t_error_message_template text); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_error_message(t_error_message_template text) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_form_region(i_region_id integer, j_get_params jsonb); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_form_region(i_region_id integer, j_get_params jsonb) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_html_region(i_region_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_html_region(i_region_id integer) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_logout_link(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_logout_link() FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_message(v_type character varying, t_message_template text); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_message(v_type character varying, t_message_template text) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_navigation_breadcrumb(i_navigation_id integer, i_page_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_navigation_breadcrumb(i_navigation_id integer, i_page_id integer) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_navigation_in_order(i_navigation_id integer, i_parent_navigation_item_id integer, i_parent_ids integer[]); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_navigation_in_order(i_navigation_id integer, i_parent_navigation_item_id integer, i_parent_ids integer[]) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_navigation_items_with_levels(i_navigation_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_navigation_items_with_levels(i_navigation_id integer) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_navigation_of_type(i_navigation_id integer, i_page_id integer, v_navigation_type character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_navigation_of_type(i_navigation_id integer, i_page_id integer, v_navigation_type character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_navigation_region(i_region_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_navigation_region(i_region_id integer) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_page_id(i_application_id integer, v_page_id character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_page_id(i_application_id integer, v_page_id character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_page_regions(i_page_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_page_regions(i_page_id integer) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_report_region(i_region_id integer, j_get_params jsonb); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_report_region(i_region_id integer, j_get_params jsonb) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_report_region_with_template(i_region_id integer, j_data json, v_pagination_query_param character varying, i_page_count integer, i_current_page integer, b_show_header boolean); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_report_region_with_template(i_region_id integer, j_data json, v_pagination_query_param character varying, i_page_count integer, i_current_page integer, b_show_header boolean) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_row_count(v_schema_name character varying, v_view_name character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_row_count(v_schema_name character varying, v_view_name character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_session_id(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_session_id() FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_setting(v_key character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_setting(v_key character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_app_get_success_message(t_success_message_template text); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_get_success_message(t_success_message_template text) FROM PUBLIC;


--
-- Name: FUNCTION f_app_html_special_chars(t_text text); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_html_special_chars(t_text text) FROM PUBLIC;


--
-- Name: FUNCTION f_app_is_authenticated(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_is_authenticated() FROM PUBLIC;


--
-- Name: FUNCTION f_app_logout(v_application_root character varying, v_application_id character varying, j_headers jsonb); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_logout(v_application_root character varying, v_application_id character varying, j_headers jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_app_logout(v_application_root character varying, v_application_id character varying, j_headers jsonb) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_app_logout(v_application_root character varying, v_application_id character varying, j_headers jsonb) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_app_open_session(v_application_root character varying, i_application_id integer, j_headers jsonb); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_open_session(v_application_root character varying, i_application_id integer, j_headers jsonb) FROM PUBLIC;


--
-- Name: FUNCTION f_app_parse_operation(i_application_id integer, i_page_id integer, v_method character varying, j_headers jsonb, j_get_params jsonb, j_post_params jsonb); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_parse_operation(i_application_id integer, i_page_id integer, v_method character varying, j_headers jsonb, j_get_params jsonb, j_post_params jsonb) FROM PUBLIC;


--
-- Name: FUNCTION f_app_query_page(v_application_root character varying, v_application_id character varying, v_page_id character varying, v_method character varying, j_headers jsonb, j_get_params jsonb, j_post_params jsonb); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_query_page(v_application_root character varying, v_application_id character varying, v_page_id character varying, v_method character varying, j_headers jsonb, j_get_params jsonb, j_post_params jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_app_query_page(v_application_root character varying, v_application_id character varying, v_page_id character varying, v_method character varying, j_headers jsonb, j_get_params jsonb, j_post_params jsonb) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_app_query_page(v_application_root character varying, v_application_id character varying, v_page_id character varying, v_method character varying, j_headers jsonb, j_get_params jsonb, j_post_params jsonb) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_app_replace_system_variables(t_template text); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_replace_system_variables(t_template text) FROM PUBLIC;


--
-- Name: FUNCTION f_app_session_read(v_key character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_session_read(v_key character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_app_session_write(v_key character varying, v_value character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_session_write(v_key character varying, v_value character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_app_set_cookie(v_cookie_name character varying, v_cookie_value character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_set_cookie(v_cookie_name character varying, v_cookie_value character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_app_set_header(v_field_name character varying, t_value text); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_app_set_header(v_field_name character varying, t_value text) FROM PUBLIC;


--
-- Name: FUNCTION f_application_application_may_have_a_name(i_id integer, v_name character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_application_application_may_have_a_name(i_id integer, v_name character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_application_application_may_have_a_name(i_id integer, v_name character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_application_application_may_have_a_name(i_id integer, v_name character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_application_application_may_have_an_alias(i_id integer, v_alias character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_application_application_may_have_an_alias(i_id integer, v_alias character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_application_application_may_have_an_alias(i_id integer, v_alias character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_application_application_may_have_an_alias(i_id integer, v_alias character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_application_delete_application(i_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_application_delete_application(i_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_application_delete_application(i_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_application_delete_application(i_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_application_get_application(i_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_application_get_application(i_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_application_get_application(i_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_application_get_application(i_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_application_get_application_authentication(i_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_application_get_application_authentication(i_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_application_get_application_authentication(i_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_application_get_application_authentication(i_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_application_get_applications(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_application_get_applications() FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_application_get_applications() TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_application_get_applications() TO pgapex_live_app_user;


--
-- Name: FUNCTION f_application_save_application(i_id integer, v_name character varying, v_alias character varying, v_database character varying, v_database_username character varying, v_database_password character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_application_save_application(i_id integer, v_name character varying, v_alias character varying, v_database character varying, v_database_username character varying, v_database_password character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_application_save_application(i_id integer, v_name character varying, v_alias character varying, v_database character varying, v_database_username character varying, v_database_password character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_application_save_application(i_id integer, v_name character varying, v_alias character varying, v_database character varying, v_database_username character varying, v_database_password character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_application_save_application_authentication(i_id integer, v_authentication_scheme character varying, v_authentication_function_schema_name character varying, v_authentication_function_name character varying, i_login_page_template integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_application_save_application_authentication(i_id integer, v_authentication_scheme character varying, v_authentication_function_schema_name character varying, v_authentication_function_name character varying, i_login_page_template integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_application_save_application_authentication(i_id integer, v_authentication_scheme character varying, v_authentication_function_schema_name character varying, v_authentication_function_name character varying, i_login_page_template integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_application_save_application_authentication(i_id integer, v_authentication_scheme character varying, v_authentication_function_schema_name character varying, v_authentication_function_name character varying, i_login_page_template integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_database_object_get_authentication_functions(i_application_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_database_object_get_authentication_functions(i_application_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_database_object_get_authentication_functions(i_application_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_database_object_get_authentication_functions(i_application_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_database_object_get_databases(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_database_object_get_databases() FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_database_object_get_databases() TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_database_object_get_databases() TO pgapex_live_app_user;


--
-- Name: FUNCTION f_database_object_get_functions_with_parameters(i_application_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_database_object_get_functions_with_parameters(i_application_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_database_object_get_functions_with_parameters(i_application_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_database_object_get_functions_with_parameters(i_application_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_database_object_get_views_with_columns(i_application_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_database_object_get_views_with_columns(i_application_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_database_object_get_views_with_columns(i_application_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_database_object_get_views_with_columns(i_application_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_get_function_meta_info(database character varying, username character varying, password character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_get_function_meta_info(database character varying, username character varying, password character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_get_function_parameter_meta_info(database character varying, username character varying, password character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_get_function_parameter_meta_info(database character varying, username character varying, password character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_get_schema_meta_info(database character varying, username character varying, password character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_get_schema_meta_info(database character varying, username character varying, password character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_get_view_column_meta_info(database character varying, username character varying, password character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_get_view_column_meta_info(database character varying, username character varying, password character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_get_view_meta_info(database character varying, username character varying, password character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_get_view_meta_info(database character varying, username character varying, password character varying) FROM PUBLIC;


--
-- Name: FUNCTION f_is_superuser(username character varying, password character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_is_superuser(username character varying, password character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_is_superuser(username character varying, password character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_is_superuser(username character varying, password character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_navigation_delete_navigation(i_navigation_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_navigation_delete_navigation(i_navigation_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_navigation_delete_navigation(i_navigation_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_navigation_delete_navigation(i_navigation_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_navigation_delete_navigation_item(i_navigation_item_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_navigation_delete_navigation_item(i_navigation_item_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_navigation_delete_navigation_item(i_navigation_item_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_navigation_delete_navigation_item(i_navigation_item_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_navigation_get_navigation(i_navigation_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_navigation_get_navigation(i_navigation_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_navigation_get_navigation(i_navigation_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_navigation_get_navigation(i_navigation_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_navigation_get_navigation_item(i_navigation_item_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_navigation_get_navigation_item(i_navigation_item_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_navigation_get_navigation_item(i_navigation_item_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_navigation_get_navigation_item(i_navigation_item_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_navigation_get_navigation_items(i_navigation_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_navigation_get_navigation_items(i_navigation_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_navigation_get_navigation_items(i_navigation_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_navigation_get_navigation_items(i_navigation_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_navigation_get_navigations(i_application_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_navigation_get_navigations(i_application_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_navigation_get_navigations(i_application_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_navigation_get_navigations(i_application_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_navigation_navigation_item_contains_cycle(i_navigation_item_id integer, i_parent_navigation_item_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_navigation_navigation_item_contains_cycle(i_navigation_item_id integer, i_parent_navigation_item_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_navigation_navigation_item_contains_cycle(i_navigation_item_id integer, i_parent_navigation_item_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_navigation_navigation_item_contains_cycle(i_navigation_item_id integer, i_parent_navigation_item_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_navigation_navigation_item_may_have_a_sequence(i_navigation_item_id integer, i_navigation_id integer, i_parent_navigation_item_id integer, i_sequence integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_navigation_navigation_item_may_have_a_sequence(i_navigation_item_id integer, i_navigation_id integer, i_parent_navigation_item_id integer, i_sequence integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_navigation_navigation_item_may_have_a_sequence(i_navigation_item_id integer, i_navigation_id integer, i_parent_navigation_item_id integer, i_sequence integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_navigation_navigation_item_may_have_a_sequence(i_navigation_item_id integer, i_navigation_id integer, i_parent_navigation_item_id integer, i_sequence integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_navigation_navigation_item_may_refer_to_page(i_navigation_item_id integer, i_navigation_id integer, i_page_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_navigation_navigation_item_may_refer_to_page(i_navigation_item_id integer, i_navigation_id integer, i_page_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_navigation_navigation_item_may_refer_to_page(i_navigation_item_id integer, i_navigation_id integer, i_page_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_navigation_navigation_item_may_refer_to_page(i_navigation_item_id integer, i_navigation_id integer, i_page_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_navigation_navigation_may_have_a_name(i_navigation_id integer, i_application_id integer, v_name character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_navigation_navigation_may_have_a_name(i_navigation_id integer, i_application_id integer, v_name character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_navigation_navigation_may_have_a_name(i_navigation_id integer, i_application_id integer, v_name character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_navigation_navigation_may_have_a_name(i_navigation_id integer, i_application_id integer, v_name character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_navigation_save_navigation(i_navigation_id integer, i_application_id integer, v_name character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_navigation_save_navigation(i_navigation_id integer, i_application_id integer, v_name character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_navigation_save_navigation(i_navigation_id integer, i_application_id integer, v_name character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_navigation_save_navigation(i_navigation_id integer, i_application_id integer, v_name character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_navigation_save_navigation_item(i_navigation_item_id integer, i_parent_navigation_item_id integer, i_navigation_id integer, v_name character varying, i_sequence integer, i_page_id integer, v_url character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_navigation_save_navigation_item(i_navigation_item_id integer, i_parent_navigation_item_id integer, i_navigation_id integer, v_name character varying, i_sequence integer, i_page_id integer, v_url character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_navigation_save_navigation_item(i_navigation_item_id integer, i_parent_navigation_item_id integer, i_navigation_id integer, v_name character varying, i_sequence integer, i_page_id integer, v_url character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_navigation_save_navigation_item(i_navigation_item_id integer, i_parent_navigation_item_id integer, i_navigation_id integer, v_name character varying, i_sequence integer, i_page_id integer, v_url character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_page_delete_page(i_page_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_page_delete_page(i_page_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_page_delete_page(i_page_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_page_delete_page(i_page_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_page_get_page(i_page_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_page_get_page(i_page_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_page_get_page(i_page_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_page_get_page(i_page_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_page_get_pages(i_application_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_page_get_pages(i_application_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_page_get_pages(i_application_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_page_get_pages(i_application_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_page_page_may_have_an_alias(i_page_id integer, i_application_id integer, v_alias character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_page_page_may_have_an_alias(i_page_id integer, i_application_id integer, v_alias character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_page_page_may_have_an_alias(i_page_id integer, i_application_id integer, v_alias character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_page_page_may_have_an_alias(i_page_id integer, i_application_id integer, v_alias character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_page_save_page(i_page_id integer, i_application_id integer, i_template_id integer, v_title character varying, v_alias character varying, b_is_homepage boolean, b_is_authentication_required boolean); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_page_save_page(i_page_id integer, i_application_id integer, i_template_id integer, v_title character varying, v_alias character varying, b_is_homepage boolean, b_is_authentication_required boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_page_save_page(i_page_id integer, i_application_id integer, i_template_id integer, v_title character varying, v_alias character varying, b_is_homepage boolean, b_is_authentication_required boolean) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_page_save_page(i_page_id integer, i_application_id integer, i_template_id integer, v_title character varying, v_alias character varying, b_is_homepage boolean, b_is_authentication_required boolean) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_refresh_database_objects(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_refresh_database_objects() FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_refresh_database_objects() TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_refresh_database_objects() TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_create_report_region_column(i_region_id integer, v_view_column_name character varying, v_heading character varying, i_sequence integer, b_is_text_escaped boolean); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_create_report_region_column(i_region_id integer, v_view_column_name character varying, v_heading character varying, i_sequence integer, b_is_text_escaped boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_create_report_region_column(i_region_id integer, v_view_column_name character varying, v_heading character varying, i_sequence integer, b_is_text_escaped boolean) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_create_report_region_column(i_region_id integer, v_view_column_name character varying, v_heading character varying, i_sequence integer, b_is_text_escaped boolean) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_create_report_region_link(i_region_id integer, v_heading character varying, i_sequence integer, b_is_text_escaped boolean, v_url character varying, v_link_text character varying, v_attributes character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_create_report_region_link(i_region_id integer, v_heading character varying, i_sequence integer, b_is_text_escaped boolean, v_url character varying, v_link_text character varying, v_attributes character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_create_report_region_link(i_region_id integer, v_heading character varying, i_sequence integer, b_is_text_escaped boolean, v_url character varying, v_link_text character varying, v_attributes character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_create_report_region_link(i_region_id integer, v_heading character varying, i_sequence integer, b_is_text_escaped boolean, v_url character varying, v_link_text character varying, v_attributes character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_delete_form_pre_fill_and_form_field(i_region_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_delete_form_pre_fill_and_form_field(i_region_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_delete_form_pre_fill_and_form_field(i_region_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_delete_form_pre_fill_and_form_field(i_region_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_delete_region(i_region_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_delete_region(i_region_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_delete_region(i_region_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_delete_region(i_region_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_delete_report_region_columns(i_region_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_delete_report_region_columns(i_region_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_delete_report_region_columns(i_region_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_delete_report_region_columns(i_region_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_get_display_points_with_regions(i_page_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_get_display_points_with_regions(i_page_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_get_display_points_with_regions(i_page_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_get_display_points_with_regions(i_page_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_get_form_region(i_region_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_get_form_region(i_region_id integer) FROM PUBLIC;


--
-- Name: FUNCTION f_region_get_html_region(i_region_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_get_html_region(i_region_id integer) FROM PUBLIC;


--
-- Name: FUNCTION f_region_get_navigation_region(i_region_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_get_navigation_region(i_region_id integer) FROM PUBLIC;


--
-- Name: FUNCTION f_region_get_region(i_region_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_get_region(i_region_id integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_get_region(i_region_id integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_get_region(i_region_id integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_get_report_region(i_region_id integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_get_report_region(i_region_id integer) FROM PUBLIC;


--
-- Name: FUNCTION f_region_region_may_have_a_sequence(i_region_id integer, i_page_id integer, i_page_template_display_point_id integer, i_sequence integer); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_region_may_have_a_sequence(i_region_id integer, i_page_id integer, i_page_template_display_point_id integer, i_sequence integer) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_region_may_have_a_sequence(i_region_id integer, i_page_id integer, i_page_template_display_point_id integer, i_sequence integer) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_region_may_have_a_sequence(i_region_id integer, i_page_id integer, i_page_template_display_point_id integer, i_sequence integer) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_save_fetch_row_condition(i_form_pre_fill_id integer, i_region_id integer, v_url_parameter character varying, v_view_column_name character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_save_fetch_row_condition(i_form_pre_fill_id integer, i_region_id integer, v_url_parameter character varying, v_view_column_name character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_save_fetch_row_condition(i_form_pre_fill_id integer, i_region_id integer, v_url_parameter character varying, v_view_column_name character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_save_fetch_row_condition(i_form_pre_fill_id integer, i_region_id integer, v_url_parameter character varying, v_view_column_name character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_save_form_field(i_region_id integer, v_field_type_id character varying, i_list_of_values_id integer, i_form_field_template_id integer, v_field_pre_fill_view_column_name character varying, v_form_element_name character varying, v_label character varying, i_sequence integer, b_is_mandatory boolean, b_is_visible boolean, v_default_value character varying, v_help_text character varying, v_function_parameter_type character varying, v_function_parameter_ordinal_position smallint); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_save_form_field(i_region_id integer, v_field_type_id character varying, i_list_of_values_id integer, i_form_field_template_id integer, v_field_pre_fill_view_column_name character varying, v_form_element_name character varying, v_label character varying, i_sequence integer, b_is_mandatory boolean, b_is_visible boolean, v_default_value character varying, v_help_text character varying, v_function_parameter_type character varying, v_function_parameter_ordinal_position smallint) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_save_form_field(i_region_id integer, v_field_type_id character varying, i_list_of_values_id integer, i_form_field_template_id integer, v_field_pre_fill_view_column_name character varying, v_form_element_name character varying, v_label character varying, i_sequence integer, b_is_mandatory boolean, b_is_visible boolean, v_default_value character varying, v_help_text character varying, v_function_parameter_type character varying, v_function_parameter_ordinal_position smallint) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_save_form_field(i_region_id integer, v_field_type_id character varying, i_list_of_values_id integer, i_form_field_template_id integer, v_field_pre_fill_view_column_name character varying, v_form_element_name character varying, v_label character varying, i_sequence integer, b_is_mandatory boolean, b_is_visible boolean, v_default_value character varying, v_help_text character varying, v_function_parameter_type character varying, v_function_parameter_ordinal_position smallint) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_save_form_pre_fill(v_schema_name character varying, v_view_name character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_save_form_pre_fill(v_schema_name character varying, v_view_name character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_save_form_pre_fill(v_schema_name character varying, v_view_name character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_save_form_pre_fill(v_schema_name character varying, v_view_name character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_save_form_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_form_pre_fill_id integer, i_form_template_id integer, i_button_template_id integer, v_schema_name character varying, v_function_name character varying, v_button_label character varying, v_success_message character varying, v_error_message character varying, v_redirect_url character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_save_form_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_form_pre_fill_id integer, i_form_template_id integer, i_button_template_id integer, v_schema_name character varying, v_function_name character varying, v_button_label character varying, v_success_message character varying, v_error_message character varying, v_redirect_url character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_save_form_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_form_pre_fill_id integer, i_form_template_id integer, i_button_template_id integer, v_schema_name character varying, v_function_name character varying, v_button_label character varying, v_success_message character varying, v_error_message character varying, v_redirect_url character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_save_form_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_form_pre_fill_id integer, i_form_template_id integer, i_button_template_id integer, v_schema_name character varying, v_function_name character varying, v_button_label character varying, v_success_message character varying, v_error_message character varying, v_redirect_url character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_save_html_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, t_content character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_save_html_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, t_content character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_save_html_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, t_content character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_save_html_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, t_content character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_save_list_of_values(v_value_view_column_name character varying, v_label_view_column_name character varying, v_view_name character varying, v_schema_name character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_save_list_of_values(v_value_view_column_name character varying, v_label_view_column_name character varying, v_view_name character varying, v_schema_name character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_save_list_of_values(v_value_view_column_name character varying, v_label_view_column_name character varying, v_view_name character varying, v_schema_name character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_save_list_of_values(v_value_view_column_name character varying, v_label_view_column_name character varying, v_view_name character varying, v_schema_name character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_save_navigation_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_navigation_type_id character varying, i_navigation_id integer, i_navigation_template_id integer, b_repeat_last_level boolean); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_save_navigation_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_navigation_type_id character varying, i_navigation_id integer, i_navigation_template_id integer, b_repeat_last_level boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_save_navigation_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_navigation_type_id character varying, i_navigation_id integer, i_navigation_template_id integer, b_repeat_last_level boolean) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_save_navigation_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_navigation_type_id character varying, i_navigation_id integer, i_navigation_template_id integer, b_repeat_last_level boolean) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_region_save_report_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_report_template_id integer, v_schema_name character varying, v_view_name character varying, i_items_per_page integer, b_show_header boolean, v_pagination_query_parameter character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_region_save_report_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_report_template_id integer, v_schema_name character varying, v_view_name character varying, i_items_per_page integer, b_show_header boolean, v_pagination_query_parameter character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_region_save_report_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_report_template_id integer, v_schema_name character varying, v_view_name character varying, i_items_per_page integer, b_show_header boolean, v_pagination_query_parameter character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_region_save_report_region(i_region_id integer, i_page_id integer, i_region_template_id integer, i_page_template_display_point_id integer, v_name character varying, i_sequence integer, b_is_visible boolean, i_report_template_id integer, v_schema_name character varying, v_view_name character varying, i_items_per_page integer, b_show_header boolean, v_pagination_query_parameter character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_template_get_button_templates(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_template_get_button_templates() FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_template_get_button_templates() TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_template_get_button_templates() TO pgapex_live_app_user;


--
-- Name: FUNCTION f_template_get_drop_down_templates(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_template_get_drop_down_templates() FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_template_get_drop_down_templates() TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_template_get_drop_down_templates() TO pgapex_live_app_user;


--
-- Name: FUNCTION f_template_get_form_templates(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_template_get_form_templates() FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_template_get_form_templates() TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_template_get_form_templates() TO pgapex_live_app_user;


--
-- Name: FUNCTION f_template_get_input_templates(v_input_template_type character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_template_get_input_templates(v_input_template_type character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_template_get_input_templates(v_input_template_type character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_template_get_input_templates(v_input_template_type character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_template_get_navigation_templates(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_template_get_navigation_templates() FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_template_get_navigation_templates() TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_template_get_navigation_templates() TO pgapex_live_app_user;


--
-- Name: FUNCTION f_template_get_page_templates(v_page_type character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_template_get_page_templates(v_page_type character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_template_get_page_templates(v_page_type character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_template_get_page_templates(v_page_type character varying) TO pgapex_live_app_user;


--
-- Name: FUNCTION f_template_get_region_templates(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_template_get_region_templates() FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_template_get_region_templates() TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_template_get_region_templates() TO pgapex_live_app_user;


--
-- Name: FUNCTION f_template_get_report_templates(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_template_get_report_templates() FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_template_get_report_templates() TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_template_get_report_templates() TO pgapex_live_app_user;


--
-- Name: FUNCTION f_template_get_textarea_templates(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_template_get_textarea_templates() FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_template_get_textarea_templates() TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_template_get_textarea_templates() TO pgapex_live_app_user;


--
-- Name: FUNCTION f_trig_application_authentication_function_exists(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_trig_application_authentication_function_exists() FROM PUBLIC;


--
-- Name: FUNCTION f_trig_form_pre_fill_must_be_deleted_with_form_region(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_trig_form_pre_fill_must_be_deleted_with_form_region() FROM PUBLIC;


--
-- Name: FUNCTION f_trig_list_of_values_must_be_deleted_with_form_field(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_trig_list_of_values_must_be_deleted_with_form_field() FROM PUBLIC;


--
-- Name: FUNCTION f_trig_navigation_item_may_not_contain_cycles(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_trig_navigation_item_may_not_contain_cycles() FROM PUBLIC;


--
-- Name: FUNCTION f_trig_page_only_one_homepage_per_application(); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_trig_page_only_one_homepage_per_application() FROM PUBLIC;


--
-- Name: FUNCTION f_user_exists(username character varying, password character varying); Type: ACL; Schema: pgapex; Owner: t143682
--

REVOKE ALL ON FUNCTION pgapex.f_user_exists(username character varying, password character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION pgapex.f_user_exists(username character varying, password character varying) TO pgapex_app;
GRANT ALL ON FUNCTION pgapex.f_user_exists(username character varying, password character varying) TO pgapex_live_app_user;


--
-- Name: function; Type: MATERIALIZED VIEW DATA; Schema: pgapex; Owner: t143682
--

REFRESH MATERIALIZED VIEW pgapex.function;


--
-- Name: parameter; Type: MATERIALIZED VIEW DATA; Schema: pgapex; Owner: t143682
--

REFRESH MATERIALIZED VIEW pgapex.parameter;


--
-- Name: view_column; Type: MATERIALIZED VIEW DATA; Schema: pgapex; Owner: t143682
--

REFRESH MATERIALIZED VIEW pgapex.view_column;


--
-- Name: data_type; Type: MATERIALIZED VIEW DATA; Schema: pgapex; Owner: t143682
--

REFRESH MATERIALIZED VIEW pgapex.data_type;


--
-- Name: database; Type: MATERIALIZED VIEW DATA; Schema: pgapex; Owner: t143682
--

REFRESH MATERIALIZED VIEW pgapex.database;


--
-- Name: schema; Type: MATERIALIZED VIEW DATA; Schema: pgapex; Owner: t143682
--

REFRESH MATERIALIZED VIEW pgapex.schema;


--
-- Name: view; Type: MATERIALIZED VIEW DATA; Schema: pgapex; Owner: t143682
--

REFRESH MATERIALIZED VIEW pgapex.view;


--
-- PostgreSQL database dump complete
--

