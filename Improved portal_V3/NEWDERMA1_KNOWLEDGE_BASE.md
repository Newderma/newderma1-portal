# Newderma1 Portal — Complete Knowledge Base
### Upload this file at the start of every session for instant full context

---

## PROJECT IDENTITY
- **Live URL:** https://newderma1.netlify.app
- **GitHub:** Newderma1/newderma1-portal
- **Supabase:** https://pdlhcgdjrqzjanonevqx.supabase.co
- **Stack:** Pure HTML/JS/CSS — no build step, no framework
- **Deploy:** Push to GitHub → Netlify auto-deploys in ~1 min

## FILES
| File | Purpose | Recovery Key |
|------|---------|-------------|
| `clinic-tracker-v2.html` | Main portal | `NEWDERMA1-RESET-2024` |
| `attendance.html` | Attendance module | `NEWDERMA1-ATT-RESET` |
| `finance.html` | Bank reconciliation tool | N/A |

⚠️ **Always push the file Claude hands you to GitHub before pulling "latest" from Netlify.** Netlify only ever reflects the last GitHub push, not the last Claude session — pulling from Netlify between sessions has caused completed work (letterhead, fonts, delete-letter feature) to silently disappear and need redoing more than once.

## BACKUP STRATEGY (CRITICAL — learned from June 2026 incident)

### 1. HTML files (weekly — save to Google Drive)
- Download from GitHub → save to `Newderma1 Backups/HTML Files/YYYY-MM-DD/`

### 2. Supabase data (weekly — use built-in backup button)
- GM → Manage tab → scroll to bottom → **💾 Download Backup**
- Save to `Newderma1 Backups/Data Backups/`
- To restore: **♻️ Restore from Backup** → select Excel file → confirm

### 3. Excel backup contains 8 sheets:
| Sheet | Contents |
|-------|---------|
| Payroll History | Doctor payroll records |
| Payments Detail | Payment entries |
| Doctor Profiles | Doctor salary/rent settings |
| Staff List | Names and roles |
| Procedure Records | All patient records |
| Vacation Requests | All leave requests |
| Employee Profiles | Contract dates, historicalUsed, emails ← CRITICAL |
| JSON Restore Data | Raw JSON — paste into Supabase to restore instantly |

### 4. GitHub is also a code backup
Every push saves a snapshot. Go to commits to restore old version.

---

## SESSION WORKFLOW
1. Upload this knowledge base file
2. Upload latest `clinic-tracker-v2.html` → Claude copies to `/home/claude/clinic-tracker-v4.html`
3. Upload latest `attendance.html` if needed
4. State the issue clearly
5. Claude edits, JS syntax checks, copies to `/mnt/user-data/outputs/`

---

## ⛔ CRITICAL DATA SAFETY RULES

### Rule 1 — empProfiles STRICT MERGE RULE
**NEVER reconstruct empProfiles from scratch. ALWAYS read first, merge, write back full object.**
```javascript
// CORRECT
var p = empProfiles[name] || {};
p.newField = newValue;
empProfiles[name] = p;
await saveConfig('empProfiles', empProfiles);
// WRONG — destroys contractStart, historicalUsed, email
empProfiles[name] = { contractStart, entitledDays, newField }; // ❌
```
**Fields to always preserve:** `contractStart`, `entitledDays`, `historicalUsed`, `email`

### Rule 2 — New tools READ-ONLY by default
Any new feature: read only unless explicitly confirmed. Never call saveConfig from new code without GM confirmation.

### Rule 3 — New features go INSIDE the tracker as tabs
No separate HTML portals sharing Supabase. The HR portal incident (June 2026) wiped all email and contract data.

### Rule 4 — Safe isolated config keys
- `hr_driveLinks` — Drive folder URLs — **currently localStorage only, NOT yet migrated to Supabase.** GM wants this made permanent/cross-device, but migration is paused pending the RLS situation below — adding a new write path to `ct_config` before Stage 1 means the Drive links inherit the same wide-open exposure as everything else in that table. GM has been informed and has not yet decided to proceed.
- Never write to: `lists`, `empProfiles`, `staffPasswords`, `adminPassword`, `staffPrivileges`, `annualDays`

### Rule 5 — HR JS functions MUST be after })();
HR module functions are global — they must be placed AFTER the IIFE `})();` closing in the script tag. Placing them inside the IIFE makes them invisible to HTML onclick handlers.

### Rule 6 — No id/function name conflicts
Never name a div with the same id as a function. e.g. `id="hrGrid"` with `function hrGrid()` — browser treats div as the function. Use `id="hrStaffGrid"` with `function hrRenderGrid()`.

---

## 🔓 SECURITY STATUS (investigated June 2026 — IMPORTANT, READ BEFORE NEW FEATURES)

### How auth currently works (and why that matters for RLS)
The app has **no real Supabase Auth accounts**. `doLogin()` just downloads all staff passwords from `ct_config` into the browser and compares the typed value in JavaScript — Supabase itself never knows "who" is asking, only that *some* request came in with the public anon key. This means real per-user Row Level Security (which needs `auth.uid()` to check against) does not currently exist anywhere in this system — there is nothing for a policy to check.

### Anon key is public by design, but currently the only gate
`SB_URL`/`SB_KEY` are hardcoded in plaintext in `clinic-tracker-v2.html` (visible via "View Page Source" on the public Netlify site — this is normal/expected for Supabase's anon key, but means **RLS policies are the only real protection** on the data). Key is the standard `anon` role JWT (not the privileged service-role key), issued March 2026, expires 2036 — never designed to be rotated.

### Confirmed RLS findings (June 2026 audit)
| Table | Status | Notes |
|-------|--------|-------|
| `ct_config` | RLS technically ON, but policy is `allow_all` (`USING (true) WITH CHECK (true)`) | Functionally identical to RLS being off — anyone with the anon key can read/write staff passwords, salary, empProfiles, everything in this table |
| `ct_records` | Same `allow_all` policy | Same exposure — all procedure/financial records |
| `ct_vacation` | Same `allow_all` policy | Same exposure — all leave requests |
| `att_config` | Not yet individually re-checked, likely same pattern (was part of original setup SQL) | |
| `portal_settings` | **RLS disabled outright** (confirmed via Supabase dashboard + Security Advisor lint "RLS Disabled in Public") | NOT part of `clinic-tracker-v2.html` or this knowledge base — belongs to a separate/unknown tool. Contains exactly one value: a manager recovery PIN (was `1969` — flagged as guessable, GM was advised to change it and enable RLS with no policy attached, since nothing in the known tools appeared to depend on reading it live) |

### Stage 0 audit outcome (June 2026)
GM checked Supabase API/Postgres logs and found no signs of unusual access patterns, and Security Advisor flagged only `portal_settings` (not the `ct_*` tables, since those technically have RLS "on" even though the policy is wide open — Advisor doesn't flag permissive policies, only fully-disabled RLS). **No confirmed exploitation found**, but exposure has existed since original setup with no rotation, and Supabase free-tier log retention is short, so this only confirms recent activity looks clean, not the entire history.

### Staged remediation plan (agreed approach — do NOT skip straight to Stage 2)
- **Stage 0 (done)** — Audit logs/Advisor for signs of active exploitation. Enable RLS with no policy on any fully-open table with no live dependency (e.g. `portal_settings`). Rotate any credential that was sitting exposed (e.g. the manager PIN).
- **Stage 1 (not started)** — Add real Supabase Auth for the GM login only. Lock `ct_config` behind "must be authenticated as GM." Leave staff-side tables as-is temporarily. This closes the single biggest exposure (payroll/passwords) without yet touching how staff log in.
- **Stage 2 (not started, full project)** — Real accounts for all staff, proper per-row policies everywhere (e.g. staff can only see their own vacation row), retire the JS password-check entirely. Requires adding role/user_id columns to tables that don't have them, migrating existing passwords, and re-testing every feature that currently assumes "if the browser can read it, it's allowed." This is a genuine project, not a quick fix — should be scoped as its own piece of work, ideally piloted on one table (`ct_vacation` suggested as lowest-stakes starting point) before expanding.

### Rule 7 — Do not add new write paths to open tables without flagging this status first
Any new feature that writes new sensitive data into `ct_config` (e.g. Drive links) is exactly as exposed as everything else already there until Stage 1/2 happen. This isn't a reason to block new features, but the GM should make that tradeoff knowingly each time, not by default.

---

# MODULE 1 — CLINIC TRACKER (`clinic-tracker-v2.html`)

## Access & Roles
- **GM:** Full access — all tabs, all data
- **Doctor/Nurse:** Records entry, own vacation, own balance
- **Other Staff:** Vacation only (default)
- **Remote Staff:** Hidden from login — GM only via Manage tab

## Navigation (GM only) — 7 tabs as of June 2026
`Costs · Records · Dashboard · Utilization · HR · Payroll · Finance · Manage`

Note: "Vacation" tab was renamed to "HR" in June 2026 merge.
Finance tab opens `finance.html` in new tab via `openFinance()` — NOT part of showPage system.

## Database Tables
| Table | Contents |
|-------|---------|
| `ct_records` | Procedure records |
| `ct_vacation` | Vacation requests (`selected_dates` TEXT column) |
| `ct_config` | All config as key/value pairs |
| `att_config` | Attendance config + `autoStaff` list |

## Config Keys in `ct_config`
`lists` · `itemCosts` · `annualDays` · `staffPasswords` · `adminPassword` · `empProfiles` · `shiftHours` · `staffPrivileges` · `emailjsConfig` · `autoStaff`

## Key Data Structures
```javascript
lists = { doctors:[], nurses:[], procedures:[], items:[], areas:[], staff:[], logo:'' }
empProfiles = { "Name": { contractStart, entitledDays, historicalUsed, email } }
staffPrivileges = { "Name": ["entry","records","vacation"] }
autoStaff = ["Name1","Name2"] // remote staff
```

## Employee Profile IDs
**CRITICAL:** Uses index-based IDs (`emp_0`, `emp_1`) NOT name-based.
Both `renderEmpProfiles()` and `saveEmpProfiles()` use `all.forEach(function(emp, idx)`.

## Arabic Name Matching — CRITICAL
empProfiles keys must match lists.staff/doctors/nurses EXACTLY:
- ة vs ه (taa marbuta vs haa)
- ى vs ي (alef maqsura vs yaa)
- ق vs ف differences
- Spacing differences

Verify with: `console.log(JSON.stringify(lists.staff))` and `console.log(JSON.stringify(Object.keys(empProfiles)))`

## HR Tab (merged into Vacation tab — June 2026)
The old separate "HR" tab was merged into the "Vacation" tab which was renamed "HR".

### Sub-tabs (GM only):
- **New Request** — existing vacation request form (untouched)
- **Pending** — existing pending approvals (untouched)
- **Balances** — existing leave balances (untouched)
- **History** — existing leave history (untouched)
- **Staff & Docs** — NEW: staff cards with document status
- **Letters** — NEW: HR letter generator

### Staff & Docs features:
- Cards showing all staff with role badge, leave balance bar, 8 document dots
- Click card → detail panel with leave balance, leave history, document checklist, Drive folder, letters
- Document dots: 🟢 green = Drive link uploaded, 🔴 red = no link yet
- Drive folder links and document status stored in localStorage (NOT Supabase)
- localStorage key pattern: `hr_` + btoa(name) + `_` + suffix (docs/url/lets)

### Letters features:
- 6 letter types: experience cert, salary cert, leave approval, warning, end of service, internal memo
- Bilingual Arabic/English generated locally (no API)
- **Wording is editable** — all 6 templates live in `HR_LETTER_TEMPLATES` object (with `{{token}}` placeholders like `{{emp}}`, `{{pos}}`, `{{fromAR}}`), not hardcoded inline — change wording by editing that one block, not the surrounding logic
- Clinic Arabic name constant `CA` = `مركز البشرة الجديدة الاولي` (must match official letterhead exactly — was previously wrong/transliterated, fixed June 2026)
- **Prints on official letterhead** — header (logo + bilingual name + green divider) and footer (green divider + contact info) embedded as base64 images, extracted from `ND_Head_letter.pdf`. Function: `hrPrintWithLetterhead(text)`. Margins: header/footer inset 14mm sides / 8mm top-bottom from page edge (not flush), body padding 36mm top / 30mm bottom / 16mm sides
- **Side-by-side bilingual layout** — `hrLetterToHTML(text)` splits stored text on the dashed separator (`/\n-{10,}\n+/`) and renders as a 2-column table: English left (LTR, left-aligned), Arabic right (RTL, right-aligned), divided by a dashed border. Used for both on-screen preview and print
- **Font:** Calibri first choice (`Calibri,'Segoe UI','Noto Sans Arabic',Tahoma,Arial,sans-serif` for Arabic; `Calibri,'Segoe UI',Arial,sans-serif` for English) — renders via the user's own browser/OS fonts at print time, not bundled
- Raw plain-text letter stored via `el.setAttribute('data-raw', txt)`; helper `hrRawText(el)` reads it back (falls back to `textContent`) — keeps Copy/Save working against plain text while preview/print show formatted HTML
- Letters saved to localStorage per employee, can be viewed, reprinted, and **deleted** (`hrDeleteLet(name, idx)` with confirm dialog, ✕ button next to View/Print in the saved-letters list)
- Click "+ Letter" in staff detail to generate for that person
- After Save, form closes and returns to that employee's Staff & Docs profile view (previously stayed stuck on the letter generator)

### Nitaqat:
- Was a separate sub-tab in old HR tab, NOT included in merged version
- Can be added back later if needed

## HR Functions (global — after })(); in script)
Key functions: `hrGrid()`, `hrSelect(name)`, `hrSelectEl(el)`, `hrDetail(name)`, `hrClose()`, `hrDocToggle(name,docId)`, `hrDocLink(name,docId)`, `hrEditUrl(name)`, `hrLetter(type)`, `hrLetter2(type,empName)`, `hrGenerate()`, `hrRawText(el)`, `hrCopy()`, `hrPrint()`, `hrPrintWithLetterhead(text)`, `hrLetterToHTML(text)`, `hrFillTemplate(tpl,vals)`, `hrSave()`, `hrViewLet(name,idx)`, `hrPrintLet(name,idx)`, `hrDeleteLet(name,idx)`, `hrShowSaved()`, `hrAllEmps()`

## Vacation System

### Leave Types
| Type | Deducts from balance? |
|------|-----------------------|
| Annual Leave | ✅ Yes |
| Emergency Leave | ✅ Yes |
| Unpaid Leave | ✅ Yes |
| Sick Leave | ❌ No |
| Maternity Leave | ❌ No |

### Balance Formula
```
accrual period = 334 days (11 months)
accruedThis = min(daysIntoYear × (entitled/334), entitled)
totalEarned = (completedYears × entitled) + accruedThis
available = max(totalEarned − historicalUsed − appUsed, 0)
```

### calcBalance() returns:
`{ available, entitled, totalUsed, daysIntoYear, completedYears, accrualPct }`
Note: field is `daysIntoYear` NOT `daysIn`

### showVTab(id, btn) handles all sub-tab switching
```javascript
if(id==='staff')   { hrGrid(); }
if(id==='letters') { hrShowSaved(); }
```

## Payroll System

### Three Types
| Type | Tabby deducted? |
|------|----------------|
| Renting | ✅ Yes |
| Shared Partner | ✅ Yes |
| Salary+Performance | ❌ No |

### Saved Record Structure
```javascript
{ doctor, month, type, gross, vat, net, tabbyIncome, tabbyFee,
  netOwed, grandTotal, rows, savedAt, baseSalary, perfBonus }
```

## Backup & Restore (added June 2026)
- Location: **Manage tab → bottom → "🗄️ Data Backup & Restore"**
- **💾 Download Backup** → exports 8-sheet Excel
- **♻️ Restore from Backup** → reads JSON Restore Data sheet → restores to Supabase
- Records last backup time in localStorage key `nd_last_backup`

## Remote Staff System
- `autoStaff` stored in BOTH `ct_config` AND `att_config`
- `addAutoStaff()` syncs everywhere automatically
- Hidden from login, vacation form (non-GM), live board login
- Auto-attendance: Sat–Thu, 2–10 PM, skips Fridays and approved vacation

---

# MODULE 2 — ATTENDANCE (`attendance.html`)

## Auto-Attendance (Remote Staff)
- Runs on every load via `runAutoAttendance()`
- Loop ceiling: YESTERDAY only (never includes today)
- Clock-in: 1:50–2:10 PM · Clock-out: 9:50–10:05 PM

---

# MODULE 3 — BANK RECONCILIATION (`finance.html`)
Match M3N accounting entries against bank statements.

---

# WORKING DAY RULES
- Working days: Saturday – Thursday
- Day off: Friday (getDay() === 5)
- Default entitled days: 21 days/year
- Tabby fee: 10%
- GPS radius: 150m · Grace period: 10 min
- Accrual period: 334 days

---

# KNOWN BUGS FIXED
1. Arabic names in empProfiles → use index IDs (emp_0, emp_1)
2. HR functions inside IIFE → not global → moved after })();
3. div id="hrGrid" conflicted with function hrGrid() → renamed to hrStaffGrid
4. hrGrid() used getElementById('hrGrid') after rename → fixed to hrStaffGrid
5. calcBalance returns daysIntoYear not daysIn → fixed in HR detail panel
6. Document dot showed red even with Drive link → fixed: green = has URL, red = no URL
7. HR portal (June 2026) overwrote empProfiles → wiped contractStart and email. Recovered from localStorage hr_portal_cache.
8. Arabic name mismatches (ة/ه, ى/ي, ق/ف) → fix by renaming empProfiles keys to match lists exactly via console
9. empProfiles stored as double-encoded string → parsed and re-saved correctly
10. Duplicate })(); before HR block → removed
11. hrRenderGrid called but function named hrGrid → fixed all references
12. Arabic clinic name constant `CA` was wrong/transliterated ("عيادة نيو ديرما سنتر") → corrected to match official letterhead ("مركز البشرة الجديدة الاولي")
13. Letter print used `direction:auto` (guesses direction per line, doesn't align/justify) → replaced with explicit RTL/LTR side-by-side table layout

---

## NEXT SESSION — PENDING WORK
- **Drive links → Supabase migration** — GM wants Drive folder links to persist across devices/browsers instead of localStorage-only. Paused pending GM's decision on the RLS/security tradeoff (see Security Status section above). Revisit once GM decides whether to proceed under current exposure, or wait for Stage 1.
- **Security Stage 1** — add real Supabase Auth for GM login only, lock `ct_config` behind authenticated-GM policy. Not started. Should be scoped as its own session, not bundled into feature requests.
- **portal_settings table** — GM to confirm: enabled RLS with no policy (should be safe, nothing known depends on it), and changed the manager PIN away from `1969`. Confirm this was completed and nothing broke.
- Letterhead/font/bilingual-layout/delete-letter work (previously pending) — ✅ done June 2026, see Letters features section above.

---

*Last updated: June 18, 2026 — Newderma1 Medical Center, Jeddah KSA*
*Major updates: Letterhead printing (real PDF header/footer), Calibri font, side-by-side EN/AR letter layout, editable letter templates, delete-letter feature, corrected Arabic clinic name, Supabase RLS security audit (Stage 0 complete, Stage 1 pending)*
