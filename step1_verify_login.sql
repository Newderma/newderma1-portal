-- =============================================================================
-- STEP 1: verify_inner_login RPC
-- Project : Newderma1 Portal
-- File    : step1_verify_login.sql
-- Run in  : Supabase Dashboard → SQL Editor
-- Purpose : Server-side login check for clinic-tracker-v2.html.
--           Reads adminPassword and staffPasswords from ct_config via
--           SECURITY DEFINER so the raw values never travel to the browser.
--           Returns { "valid": true|false, "role": "gm"|"staff" } only.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. CREATE OR REPLACE the function
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION verify_inner_login(p_username text, p_pin text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_password  text;
  v_staff_passwords jsonb;
  v_stored_pin      text;
BEGIN

  -- ── Admin check ─────────────────────────────────────────────────────────────
  --
  -- adminPassword is stored in ct_config as a jsonb string, e.g. "MyPass".
  -- The operator  #>> '{}'  extracts the top-level scalar as plain text,
  -- stripping the surrounding JSON quotes.  value::text would include them.
  --
  -- Falls back to 'admin123' when the row is absent or empty, which matches
  -- the existing JS behaviour:  adminPassword || 'admin123'
  --
  IF lower(p_username) = 'admin' THEN

    SELECT value #>> '{}'
      INTO v_admin_password
      FROM ct_config
     WHERE key = 'adminPassword';

    IF p_pin = COALESCE(NULLIF(v_admin_password, ''), 'admin123') THEN
      RETURN jsonb_build_object('valid', true, 'role', 'gm');
    ELSE
      RETURN jsonb_build_object('valid', false);
    END IF;

  END IF;

  -- ── Staff check ──────────────────────────────────────────────────────────────
  --
  -- staffPasswords is stored as a jsonb object:
  --   { "Joan Amilano": "J8697", "Ahmed Khan": "A6048", ... }
  --
  -- p_username is the exact-case staff name that the JS name-matching loop
  -- already resolved from the lists array, so a direct ->> lookup is correct.
  --
  -- Falls back to 'staff123' when the person has no entry in staffPasswords,
  -- which matches the existing JS behaviour:  staffPasswords[name] || 'staff123'
  --
  SELECT value
    INTO v_staff_passwords
    FROM ct_config
   WHERE key = 'staffPasswords';

  IF v_staff_passwords IS NOT NULL THEN
    v_stored_pin := v_staff_passwords ->> p_username;
  END IF;

  IF p_pin = COALESCE(NULLIF(v_stored_pin, ''), 'staff123') THEN
    RETURN jsonb_build_object('valid', true, 'role', 'staff');
  END IF;

  -- ── No match ─────────────────────────────────────────────────────────────────
  RETURN jsonb_build_object('valid', false);

END;
$$;


-- -----------------------------------------------------------------------------
-- 2. Grant EXECUTE
--
-- anon   : needed now because the building lock is not yet in place and the
--          browser calls this with only the anon key.
-- authenticated : needed for when the building lock is added later.
--
-- When Step 4 (building lock) is implemented, the anon grant will be revoked:
--   REVOKE EXECUTE ON FUNCTION verify_inner_login(text, text) FROM anon;
-- -----------------------------------------------------------------------------

GRANT EXECUTE ON FUNCTION verify_inner_login(text, text) TO anon;
GRANT EXECUTE ON FUNCTION verify_inner_login(text, text) TO authenticated;


-- -----------------------------------------------------------------------------
-- 3. Verify the function was created
--    Expected result: one row with routine_name = 'verify_inner_login'
-- -----------------------------------------------------------------------------

SELECT
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name   = 'verify_inner_login';


-- -----------------------------------------------------------------------------
-- 4. Sanity-check queries (safe to run — wrong credentials only)
--    Both should return:  {"valid": false}
-- -----------------------------------------------------------------------------

-- 4a. Wrong admin password
SELECT verify_inner_login('admin', 'wrongpassword');

-- 4b. Nonexistent user
SELECT verify_inner_login('nobody', 'anything');
