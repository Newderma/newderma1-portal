# Clinic Bank Reconciliation — Full Documentation
**File:** `finance.html`  
**Clinic:** Newderma1 — مركز البشرة الجديدة الاولى  
**Last updated:** June 2026  

---

## 1. WHAT THIS MODULE DOES

This is a standalone HTML file that reconciles the clinic's **bank statement** against the **internal accounting system** for any given month. It detects:

- ✅ Matched transactions
- ❌ Transactions in the bank but missing from the internal system
- ❌ Transactions in the internal system but not found in the bank
- ⚠️ Transactions found on both sides but with different amounts

It runs entirely in the browser — no server needed. Files are read locally via JavaScript.

---

## 2. FILES REQUIRED TO RUN

### Bank Statement (Excel .xlsx)
| Rule | Detail |
|---|---|
| Period | May 1 → June 1 (include June 1 for POS boundary) |
| Source | Alinma Bank export |
| Language | Arabic + English headers |

### Internal System (Excel .xlsx)
| Rule | Detail |
|---|---|
| Period | April 30 → June 1 |
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
| Col 3-5 | Empty | — |
| Col 6 | Reference Number | الرقم المرجعي |
| Col 7 | Empty | — |
| Col 8 | Transaction Date | تاريخ العملية |

**Key header:** `دائن/مدين\nCredit/Debit` — tool detects this to switch to new format.

**Value date (when POS was charged):** Embedded as `YYYYMMDD` prefix in description.  
Example: `20260501 SPANMRC - Total POS Purchase...` → value date = 2026-05-01

**SWIFT/RTGS transfers:** When the Reference column contains a long date-based code like `20260430SARJHIRJHI2BOPF...`, the real FT reference is extracted from the description text.  
Example: desc contains `رقم المرجع FT26121TR2V7` → tool uses `FT26121TR2V7` as the match key.

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
| Col 0 | Debit (مدين) | Outgoing from clinic perspective |
| Col 1 | Credit (دائن) | Incoming or expense in cost-center accounting |
| Col 2 | Debit Balance | رصيد مدين |
| Col 3 | Credit Balance | رصيد دائن |
| Col 4 | Description | كشف حساب — contains Arabic label + reference number |
| Col 5 | Date | التاريخ |
| Col 6 | Entry Number | رقم القيد |
| Col 7 | Cost Center | مركز التكلفة |

**Important:** Outgoing payments (expenses, salaries, iqama renewals etc.) are recorded as **Credit** in the internal system (cost-center accounting). The tool matches by absolute amount — direction is ignored.

**Reference numbers must appear in the description after a dash:**
```
فواتير مدى من تاريخ 30/04/2026 الي تاريخ 30/04/2026 - ATMTOT202605012212800000000099268
عمولة نقاط البيع ليوم 11 مايو - ATMTOT202605113217900000000048240
تجديد رخص الممرضه - FT26123W12BF
خصم قسط القرض - LD2234826185
```

---

## 5. TRANSACTION TYPES & CLASSIFICATION

### Bank Transaction Types (`bankTxType()` function)

| Bank Code | Detected By | Type Assigned |
|---|---|---|
| `SPANMRC` | Anywhere in description | `POS_MADA` |
| `SFEEMRC` | Anywhere in description | `FEE_MADA` |
| `VISAMRC` | Anywhere in description | `POS_VISA` |
| `VFEEMRC` | Anywhere in description | `FEE_VISA` |
| `BNETMRC` | Anywhere in description | `POS_MASTER` |
| `BFEEMRC` | Anywhere in description | `FEE_MASTER` |
| `ATMTOT...` + `ضريبة/ضريبه` | Starts with ATMTOT + Arabic VAT word | `VAT` |
| Everything else | — | `OTHER` |

**Note:** Codes appear anywhere in description (new format puts machine number first).

### Internal Transaction Types (`internalTxType()` function)

| Arabic Keyword | Type Assigned | Notes |
|---|---|---|
| `فواتير مدى` | `POS_MADA` | Mada POS sales |
| `فواتير فيزا` | `POS_VISA` | Visa POS sales |
| `فواتير ماستر` | `POS_MASTER` | Master POS sales |
| `فواتير تحويل` | `OTHER` | Daily income via bank transfer (matched by FT ref) |
| `عمولة` + `نقاط البيع/البيه` | `FEE` | Bank fee for POS usage |
| `ضريبة/ضريبه` + `نقاط البيع/البيه` | `VAT` | VAT on POS fees |
| `^قيد يومية رقمNNN ATMTOT` | `VAT` | Bare-ref rows with no Arabic label |
| Everything else | `OTHER` | Transfers, expenses, salaries, refunds |

**Typo variants accepted:**
- `نقاط البيه` accepted same as `نقاط البيع`
- Both `ضريبة` and `ضريبه` accepted

---

## 6. REFERENCE NUMBER FORMATS (`REF_RE` constant)

```javascript
const REF_RE = /\b(ATMTOT[A-Z0-9]+|FT[A-Z0-9]{8,}|LD[A-Z0-9]{5,}|[A-Z]{2,}[0-9]{6,}[A-Z0-9]*)\b/g;
```

| Pattern | Type | Example |
|---|---|---|
| `ATMTOT[A-Z0-9]+` | POS fee/VAT reference | `ATMTOT202605012200700000000071433` |
| `FT[A-Z0-9]{8,}` | Bank transfer | `FT26123W12BF` |
| `LD[A-Z0-9]{5,}` | Loan/financing payment | `LD2234826185` |
| `[A-Z]{2,}[0-9]{6,}` | Future-proof catch-all | Any new format the bank introduces |

---

## 7. RECONCILIATION ENGINE (`reconcile()` function)

### Section 1 — POS Sales Matching
**Logic:** Match by reference number (NOT by date).  
**Why:** Bank processes POS next day — date shift makes date matching unreliable.

```
Internal entry: فواتير مدى - ATMTOT202605012200700000000071433 - ATMTOT202605012212800000000099268
  ↓ extract refs
  ↓ look up each ref in bank POS index
  ↓ sum bank amounts for found refs
  ↓ compare total to internal amount
```

**Internal entries are summed per day per network:**
- All Mada for one day = one internal entry with multiple refs
- All Visa for one day = one internal entry
- All Master for one day = one internal entry

**Status rules:**
- No refs found in bank → `Missing in Bank`
- Some refs found, some not → `Amount Mismatch`
- All found, amounts match within 0.02 SAR → `Match`
- All found, amounts differ → `Amount Mismatch`

### Section 2 — Fee/VAT Matching
**Logic:** Group by reference number, sum all fee+VAT rows for same ref, compare totals.

```
Bank: VFEEMRC row (4.37) + VAT row (0.66) → both have ref ATMTOT...103666 → total 5.03
Internal: عمولة row (4.37) + ضريبة row (0.66) → both have ref ATMTOT...103666 → total 5.03
→ Match ✅
```

**Key:** Fee and VAT always share the same reference number. Summed together on both sides.

### Section 3 — Other Transactions Matching
**Logic:** Match by reference number, absolute amounts (ignore credit/debit direction).

**Covers:**
- `فواتير تحويل` (daily income via bank transfer) — FT refs
- Outgoing payments (salaries, iqama, licenses) — FT refs
- Loan payments — LD refs
- Any other bank transfer

**SWIFT/RTGS handling:** When bank ref column contains long SWIFT code, the real FT ref is extracted from the description text.

---

## 8. BOUNDARY DAY HANDLING

### April 30 (First day of internal, not in bank)
- Internal has POS entries dated April 30 with refs `ATMTOT20260501...`
- Bank has those same refs dated May 1
- **Handled automatically** by ref-based matching (date is irrelevant)

### June 1 (Last day of bank, extra boundary day)
- Bank file includes June 1 for POS boundary matching
- Auto-detected: if last day of bank file is the 1st of a month → it's a boundary day
- **Filter applied:** Only POS rows (Mada/Visa/Master) and incoming credit transfers kept from that day
- Fee/VAT and outgoing transfers on June 1 are excluded (they belong to June reconciliation)

**Detection logic:**
```javascript
const lastIsFirstOfMonth = lastDate.slice(8) === '01';
```

---

## 9. POS MACHINES

Auto-detected from bank file by scanning for 16-digit numbers in descriptions.  
Named `POS1`, `POS2`, etc. in order of first appearance.

**Known machines (May 2026):**
- POS1: `5552513677806212`
- POS2: `5552513577806212`

No hardcoding — new machines added by the bank are detected automatically.

---

## 10. FILE STRUCTURE (HTML)

```
finance.html
├── HTML structure
│   ├── Header (title, language toggle, summary badges)
│   ├── Upload cards (bank + internal) with visible rules
│   ├── Run button
│   ├── Info panel (machines detected, warnings)
│   ├── Alert box (discrepancy summary)
│   ├── Filter buttons (status + category)
│   └── Results table (expandable rows)
│
├── CSS (lines ~130-380)
│   ├── CSS variables (colors, spacing)
│   ├── Layout styles
│   ├── Upload card styles
│   ├── Table styles
│   ├── Badge/tag styles
│   └── Info modal styles
│
└── JavaScript (lines ~380-940)
    ├── TRANSLATIONS (T object) — all UI text EN + AR
    ├── setLang() — switches language + RTL/LTR
    ├── renderStatic() — renders all static text via t()
    ├── CORE HELPERS
    │   ├── parseNum() — safe number parsing (NaN guard)
    │   ├── fmtDate() — handles dd/mm/yyyy, yyyy-mm-dd, Excel serials
    │   ├── isValidDate() — validates parsed dates
    │   ├── round2() — rounds to 2 decimal places
    │   └── SAR() — formats as Saudi Riyal
    ├── COLUMN DETECTION
    │   ├── detectBankColumns() — auto-detects old vs new bank format
    │   └── detectInternalColumns() — finds column positions by header keyword
    ├── CLASSIFICATION
    │   ├── REF_RE — reference number regex pattern
    │   ├── extractRefs() — extracts all refs from a description string
    │   ├── BANK_PFX — maps bank codes to transaction types
    │   ├── bankTxType() — classifies bank rows
    │   ├── internalTxType() — classifies internal rows
    │   └── detectMachines() — finds POS machine numbers
    ├── PARSERS
    │   ├── parseBank() — reads + classifies bank rows, applies boundary filter
    │   └── parseInternal() — reads + classifies internal rows
    ├── reconcile() — main matching engine (3 sections)
    ├── UI RENDERING
    │   ├── renderInfoPanel() — shows machines + warnings
    │   ├── renderBadges() — header summary counts
    │   ├── renderAlert() — discrepancy list
    │   ├── renderFilters() — filter buttons + table headers
    │   └── renderTable() — results table rows
    ├── loadFile() — reads Excel file via XLSX.js (lazy loaded)
    └── runReconciliation() — orchestrates full run
```

---

## 11. KEY CONSTANTS TO MODIFY

| Constant | Location | When to change |
|---|---|---|
| `BANK_PFX` | line ~620 | Bank adds new POS network codes |
| `REF_RE` | line ~618 | Bank introduces new reference format |
| Tolerance `0.02` | `reconcile()` — 3 places | If rounding tolerance needs adjustment |
| `lastIsFirstOfMonth` | `parseBank()` end | If boundary day logic needs to change |

---

## 12. HISTORY OF ALL FIXES

| Date | Bug | Root Cause | Fix Applied |
|---|---|---|---|
| May 2026 | April 30 POS not matching | Date-based matching couldn't handle +1 day shift | Switched to ref-based matching entirely |
| May 2026 | Fee/VAT NaN causing wrong totals | JS `NaN !== 0` is `true` — empty credit cell returned NaN, wrong amount used | Added `isNaN()` guard in `parseNum()` |
| May 2026 | First bank row always dropped | `.slice(1)` removed first data row — XLSX already skips header row | Removed `.slice(1)` from `bankData` |
| May 2026 | `نقاط البيه` not recognized | Typo in accountant's data entry | Added typo variant to `internalTxType()` |
| May 2026 | Bare-ref rows not classified | Rows like `قيد يومية رقم955 ATMTOT...` had no Arabic type label | Added bare-ref pattern → `VAT` |
| May 2026 | `LD...` refs not extracted | Only `ATMTOT` and `FT` were in the pattern | Added `LD[A-Z0-9]{5,}` to `REF_RE` |
| May 2026 | `FT261341VT13` Fee/VAT ref not matched | Fee row had `البيه` typo variant | Typo fix covered this |
| Jun 2026 | 390 discrepancies on new month | Bank changed export format completely — new single combined amount column | Added `detectBankColumns()` auto-detection |
| Jun 2026 | Fee codes not detected | New format puts machine number BEFORE the code — `5552...SFEEMRC` | Changed `bankTxType()` to search anywhere in desc with `\b...\b` |
| Jun 2026 | FT transfers showing as mismatches | Internal records outgoing payments as Credit; tool was comparing direction | Removed `TRANSFER_IN/OUT` types; all go to `OTHER`, match by absolute amount |
| Jun 2026 | SWIFT transfers not matching | Bank ref column has long SWIFT code; internal uses short FT ref | Extract FT ref from description when ref col starts with `YYYYMMDDX...` |
| Jun 2026 | `فواتير تحويل` wrong category | Was classified as POS; it's daily income via direct bank transfer | Changed to `OTHER`, matched by FT ref against bank credit transfers |
| Jun 2026 | May 31 POS missing (boundary) | Bank file needed to include June 1 for POS date shift | Agreed to upload bank May 1 → June 1, internal April 30 → June 1 |
| Jun 2026 | June 1 fees incorrectly included | June 1 Fee/VAT rows from bank were being matched against May entries | Auto-detect if last day is 1st of month → filter to POS only |

---

## 13. KNOWN EXPECTED DISCREPANCIES (NOT BUGS)

These will appear in results but are correct behavior:

1. **Missing refs in internal** — Accountant hasn't entered the transaction yet. Check with accountant.

2. **Fee/VAT small differences** — Accountant entered fee without VAT row, or vice versa, for same reference. Real accounting discrepancy.

3. **`FT26120WC7ZS`** — Recorded in internal (part of combined تحويل entry) but not found in bank. Verify with bank if transfer was actually received.

---

## 14. BILINGUAL SUPPORT

The tool is fully bilingual Arabic/English. Toggle with EN/ع button in header.

- Arabic mode enables RTL layout automatically (`dir=rtl`)
- All column headers, status labels, filter buttons, expanded row labels switch
- Arabic font: IBM Plex Sans Arabic (loaded from Google Fonts)
- All text goes through `t(key)` function which reads from `T.en` or `T.ar` objects
- **To add a new UI string:** Add it to both `T.en` and `T.ar` objects, then use `t('keyName')` in the code

---

## 15. HOW TO ADD A NEW TRANSACTION TYPE

Example: bank adds a new payment network `AMEXMRC`

**Step 1:** Add to `BANK_PFX` constant:
```javascript
const BANK_PFX = { ..., AMEXMRC: 'POS_AMEX' };
```

**Step 2:** Add to `bankTxType()` search pattern (already handled automatically if it ends in `MRC`).

**Step 3:** Add to POS matcher in `reconcile()` section 1:
```javascript
if(!['POS_MADA','POS_VISA','POS_MASTER','POS_AMEX'].includes(ir.txType))continue;
```

**Step 4:** Add Arabic keyword to `internalTxType()`:
```javascript
if(d.includes('فواتير أمريكان إكسبريس')) return 'POS_AMEX';
```

**Step 5:** Add to bank POS index builder:
```javascript
if(['POS_MADA','POS_VISA','POS_MASTER','POS_AMEX'].includes(r.txType)) bpRef[r.ref]=r;
```
