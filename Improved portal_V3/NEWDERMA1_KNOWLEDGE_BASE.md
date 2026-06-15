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
There are THREE things to back up:

### 1. HTML files (weekly — save to Google Drive)
- Download latest `clinic-tracker-v2.html` from GitHub
- Download latest `attendance.html` from GitHub
- Download latest `finance.html` from GitHub
- Store in Google Drive folder: `Newderma1 Backups/HTML Files/YYYY-MM-DD/`
- These contain all the code and logic

### 2. Supabase data (weekly — use built-in backup button)
- Log in as GM → Manage tab → scroll to bottom
- Click **💾 Download Backup** → saves Excel file
- Store in Google Drive folder: `Newderma1 Backups/Data Backups/`
- Excel file contains 8 sheets including Employee Profiles and JSON Restore Data
- To restore: click **♻️ Restore from Backup** → select Excel file → confirm

### 3. What the Excel backup contains
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
- Every push to GitHub saves a snapshot of the HTML files
- Go to github.com/Newderma1/newderma1-portal → commits → click any commit to restore old version

---

## SESSION WORKFLOW
1. Upload this knowledge base file
2. Upload latest `clinic-tracker-v2.html` → Claude copies to `/home/claude/clinic-tracker-v4.html`
3. Upload latest `attendance.html` → Claude copies to `/home/claude/attendance-v2.html`
4. Upload `finance.html` if needed
5. State the issue clearly
6. Claude edits, JS syntax checks, copies to `/mnt/user-data/outputs/`

---

## ⛔ CRITICAL DATA SAFETY RULES — ENFORCE IN EVERY SESSION

### Rule 1 — empProfiles STRICT MERGE RULE
**NEVER reconstruct empProfiles from scratch. ALWAYS read first, merge one field, write back full object.**

```javascript
// CORRECT
var p = empProfiles[name] || {};
p.newField = newValue;
empProfiles[name] = p;
await saveConfig('empProfiles', empProfiles);

// WRONG — destroys contractStart, historicalUsed, email, etc.
empProfiles[name] = { contractStart, entitledDays, newField }; // ❌
```

**Fields that must always be preserved:**
- `contractStart` — leave balance depends on this
- `entitledDays` — leave entitlement
- `historicalUsed` — pre-app leave days (critical for balance)
- `email` — vacation notification emails

### Rule 2 — New tools are READ-ONLY by default
- Any new feature connecting to Supabase: read only unless explicitly confirmed
- If a write is needed: state exactly what table, key, and fields will be written
- Never call saveConfig from new code without GM confirmation

### Rule 3 — New features go INSIDE the tracker as tabs
- No separate HTML portals that share the same Supabase
- Separate files only for truly independent tools (finance.html, attendance.html)
- The HR portal incident (June 2026): separate file wrote to empProfiles, wiped all email and contract data

### Rule 4 — Safe isolated config keys for new features
- `hr_driveLinks` — Drive folder URLs per employee (localStorage only, not Supabase)
- Never write to: `lists`, `empProfiles`, `staffPasswords`, `adminPassword`, `staffPrivileges`, `annualDays` from new code

### Rule 5 — Test before production
- If new code must write to Supabase, test with a throwaway key first
- Always syntax-check JS with node before delivering

---

# MODULE 1 — CLINIC TRACKER (`clinic-tracker-v2.html`)

## Access & Roles
- **GM (General Manager):** Full access — all tabs, all data, approve vacations, run payroll
- **Doctor:** Records entry, own vacation, own balance
- **Nurse:** Records entry, own vacation, own balance
- **Other Staff:** Vacation only (default), configurable per-staff
- **Remote Staff:** Hidden from login — managed by GM only via Manage tab
- GM login: select "General Manager" → admin password
- Staff login: select name → staff password

## Navigation (GM only)
`Costs · Records · Dashboard · Utilization · Vacation · Payroll · HR · Manage`

Finance tab opens `https://newderma1.netlify.app/finance.html` in new tab using `window.open()` via `openFinance()` function — NOT part of showPage system.

HR tab added June 2026 — GM only, read-only, no Supabase writes.

## Database Tables
| Table | Contents |
|-------|---------|
| `ct_records` | Procedure records |
| `ct_vacation` | Vacation requests (has `selected_dates` TEXT column) |
| `ct_config` | All config as key/value pairs |
| `att_config` | Attendance config (also stores `autoStaff` list) |

## Config Keys in `ct_config`
`lists` · `itemCosts` · `annualDays` · `staffPasswords` · `adminPassword` · `empProfiles` · `shiftHours` · `staffPrivileges` · `emailjsConfig` · `autoStaff`

## Key Data Structures
```javascript
lists = { doctors:[], nurses:[], procedures:[], items:[], areas:[], staff:[], logo:'' }
empProfiles = { "Name": { contractStart, entitledDays, historicalUsed, email } }
staffPrivileges = { "Name": ["entry","records","vacation"] }
itemCosts = { "ItemName": costPerMl }
drProfiles = { "Name": { type, rent, salary, gosi, sharedSalary, baseSalary, threshold, perfPct } }
autoStaff = ["Name1","Name2"] // remote staff
```

## Employee Profile IDs
**CRITICAL:** Uses index-based IDs (`emp_0`, `emp_1`...) NOT name-based.
Both `renderEmpProfiles()` and `saveEmpProfiles()` use `all.forEach(function(emp, idx)`.
Arabic names would collide if name-based IDs were used.

## Arabic Name Matching — CRITICAL
empProfiles keys must match lists.staff/doctors/nurses EXACTLY including:
- ة vs ه (taa marbuta vs haa)
- ى vs ي (alef maqsura vs yaa)
- Spacing differences
- ق vs ف differences

Always verify with: `console.log(JSON.stringify(lists.staff))` and `console.log(JSON.stringify(Object.keys(empProfiles)))` to compare spelling before fixing.

## Records System
- Items stored as objects: `{name, qty, sellPerMl, costPerMl, totalSell, totalCost, profit}`
- Patient history filtered by `patientId` (file number) first, falls back to name
- `openPatientHistory(name, pid)` — takes both params
- Edit modal: `costPerMl` falls back to `itemCosts[name]` if 0/missing
- Filters: Search · Doctor · Nurse · Month · Item · Procedure
- `exportRecXLS()` respects ALL active filters

## Vacation System

### Leave Types
| Type | Deducts from balance? |
|------|-----------------------|
| Annual Leave | ✅ Yes |
| Emergency Leave | ✅ Yes |
| Unpaid Leave | ✅ Yes |
| Sick Leave | ❌ No |
| Maternity Leave | ❌ No (up to 70 days paid separately) |

### Balance Formula
```
accrual period = 334 days (11 months)
accruedThis = min(daysIntoYear × (entitled/334), entitled)
totalEarned = (completedYears × entitled) + accruedThis
available = max(totalEarned − historicalUsed − appUsed, 0)
```

### Vacation Tabs
- **GM:** New Request · Pending · Balances · History
- **Staff:** Submit · My Requests · My Balance · My History
- Default landing: Submit/New Request for ALL users
- Multi-day: toggle calendar picker → stored as JSON in `selected_dates`
- `normVac(r)` parses `selected_dates` into `r.selectedDates`
- GM can submit on behalf of ANY staff including remote staff
- `populateVacEmp()` includes doctors + nurses + all staff for GM

### Vacation PDF
Bilingual EN/AR, shows selected days or date range, clinic logo in header.
Generated by `generateVacPDF(vacId)` — opens in new window.

## Payroll System

### Three Types
| Type | Formula |
|------|---------|
| **Renting** | Gross − VAT − Monthly Expenses − Salary − GOSI − Special + RentExternal + Addition + CarryForward |
| **Shared Partner** | Net×50% − Lab − Chair − Salary − Special + External + Addition + CarryForward. **Tabby deducted** |
| **Salary+Performance** | if Net+SpExternal > Threshold: (Excess × Perf%) + BaseSalary − Deductions + Addition. **Tabby NOT deducted** |

### Carry-Forward
- Stored as: `prCarryDeduct` and `prCarryAdd` (hidden inputs)
- `netOwed` = this-month only (for ledger running balance)
- `grandTotal` = including carry-forward (for PDF and history display)

### Saved Record Structure
```javascript
{ doctor, month, type, gross, vat, net, tabbyIncome, tabbyFee,
  netOwed, grandTotal, rows, savedAt, baseSalary, perfBonus }
```

## HR Tab (added June 2026)
- GM only, read-only — zero Supabase writes
- Staff directory with leave balance cards
- HR letter generator (6 types, bilingual AR/EN, local templates — no API)
- Nitaqat/Saudization tracker
- Drive folder links stored in localStorage only (not Supabase)

## Backup & Restore (added June 2026)
- Location: Manage tab → bottom card "🗄️ Data Backup & Restore"
- **💾 Download Backup** → exports 8-sheet Excel file
- **♻️ Restore from Backup** → reads JSON Restore Data sheet → restores empProfiles + lists to Supabase
- Records last backup time in localStorage

## Remote Staff System

### Storage
- `autoStaff` array stored in BOTH `ct_config` AND `att_config`
- `mirrorAutoStaffToAtt()` writes to `att_config` whenever list changes

### Adding Remote Staff
`addAutoStaff()` does ALL of:
1. Adds to `autoStaff` → saves to `ct_config`
2. Mirrors to `att_config`
3. Adds to Other Staff list
4. Creates blank `empProfile`
5. Adds to attendance `attStaff` list

---

# MODULE 2 — ATTENDANCE (`attendance.html`)

## Access
- **Admin:** "Admin (General Manager)" → admin password
- **Staff:** Select name → password (or PIN on touchscreen)
- Remote Staff: NOT in login dropdown

## Supabase Tables
| Table | Contents |
|-------|---------|
| `att_records` | Clock-in/out records |
| `att_config` | Staff list, settings, remote staff |
| `ct_vacation` | Read-only — skip approved vacation days |

## Auto-Attendance (Remote Staff)
- Runs on every app load via `runAutoAttendance()`
- Skips Fridays, existing records, approved vacation days
- Clock-in: 1:50–2:10 PM random · Clock-out: 9:50–10:05 PM random
- Loop ceiling: YESTERDAY only (never includes today)

---

# MODULE 3 — BANK RECONCILIATION (`finance.html`)

## Purpose
Match internal accounting (M3N) entries against bank statements.

## Matching Logic
1. POS Sales — match by reference number
2. Fee/VAT — group by ref, compare totals
3. Other — match bank OTHER entries to internal TRANSFER/OTHER

---

# WORKING DAY RULES
- Working days: Saturday – Thursday
- Day off: Friday (getDay() === 5)
- Remote staff shift: 2:00 PM – 10:00 PM (UTC+3)
- Default entitled days: 21 days/year
- Tabby fee: 10% of Tabby/Tamara income
- GPS radius: 150 meters default
- Grace period: 10 minutes default
- Accrual period: 334 days (11 months)

---

# KNOWN BUGS FIXED
1. Arabic names in empProfiles → use index IDs (emp_0, emp_1)
2. Duplicate generateVacPDF → old Arabic version removed
3. normVac wasn't parsing selected_dates → fixed
4. exportRecXLS ignored item/procedure filters → fixed
5. Vacation form not cleared between users → clearVac() in doLogout and startApp
6. Request date used form field → now always new Date() on submit
7. saveItemCosts was sequential → now parallel batches of 20
8. Patient history matched by name only → now matches by patientId first
9. SP deductions resetting to 0 on edit → fixed label matching
10. Finance tab blanking page → openFinance() outside showPage system
11. Ledger double-counting carry-forward → strips carry-forward rows automatically
12. Monthly Expenses doubled on edit → excluded from specRow search
13. prOnMonthChange() → prEditHistory() for saved, prResetToProfileDefaults() for new
14. Summary bar showed negative → absolute value, hidden for specific doctor filter
15. Remote staff auto-attendance included today → fixed to stop at yesterday only
16. HR portal (June 2026) overwrote empProfiles → wiped contractStart and email for all staff. Recovered from localStorage hr_portal_cache. Safety rules added.
17. Arabic name mismatches between lists and empProfiles → ة/ه, ى/ي, ق/ف differences cause "No contract date set". Fix by renaming empProfiles keys to match lists exactly via console.

---

*Last updated: June 2026 — Newderma1 Medical Center, Jeddah KSA*
*Major update: HR portal incident recovery + backup system added*
