# Design System Inspired by Jules

## 1. Visual Theme & Atmosphere

Jules embraces a **dark, tech-forward aesthetic** with a distinctly cyberpunk energy. The design system features deep purples and blacks as foundational surfaces, punctuated by bold neon magenta accents that command attention and convey innovation. The monospace typography reinforces the coding-agent identity, while minimalist layouts and generous whitespace create breathing room within the dark environment. The overall atmosphere is futuristic yet approachable—a sophisticated AI assistant that feels powerful without being intimidating. Dotted borders and geometric precision suggest algorithmic precision and autonomous intelligence.

**Key Characteristics**
- Deep purple-black color foundation (`#09051C`, `#1D0245`)
- Vibrant neon magenta highlights (`#FF79C6`) for primary interactions
- Monospace typography throughout for technical authenticity
- High contrast for accessibility and impact
- Minimal geometric ornamentation (dotted borders, sharp edges)
- Clean, spacious layouts with intentional negative space
- Cyan/teal accent for secondary interactions (inferred from UI patterns)

## 2. Color Palette & Roles

### Primary
- **Brand Magenta** (`#FF79C6`): Primary call-to-action buttons, accent highlights, attention-drawing UI elements, and interactive states
- **Deep Purple Night** (`#09051C`): Primary background for dark mode dominance and deep surface foundation

### Accent Colors
- **Dark Violet** (`#1D0245`): Secondary background layer, subtle depth distinction
- **Cyan Teal** (`#00D9FF`): Secondary interactive elements, plan navigation buttons, link underlines (inferred from UI)

### Interactive
- **Magenta Button** (`#FF79C6`): Primary CTA background and active states
- **Cyan Border** (`#00D9FF`): Outlined button borders, secondary navigation highlights
- **Magenta-Purple Active** (`#C449A0`): Hover and pressed states (derived from magenta with darkened tone)

### Neutral Scale
- **Pure Black** (`#000000`): Text content, code backgrounds, hard shadows, maximum contrast
- **Pure White** (`#FFFFFF`): Primary text on dark backgrounds, code comments, high-contrast labels

### Surface & Borders
- **Deep Night** (`#09051C`): Main surface and container backgrounds
- **Violet Layer** (`#1D0245`): Nested containers, code editor backgrounds
- **Cyan Border** (`#00D9FF`): Decorative dotted borders, accent frames

## 3. Typography Rules

### Font Family
**Primary:** `Roboto Mono Variable` with fallback `monospace`
**Secondary:** `ui-monospace`, then `'Courier New'`, then `monospace`

All typography uses monospace for consistency with coding-agent identity.

### Hierarchy

| Role | Font | Size | Weight | Line Height | Letter Spacing | Notes |
|------|------|------|--------|-------------|-----------------|-------|
| Display / H1 | Roboto Mono Variable | 15px | 400 | 22.5px | 0 | Hero headline, agent title |
| Heading | Roboto Mono Variable | 18px | 400 | 28px | 0 | Large section headers, body intro text |
| Body / Paragraph | Roboto Mono Variable | 15px | 400 | 22.5px | 0 | Standard content, descriptions |
| Body Emphasis | Roboto Mono Variable | 15px | 500 | 22.5px | 0 | List items, emphasis content |
| Link / Button Text | Roboto Mono Variable | 15px | 700 | 22.5px | 0 | Interactive text, CTA labels, navigation |
| Code / Block | ui-monospace | 14px | 400 | 24px | 0 | Code samples, syntax highlighting |
| Caption | Roboto Mono Variable | 12px | 400 | 18px | 0 | Small labels, timestamps (inferred) |

### Principles
- **Monospace consistency:** All text uses monospace fonts to reinforce the coding-agent identity and create visual cohesion
- **Weight for emphasis:** Font weight (`500`, `700`) distinguishes interactive and emphasized content rather than size changes
- **Tight leading:** Line heights match or slightly exceed font size for readability in dark mode
- **No letter spacing variation:** Maintains technical aesthetic without artificial spacing
- **Scale restraint:** Limited size range (12–18px) keeps hierarchy clear and focused

## 4. Component Stylings

### Buttons

**Primary Button**
- Background: `#FF79C6`
- Text Color: `#FFFFFF`
- Padding: `8px 16px`
- Border Radius: `0px`
- Border: `0px solid transparent`
- Font Size: `15px`
- Font Weight: `700`
- Font Family: `Roboto Mono Variable`
- Height: `38.5px`
- Line Height: `22.5px`
- Hover State: Background `#C449A0` (darken by ~20%)
- Active State: Background `#A83880`
- Transition: `background-color 200ms ease`

**Secondary Button (Outlined)**
- Background: `rgba(0, 0, 0, 0)` (transparent)
- Text Color: `#00D9FF`
- Padding: `2px 10px 2px 4px`
- Border Radius: `0px`
- Border: `4px solid #00D9FF`
- Font Size: `15px`
- Font Weight: `700`
- Font Family: `Roboto Mono Variable`
- Height: `36px`
- Box Shadow: `none`
- Hover State: Background `rgba(0, 217, 255, 0.1)`, Border `4px solid #00FFFF`
- Active State: Background `rgba(0, 217, 255, 0.2)`

**Ghost Button / Link Button**
- Background: `rgba(0, 0, 0, 0)` (transparent)
- Text Color: `#B88CC8`
- Padding: `0px 0px`
- Border Radius: `0px`
- Border: `0px solid transparent`
- Font Size: `15px`
- Font Weight: `500`
- Font Family: `Roboto Mono Variable`
- Height: `auto`
- Line Height: `22.5px`
- Hover State: Text Color `#FF79C6`, Text Decoration `underline`
- Active State: Text Color `#C449A0`

### Cards & Containers

**Code Editor Card**
- Background: `#1D0245`
- Border: `2px dotted #00D9FF`
- Border Radius: `0px`
- Padding: `24px`
- Box Shadow: `0px 8px 32px rgba(255, 121, 198, 0.15)`
- Text Color: `#FFFFFF`
- Min Height: `280px`

**Content Container**
- Background: `#09051C`
- Border Radius: `0px`
- Padding: `40px`
- Margin: `0px`
- Text Color: `#FFFFFF`

**Interactive Task Card**
- Background: `#FF79C6`
- Border Radius: `0px`
- Padding: `12px 16px`
- Border: `0px solid transparent`
- Text Color: `#FFFFFF`
- Font Weight: `700`
- Font Size: `15px`
- Hover State: Background `#C449A0`, Box Shadow `0px 4px 12px rgba(255, 121, 198, 0.3)`
- Cursor: `pointer`

**Yellow Accent Card** (alternate)
- Background: `#FFC300`
- Text Color: `#000000`
- Padding: `12px 16px`
- Font Weight: `700`

### Inputs & Forms

**Text Input**
- Background: `#1D0245`
- Text Color: `#FFFFFF`
- Border: `2px solid #00D9FF`
- Border Radius: `0px`
- Padding: `12px 16px`
- Font Size: `14px`
- Font Family: `ui-monospace`
- Line Height: `24px`
- Placeholder Color: `rgba(255, 255, 255, 0.5)`
- Focus State: Border `2px solid #FF79C6`, Box Shadow `0px 0px 12px rgba(255, 121, 198, 0.2)`

**Textarea**
- Background: `#1D0245`
- Text Color: `#FFFFFF`
- Border: `2px solid #00D9FF`
- Border Radius: `0px`
- Padding: `16px`
- Font Size: `14px`
- Font Family: `ui-monospace`
- Line Height: `24px`
- Min Height: `120px`
- Resize: `vertical`

### Navigation

**Top Navigation Bar**
- Background: `#09051C`
- Border: `0px`
- Height: `56px`
- Padding: `16px 40px`
- Display: `flex`
- Align Items: `center`
- Justify Content: `space-between`

**Navigation Link (Active)**
- Text Color: `#FFFFFF`
- Text Decoration: `none`
- Font Weight: `700`
- Font Size: `15px`
- Border Bottom: `2px solid #FF79C6`
- Padding Bottom: `8px`

**Navigation Link (Inactive)**
- Text Color: `#B88CC8`
- Text Decoration: `none`
- Font Weight: `500`
- Font Size: `15px`
- Hover State: Text Color `#FF79C6`

### Badge / Tag

**Magenta Badge**
- Background: `#FF79C6`
- Text Color: `#000000`
- Padding: `8px 12px`
- Border Radius: `0px`
- Font Size: `15px`
- Font Weight: `700`
- Display: `inline-block`

**Cyan Badge**
- Background: `#00D9FF`
- Text Color: `#000000`
- Padding: `8px 12px`
- Border Radius: `0px`
- Font Size: `15px`
- Font Weight: `700`

## 5. Layout Principles

### Spacing System
**Base Unit:** `8px`

**Scale:**
- `8px` — Extra tight spacing (between inline elements, micro padding)
- `12px` — Tight spacing (form input padding, small gaps)
- `16px` — Standard padding (button padding, card internal spacing)
- `24px` — Medium spacing (section internal padding, card padding)
- `32px` — Large spacing (between major sections)
- `40px` — Extra large spacing (container padding, horizontal gutters)
- `48px` — Section margin (between logical sections)
- `56px` — Large section margin (full-screen section separation)
- `80px` — Maximum margin (hero sections, primary separation)

**Usage Context:**
- Component internal padding: `12px–24px`
- Container padding: `40px`
- Section margins: `48px–80px`
- Gap between grid items: `32px–40px`

### Grid & Container
- **Max Width:** `1200px` (inferred from responsive layout)
- **Container Padding:** `40px` left and right
- **Column Strategy:** 12-column grid for flexible layouts, but uses full-width sections for hero and code displays
- **Section Patterns:** Hero section (full width), content container (centered, max-width), sidebar layouts (content + action panel)

### Whitespace Philosophy
The design prioritizes generous whitespace to prevent visual clutter in the dark environment. Spacing between elements emphasizes hierarchy and allows the eye to rest. Major sections are separated by significant vertical margins (`48px–80px`) to create distinct zones. Internal card spacing maintains breathing room around text and interactive elements.

### Border Radius Scale
- **Sharp (0px):** All buttons, cards, containers, and inputs use sharp 90-degree corners to reinforce the technical, cyberpunk aesthetic
- **No rounded corners** — Consistent use of `0px` throughout maintains geometric precision and aligns with monospace typography

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat / Base | No shadow | Backgrounds, containers, body text |
| Raised / L1 | `0px 4px 12px rgba(255, 121, 198, 0.15)` | Cards, input focus states, interactive elements |
| Elevated / L2 | `0px 8px 32px rgba(255, 121, 198, 0.15)` | Code editor card, modal windows, navigation overlays |
| Floating / L3 | `0px 16px 48px rgba(255, 121, 198, 0.2)` | Dropdowns, popovers, floating action elements |
| Maximum / L4 | `0px 24px 64px rgba(0, 0, 0, 0.4)` | Modal backdrop, full-screen overlays |

**Shadow Philosophy:**
Shadows use magenta tint (`rgba(255, 121, 198, ...)`) to reinforce brand identity and create depth in dark mode. Shadows are subtle and rarely exceed 20% opacity to maintain the dark atmosphere. The elevation system is restrained—most UI elements live at flat or raised levels. Shadows primarily indicate interactive layering and hover states rather than static hierarchy.

## 7. Do's and Don'ts

### Do
- **Use magenta (`#FF79C6`) for all primary CTAs** — Buttons, highlights, focus states, and attention-grabbing interactive elements
- **Maintain monospace typography** — All text should use `Roboto Mono Variable` or `ui-monospace` for consistency and brand identity
- **Preserve sharp corners** — Keep all border radius at `0px` for a precise, technical aesthetic
- **Leverage cyan (`#00D9FF`) for secondary actions** — Outlined buttons, decorative borders, and secondary navigation
- **Honor contrast ratios** — Ensure white text on dark backgrounds and magenta on dark backgrounds meet WCAG AA standards
- **Use generous spacing** — Apply `24px–40px` padding to containers and `48px–80px` margins between sections
- **Apply subtle shadows** — Keep shadows below 20% opacity and use magenta tint for brand consistency
- **Keep layouts grid-based** — Maintain alignment to a 12-column grid or full-width blocks for predictability

### Don't
- **Avoid rounded corners** — Never use border-radius values other than `0px`; the design is explicitly angular
- **Don't use gradients** — Maintain solid color fills; no gradient overlays or transitions
- **Avoid unnecessary colors** — Stick to the core palette (`#09051C`, `#1D0245`, `#FF79C6`, `#00D9FF`, `#FFFFFF`, `#000000`)
- **Don't mix serif fonts** — All typography is monospace; never introduce serif or sans-serif typefaces
- **Avoid light backgrounds** — The design is dark-mode only; do not apply light surface colors
- **Don't use thick borders** — Borders should be `2px–4px` maximum; heavy strokes conflict with the minimal aesthetic
- **Avoid very large shadows** — Keep box-shadow blur radius under `48px` and spread under `4px`
- **Don't center content excessively** — Use left-aligned or grid-based layouts for readability; center only for hero sections

## 8. Responsive Behavior

### Breakpoints

| Name | Width | Key Changes |
|------|-------|-------------|
| Mobile | 320px–767px | Single column, full-width containers, reduced padding (`24px`), stack cards vertically, hide secondary navigation |
| Tablet | 768px–1023px | 2-column layouts, moderate padding (`32px`), reduce font sizes by 1–2px, collapse sidebars |
| Desktop | 1024px–1279px | 3-column grid, full padding (`40px`), standard font sizes, side-by-side card layouts |
| Large | 1280px+ | Max-width containers, hero sections use full-bleed backgrounds, 12-column grid, generous margins (`80px`) |

### Touch Targets
- **Minimum size:** `36px × 36px` for all interactive elements (buttons, links, input fields)
- **Recommended size:** `44px × 44px` for primary CTAs and frequently used controls
- **Spacing between targets:** Minimum `8px` between adjacent interactive elements
- **Link padding:** Outlined buttons should maintain `2px 10px` internal spacing for comfortable tap zones

### Collapsing Strategy
- **Containers:** Reduce max-width and padding as viewport shrinks; at mobile (< 768px), use full width with `24px` side padding
- **Navigation:** Convert horizontal navigation to hamburger menu on tablets (< 1024px); show full nav only on desktop
- **Code cards:** Stack code blocks vertically on mobile; allow horizontal scroll on desktop for long lines
- **Button groups:** Break into vertical stacks on mobile; arrange horizontally on tablet and above
- **Typography:** Maintain 15px base font size down to tablet; reduce to 13px on mobile to fit more content
- **Spacing:** Reduce margins and padding by 25% on mobile, 12% on tablet; use full scale on desktop

## 9. Agent Prompt Guide

### Quick Color Reference
- **Primary CTA Button:** Brand Magenta (`#FF79C6`) background, white text
- **Secondary CTA Button:** Cyan Teal (`#00D9FF`) border, transparent background, cyan text
- **Background (Primary):** Deep Purple Night (`#09051C`)
- **Background (Secondary):** Dark Violet (`#1D0245`)
- **Text (Primary):** Pure White (`#FFFFFF`)
- **Text (Secondary):** Light Purple (`#B88CC8`, inferred)
- **Text (Code):** Pure White (`#FFFFFF`) on dark background
- **Accent / Highlight:** Neon Magenta (`#FF79C6`)
- **Secondary Accent:** Cyan (`#00D9FF`)
- **Border / Frame:** Cyan Teal (`#00D9FF`) for dotted borders

### Iteration Guide

1. **All text uses monospace:** Default to `Roboto Mono Variable` for all typography; use `ui-monospace` only for code blocks. No serif or sans-serif fonts.

2. **Sharp corners everywhere:** Set all `border-radius` to `0px`. The design is explicitly angular; never round corners.

3. **Magenta for primary interactions:** Use `#FF79C6` for primary buttons, focus states, and highlighted elements. Hover state darkens to `#C449A0` (~20% darker).

4. **Cyan for secondary interactivity:** Use `#00D9FF` for outlined buttons, decorative borders, and secondary navigation; reserve magenta for primary actions.

5. **Dark backgrounds only:** Containers and surfaces use either `#09051C` (primary) or `#1D0245` (secondary). Never use light backgrounds; this is a dark-mode-only design.

6. **Subtle, magenta-tinted shadows:** Apply shadows only to elevated elements (cards, modals, focused inputs). Use `rgba(255, 121, 198, ...)` with opacity under 20%; keep blur radius under 48px.

7. **Spacing follows 8px grid:** Use multiples of 8px for all spacing (margins, padding, gaps). Common values: `12px`, `16px`, `24px`, `32px`, `40px`, `48px`, `80px`.

8. **Weight conveys hierarchy:** Use `400` for body text, `500` for emphasis, `700` for interactive/heading text. Rarely change font size; use weight instead.

9. **Minimum interactive size is 36px:** All buttons, links, and inputs must be at least `36px` tall or wide. Preferred is `44px` for frequently used controls.

10. **Focus and hover states are required:** Every interactive element must have a distinct `:hover` and `:focus` state using magenta highlight or opacity increase; provide tactile feedback.