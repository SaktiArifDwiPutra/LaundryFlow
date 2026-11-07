# LaundryFlow Design System (DESIGN.md)

**Product:** LaundryFlow — Point of Sale (POS) & Operational Laundry Management  
**Design Philosophy:** Modern POS + Operational-First + Anti-AI-Slop  
**Target Platform:** Android (Phones & Tablets) — Flutter Material 3 Expressive

---

## 1. Design Principles

1. **Operational-First (Cashier Speed):** Every high-frequency operation (Search, Create Order, Advance Status, Record Payment) must be achievable in minimum taps. Zero unnecessary modal interruptions.
2. **Anti-AI-Slop Restraint:**
   - No generic purple/indigo blurred blobs or decorative AI gradients.
   - No raw emojis as UI icons; use cohesive, single-weight Material / Cupertino iconography.
   - No vanity stats or fabricated percentages. Every displayed figure comes from real Odoo telemetry.
   - No oversized, low-density cards that force endless vertical scrolling.
   - Clear distinction between **Processing Status** (Received -> Washing -> Drying -> Ironing -> Ready -> Completed) and **Payment Status** (Unpaid -> Partial -> Paid).
3. **Adaptive Visual Hierarchy:** High contrast between interactive elements and surface containers. Financial numbers and order statuses are readable at a glance from an arm's length (cashier counter distance).
4. **Resilient Dark/Light Adaptivity:** Both themes must meet WCAG AA contrast standards (minimum 4.5:1 for body copy, 3:1 for large display text).

---

## 2. Color Palette & Semantic Tokens

### Core Brand
- **Primary Blue:** `#2563EB` (Tailwind Blue 600 / M3 Key Primary)
- **Primary Dark:** `#1D4ED8` (Tailwind Blue 700 / High-emphasis interactive state)
- **Primary Container Light:** `#DBEAFE` (Blue 100)
- **Primary Container Dark:** `#1E3A8A` (Blue 900)

### Semantic Tokens
- **Success (Lunas / Ready / Selesai):**
  - Base: `#16A34A`
  - Container (Light): `#DCFCE7` | Container (Dark): `#14532D`
  - Text: `#15803D` (Light) | `#86EFAC` (Dark)
- **Warning (Sebagian / Express / Urgent):**
  - Base: `#D97706`
  - Container (Light): `#FEF3C7` | Container (Dark): `#78350F`
  - Text: `#B45309` (Light) | `#FDE68A` (Dark)
- **Danger (Belum Lunas / Terlambat / Batal):**
  - Base: `#DC2626`
  - Container (Light): `#FEE2E2` | Container (Dark): `#7F1D1D`
  - Text: `#B91C1C` (Light) | `#FCA5A5` (Dark)
- **Neutral / Meta:**
  - Base: `#64748B` (Slate 500)
  - Container (Light): `#F1F5F9` | Container (Dark): `#334155`

### Light Theme Surfaces & Text
- **Background:** `#F8FAFC` (Slate 50)
- **Surface (Cards, Bottom Sheets):** `#FFFFFF`
- **Surface Elevated:** `#F1F5F9` (Slate 100)
- **Primary Text:** `#0F172A` (Slate 900)
- **Secondary Text:** `#64748B` (Slate 500)
- **Muted Text / Border:** `#CBD5E1` (Slate 300)
- **Hairline Border:** `#E2E8F0` (Slate 200)

### Dark Theme Surfaces & Text
- **Background:** `#0F172A` (Slate 900)
- **Surface (Cards, Bottom Sheets):** `#1E293B` (Slate 800)
- **Surface Elevated:** `#334155` (Slate 700)
- **Primary Text:** `#F8FAFC` (Slate 50)
- **Secondary Text:** `#94A3B8` (Slate 400)
- **Muted Text:** `#64748B` (Slate 500)
- **Hairline Border:** `#334155` (Slate 700)

---

## 3. Typography Hierarchy

Font family: **Inter** (with fallback to system clean sans-serif `Roboto` / `system-ui`).

| Style Role | Size | Weight | Line Height | Usage |
|---|---|---|---|---|
| **Display Currency** | 24px–26px | 700 (Bold) | 32px | Tagihan Kasir, Total Transaksi, Kembalian |
| **Page Title** | 22px–24px | 700 (Bold) | 28px | App Bar Title, Screen Headings |
| **Section Title** | 16px–18px | 600 (SemiBold) | 24px | Sub-headings, Card Section Headers |
| **Card / Item Title**| 15px–16px | 600 (SemiBold) | 22px | Nama Pelanggan, No. Pesanan, Nama Layanan |
| **Body (Default)** | 14px | 400 (Regular) | 20px | Deskripsi, List Subtitles, Form Values |
| **Button Label** | 14px | 600 (SemiBold) | 20px | CTA Actions, Dialog Confirmations |
| **Supporting / Meta**| 12px | 500 (Medium) | 16px | Timestamps, UoM (kg/pcs), Status Badges |
| **Micro Caption** | 11px | 600 (SemiBold) | 14px | Status Chips, Pill Badges, Mini Indicators |

---

## 4. Spacing Scale & Geometry

4px Strict Spacing Multiples:
- `4px` (`space-xxs`): Badge insets, icon-to-label gaps
- `8px` (`space-xs`): Item inner padding, compact chips, list tile vertical rhythm
- `12px` (`space-sm`): Card padding (compact), input field content padding
- `16px` (`space-md`): Screen horizontal margin, standard card padding, dialog body padding
- `20px` (`space-lg`): Section separation in scrollable detail views
- `24px` (`space-xl`): Distinct group blocks, bottom sheet top padding
- `32px` (`space-xxl`): Screen bottom inset buffer, header-to-content gap

Corner Radii:
- **Inputs:** `10px`
- **Buttons:** `12px`
- **Cards & Dialogs:** `14px`–`16px`
- **Pill Badges:** `9999px` (Full circular)

Touch Targets & Heights:
- **Primary CTA Buttons:** `48px`–`52px` height
- **Icon Buttons & Targets:** minimum `44px × 44px`
- **List Tiles:** minimum `64px` height for rapid touch accuracy

---

## 5. Navigation Architecture

Modern 5-Anchor Navigation Bar with Elevated Central Action:

```
┌──────────────────────────────────────────────────────────┐
│  [Antrian]    [Pesanan]    ( + )    [Pelanggan]   [Setelan] │
│   Queue        Orders    New Order   Customers    Settings  │
└──────────────────────────────────────────────────────────┘
```

1. **Antrian (Queue / Dashboard):** Operational dashboard displaying active work-in-progress, overdue alerts, ready-for-collection orders, and quick stage filters.
2. **Pesanan (Orders):** Comprehensive order book with multi-criteria search, date filters, payment status badges, and processing stages.
3. **(+) Buat Pesanan (Create Order):** Prominent central primary action that launches the rapid POS order flow with zero navigation friction.
4. **Pelanggan (Customers):** Customer directory, fast phone/name lookup, direct order history, and contact addition.
5. **Setelan (Settings):** Staff profile card, Theme Switcher (System / Light / Dark), server connection status, and secure sign-out.

---

## 6. Component Specs

### 6.1 Order & Status Badges
- **Payment Status Badge:**
  - `Lunas (Paid)`: Green container `#DCFCE7`, text `#15803D`, icon `check_circle`
  - `Sebagian (Partial)`: Amber container `#FEF3C7`, text `#B45309`, icon `pie_chart`
  - `Belum Lunas (Unpaid)`: Red container `#FEE2E2`, text `#B91C1C`, icon `schedule`
- **Workflow Stage Chip:**
  - Dynamic stages from backend: `Diterima`, `Dicuci`, `Dikeringkan`, `Disetrika`, `Siap Diambil`, `Selesai`.
  - Icon-anchored, compact, subtle colored background matching current step.

### 6.2 Cashier Payment Section
- Prominent total bill display.
- One-tap quick amount buttons (`Uang Pas`, `+Rp 10.000`, `+Rp 50.000`, `+Rp 100.000`).
- Real-time instant change calculation.
- Tab-based payment method picker: `Tunai`, `QRIS`, `Transfer`.

### 6.3 Adaptive Layout Support
- On mobile viewports (< 600dp): Linear single-column flow with persistent bottom action dock and `SafeArea` bottom insets.
- On tablet / wider viewports (>= 600dp): Split-view master-detail pattern where appropriate or centered constrained canvas (`maxWidth: 640dp`).

