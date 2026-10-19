-- ============================================================
-- Migration 044 — Ny status 'prospect' (Potensiell kunde)
--
-- Salgsmøter, demoer og tilbudsmøter hos firmaer som ennå ikke er
-- kunde ble ført som 'customer' («Hos kunde»). Da blandes salgsarbeid
-- med besøk hos eksisterende kunder, og det er umulig å se hvor mye
-- tid som går til nysalg. 'prospect' gir dem en egen kategori.
--
-- To operasjoner, samme mønster som 013 og 032:
--
-- 1. Enum-verdien 'prospect' legges til entry_status.
-- 2. members.default_status CHECK-constrainten teller opp enum-verdiene
--    eksplisitt — droppes og opprettes på nytt med 'prospect'.
-- ============================================================

-- ── 1. Legg til 'prospect' i entry_status ────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'entry_status' AND e.enumlabel = 'prospect'
  ) THEN
    ALTER TYPE entry_status ADD VALUE 'prospect' AFTER 'customer';
  END IF;
END $$;

-- ── 2. members.default_status CHECK må mirror'e enum-listen ──
DO $$
DECLARE
  cname text;
BEGIN
  SELECT conname INTO cname
  FROM pg_constraint
  WHERE conrelid = 'public.members'::regclass
    AND pg_get_constraintdef(oid) ILIKE '%default_status%';
  IF cname IS NOT NULL THEN
    EXECUTE format('ALTER TABLE members DROP CONSTRAINT %I', cname);
  END IF;
END $$;

ALTER TABLE members
  ADD CONSTRAINT members_default_status_check
  CHECK (default_status IS NULL OR default_status IN (
    'office', 'remote', 'customer', 'prospect', 'event', 'travel',
    'vacation', 'absent', 'off'
  ));
