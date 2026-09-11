# Provider Tracking Controls and Codex Metric

**Goal:** Let users manage Claude and Codex tracking independently, choose the Codex metric shown by the existing menu-bar text, and identify providers with official logos in the popover.

**Approach:** Persist provider preferences with `AppStorage`, enforce enabled providers in `UsageStore`, and extend the existing menu-bar metric model for Codex's 5-hour window. Keep the topbar layout unchanged and bundle official provider marks as local app resources.

**Design:** Both provider tracking settings default to enabled so current behavior is preserved. Disabling a provider stops its refreshes, removes its cached live state from the popover and topbar, and ignores any result already in flight. The popover footer always exposes both provider toggles so either provider can be enabled again, which triggers an immediate refresh for that provider. Each popover provider heading shows a small official logo followed by Claude or Codex. Claude keeps its current metric picker; Codex gains a picker limited to Session and Weekly. The chosen Codex metric changes only the value selected by the existing topbar text and does not alter its layout.

**Out of scope:** A separate settings window, changes to the topbar's visual structure, new dependencies, and generalized preferences infrastructure for hypothetical providers.

**Success criteria:** Disabling either provider never changes the other provider's refresh schedule or data. Disabled providers are not polled or displayed. Re-enabling a provider refreshes it. Both settings and metric selections survive relaunches. Codex can show either its 5-hour or weekly usage in the existing topbar text. The popover uses recognizable official Claude and ChatGPT marks. Existing defaults remain unchanged, tests and builds pass, and the popover is visually checked in light and dark appearance.
