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
- `hr_driveLinks` — Drive folder URLs (localStorage only)
- Never write to: `lists`, `empProfiles`, `staffPasswords`, `adminPassword`, `staffPrivileges`, `annualDays`

### Rule 5 — HR JS functions MUST be after })();
HR module functions are global — they must be placed AFTER the IIFE `})();` closing in the script tag. Placing them inside the IIFE makes them invisible to HTML onclick handlers.

### Rule 6 — No id/function name conflicts
Never name a div with the same id as a function. e.g. `id="hrGrid"` with `function hrGrid()` — browser treats div as the function. Use `id="hrStaffGrid"` with `function hrRenderGrid()`.

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
- Letters saved to localStorage per employee, can be viewed and reprinted
- Click "+ Letter" in staff detail to generate for that person

### Nitaqat:
- Was a separate sub-tab in old HR tab, NOT included in merged version
- Can be added back later if needed

## HR Functions (global — after })(); in script)
Key functions: `hrGrid()`, `hrSelect(name)`, `hrSelectEl(el)`, `hrDetail(name)`, `hrClose()`, `hrDocToggle(name,docId)`, `hrDocLink(name,docId)`, `hrEditUrl(name)`, `hrLetter(type)`, `hrLetter2(type,empName)`, `hrGenerate()`, `hrCopy()`, `hrPrint()`, `hrSave()`, `hrViewLet(name,idx)`, `hrPrintLet(name,idx)`, `hrShowSaved()`, `hrAllEmps()`

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

---

## NEXT SESSION — PENDING WORK
- HR letter generator: make print output look professional with logo, proper layout (Option 1 mockup shown, approved for build)
- Option 2: upload letterhead image as background
- Option 3: Canva integration for letters

---

*Last updated: June 17, 2026 — Newderma1 Medical Center, Jeddah KSA*
*Major updates: HR tab merged into Vacation tab, staff cards working, document tracking, letter generator*
