<div align="center">

<img src="assets/banner.png" alt="Streak, a minimal, private, ad-free habit tracker" width="100%" />

</div>

---

<div align="right">
  <sub><b>English</b> · <a href="docs/README.es.md">Español</a> · <a href="docs/README.zh-CN.md">中文</a> · <a href="docs/README.ru.md">Русский</a> · <a href="docs/README.ja.md">日本語</a></sub>
</div>

<div align="center">

### Streak: Focus Desktop Edition

<img src="assets/icon.svg" width="72" alt="Streak logo" />

### An executive, private habit tracker & focus workspace

Log habits with one tap, track deep work sessions, and master your daily focus momentum.

<br/>

<p>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white" />
  <img alt="Dart" src="https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white" />
  <img alt="Windows Desktop" src="https://img.shields.io/badge/Windows-0078D6?style=flat&logo=windows&logoColor=white" />
  <img alt="License GPLv3" src="https://img.shields.io/badge/License-GPLv3-7C3AED?style=flat&logo=gnu&logoColor=white" />
  <img alt="100% Offline & Private" src="https://img.shields.io/badge/100%25%20Offline%20%C2%B7%20No%20tracking-22C55E?style=flat&logo=shield&logoColor=white" />
</p>

<br/>

<a href="https://github.com/0xNDM/streak/releases"><img alt="Download Windows Installer" src="https://img.shields.io/badge/Download-Windows%20x64%20Installer-0078D6?style=for-the-badge&logo=windows&logoColor=white" height="38" /></a>
&nbsp;
<a href="fork.md"><img alt="Fork Documentation" src="https://img.shields.io/badge/Documentation-Fork%20Divergence%20(fork.md)-7C3AED?style=for-the-badge&logo=markdown&logoColor=white" height="38" /></a>

<br/>
<br/>

> [!IMPORTANT]
> **Streak: Focus Desktop Edition** is a specialized fork of [InlitX/streak](https://github.com/InlitX/streak) maintained by [0xNDM](https://github.com/0xNDM/streak).
> It transforms Streak into an **executive, focus-first desktop productivity suite on Windows**—featuring an executive Focus Dashboard, interactive timelines, Last.fm-style bubble cloud analytics, multi-tag tracking, independent daily/weekly targets, and desktop modal ergonomics—while preserving 100% of upstream's habit tracking capabilities and database compatibility.
>
> 📖 **Read the full architectural divergence doc:** [fork.md](fork.md)

<br/>

<sub>
  <a href="#-focus-desktop-edition-whats-new">What's New</a> ·
  <a href="#features">Features</a> ·
  <a href="#download">Download</a> ·
  <a href="#privacy">Privacy</a> ·
  <a href="fork.md">Fork Docs</a>
</sub>

</div>

---

<div align="center">

<img src="screenshots/01-today.png" alt="Today" width="145" />
<img src="screenshots/02-focus.png" alt="Focus" width="145" />
<img src="screenshots/03-stats.png" alt="Statistics" width="145" />
<img src="screenshots/04-insights.png" alt="Insights" width="145" />

<img src="screenshots/05-amount.png" alt="Amount habits" width="145" />
<img src="screenshots/06-notes.png" alt="Day notes" width="145" />
<img src="screenshots/07-customize.png" alt="Personalize" width="145" />
<img src="screenshots/08-private.png" alt="Free &amp; private" width="145" />

<sub><b>Today</b> · <b>Focus</b> · <b>Statistics</b> · <b>Insights</b> · <b>Amounts</b> · <b>Notes</b> · <b>Personalize</b> · <b>Free &amp; private</b></sub>

</div>

---

## Overview

Streak is an open source habit tracker for Android, Windows and Linux. Make as
many habits as you want, log them with one tap, and watch the grid, the streak
counters and the statistics fill up.

Everything stays on your device. No account, no ads, nothing to sync.

---

## ✨ Focus Desktop Edition: What's New

This fork reimagines the desktop experience on Windows with a modern, focus-first productivity suite:

- 🎯 **Executive Focus Command Center**: Windows launches directly into the Focus dashboard, featuring a lifetime metrics header strip (*Locked In* total hours, active days count, day streak) and frosted pill tabs (`Today` & `Analytics`).
- ⏱️ **Redesigned Today Dashboard**:
  - **Bold Hero Card**: Large 56px timer typography, daily goal progress bar, goal "HIT" badge, and real-time active session banner.
  - **Curated Session History**: Displays your 3 latest sessions with localized start-end times, custom color-coded tag pills, and instant rollback deletion.
  - **24-Hour Continuous Timeline**: Compact, centered weekly timeline across 7 daily tracks with interactive hover tooltips and week-by-week navigation.
- 📊 **Executive Analytics Suite**:
  - **Weekly Target Comparison**: Progress bar against weekly target, remaining hours, and week-over-week performance delta (`+X% vs last week`).
  - **Compact 2x2 KPI Grid**: Longest session, Best focus day (with date), This Month total hours, and Longest Streak.
  - **Interactive Range Chart**: Tap any bar in Week, Month (calendar weeks), or Year views to inspect all sessions in a dedicated modal.
  - **Day-of-Week & Time-of-Day Breakdowns**: Side-by-side analysis comparing All-Time vs. This-Month weekday averages, plus Morning/Afternoon/Evening/Night distribution.
  - **Auto-Fitting Annual Heatmap**: GitHub-style full-year activity heatmap with dynamic responsive cell sizing (no horizontal scrollbars).
- 🫧 **Interactive Proportional Bubble Cloud**:
  - Last.fm-style bubble chart showcasing your **Top 10 focus labels**.
  - Bubble radius scales proportionally with the square root of time spent ($\sqrt{\text{share}}$, true area scaling).
  - Responsive bubbles scale from 54px up to ~190px and stay inside the card on narrow layouts.
  - Smart text containment: never cuts single words across lines, scales down smoothly, and stacks two-word labels into two lines.
  - Interactive hover tooltips reveal exact duration and label name.
- 🏷️ **Multi-Tag Sessions & Label Management**:
  - Tag sessions with multiple labels (`tags`), backwards compatible with legacy single labels.
  - Rename labels retroactively across your entire historical database in Hive.
  - Hex code color picker for custom palette selection.
- 🎯 **Independent Daily & Weekly Targets**:
  - Set a custom daily target for today without modifying past or future days.
  - Adjust weekly targets independently per week.
- ⚡ **Auto-Complete & Desktop Dialog Ergonomics**:
  - Countdown timers automatically save, celebrate, and dismiss at 00:00 without manual stop prompts.
  - Guarded against double-crediting habit time across auto-completes and manual stops.
  - Replaced full-page mobile pushes with centered, keyboard-friendly desktop modal dialogs (`FocusSetupDialog`, `HabitFormDialog`, `HabitDetailsDialog`, etc.).
- 🔒 **100% Private, Offline & Upstream Compatible**:
  - Zero network requests, zero telemetry, zero accounts.
  - Fully compatible with upstream Streak backup archives (`.zip`) and mobile database schemas.

---

## Features

<table>
<tr>
<td width="50%" valign="top">

### Tracking

- One-tap logging from the home screen, a widget or the notification
- Three kinds of habit: **normal**, **avoid** (with relapses) and **amount**,
  with your unit and daily goal
- **Checklists** split a habit into steps, done when all are checked
- **Flexible schedules**: daily, X times a week or month, chosen weekdays, or
  every N days
- **Fill in the past**: tap any day to add or remove it
- **Day notes**: long-press a day to write what happened, or attach a photo
- **Vacation mode** pauses a habit without breaking anything

</td>
<td width="50%" valign="top">

### Seeing your progress

- GitHub-style **activity grid**, by week, month or the whole year
- **Month calendar**, with your week starting on Monday, Saturday or Sunday
- **Completions per month**, so you can see the shape of a whole year
- **Streak evolution** charted over time, watching the line climb
- **"When are you most consistent?"** finds the hours you actually show up
- Totals, best and current streak, completion rate and a per-habit
  **strength** score
- A **shareable progress card** in several sizes, exported as a polished image

</td>
</tr>
<tr>
<td width="50%" valign="top">

### Focus sessions

- A timer for the habits that need one, free or tied to a habit and its goal
- **Pomodoro rounds** with short breaks, or one long stretch
- Three clock styles: **Circle**, **Flip** and **Dots**
- Built-in sounds (rain, brown noise, fire) or your own tracks, in order
  or shuffled
- Calm scenes as a background, or a photo of your own
- Tick off subtasks without leaving the timer, and keep the screen awake
- A **daily focus goal**, plus a history of every session you finish

</td>
<td width="50%" valign="top">

### Making it yours

- **Classic, Minimal or Express**: three complete designs, each with its own
  typography, shapes and motion
- Minimalist icon pack, or any emoji you like
- Custom accent color with a full picker
- Light and dark themes, plus five app backgrounds: solid, gradient, dots,
  true-black OLED or a photo of your own
- Cover photos, categories, drag-to-reorder, profile name and photo
- Three launcher icons, so Streak matches the rest of your home screen
- A burst of confetti the day you finish everything

</td>
</tr>
<tr>
<td width="50%" valign="top">

### Reminders and widgets

- Reminders per habit, on the days you choose or every N days, each with a
  short encouraging line
- **Done**, **Snooze** and **Add amount** buttons right in the notification
- **Four home-screen widgets**: habit, today, stats and activity grid
- Each widget styled on its own, with color or photo, opacity and border
- Choose which figures the **stats widget** shows, and how they sit together
- Tick a day straight from a widget, it saves without opening the app
- Tap the activity grid to jump into that habit

</td>
<td width="50%" valign="top">

### Your data

- **Import** from Loop Habit Tracker, HabitKit, Habitica and HabitBull,
  history and streaks included, or any CSV with a habit and a date
- Backup and restore with a single file you keep yourself
- **Automatic backups**, daily or weekly, to a folder of your choosing
- **App lock** with a PIN or your fingerprint, for phones without one
- **Archive** habits without losing a day of their history
- Everything is offline: no account, no server, nothing to sync
- Seven languages, with more open on Weblate

</td>
</tr>
</table>

---

## Coming from another app?

<details>
<summary><b>How the import works</b></summary>

Bring your history with you. Streak reads exports from **Loop Habit Tracker**,
**HabitKit**, **Habitica** and **HabitBull**, so your past days and your streaks
survive the move. Any other CSV works too, as long as it has a habit and a date.

<div align="center"><sub><b>Settings → Data → Import from another app</b></sub></div>

</details>

---

## Download

[**F-Droid**](https://f-droid.org/packages/com.streak.app/) is the easiest way:
it installs Streak and keeps it updated for you. It's also on
[**IzzyOnDroid**](https://apt.izzysoft.de/fdroid/index/apk/com.streak.app?repo=main)
and [**OpenAPK**](https://www.openapk.net/streak/com.streak.app/).

Streak runs on Windows, Android and Linux:

| Platform | Edition / Status | Download |
|----------|------------------|----------|
| **Windows** | 🚀 **Focus Desktop Edition** | [**Windows x64 Installer**](https://github.com/0xNDM/streak/releases) |
| Android | ✅ Supported | [F-Droid](https://f-droid.org/packages/com.streak.app/) · [GitHub](https://github.com/InlitX/streak/releases) |
| Linux | ✅ Supported | [Releases](https://github.com/InlitX/streak/releases) |
| iOS | 🚧 In progress | — |
| macOS | 📅 Planned | — |

<details open>
<summary><b>Windows (Focus Desktop Edition)</b></summary>

Download the standalone installer directly from the [**0xNDM/streak Releases**](https://github.com/0xNDM/streak/releases) page:

| File | For |
|------|-----|
| `Streak-windows-x64-setup.exe` | Windows 10/11 64-bit installer with desktop shortcuts and auto-updates |

For detailed technical notes on all differences between this fork and upstream, see [**fork.md**](fork.md).

</details>

<details>
<summary><b>Linux</b></summary>

Two files on the [**Releases**](https://github.com/InlitX/streak/releases) page,
both for 64-bit x86:

| File | For |
|------|-----|
| `Streak-x86_64.AppImage` | Any distribution: make it executable and run it |
| `Streak-linux-x64.tar.gz` | Unpack anywhere and run `Streak` |

The Linux build has only just landed, so expect some rough edges. Reminders ring
while Streak is open. If something does not work, open an issue and I will fix
them as they come.

</details>

<details>
<summary><b>Install the APK yourself</b></summary>

Prefer the raw APK? It's on the
[**Releases**](https://github.com/InlitX/streak/releases) page, one file per
phone type so each download stays small:

| APK | For |
|-----|-----|
| `Streak-arm64-v8a.apk` | Modern 64-bit phones, **pick this one** |
| `Streak-armeabi-v7a.apk` | Older 32-bit devices |
| `Streak-x86_64.apk` | Emulators and x86 tablets |

Runs on **Android 9 (Pie) and newer**.

If you install the APK yourself, [**Obtainium**](https://github.com/ImranR98/Obtainium)
keeps it updated: add `https://github.com/InlitX/streak` and it will follow the
Releases page, tell you when a new version is out and pick the right APK for
your phone.

> [!NOTE]
>Streak isn't on the Play Store. Since the APK doesn't come from a store,
>Android may ask you to allow installs from your browser or file manager the
>first time.

</details>

---

## Privacy

> [!IMPORTANT]
>Streak **never connects to the internet**, and that is a core rule, not a
>setting. On Android it does not even ask for the internet permission. There
>are no analytics, no ads, no accounts and no servers: your data never leaves
>your device. If you want a copy somewhere else, such as a cloud drive, you
>export it and put it there yourself. Links you tap open in your browser.

---

## Translations

Translations are managed on [**Weblate**](https://hosted.weblate.org/engage/streak/):
no coding needed, just short phrases you translate in your browser. New
languages are welcome.

[![Translation status per language](https://hosted.weblate.org/widget/streak/app-strings/multi-auto.svg)](https://hosted.weblate.org/engage/streak/)

How it works → [**TRANSLATING.md**](TRANSLATING.md)

---

## Contributing

Bug reports, ideas and pull requests are all welcome, see
[**CONTRIBUTING.md**](CONTRIBUTING.md). For anything larger than a fix, open an
issue first so we can agree on the direction.

---

## Inspiration

<details>
<summary><b>The apps that shaped Streak</b></summary>

These are the apps Streak learned from:

- **[Loop Habit Tracker](https://github.com/iSoron/uhabits)**, for proving a
  habit tracker can be free, offline and still excellent.
- **[Grit](https://github.com/shub39/Grit)**, for the small motions that make a
  list feel alive.
- **[HabitKit](https://www.habitkit.app/)**, for how good a year of history
  looks as a coloured grid.
- **[Habitica](https://github.com/habitRPG/habitica)**, for treating showing up
  as something worth celebrating.

The island you build in the gamification tab is drawn with
**[Mykonos Island Voxels](https://github.com/boona13/mykonos-island-voxels)** by
boona13, an MIT licensed set of isometric voxel art. Thank you for putting it
out there for anyone to use.

The streak flame on the home screen widgets is the fire from
**[Fluent Emoji](https://github.com/microsoft/fluentui-emoji)** by Microsoft,
released under the MIT license.

</details>

---

## Support

<div align="center">

Streak is free, open source and free of ads, and it stays that way.

If you want to give something back, a star, a translation or a clear bug report
help as much as a coffee does.

<a href="https://ko-fi.com/inlitx"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi" height="38" /></a>

<sub><b>Crypto wallets</b></sub>

<table align="center">
  <tr>
    <td align="center" width="130"><img src="assets/crypto/bitcoin.svg" width="22" alt="Bitcoin" /><br/><sub><b>Bitcoin</b></sub></td>
    <td><code>bc1qm0r4pg8nknnjh3a7n2t63ckafhsz8jdd6qer29</code></td>
  </tr>
  <tr>
    <td align="center" width="130"><img src="assets/crypto/ethereum.svg" width="22" alt="Ethereum" /><br/><sub><b>Ethereum</b></sub></td>
    <td><code>0x34b7A5552132cBca150Ae29c1E632faA49430e1a</code></td>
  </tr>
  <tr>
    <td align="center" width="130"><img src="assets/crypto/solana.svg" width="22" alt="Solana" /><br/><sub><b>Solana</b></sub></td>
    <td><code>DC8dNEUNJhWdtBHBZAn4FTheVC3W4PtkGhbazvtk17Jo</code></td>
  </tr>
  <tr>
    <td align="center" width="130"><img src="assets/crypto/monero.svg" width="22" alt="Monero" /><br/><sub><b>Monero</b></sub></td>
    <td><code>44SECMEf3rfV228kpy3Gs48wLmLXnq231gAMG7ULYoCWBWLYLHdwYV7YFkhMk31DR5P7SRAyRPyhkYaehtgEoajASz7qubq</code></td>
  </tr>
</table>

<br/>
<br/>

<a href="https://www.star-history.com/?repos=InlitX%2Fstreak&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=InlitX/streak&type=date&theme=dark&legend=top-left&sealed_token=aNqDTOocHK1NkSrMsZrD1iFDpo1AtZvvUo3ZqETCzSujh-eSh0ekwpay4FpVGocizt1wmR5QWrkuMUAl2r9yllwF4v9e3tnsI6c1lv0upumuFVgsXGvAwA" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=InlitX/streak&type=date&legend=top-left&sealed_token=aNqDTOocHK1NkSrMsZrD1iFDpo1AtZvvUo3ZqETCzSujh-eSh0ekwpay4FpVGocizt1wmR5QWrkuMUAl2r9yllwF4v9e3tnsI6c1lv0upumuFVgsXGvAwA" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=InlitX/streak&type=date&legend=top-left&sealed_token=aNqDTOocHK1NkSrMsZrD1iFDpo1AtZvvUo3ZqETCzSujh-eSh0ekwpay4FpVGocizt1wmR5QWrkuMUAl2r9yllwF4v9e3tnsI6c1lv0upumuFVgsXGvAwA" />
 </picture>
</a>

<br/>
<br/>

Released under the <a href="LICENSE"><b>GNU GPLv3</b></a>, with the <a href="ADDITIONAL_TERMS.md">attribution term</a> of its section 7(b).

</div>
