---
name: Aura Travel
colors:
  surface: '#faf8ff'
  surface-dim: '#d2d9f4'
  surface-bright: '#faf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f3ff'
  surface-container: '#eaedff'
  surface-container-high: '#e2e7ff'
  surface-container-highest: '#dae2fd'
  on-surface: '#131b2e'
  on-surface-variant: '#414755'
  inverse-surface: '#283044'
  inverse-on-surface: '#eef0ff'
  outline: '#717786'
  outline-variant: '#c1c6d7'
  surface-tint: '#005bc1'
  primary: '#0058bc'
  on-primary: '#ffffff'
  primary-container: '#0070eb'
  on-primary-container: '#fefcff'
  inverse-primary: '#adc6ff'
  secondary: '#006a66'
  on-secondary: '#ffffff'
  secondary-container: '#61f5ed'
  on-secondary-container: '#006f6a'
  tertiary: '#9e3d00'
  on-tertiary: '#ffffff'
  tertiary-container: '#c64f00'
  on-tertiary-container: '#fffbff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d8e2ff'
  primary-fixed-dim: '#adc6ff'
  on-primary-fixed: '#001a41'
  on-primary-fixed-variant: '#004493'
  secondary-fixed: '#65f8f0'
  secondary-fixed-dim: '#3fdbd4'
  on-secondary-fixed: '#00201e'
  on-secondary-fixed-variant: '#00504d'
  tertiary-fixed: '#ffdbcc'
  tertiary-fixed-dim: '#ffb595'
  on-tertiary-fixed: '#351000'
  on-tertiary-fixed-variant: '#7c2e00'
  background: '#faf8ff'
  on-background: '#131b2e'
  surface-variant: '#dae2fd'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  base: 8px
  container-padding-mobile: 20px
  container-padding-desktop: 40px
  gutter: 16px
  section-gap: 48px
---

## Brand & Style

The design system focuses on a **Modern Minimalist** aesthetic tailored for an AI-powered travel assistant. The goal is to reduce the cognitive load of trip planning by providing an airy, spacious environment that feels both intelligent and inspiring. 

The visual narrative is built on "Clarity and Flow." We utilize high-contrast layouts where content is king, supported by a sophisticated digital atmosphere. The interface should feel like a premium concierge—professional yet welcoming. Key stylistic influences include:
- **Airy Minimalism:** Generous white space to separate complex AI-generated itineraries.
- **Glassmorphism:** Used strategically for overlays and navigation bars to maintain a sense of depth and context without cluttering the view.
- **Soft Geometry:** Extra-large corner radii to evoke a sense of safety and friendliness.

## Colors

The palette is centered around **"Deep Horizon Blue"** (#007AFF), representing trust and the vastness of travel. We complement this with a **"Voyager Teal"** (#00C2BB) for AI-driven highlights and success states.

- **Primary:** Deep Horizon Blue for main actions and branding.
- **Secondary:** Voyager Teal for AI insights and secondary interactions.
- **Neutral:** A spectrum of Slate Grays. #0F172A for primary headings to ensure high legibility against the crisp white background.
- **Background:** Pure white (#FFFFFF) is the standard to maintain the "airy" feel, with extremely light gray (#F8FAFC) used for subtle section grouping.

## Typography

This design system uses **Inter** across all levels to ensure a systematic, utilitarian, and modern feel. Since the primary language is **Russian**, Inter is selected for its excellent Cyrillic support and legibility at small sizes.

- **Headlines:** Use Bold (700) or SemiBold (600) weights with slight negative letter spacing to create a high-contrast, editorial look.
- **Body:** Use Regular (400) weight with generous line height (1.5x) to ensure long travel itineraries are easy to scan.
- **Labels:** Use Medium (500) or SemiBold (600) for UI controls, buttons, and metadata tags.

## Layout & Spacing

The layout philosophy follows a **Fluid Grid** with a strong emphasis on vertical rhythm. 

- **Mobile:** A 4-column grid with 20px side margins. Elements should mostly span the full width or use horizontal carousels for card lists.
- **Desktop:** A 12-column grid centered in a max-width container of 1280px. 
- **Spacing Logic:** All spacing is based on an 8px scale. Use 48px or 64px for vertical gaps between major sections to maintain the "airy" aesthetic. Components within cards should use 16px (gutter) for internal padding.

## Elevation & Depth

Hierarchy is achieved through a combination of **Tonal Layering** and **Glassmorphism**.

1.  **Level 0 (Base):** Pure white background.
2.  **Level 1 (Cards):** Very subtle 1px border (#E2E8F0) or a soft ambient shadow (0px 4px 20px rgba(0, 0, 0, 0.05)).
3.  **Level 2 (Glass Overlays):** Used for bottom navigation bars and floating headers. Style: Background blur (20px) with a semi-transparent white fill (80% opacity) and a thin white top-border to simulate a glass edge.
4.  **Level 3 (Modals/Popups):** High-diffused shadows with 10% opacity, ensuring the element "floats" significantly above the base layer.

## Shapes

The design system utilizes **large, soft radii** to create a modern and friendly atmosphere.

- **Small Components:** 12px (e.g., small buttons, input fields).
- **Standard Cards:** 24px (e.g., destination cards, itinerary items).
- **Large Containers:** 32px or 40px (e.g., bottom sheets, main image containers).
- **Interactive Elements:** Full-pill shapes for action buttons and chips to contrast against the rectangular grid.

## Components

- **Buttons:** 
    - *Primary:* Filled with Deep Horizon Blue, white text, 24px+ height, pill-shaped.
    - *Floating Action Button (FAB):* Always pill-shaped or circular, high-elevation shadow, used for "Ask AI" or "New Trip."
- **Cards:** White background, 24px corner radius, subtle 1px border. Images should have a 20px internal radius to create a "nested" look.
- **Input Fields:** Large (56px height), 12px corner radius, light gray background (#F1F5F9), transitions to a 2px primary blue border on focus.
- **Chips (Filter Tags):** Pill-shaped, light gray background, active state uses a subtle teal tint with teal text.
- **AI "Magic" Overlays:** Use a subtle glassmorphic effect with a very fine gradient border (Blue to Teal) to signify AI-generated content.
- **Lists:** Clean separation using whitespace rather than dividers wherever possible. If dividers are needed, use a 1px #F1F5F9 line.