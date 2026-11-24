---
name: "Thuê Đồ Sinh Viên — Material 3 Design System"
description: "Light-first Flutter Material 3 design system for peer-to-peer student item rentals at Saigon University, built on an 8dp grid with deep midnight indigo (#0A0435) and warm terracotta accents."
---

## Overview

Thuê Đồ Sinh Viên is a campus-first peer-to-peer rental platform for Saigon University students across Cơ sở 1, Cơ sở 2, and Cơ sở Chính. The interface is trustworthy, transparent, and practical—designed to make daily rates, refundable deposits, platform fees, and in-person handoffs effortless to verify on both Android and desktop web.

The visual direction pairs **Flutter Material 3** tonal surfaces with **Corporate / Modern** clarity: crisp light-mode grounds (`#FCF8FD`), real 4:3 item photography, clear status chips combining icons and Vietnamese labels, and a single primary action per step.

## Colors

The palette anchors on a deep midnight indigo (`#0A0435`) for primary actions, trust badges, and active navigation, paired with a warm terracotta (`#693A2C`) tertiary accent for deposit and handoff highlights. Neutral surfaces step cleanly from `#FFFFFF` cards over `#FCF8FD` canvas grounds so financial breakdowns remain scannable.

- **Primary:** Deep midnight indigo (`#0A0435`) for primary CTAs, active tabs, and verified student badges.
- **Secondary:** Muted slate-indigo (`#5E5C71`) for filter chips, secondary actions, and metadata containers (`#E4DFF9`).
- **Tertiary:** Warm terracotta (`#693A2C`) for deposit callouts and scheduled handoff reminders.
- **Status:** Semantic success, warning, and error tokens are reserved strictly for booking states, overdue alerts, and validation feedback, always paired with an icon and text label.

```yaml
colors:
  success: "#146C2E"
  on-success: "#FFFFFF"
  success-container: "#D3F3D9"
  on-success-container: "#073815"
  warning: "#8C4A00"
  on-warning: "#FFFFFF"
  warning-container: "#FFDCBE"
  on-warning-container: "#4A2300"
  light:
    primary: "#0A0435"
    on-primary: "#FFFFFF"
    primary-container: "#191443"
    on-primary-container: "#E4DFFF"
    secondary: "#5E5C71"
    on-secondary: "#FFFFFF"
    secondary-container: "#E4DFF9"
    on-secondary-container: "#302E42"
    tertiary: "#693A2C"
    on-tertiary: "#FFFFFF"
    tertiary-container: "#845141"
    on-tertiary-container: "#FFDBD0"
    error: "#BA1A1A"
    on-error: "#FFFFFF"
    error-container: "#FFDAD6"
    on-error-container: "#93000A"
    background: "#FCF8FD"
    on-background: "#1C1B1F"
    surface: "#FCF8FD"
    surface-dim: "#DDD9DD"
    surface-bright: "#FCF8FD"
    surface-container-lowest: "#FFFFFF"
    surface-container-low: "#F7F2F7"
    surface-container: "#F1ECF1"
    surface-container-high: "#EBE7EC"
    surface-container-highest: "#E5E1E6"
    on-surface: "#1C1B1F"
    surface-variant: "#E5E1EC"
    on-surface-variant: "#47464F"
    outline: "#787680"
    outline-variant: "#C8C5D0"
    inverse-surface: "#313034"
    inverse-on-surface: "#F4EFF4"
    inverse-primary: "#C6C0F9"
  dark:
    primary: "#C6C0F9"
    on-primary: "#2E2A59"
    primary-container: "#0A0435"
    on-primary-container: "#E4DFFF"
    secondary: "#C8C3DD"
    on-secondary: "#302E42"
    secondary-container: "#474459"
    on-secondary-container: "#E4DFF9"
    tertiary: "#F9B7A3"
    on-tertiary: "#4E2517"
    tertiary-container: "#693A2C"
    on-tertiary-container: "#FFDBD0"
    error: "#FFB4AB"
    on-error: "#690005"
    error-container: "#93000A"
    on-error-container: "#FFDAD6"
    background: "#141316"
    on-background: "#E5E1E6"
    surface: "#141316"
    surface-dim: "#141316"
    surface-bright: "#3A393C"
    surface-container-lowest: "#0E0E11"
    surface-container-low: "#1C1B1F"
    surface-container: "#201F23"
    surface-container-high: "#2A292D"
    surface-container-highest: "#353438"
    on-surface: "#E5E1E6"
    surface-variant: "#47464F"
    on-surface-variant: "#C8C5D0"
    outline: "#928F99"
    outline-variant: "#47464F"
    inverse-surface: "#E5E1E6"
    inverse-on-surface: "#313034"
    inverse-primary: "#5D598B"
```

## Typography

Typography uses **Plus Jakarta Sans** across headlines and body copy for crisp, native Vietnamese diacritic legibility at every scale, paired with **Source Code Pro** for receipt codes, OTPs, and tabular financial figures. All currency and date figures use `tabular-nums` so quotes and reconciliation rows align vertically.

```yaml
typography:
  display-lg:
    fontFamily: "Plus Jakarta Sans"
    fontSize: 36px
    fontWeight: 700
    lineHeight: 44px
    letterSpacing: -0.5px
  display-lg-mobile:
    fontFamily: "Plus Jakarta Sans"
    fontSize: 28px
    fontWeight: 700
    lineHeight: 36px
    letterSpacing: -0.25px
  headline-lg:
    fontFamily: "Plus Jakarta Sans"
    fontSize: 26px
    fontWeight: 700
    lineHeight: 32px
    letterSpacing: -0.25px
  headline-md:
    fontFamily: "Plus Jakarta Sans"
    fontSize: 22px
    fontWeight: 700
    lineHeight: 28px
    letterSpacing: 0px
  title-lg:
    fontFamily: "Plus Jakarta Sans"
    fontSize: 18px
    fontWeight: 600
    lineHeight: 24px
    letterSpacing: 0px
  title-md:
    fontFamily: "Plus Jakarta Sans"
    fontSize: 16px
    fontWeight: 600
    lineHeight: 22px
    letterSpacing: 0px
  body-lg:
    fontFamily: "Plus Jakarta Sans"
    fontSize: 16px
    fontWeight: 400
    lineHeight: 24px
    letterSpacing: 0px
  body-md:
    fontFamily: "Plus Jakarta Sans"
    fontSize: 14px
    fontWeight: 400
    lineHeight: 20px
    letterSpacing: 0.1px
  label-lg:
    fontFamily: "Plus Jakarta Sans"
    fontSize: 14px
    fontWeight: 600
    lineHeight: 20px
    letterSpacing: 0.1px
  label-md:
    fontFamily: "Plus Jakarta Sans"
    fontSize: 12px
    fontWeight: 600
    lineHeight: 16px
    letterSpacing: 0.25px
  label-sm:
    fontFamily: "Plus Jakarta Sans"
    fontSize: 11px
    fontWeight: 500
    lineHeight: 14px
    letterSpacing: 0.25px
  mono-sm:
    fontFamily: "Source Code Pro"
    fontSize: 12px
    fontWeight: 500
    lineHeight: 16px
    letterSpacing: 0px
```

## Layout & Spacing

The layout follows a **Fluid Grid** on mobile (`390px`, 16px page margins, 2-column item cards or 1-column detail stack) and a **Fixed-Max-Width Grid** (`1200px` max container with a persistent `240px` left navigation rail) on desktop web. Every spacing value sits on a strict **8dp** grid with a **4dp** half-step for tight icon-label pairs. Interactive touch targets on mobile are at least `48px` tall.

```yaml
spacing:
  gutter-xs: 4px
  gutter-sm: 8px
  gutter-md: 16px
  gutter-lg: 24px
  gutter-xl: 32px
  section: 48px
  page-margin: 16px
```

## Elevation & Depth

Hierarchy relies on **Tonal layers** (`surface` → `surface-container-lowest` for item cards and quote sheets, `surface-container-low` for secondary panels) paired with subtle `1px` `outline-variant` hairline borders on interactive inputs and summary tables. Sticky headers and bottom action bars use crisp solid surface fills with a subtle `1px` top or bottom `outline-variant` divider—no backdrop blur or heavy drop shadows.

## Shapes

Shapes follow Material 3's approachable rounded geometry. Cards use `16px` (`lg`), inner 4:3 item thumbnails inside padded cards step down to `12px` (`md`), input fields and quote boxes use `12px` (`md`), and primary pill buttons and filter chips use `9999px` (`full`) or `12px` (`md`) for rectangular action bars.

```yaml
rounded:
  sm: 4px
  DEFAULT: 8px
  md: 12px
  lg: 16px
  xl: 24px
  full: 9999px
```

## Motion & Micro-interaction

Motion is crisp and functional. Taps on chips, buttons, and cards respond within `100ms` via opacity and color transitions. Bottom sheets, date-range dialogs, and step transitions enter over `250ms` with Material emphasized deceleration and exit in `150ms`. Loading states use clean tonal skeletons; nothing loops decoratively.

```yaml
motion:
  state-change:
    duration: 100ms
    delay: 0ms
    timingFunction: ease-out
  surface-enter:
    duration: 250ms
    delay: 0ms
    timingFunction: cubic-bezier(0.2, 0, 0, 1)
  surface-exit:
    duration: 150ms
    delay: 0ms
    timingFunction: cubic-bezier(0.3, 0, 1, 1)
```

## Voice & Content Strategy

- **Tone of voice:** Clear, helpful, and student-friendly in natural Vietnamese—direct about money, dates, and campus meeting points without bureaucratic jargon.
- **Capitalisation:** Sentence case across headings, buttons, chips, and navigation labels (`Khám phá`, `Đăng đồ`, `Giao dịch`, `Cá nhân`).
- **Terminology:** Consistently use `món đồ`, `chủ đồ`, `người thuê`, `tiền cọc`, `phí dự kiến`, `Cơ sở 1`, `Cơ sở 2`, `Cơ sở Chính`.
- **Button and action labels:** Action-verb phrases naming the exact outcome (`Gửi yêu cầu thuê`, `Xác nhận đã trả máy`, `Đổi ngày thuê`, `Xóa bộ lọc`), never generic `OK` or `Gửi`.
- **Empty & error states:** Distinguish `Chưa có yêu cầu thuê` from `Không có món trống theo bộ lọc này`, always pairing an empty state with a concrete recovery action.
- **Numbers & currency:** Integer VND formatted with dot separators and `đ` suffix (`50.000đ/ngày`, `300.000đ cọc`, `401.000đ`), Vietnamese calendar dates (`T6, 27/11 – T7, 28/11 (2 ngày)`).

## Components

Component implementations live as individual HTML sticker sheet files in
`components/`. Each file contains the canonical, styled HTML components with
`<!-- COMPONENT: name -->` comment markers. Read each file before use.

- **Badge** → `@components/badge.html`: `badge-numeric`, `badge-dot`
- **Button** → `@components/button.html`: `button-primary`, `button-icon`, `button-with-icon`
- **Card** → `@components/card.html`: `card-elevated`, `card-action`, `card-interactive`, `card-interactive-2`
- **Chip** → `@components/chip.html`: `chip-action`, `chip-input`, `chip-with-icon`
- **Searchbar** → `@components/searchbar.html`: `searchbar-standard`, `searchbar-with-suggestions`
