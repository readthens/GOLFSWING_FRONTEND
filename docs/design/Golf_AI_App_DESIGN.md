# DESIGN.md — Golf AI Swing Analyzer App

> Use this file as the design instruction source for AI screen generation, frontend implementation, Figma direction, or a custom `design` skill.  
> Working product name used below: **SwingLens AI**. Rename freely later.

---

## 1. Design North Star

### Product feeling
The app should feel like a **premium aerospace-style golf lab**: cinematic, precise, technical, quiet, and confident.

Think:
- Black canvas.
- Near-white typography.
- Full-screen golf video and photography.
- Minimal interface chrome.
- Sharp analysis overlays.
- High contrast.
- No clutter.
- No playful colors.
- No cheap sports-app gradients.

The visual identity should suggest:

> “This is not a social golf app. This is a serious AI performance system.”

### Inspiration direction
Use a **SpaceX-like black/white cinematic style** as inspiration only:
- Full-screen imagery/video.
- Stark black and white palette.
- Technical uppercase labels.
- Large confident headlines.
- Ghost buttons.
- Minimal decorative UI.

Do **not** copy SpaceX assets, logos, exact layouts, trademarks, or brand language.

### Golf adaptation
SpaceX-style visual language should be adapted to golf through:
- Slow-motion swing silhouettes.
- Range lighting.
- Launch monitor-like data labels.
- Shot tracer lines.
- Frame-by-frame video analysis.
- AI confidence indicators.
- Camera placement diagrams.

---

## 2. Core Design Principles

### 1. Video is the hero
Every major screen should be built around video, motion, or a still frame from a swing.

Good examples:
- Login screen with dark golf swing silhouette.
- Home screen with latest swing freeze-frame.
- Analysis report with impact frame as background.
- Shot tracer screen with ball-flight video as the main canvas.

Avoid:
- Generic dashboard cards everywhere.
- Bright stock illustrations.
- Random golf icons as decoration.

### 2. Minimal, not empty
The interface should feel clean, but it still needs enough structure for usability.

Use:
- Thin dividers.
- Ghost panels.
- Small uppercase labels.
- Large numbers.
- Clear primary actions.

Avoid:
- Heavy cards.
- Drop shadows.
- Rounded colorful badges.
- Too many accent colors.

### 3. Technical but human
The app should look advanced, but the feedback should still be easy to understand.

Example:
- Label: `PRIMARY FAULT`
- Human text: “Your hips move toward the ball before impact.”

### 4. One screen, one mission
Each screen should have one obvious purpose.

Examples:
- Login: enter the system.
- Capture: record a usable swing.
- Report: understand the main issue.
- Drill: fix the issue.
- Tracer: export the ball flight.

### 5. Confidence matters
AI outputs must always feel measured and trustworthy.

Use:
- Confidence scores.
- “Likely issue” language.
- Evidence frames.
- Visual proof.

Avoid:
- Overconfident coaching claims.
- Medical/injury language.
- Exact launch monitor data unless actually measured.

---

## 3. Brand Personality

### Voice
- Precise.
- Calm.
- Direct.
- Premium.
- Coach-like.
- Never childish.

### Copy style
Use short sentences.

Good:
- “Angle locked.”
- “Ball visible.”
- “Impact detected.”
- “Primary fault: early extension.”
- “Fix this first.”

Avoid:
- “Awesome swing bro!”
- “Let’s crush some golf magic!”
- “Your body mechanics are catastrophically wrong.”

### UI text casing
Use uppercase for:
- Labels.
- Section headers.
- Buttons.
- Navigation.

Use sentence case for:
- Explanations.
- Coaching feedback.
- Error messages.
- Legal/privacy text.

---

## 4. Design Tokens

```yaml
brand:
  name: SwingLens AI
  style: cinematic_black_white_golf_ai
  personality: premium, technical, minimal, precise

colors:
  background_primary: "#000000"        # pure black
  background_elevated: "#080808"       # near black
  background_panel: "rgba(255,255,255,0.045)"
  background_panel_strong: "rgba(255,255,255,0.08)"
  text_primary: "#F2F2F5"              # spectral near-white
  text_secondary: "#B8B8C0"
  text_muted: "#74747D"
  border_subtle: "rgba(255,255,255,0.14)"
  border_strong: "rgba(255,255,255,0.32)"
  input_bg: "rgba(255,255,255,0.04)"
  input_border: "rgba(255,255,255,0.18)"
  button_primary_bg: "#F2F2F5"
  button_primary_text: "#000000"
  button_ghost_bg: "rgba(242,242,245,0.08)"
  button_ghost_border: "rgba(242,242,245,0.32)"
  overlay_dark: "rgba(0,0,0,0.58)"
  overlay_deep: "rgba(0,0,0,0.78)"
  success: "#F2F2F5"                   # keep monochrome by default
  warning: "#D6D6D6"
  danger: "#FFFFFF"
  optional_signal_green: "#7CFF9B"     # use rarely for tracer/data only
  optional_tracer_blue: "#9FD7FF"      # use only in tracer styles, not core UI

font_family:
  display: "D-DIN, DIN Condensed, Geist, Inter, SF Pro Display, Arial, sans-serif"
  body: "Inter, SF Pro Text, Geist, Arial, sans-serif"
  mono: "SFMono-Regular, JetBrains Mono, Menlo, monospace"

typography:
  hero:
    size_mobile: 42
    size_desktop: 64
    weight: 800
    line_height: 0.95
    letter_spacing: 0.5
    transform: uppercase
  title:
    size_mobile: 30
    size_desktop: 44
    weight: 750
    line_height: 1.0
    transform: uppercase
  section_label:
    size: 11
    weight: 700
    letter_spacing: 1.4
    transform: uppercase
  body:
    size: 15
    weight: 400
    line_height: 1.55
  button:
    size: 13
    weight: 800
    letter_spacing: 1.1
    transform: uppercase
  metric_number:
    size: 48
    weight: 800
    line_height: 0.95
  micro:
    size: 10
    weight: 600
    letter_spacing: 1.0
    transform: uppercase

spacing:
  unit: 8
  xs: 4
  sm: 8
  md: 16
  lg: 24
  xl: 32
  xxl: 48
  screen_padding_mobile: 24
  screen_padding_desktop: 48

radius:
  none: 0
  sm: 8
  md: 14
  lg: 20
  pill: 999

borders:
  thin: "1px solid rgba(255,255,255,0.14)"
  medium: "1px solid rgba(255,255,255,0.28)"

shadows:
  default: none
  philosophy: "Avoid shadows. Use contrast, overlays, borders, and video depth instead."

motion:
  fast: 120ms
  normal: 220ms
  slow: 420ms
  easing: "cubic-bezier(0.2, 0.8, 0.2, 1)"
```

---

## 5. Layout System

### Mobile canvas
Design primarily for:
- iPhone 15 / 16 style dimensions.
- 390 x 844 baseline.
- Android 360 x 800 baseline.

### Safe areas
Respect:
- Top notch / dynamic island.
- Bottom home indicator.
- Camera controls near thumb zone.

### Grid
- Use a 4-column mobile grid only when needed.
- Most screens should be vertical, cinematic, and simple.
- Use `24px` side padding for mobile.
- Use `16px` internal component spacing.

### Screen structure pattern
Most screens should follow this structure:

```text
┌────────────────────────────┐
│ Top utility / logo / status │
│                            │
│ Main visual / video / data  │
│                            │
│ Main headline or metric     │
│ Supporting explanation      │
│                            │
│ Primary CTA                 │
│ Secondary action            │
└────────────────────────────┘
```

### Cinematic overlay pattern
For screens with video/photo backgrounds:

```text
Layer 1: Full-screen video/image
Layer 2: Dark gradient overlay
Layer 3: White typography
Layer 4: Ghost buttons or analysis lines
```

---

## 6. Component System

### Buttons

#### Primary button
Use for the main action.

Visual:
- White background.
- Black text.
- Pill radius.
- Uppercase label.
- Full width on mobile when the action is important.

Example labels:
- `START ANALYSIS`
- `CREATE ACCOUNT`
- `RECORD SWING`
- `EXPORT VIDEO`

#### Ghost button
Use for secondary actions.

Visual:
- Transparent or faint white background.
- Thin white border.
- White text.
- Pill radius.

Example labels:
- `SIGN IN`
- `UPLOAD VIDEO`
- `VIEW SAMPLE`
- `MANUAL ADJUST`

#### Text button
Use for small links.

Example labels:
- `Forgot password?`
- `Use email instead`
- `Skip for now`

---

### Inputs

Visual:
- Dark translucent field.
- Thin subtle border.
- White text.
- Muted placeholder.
- 14–16px text.
- 14–16px radius.

States:
- Focus: stronger white border.
- Error: white border + clear error text. Do not use aggressive red unless absolutely necessary.
- Disabled: lower opacity.

Input examples:
- Email.
- Password.
- Name.
- Handicap.
- Club used.

---

### Panels

Use panels only when the user needs structure.

Visual:
- Very dark translucent surface.
- Thin border.
- No shadow.
- 16–20px radius.

Good uses:
- Analysis result summary.
- Swing metrics.
- Subscription plan.
- Drill steps.

Avoid using panels for every small item.

---

### Metric blocks

Visual:
- Big number.
- Small uppercase label.
- Optional micro trend.

Example:

```text
72
SWING SCORE
+8 FROM LAST SESSION
```

---

### AI status indicators

Keep them minimal.

Examples:
- `AI READY`
- `ANGLE LOCKED`
- `BALL VISIBLE`
- `CLUB NOT VISIBLE`
- `LOW LIGHT`
- `CONFIDENCE 84%`

Use monochrome badges unless the state is critical.

---

### Video overlays

Allowed overlays:
- Skeleton pose lines.
- Spine angle line.
- Hip-depth vertical line.
- Swing plane line.
- Club shaft line.
- Ball path/tracer.
- Impact frame marker.
- Small confidence labels.

Overlay style:
- Thin lines.
- White or near-white.
- Optional faint glow only for tracer.
- Avoid neon overload.

---

## 7. Screen Design Guide

## `/splash` — Splash Screen

### Purpose
Create a premium first impression.

### Layout
- Pure black background.
- Center wordmark: `SWINGLENS AI`.
- Tiny label under it: `AI GOLF PERFORMANCE SYSTEM`.
- Optional animated thin horizontal scan line.

### Feeling
Quiet. Expensive. Technical.

### AI prompt
> Create a minimalist black splash screen for a premium AI golf swing analysis app. Use a white uppercase wordmark centered vertically, small technical subtitle, no icons, no gradients except a very subtle dark glow.

---

## `/welcome` — Welcome / Landing Screen

### Purpose
Explain the app in one powerful message.

### Layout
- Full-screen slow-motion golf swing background.
- Dark overlay.
- Bottom-left or bottom-aligned headline.
- Primary button: `START NOW`.
- Secondary button: `I ALREADY HAVE AN ACCOUNT`.

### Copy
Headline:
> `SEE YOUR SWING LIKE A PRO`

Subtitle:
> Record your swing, detect the fault, and get a drill to fix it.

### AI prompt
> Design a cinematic mobile welcome screen for an AI golf app. Use a dark full-screen golf swing image/video background, near-white uppercase headline, subtle body text, a white primary CTA, and a ghost secondary CTA. Keep the layout premium, minimal, and high contrast.

---

## `/auth/sign-in` — Login Screen

### Purpose
Let returning users enter quickly.

### Layout
```text
Top:
  Small wordmark

Middle:
  Eyebrow label: MEMBER ACCESS
  Title: SIGN IN
  Subtitle: Continue your swing analysis.

Form:
  Email field
  Password field
  Forgot password link

Actions:
  Primary button: SIGN IN
  Ghost button: CONTINUE WITH APPLE
  Ghost button: CONTINUE WITH GOOGLE

Bottom:
  New here? Create account
```

### Visual direction
- Background: black or dark golf video still.
- Form container: very subtle translucent panel, or no panel if legibility is strong.
- Inputs: black translucent fields with thin white borders.
- Buttons: one white primary button, two ghost buttons.

### Important details
- Keep the screen simple.
- Do not use colorful social login buttons.
- Password visibility icon should be white outline only.
- Error text should be calm and clear.

### Example copy
- Label: `MEMBER ACCESS`
- Title: `SIGN IN`
- Subtitle: `Continue your swing analysis.`
- CTA: `SIGN IN`

### AI prompt
> Design a premium black-and-white mobile login screen for an AI golf swing analyzer. Use a cinematic dark golf background, uppercase technical labels, near-white text, translucent input fields, one white pill-shaped primary button, and ghost social-login buttons. Make it feel like a serious performance system, not a playful sports app.

---

## `/auth/sign-up` — Signup Screen

### Purpose
Create an account with minimal friction.

### Layout
```text
Top:
  Back arrow
  Small wordmark

Header:
  Eyebrow: CREATE PROFILE
  Title: START YOUR ANALYSIS
  Subtitle: Build your swing history and track progress.

Form:
  Name
  Email
  Password

Optional row:
  Handedness selector: RIGHT / LEFT

Actions:
  Primary button: CREATE ACCOUNT
  Ghost button: CONTINUE WITH APPLE
  Ghost button: CONTINUE WITH GOOGLE

Footer:
  By continuing, you agree to Terms and Privacy.
```

### Visual direction
- Mostly black background.
- A faint cropped golf ball / club / swing silhouette can sit behind the form.
- Use a step indicator if signup becomes multi-step.

### Example copy
- Label: `CREATE PROFILE`
- Title: `START YOUR ANALYSIS`
- Subtitle: `Save swings, compare progress, and unlock AI coaching.`
- CTA: `CREATE ACCOUNT`

### AI prompt
> Design a black-and-white signup screen for a premium AI golf coaching app. Use uppercase headings, minimal fields, subtle translucent surfaces, white primary CTA, ghost Apple/Google buttons, and a serious cinematic sports-tech mood.

---

## `/auth/forgot-password` — Password Reset

### Purpose
Help users recover access without breaking the premium tone.

### Layout
- Top back button.
- Title: `RESET ACCESS`.
- Subtitle explaining email reset.
- Email input.
- Primary CTA: `SEND RESET LINK`.
- Bottom: `RETURN TO SIGN IN`.

### AI prompt
> Create a minimal black password reset screen with a technical, premium feel. Use one email field, one white primary CTA, and calm helper copy.

---

## `/onboarding/profile` — Profile Setup

### Purpose
Collect basics for personalized analysis.

### Layout
- Progress label: `STEP 01 / 04`.
- Title: `BUILD YOUR GOLF PROFILE`.
- Fields/cards:
  - Handedness.
  - Skill level.
  - Common miss.
  - Main goal.
- Primary CTA: `CONTINUE`.

### Visual direction
- Use large selectable pill cards.
- Keep it monochrome.
- Selected state: white fill, black text.

### AI prompt
> Design a monochrome onboarding profile screen for an AI golf app. Use uppercase labels, black background, white selectable pill cards, and a clean progress marker.

---

## `/onboarding/goals` — Goal Selection

### Purpose
Understand why the golfer is using the app.

### Options
- `FIX MY SLICE`
- `GAIN DISTANCE`
- `IMPROVE CONTACT`
- `STOP TOPPING`
- `BUILD CONSISTENCY`
- `TRACK PROGRESS`

### Layout
- Large heading.
- 2-column selectable cards.
- Bottom CTA.

### AI prompt
> Create a dark, premium mobile goal-selection screen with monochrome selectable cards for golf improvement goals. The selected card should invert to white with black text.

---

## `/home` — Dashboard

### Purpose
Give the user one clear next action.

### Layout
```text
Top:
  Greeting
  Small settings/profile icon

Hero:
  Latest swing freeze-frame or black hero panel
  Main CTA: RECORD SWING
  Secondary CTA: UPLOAD VIDEO

Below:
  Swing score trend
  Last detected fault
  Today’s drill
  Recent swings
```

### Visual direction
- Hero should feel cinematic.
- Use large metric number if analysis exists.
- If new user, show capture education instead of empty state.

### AI prompt
> Design a premium black-and-white home dashboard for an AI golf swing app. Use a cinematic latest-swing hero, one dominant record button, small technical stats, and minimal ghost panels. Avoid colorful dashboard clutter.

---

## `/capture` — Capture Mode Selection

### Purpose
Choose what the user wants to record.

### Modes
- `SWING ANALYSIS`
- `SHOT TRACER`
- `COMPARE SWINGS`
- `DRILL CHECK`

### Layout
- Full black screen.
- Large title: `SELECT CAPTURE MODE`.
- Four vertical mode rows or full-width cards.
- Each mode has a short description.

### AI prompt
> Create a black-and-white capture-mode selection screen for a golf AI app. Use four large full-width rows, uppercase labels, thin dividers, and a premium technical tone.

---

## `/capture/angle-select` — Camera Angle Selection

### Purpose
Tell the user which angle they need.

### Options
- `FACE-ON`
- `DOWN-THE-LINE`
- `REAR / TRACER`

### Layout
- Three large cards.
- Each card includes a simple line diagram.
- Primary CTA after selection: `SET CAMERA`.

### AI prompt
> Design a monochrome camera-angle selection screen for a golf swing analyzer. Show three premium technical cards: Face-On, Down-the-Line, Rear/Tracer. Include simple white line diagrams and short use-case text.

---

## `/capture/setup-guide/:angle` — Camera Setup Guide

### Purpose
Help users place the phone correctly.

### Layout
- Top: angle name.
- Center: black-and-white diagram of golfer, ball, target line, phone position.
- Checklist:
  - `FULL BODY VISIBLE`
  - `CLUB VISIBLE`
  - `BALL VISIBLE`
  - `PHONE STABLE`
- Primary CTA: `OPEN CAMERA`.

### AI prompt
> Design a technical black-and-white camera setup guide for recording a golf swing. Use a simple top-down diagram, thin white lines, checklist items, and a strong CTA to open the camera.

---

## `/capture/live-quality` — Live Camera Quality Check

### Purpose
Make sure the video is usable before recording.

### Layout
- Full-screen live camera.
- Top status: `ANGLE CHECKING` or `ANGLE LOCKED`.
- Overlay boxes/lines around body, ball, club.
- Bottom checklist panel.
- CTA: `RECORD` only becomes active when quality is acceptable.

### Status labels
- `BODY VISIBLE`
- `BALL VISIBLE`
- `CLUB VISIBLE`
- `LOW LIGHT`
- `MOVE PHONE BACK`
- `ROTATE SLIGHTLY LEFT`

### AI prompt
> Design a live camera quality-check screen for a golf AI app. Use the camera feed as the full background, white technical overlays, small uppercase status chips, and a bottom ghost panel with capture readiness checks.

---

## `/capture/recording` — Recording Screen

### Purpose
Record clean video.

### Layout
- Full-screen camera.
- Minimal controls.
- Large white record button at bottom.
- Small timer.
- Angle label.
- Optional guide line for target line.

### AI prompt
> Create a minimal golf swing recording screen with full-screen camera preview, white record control, tiny technical status text, and almost no extra UI.

---

## `/capture/review` — Video Review Before Upload

### Purpose
Let user trim and confirm metadata.

### Layout
- Video preview top.
- Timeline scrubber.
- Metadata fields:
  - Club.
  - Angle.
  - Indoor/outdoor.
- Quality score.
- Primary CTA: `ANALYZE SWING`.

### AI prompt
> Design a dark video review screen for a golf AI app. Use a large video preview, minimal timeline, small metadata selectors, quality score, and a white analyze button.

---

## `/processing` — Analysis Processing

### Purpose
Make waiting feel premium and transparent.

### Layout
- Black background.
- Center animated ring or thin progress line.
- Current step:
  - `DETECTING POSE`
  - `TRACKING CLUB`
  - `FINDING IMPACT`
  - `BUILDING REPORT`
- Tiny reassurance text.

### AI prompt
> Design a premium AI processing screen for golf swing analysis. Use black background, white technical progress animation, uppercase processing steps, and no playful loader.

---

## `/swings/:swingId/report` — AI Swing Report

### Purpose
Show the user what to fix first.

### Layout
```text
Top:
  Swing date / club / angle

Hero:
  Impact or fault evidence frame
  Overlay line showing the problem

Main result:
  SWING SCORE
  Primary fault
  Confidence

Explanation:
  What happened
  Why it matters
  How to fix it

CTA:
  START RECOMMENDED DRILL
```

### Visual direction
- Main evidence frame should dominate.
- Avoid showing too many metrics at first.
- Let the user expand advanced metrics.

### AI prompt
> Design a premium black-and-white AI golf swing report screen. Use a large evidence video frame, white analysis overlays, a big swing score, primary fault, confidence label, concise explanation, and one main drill CTA.

---

## `/player/:videoId` — Swing Video Player

### Purpose
Review swing frame by frame.

### Layout
- Full-screen video.
- Bottom scrubber.
- Phase markers: `P1`, `P2`, `P3`, etc.
- Overlay toggles:
  - `POSE`
  - `SPINE`
  - `PLANE`
  - `CLUB`
- Button: `COMPARE`.

### AI prompt
> Create a dark full-screen golf swing video player with technical white overlays, frame markers, slow-motion controls, and minimal bottom controls.

---

## `/tracer/:projectId` — Shot Tracer Editor

### Purpose
Create and refine ball-flight tracer video.

### Layout
- Full-screen video canvas.
- White or optional accent tracer line.
- Bottom timeline.
- Mode toggle:
  - `AUTO`
  - `MANUAL`
  - `STYLE`
- Right-side or bottom controls:
  - thickness.
  - glow.
  - fade.
  - export.

### Visual direction
- Video is the entire screen.
- UI floats over it.
- Controls should feel like a professional editing tool.

### AI prompt
> Design a cinematic shot-tracer editor for a golf app. Use full-screen ball-flight video, a clean white tracer path, floating monochrome editing controls, timeline scrubber, and export CTA. Make it feel like a pro video tool.

---

## `/swings` — Swing Library

### Purpose
Browse swing history.

### Layout
- Header: `SWING LIBRARY`.
- Filter chips:
  - Club.
  - Angle.
  - Fault.
  - Date.
- List of swing rows with thumbnail, score, fault, date.
- Floating CTA: `RECORD`.

### AI prompt
> Design a black-and-white swing library screen with video thumbnails, technical metadata, thin dividers, score labels, and minimal filter chips.

---

## `/compare/:comparisonId` — Swing Comparison

### Purpose
Compare two videos.

### Layout
- Split video view.
- Sync marker at impact.
- Shared scrubber.
- Difference metrics below.
- CTA: `EXPORT COMPARISON`.

### AI prompt
> Design a monochrome golf swing comparison screen with two synchronized video panels, impact markers, shared timeline, and clean metric differences.

---

## `/coach/drills/:drillId` — Drill Detail

### Purpose
Teach the user the corrective drill.

### Layout
- Drill video/image at top.
- Label: `RECOMMENDED FOR EARLY EXTENSION`.
- Title.
- 3-step instructions.
- Reps/sets.
- CTA: `START DRILL SESSION`.

### AI prompt
> Create a premium dark drill detail screen for a golf AI app. Use video at the top, uppercase technical label, concise steps, repetition target, and a white CTA.

---

## `/settings` — Settings

### Purpose
Manage account, privacy, subscription.

### Layout
- Simple black list screen.
- Thin dividers.
- No heavy cards.
- Sections:
  - Profile.
  - Subscription.
  - Storage.
  - Privacy.
  - Delete account.

### AI prompt
> Design a minimal black-and-white settings screen with uppercase section labels, thin dividers, and simple list rows.

---

## `/academy` — Coach Dashboard

### Purpose
Let coaches manage students.

### Layout
- Header: `ACADEMY CONTROL`.
- Metrics row:
  - pending reviews.
  - active students.
  - swings this week.
- Student review queue.
- Recent analysis list.

### AI prompt
> Design a premium monochrome coach dashboard for an AI golf analysis platform. Use technical metrics, student review queue, minimal panels, and high-contrast typography.

---

## 8. Login Screen Detailed Blueprint

### Visual composition

```text
┌────────────────────────────────┐
│ SWINGLENS AI                   │
│                                │
│                                │
│        dark golf silhouette     │
│                                │
│                                │
│ MEMBER ACCESS                  │
│ SIGN IN                        │
│ Continue your swing analysis.  │
│                                │
│ [ Email                     ]  │
│ [ Password                  ]  │
│                      Forgot?   │
│                                │
│ [        SIGN IN            ]  │
│ [   CONTINUE WITH APPLE     ]  │
│ [   CONTINUE WITH GOOGLE    ]  │
│                                │
│ New here? Create account       │
└────────────────────────────────┘
```

### Styling
- Background: full-screen black with faint golfer silhouette.
- Top wordmark: 13px uppercase, letter spacing 1.6px.
- Title: 42px uppercase, bold.
- Form sits in bottom 45% of screen.
- Inputs: 52px height.
- Primary button: 54px height.
- Ghost buttons: 52px height.
- Bottom link: centered or left-aligned.

### Login AI prompt
> Create `/auth/sign-in` for SwingLens AI. It is a premium AI golf performance app with a black-and-white SpaceX-inspired cinematic style. Use a black full-screen background with a subtle golf swing silhouette, near-white uppercase typography, minimal translucent input fields, one white pill-shaped SIGN IN button, and ghost Apple/Google buttons. Keep it clean, luxury, technical, and serious.

---

## 9. Signup Screen Detailed Blueprint

### Visual composition

```text
┌────────────────────────────────┐
│ ←        SWINGLENS AI          │
│                                │
│ CREATE PROFILE                 │
│ START YOUR ANALYSIS            │
│ Save swings and track progress.│
│                                │
│ [ Name                      ]  │
│ [ Email                     ]  │
│ [ Password                  ]  │
│                                │
│ HANDEDNESS                     │
│ [ RIGHT ]        [ LEFT ]      │
│                                │
│ [      CREATE ACCOUNT       ]  │
│ [   CONTINUE WITH APPLE     ]  │
│ [   CONTINUE WITH GOOGLE    ]  │
│                                │
│ Already have account? Sign in  │
│ Terms · Privacy                │
└────────────────────────────────┘
```

### Styling
- Header aligned top with back button.
- Content begins higher than login because signup has more fields.
- Handedness selector uses two pill buttons.
- Selected handedness: white fill, black text.
- Legal text: small muted gray.

### Signup AI prompt
> Create `/auth/sign-up` for SwingLens AI. Use a premium black-and-white cinematic golf-tech design. Include name, email, password, handedness selector, white primary CREATE ACCOUNT button, ghost Apple/Google buttons, and subtle legal text. Use uppercase technical labels, near-white text, thin borders, no bright colors, no shadows, and no playful illustrations.

---

## 10. Route-to-Design Map

| Route | Screen Type | Visual Treatment | Main CTA |
|---|---|---|---|
| `/splash` | Brand intro | Pure black, centered wordmark | None |
| `/welcome` | Cinematic hero | Full-screen swing video/image | `START NOW` |
| `/auth/sign-in` | Auth form | Dark background, bottom form | `SIGN IN` |
| `/auth/sign-up` | Auth form | Dark background, stacked form | `CREATE ACCOUNT` |
| `/auth/forgot-password` | Utility form | Minimal black screen | `SEND RESET LINK` |
| `/onboarding/profile` | Setup | Selectable monochrome pills | `CONTINUE` |
| `/onboarding/goals` | Setup | Goal cards, inverted selected state | `CONTINUE` |
| `/home` | Dashboard | Latest swing hero + stats | `RECORD SWING` |
| `/capture` | Mode selection | Large technical rows | `SELECT MODE` |
| `/capture/angle-select` | Setup choice | Diagram cards | `SET CAMERA` |
| `/capture/setup-guide/:angle` | Instruction | Diagram + checklist | `OPEN CAMERA` |
| `/capture/live-quality` | Camera AI | Full-screen camera overlays | `RECORD` |
| `/capture/review` | Video utility | Preview + metadata | `ANALYZE SWING` |
| `/processing` | Loading | Technical progress animation | None |
| `/swings` | Library | Video thumbnails + filters | `RECORD` |
| `/swings/:id/report` | Analysis | Evidence frame + score | `START DRILL` |
| `/player/:videoId` | Video tool | Full-screen player overlays | `COMPARE` |
| `/tracer/:projectId` | Editor | Full-screen video/tracer | `EXPORT` |
| `/compare/:id` | Comparison | Split video | `EXPORT` |
| `/coach/drills/:id` | Education | Drill video + steps | `START DRILL` |
| `/settings` | Utility | Thin list rows | Varies |
| `/academy` | Coach dashboard | Metrics + queues | `REVIEW SWINGS` |

---

## 11. Common Patterns for AI Screen Generation

### Auth screen formula
```text
black cinematic background
+ small top wordmark
+ uppercase eyebrow label
+ huge uppercase title
+ short human subtitle
+ translucent form fields
+ white primary CTA
+ ghost secondary CTA
+ tiny muted legal/help text
```

### Analysis screen formula
```text
video evidence frame
+ white overlay lines
+ big score/metric
+ primary fault
+ confidence label
+ short explanation
+ drill CTA
```

### Capture screen formula
```text
full-screen camera
+ minimal status labels
+ white technical detection boxes/lines
+ bottom action area
+ no decorative UI
```

### Dashboard formula
```text
latest swing visual
+ one primary action
+ 2–3 important metrics
+ recommended next drill
+ recent swings
```

---

## 12. Do and Do Not

### Do
- Use black as the main canvas.
- Use near-white text, not colorful UI.
- Use full-screen video/photo where possible.
- Use uppercase labels with letter spacing.
- Use large confident headlines.
- Use thin borders and subtle panels.
- Use white primary buttons.
- Use ghost secondary buttons.
- Use technical overlays for AI analysis.
- Keep copy short and direct.

### Do not
- Do not use bright green as the main brand color.
- Do not make the app look like a generic fitness tracker.
- Do not overuse cards.
- Do not add heavy shadows.
- Do not use playful cartoon golf illustrations.
- Do not copy SpaceX logos, assets, or brand names.
- Do not show too many metrics on the first report screen.
- Do not use exact launch-monitor language unless backed by hardware/data.

---

## 13. Sample Component Prompts

### Primary button
> Create a full-width pill-shaped primary button with near-white background, black uppercase label, 54px height, 13px bold text, 1.1px letter spacing, and no shadow.

### Ghost button
> Create a transparent pill-shaped ghost button with a faint white border, near-white uppercase label, 52px height, and subtle white overlay on press.

### Input field
> Create a dark translucent input field with a thin white border, 16px radius, near-white typed text, muted gray placeholder, and stronger white border on focus.

### Metric tile
> Create a minimal metric tile on black with a huge white number, small uppercase label, muted trend text, thin border, and no shadow.

### Video overlay
> Create a technical white analysis overlay on top of a golf swing video. Use thin lines, small uppercase labels, confidence percentage, and no colorful decoration.

---

## 14. Implementation Notes for Frontend Engineers

### CSS-style tokens

```css
:root {
  --bg: #000000;
  --bg-elevated: #080808;
  --panel: rgba(255,255,255,0.045);
  --panel-strong: rgba(255,255,255,0.08);
  --text: #F2F2F5;
  --text-secondary: #B8B8C0;
  --text-muted: #74747D;
  --border: rgba(255,255,255,0.14);
  --border-strong: rgba(255,255,255,0.32);
  --button-bg: #F2F2F5;
  --button-text: #000000;
  --ghost-bg: rgba(242,242,245,0.08);
  --ghost-border: rgba(242,242,245,0.32);
  --overlay-dark: rgba(0,0,0,0.58);
  --radius-sm: 8px;
  --radius-md: 14px;
  --radius-lg: 20px;
  --radius-pill: 999px;
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 16px;
  --space-4: 24px;
  --space-5: 32px;
  --space-6: 48px;
}
```

### Tailwind-style direction
Use classes like:
- `bg-black`
- `text-[#F2F2F5]`
- `border-white/15`
- `bg-white/5`
- `rounded-full`
- `uppercase`
- `tracking-[0.12em]`
- `font-bold`

### Accessibility
- Keep high contrast.
- Minimum tap target: 44px.
- Do not rely on color only for status.
- Add text labels for all AI checks.
- Provide readable error messages.
- Allow dynamic text scaling where possible.

---

## 15. Final AI Design Instruction

When designing any screen for this app, follow this master instruction:

> Design a premium black-and-white AI golf performance app. The style is cinematic, minimal, technical, and serious. Use black backgrounds, near-white uppercase typography, full-screen golf video or photography when possible, ghost buttons, thin white borders, and precise AI analysis overlays. Avoid bright colors, playful sports graphics, heavy cards, shadows, and generic dashboard clutter. Every screen should feel like a high-end performance system for analyzing golf swings and ball flight.

