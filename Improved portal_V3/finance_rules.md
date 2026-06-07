# Clinic Bank Reconciliation — Full Documentation
**File:** `finance.html`  
**Clinic:** Newderma1 — مركز البشرة الجديدة الاولى  
**Last updated:** June 2026  

---

## 1. WHAT THIS MODULE DOES

A standalone HTML file that reconciles the clinic's **bank statement** against the **internal accounting system** for any given month. It detects:

- ✅ Matched transactions
- ❌ Transactions in the bank but missing from the internal system
- ❌ Transactions in the internal system but not found in the bank
- ⚠️ Transactions found on both sides but with different amounts

Runs entirely in the browser — no server needed. XLSX library loads lazily on first file upload for fast page open.

---

## 2. FILES REQUIRED TO RUN

### Bank Statement (Excel .xlsx)
| Rule | Detail |
|---|---|
| Period | May 1 → **June 1** (must include June 1 for POS boundary) |
| Source | Alinma Bank export |
| Language | Arabic + English headers |

### Internal System (Excel .xlsx)
| Rule | Detail |
|---|---|
| Period | **April 30** → June 1 |
| Source | Internal accounting system export |
| Language | Arabic |

**Why the overlap:**
- April 30 internal → matches May 1 bank (POS +1 day processing shift)
- May 31 internal → matches June 1 bank POS (same +1 day shift)

---

## 3. BANK FILE FORMAT — TWO VERSIONS (AUTO-DETECTED)

### New Format (Alinma Bank — from May 2026 onwards)
| Position | Column | Notes |
|---|---|---|
| Col 0 | Balance | رصيد |
| Col 1 | **Combined Credit/Debit** | Positive = credit in, Negative = debit out |
| Col 2 | Transaction Description | تفاصيل العملية |
| Col 6 | Reference Number | الرقم المرجعي |
| Col 8 | Transaction Date | تاريخ العملية |

**Key header:** `دائن/مدين\nCredit/Debit` — tool detects this to switch to new format.

**Value date:** Embedded as `YYYYMMDD` prefix in description.
Example: `20260501 SPANMRC - Total POS Purchase...` → value date = 2026-05-01

**SWIFT/RTGS transfers:** Ref column has a long date-based code like `20260430SARJHIRJHI2BOPF...` — real FT ref extracted from description text instead.

### Old Format (before May 2026)
| Position | Column |
|---|---|
| Col 2 | Credit (دائن) |
| Col 3 | Debit (مدين) |
| Col 4 | Description |
| Col 8 | Reference |
| Col 12 | Date |

**Value date (old format):** Embedded as `Value Dated YYYYMMDD` anywhere in description.

---

## 4. INTERNAL SYSTEM FILE FORMAT

| Position | Column | Notes |
|---|---|---|
| Col 0 | Debit (مدين) | |
| Col 1 | Credit (دائن) | Outgoing expenses recorded here (cost-center accounting) |
| Col 4 | Description | Arabic label + reference number after dash |
| Col 5 | Date | |
| Col 6 | Entry Number | رقم القيد |
| Col 7 | Cost Center | |

**Critical rule:** Reference numbers must appear in the description **after a dash**:
```
فواتير مدى من تاريخ 30/04/2026 الي تاريخ 30/04/2026 - ATMTOT202605012212800000000099268
عمولة نقاط البيع ليوم 11 مايو - ATMTOT202605113217900000000048240
تجديد رخص الممرضه - FT26123W12BF
خصم قسط القرض - LD2234826185
```

**ATMTOT ref length:** Must be exactly **33 characters**. The tool warns if shorter.

**Direction:** Outgoing payments recorded as Credit in internal system. Tool matches by absolute amount — direction ignored.

---

## 5. TRANSACTION TYPES & CLASSIFICATION

### Bank (`bankTxType()`)

| Bank Code | Detected By | Type |
|---|---|---|
| `SPANMRC` | Anywhere in description | `POS_MADA` |
| `SFEEMRC` | Anywhere in description | `FEE_MADA` |
| `VISAMRC` | Anywhere in description | `POS_VISA` |
| `VFEEMRC` | Anywhere in description | `FEE_VISA` |
| `BNETMRC` | Anywhere in description | `POS_MASTER` |
| `BFEEMRC` | Anywhere in description | `FEE_MASTER` |
| `ATMTOT...` + `ضريبة/ضريبه` | Starts with ATMTOT + VAT word | `VAT` |
| Everything else | — | `OTHER` |

### Internal (`internalTxType()`)

| Arabic Keyword | Type | Notes |
|---|---|---|
| `فواتير مدى` | `POS_MADA` | |
| `فواتير فيزا` | `POS_VISA` | |
| `فواتير ماستر` | `POS_MASTER` | |
| `فواتير تحويل` | `OTHER` | Daily income via bank transfer — matched by FT ref |
| `عمولة` + `نقاط البيع/البيه` | `FEE` | |
| `ضريبة/ضريبه` + `نقاط البيع/البيه` | `VAT` | |
| `^قيد يومية رقمNNN ATMTOT` | `VAT` | Bare-ref rows with no Arabic label |
| Everything else | `OTHER` | Transfers, expenses, salaries |

**Typo variants accepted:** `نقاط البيه` = `نقاط البيع` / `ضريبه` = `ضريبة`

---

## 6. REFERENCE NUMBER FORMATS (`REF_RE`)

| Pattern | Type | Length |
|---|---|---|
| `ATMTOT[A-Z0-9]+` | POS fee/VAT | **Always 33 chars** |
| `FT[A-Z0-9]{8,}` | Bank transfer | Variable |
| `LD[A-Z0-9]{5,}` | Loan payment | Variable |
| `[A-Z]{2,}[0-9]{6,}` | Future-proof | Variable |

---

## 7. RECONCILIATION ENGINE (`reconcile()`)

### Section 1 — POS Sales
Match by **reference number only** (not date — bank processes next day).

Internal entries are **summed per day per network** — one total for all Mada, one for Visa, one for Master.

Status: No refs in bank → `Missing in Bank` | Partial → `Amount Mismatch` | Within 0.02 SAR → `Match`

### Section 2 — Fee/VAT
Group by reference number, sum all fee+VAT rows for same ref, compare totals.
Fee and VAT rows always share the same reference number.

### Section 3 — Other
Match by reference number, absolute amounts (ignore credit/debit direction).
Covers: `فواتير تحويل`, outgoing payments, loans, any FT/LD transfers.

---

## 8. BOUNDARY DAY HANDLING

### April 30 (First internal day, not in bank)
Internal POS entries dated April 30 contain refs `ATMTOT20260501...` — bank has those refs on May 1.
Handled automatically by ref-based matching.

### June 1 (Last bank day, boundary day)
Auto-detected when last date of bank file = 1st of a month.

**Filter applied on June 1:**
- ✅ KEEP: POS rows (Mada/Visa/Master)
- ✅ KEEP: Fee/VAT rows whose ref **prefix** (first 25 chars) matches a June 1 POS ref
- ❌ REMOVE: Everything else — deposits, transfers, salary, STC bills

**Why prefix match for Fee/VAT:** Bank uses slightly different ref suffix for fee vs POS row (last digit differs), so prefix matching is used.

```javascript
const lastIsFirstOfMonth = lastDate.slice(8) === '01';
```

---

## 9. REFERENCE VALIDATION (NEW — June 2026)

Tool automatically detects bad ATMTOT refs in the internal system and shows a **red warning box** before results:

| Problem | Example | Detection |
|---|---|---|
| Truncated ref | `ATMTOT20260513521840000000016416` (32 chars) | `ref.length < 33` |
| Stray char before ATMTOT | `5ATMTOT202605135218400...` | `/[A-Z0-9]ATMTOT/.test(desc)` |

Warning lists each bad ref with its full description so accountant knows exactly which entry to fix.

**Common cause:** Excel cell not wide enough when copy-pasting — ref gets cut off. Always paste in a wide column and verify ref is 33 characters.

---

## 10. UI FEATURES

### Filters (v2 design)
Two labeled rows — **Status** and **Category** — each independent:
- Click one status filter + one category filter to narrow down
- OR click just one for broader view
- **Clear filters** button appears when any filter is active

### Info Panel
Shown after running, above results:
- POS machines detected (auto from bank file)
- Count of bare-ref entries
- ⚠️ Red warning if truncated/corrupted ATMTOT refs found (listed explicitly)

### Reset Button
Clears everything: files, results, warnings, upload boxes back to original state.

### Bilingual
EN/ع toggle in header. Arabic mode = RTL layout + IBM Plex Sans Arabic font.
All text through `t(key)` → `T.en` or `T.ar` objects.

---

## 11. FILE STRUCTURE

```
finance.html (944 lines)
├── Comment block — matching rules summary (top of file)
├── HTML
│   ├── Header (title, lang toggle, badges)
│   ├── Upload cards (bank + internal) with visible rules
│   ├── Reset button
│   ├── Run button
│   ├── Info panel (warnings)
│   ├── Alert box (discrepancy list)
│   ├── Filter bar (2 rows: status + category)
│   └── Results table (expandable rows)
├── CSS (~130-380)
└── JavaScript (~380-944)
    ├── T{} — all translations EN + AR
    ├── setLang(), renderStatic(), openInfo(), closeInfo()
    ├── parseNum(), fmtDate(), isValidDate(), round2(), SAR()
    ├── detectBankColumns(), detectInternalColumns()
    ├── REF_RE, extractRefs(), BANK_PFX
    ├── bankTxType(), internalTxType(), detectMachines()
    ├── parseBank() — with boundary filter
    ├── parseInternal()
    ├── reconcile() — sections 1 (POS), 2 (Fee/VAT), 3 (Other)
    ├── renderInfoPanel(), renderBadges(), renderAlert()
    ├── renderFilters(), renderTable(), toggleExpand()
    ├── setStatusFilter(), setCatFilter(), resetFilters()
    ├── loadFile(), markLoaded(), loadXLSX() (lazy)
    ├── resetAll()
    └── runReconciliation()
```

---

## 12. KEY CONSTANTS

| Constant | Where | Change when |
|---|---|---|
| `BANK_PFX` | ~line 620 | Bank adds new POS network code |
| `REF_RE` | ~line 618 | New reference format introduced |
| `ATMTOT_FULL_LEN = 33` | `renderInfoPanel()` | ATMTOT ref length changes |
| Tolerance `0.02` | `reconcile()` x3 | Rounding tolerance needs adjustment |
| `lastIsFirstOfMonth` | `parseBank()` end | Boundary day logic changes |

---

## 13. HISTORY OF ALL FIXES

| Date | Bug | Root Cause | Fix |
|---|---|---|---|
| May 2026 | April 30 POS not matching | Date-based matching, +1 day shift | Switched to ref-based matching |
| May 2026 | Fee/VAT NaN totals | JS `NaN !== 0` is `true` | Added `isNaN()` guard in `parseNum()` |
| May 2026 | First bank row dropped | `.slice(1)` removed first data row | Removed `.slice(1)` |
| May 2026 | `نقاط البيه` not recognized | Typo in data entry | Added typo variant |
| May 2026 | Bare-ref rows not classified | No Arabic label in description | Added bare-ref pattern → VAT |
| May 2026 | `LD...` refs not extracted | Missing from REF_RE pattern | Added `LD[A-Z0-9]{5,}` |
| Jun 2026 | 390 discrepancies new month | Bank changed to combined credit/debit column | Added `detectBankColumns()` auto-detection |
| Jun 2026 | Fee codes not detected | Machine number now before code in desc | `bankTxType()` searches anywhere in desc |
| Jun 2026 | FT transfers mismatching | Internal records expenses as Credit | Removed direction check; match by absolute amount |
| Jun 2026 | SWIFT refs not matching | Bank ref col = long SWIFT code | Extract FT ref from description text |
| Jun 2026 | `فواتير تحويل` wrong category | Was treated as POS | Changed to OTHER, matched by FT ref |
| Jun 2026 | May 31 POS missing | Bank file needed June 1 | Upload bank May 1→June 1, internal Apr 30→June 1 |
| Jun 2026 | June 1 non-POS incorrectly included | Filter kept all June 1 rows | Auto-detect boundary day → POS + related Fee/VAT only |
| Jun 2026 | June 1 Fee/VAT ref prefix mismatch | Fee ref differs by last digit from POS ref | Use first 25 chars as prefix for matching |
| Jun 2026 | June 1 deposit showing as discrepancy | Filter kept incoming credit transfers | Removed OTHER credit from June 1 keep list |
| Jun 2026 | `Bank:/Sys:` reversed in Arabic mode | RTL flipped English text | Added `dir="ltr"` + Unicode LTR marks |
| Jun 2026 | Truncated ATMTOT refs causing false mismatches | Accountant copy-paste cut off ref in narrow Excel cell | Added validation: flag refs shorter than 33 chars or with stray chars |
| Jun 2026 | Reset button didn't clear warning panel | `resetAll()` didn't clear info-panel | Added panel clear + icon reset to `resetAll()` |
| Jun 2026 | Filter UI confusing (single row) | Status + category filters looked the same | Redesigned as two labeled rows with icons + Clear button |

---

## 14. KNOWN EXPECTED DISCREPANCIES

1. **Missing entries in internal** — accountant hasn't recorded yet
2. **Fee/VAT amount differences** — entered wrong amount or missing a row
3. **1 SAR differences** — rounding in accountant's calculation
4. **Truncated ATMTOT refs** — tool warns explicitly, accountant must re-enter

---

## 15. HOW TO ADD A NEW TRANSACTION TYPE

Example: bank adds `AMEXMRC` (American Express)

1. Add to `BANK_PFX`: `AMEXMRC: 'POS_AMEX'`
2. Add to `internalTxType()`: `if(d.includes('فواتير أمريكان')) return 'POS_AMEX';`
3. Add to POS index in `reconcile()` section 1: include `'POS_AMEX'` in the array
4. Add to bank POS index builder: include `'POS_AMEX'` in the filter array
