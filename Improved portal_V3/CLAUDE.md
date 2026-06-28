# New Derma Center — Clinic Portal

Internal management portal for New Derma Center (مركز البشرة الجديدة الأولى), a dermatology/aesthetics clinic in Jeddah, Saudi Arabia. GM/owner is the primary user and decision-maker for this repo.

## Stack
- Single-file HTML/JS tools deployed on Netlify
- Backend: Supabase (project ref `pdlhcgdjrqzjanonevqx`)
- GitHub: `Newderma1/newderma1-portal`
- Currently mid-rebuild: consolidating scattered standalone tools into one unified portal

## Critical rules — never violate these

1. **Never overwrite entire config/data blobs.** A past incident silently stripped the `email` field from all 22 staff records in `empProfiles` because a tool overwrote the whole blob instead of merging at the row level. Always use strict merge patterns for updates — read existing record, merge only the changed fields, write back. Never replace an entire object/array wholesale when only part of it changed.
2. **No `allow_all` RLS policies on new or migrated tables.** The portal is actively migrating off `allow_all` Supabase RLS policies to proper auth-scoped policies. Any new table must ship with auth-scoped RLS from the start. When touching an existing `allow_all` table, flag it and propose a proper policy rather than leaving it as-is.
3. **Session persistence is intentionally disabled.** Fresh login is required every page load, by design. Do not "fix" this or add persistent sessions/local auth caching unless explicitly asked.
4. **Staff/HR data must not be scattered across representations.** Phase 0 audit found staff data duplicated across four different representations. New work should consolidate toward a single source of truth, not add a fifth.

## Naming & schema conventions
- All new Supabase tables use the `ct_` prefix (e.g. `ct_config`, `ct_records`, `ct_vacation`).
- Known existing tables: `ct_config`, `ct_records`, `ct_vacation`, `att_config`, `att_records`, `md_svc_config`, `md_service_reports`, plus payroll tables.
- Auth-scoped RLS only — no blanket-open policies on anything new.

## Roles (finalized — six total)
GM/Admin, Doctor, Nurse, Receptionist, Engineer, Vendor.

## Existing production tools (being consolidated, not thrown away)
- `clinic-tracker-v2.html` — HR, vacation, payroll, patient records, HR letter generator
- `attendance.html` — GPS-geofenced clock in/out, monthly summary, XLS export
- `device-service.html` — SFDA certificates, PPM scheduling, service reports, compliance dashboard
- `finance.html` / `cash-reconciliation.html` — bank reconciliation, cash reconciliation (M3N vs. kashf)
- `content-tracker.html` — social media content calendar (TikTok/Instagram), Supabase Auth-based
- Room Profitability Tracker

## UI/formatting conventions
- **Brand colors:** primary green `#6abf4b`, darker green `#5aaf3b`, dark slate/navy `#1e293b` (use for headers/nav, NOT green), medium slate `#475569`, light slate `#94a3b8`, light background `#f8fafc`, border gray `#e2e8f0`. Status colors: red `#ef4444`, green `#22c55e`, amber `#f59e0b`.
- **Font:** Calibri preferred, Carlito as fallback on mobile.
- **Bilingual content:** English left/LTR, Arabic right/RTL, two-column table layout where applicable. All staff-facing guides/instructions are written in Arabic.
- Document status convention: green dot = link/file exists, red dot = missing.

## Working style
- Discuss approach before building — don't jump straight to large refactors without confirming the plan first.
- Prefer concise, combined documentation over many separate files.
- Catch logic/rendering issues by testing output, not just reading code — verify behavior, not just syntax.
- When in doubt about a data-integrity tradeoff, ask rather than assume.
