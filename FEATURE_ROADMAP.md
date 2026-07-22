# Inklings Plugin — Feature Roadmap

Planned enhancements for future releases. Organized by phase and release.

---

## Next Feature Release

### Web Portal Enhancements

**CSS Classes for End-User Customization**
- Add unique, semantic CSS classes to all key web elements
- Use namespaced pattern: `inkling-thread-list`, `inkling-thread-row`, `inkling-detail-modal`, etc.
- Allows game admins to theme the plugin UI via custom CSS without modifying code
- Reference: ARES_PLUGIN_DEVELOPMENT_GUIDE.md section "CSS Classes for End-User Customization"

**Type Picker Help — ? Icon Beside Add Inkling Type Dropdown**
- Add a clickable `?` button/icon beside the type dropdown in the "Add Inkling" form
- Clicking it pops up a modal or inline help displaying:
  - All available inkling types
  - Description for each type (from `game/config/inklings.yml` config)
  - Example use cases (optional, can be added to descriptions in config)
- Accessible to both profile tab (per-character) and admin page (system-wide)
- Provides in-context help without requiring players to memorize or look up commands

**Link Scenes to Inklings**
- New command: `+inkling/link-scene <inkling_id>=<scene_id>/<summary>`
- Players and staff can link related Scenes to an Inkling
- Creates a clickable link in the thread that jumps directly to the Scene
- Summary field (required) describes the relationship or relevance (e.g., "opening scene," "climax," "flashback")
- Links display in both MUSH `+inkling <id>` output and web detail view
- Web equivalent: button/form in Inkling detail modal to add scene links
- Requires Scenes plugin to be installed; degrades gracefully if absent
- Staff can remove scene links with: `+inkling/unlink-scene <inkling_id>=<scene_id>`

**Clone Inkling to Multiple Players**
- New command: `+inkling/clone <inkling_id>=<player1>,<player2>,<player3>`
- Creates a fresh copy of the inkling for each listed player as the owner
- Each clone is independent: separate threads, separate approvals, separate rewards
- Useful for staff creating a shared prompt/challenge that multiple players develop independently
- Example: staff creates a "first meeting" inkling, clones it to 3 players, each develops their character's unique perspective on the meeting
- Web UI: button in detail view (staff only) to open clone dialog with character picker

**Separate Rewards Per Player**
- Allow granting rewards to different participants in a multi-player inkling
- Current system awards to the owner only
- New capability: staff can specify which participant(s) receive a reward via `+inkling/reward <inkling_id>=<player>:<reward_type>:<amount>`
- Web equivalent: reward modal shows participant picker, option to award to one or multiple
- Enables collaborative inklings to properly credit each participant's contribution

**Tags Management on Web**
- Current: tags can only be added/removed via MUSH commands (`+inkling/tag`, `+inkling/untag`)
- Add tag UI to web detail view:
  - Show existing tags as badges
  - Input field or tag picker to add new tags
  - Remove button/X on each tag badge
- Players and staff can manage tags without MUSH client
- Improves discoverability and organization on the web portal

**Admin Commands on Web**
- Extend web portal admin actions to include:
  - `+inkling/reward` — award XP, FS3 skills, or custom rewards
  - `+inkling/approve` — approve submitted threads
  - `+inkling/needschanges` — send back for revisions
  - `+inkling/unlock` — reopen completed threads
  - `+inkling/delete` — delete threads (staff only)
  - `+inkling/gm` — add GM notes
- Web UI: action buttons in detail view (staff only) with appropriate forms/modals
- Provides parity with MUSH command set; staff don't need command line for common actions
- Keep destructive actions (`delete`, `reset`) on MUSH only or behind confirmation dialogs

**Admin Visibility: Submitted Status Indicator and Filter**
- Add visual indicator (e.g., `*` or flag icon) on web admin list and `+inkling/admin` MUSH output for inklings awaiting staff response
- Extend admin list view/command with status filter options: `open`, `closed`, `submitted`, `all`
- Web: dropdown or button group to filter by status (default shows all open + submitted)
- MUSH: `+inkling/admin submitted` shows only submitted inklings awaiting review
- Highlights workload for staff and makes it easy to focus on pending reviews
- Integrates with existing admin list views without redesign

**Inspirations — Optional Submission Currency**
- Optional currency system ("Inspirations") to gatekeep and encourage quality submissions
- **Accrual**: players earn Inspirations automatically at a configurable rate (e.g., 1/week, 5/month) via Cron job
- **Extensibility**: other game systems (RP rewards, achievements, staff grants) can award Inspirations via generic `grant_inspiration` method
- **Cost**: submitting an inkling costs a configurable amount per type (e.g., pitch = 1, plot = 4, goal = 2)
- **Refund**: denials (`+inkling/needschanges`) or explicit rejections refund the spent Inspirations to the player
- **Configuration** (in `game/config/inklings.yml`):
  ```yaml
  inspiration_enabled: false              # Enable/disable (default: off)
  inspiration_accrual_amount: 1           # Points earned per cycle
  inspiration_accrual_period:             # Cron format (e.g., weekly, monthly)
    day_of_week: [Sat]
    hour: [0]
    minute: [0]
  inspiration_submit_costs:               # Cost per inkling type
    goal: 1
    pitch: 2
    plot: 4
    # ... other types as defined in inklings.yml types:
  ```
- **Use Case**: staff on high-volume games can gatekeep submissions without rejecting them outright, while encouraging thoughtful work (players choose which threads are worth the resource cost)
- **Web UI**:
  - Display current Inspiration balance in profile/portal
  - Show cost before submitting ("This will cost 2 Inspirations")
  - Warn if player doesn't have enough (suggest pending accrual)
  - Optional: show Inspiration accrual date/countdown
- **MUSH Commands**:
  - `+inspiration` / `+inspiration/balance` — check current balance and next accrual date
  - `+inkling/submit <id>` — deducts cost if enabled (existing command, enhanced)
  - Staff: `+inkling/grant-inspiration <player>=<amount>` — manually award Inspirations
- **Default**: disabled (0/off) so existing games are unaffected

**In-Game Text Editor for Inkling Messages**
- Web: Add edit button to Inkling detail view for inline text editing
- MUSH: Add `+inkling/edit <id>` command that emulates BG/Edit pattern, pulling text into MUD's built-in editor window
- Allows multi-line editing both on web portal and for MUSH-only clients
- Useful for quick edits without switching interfaces
- Should support editing both public messages (`+inkling/advance`) and private messages
- Related: verify if BG plugin's text-editor integration is reusable or if pattern needs reimplementation

**Inkling Details in App Review**
- Extend `app/review <name>` command to display character's inkling secret and goal
- Show full secret and goal text (title + description) inline in app/review output
- Allows staff to see inkling chargen data without switching to web portal
- Integrates with existing chargen approval workflow
- Improves staff efficiency during character review process

### Architecture / Internal

**Audit Component Arguments**
- Review all shared component invocations in `custom-install/` snippets
- Ensure all arguments match component implementations
- Prevents bugs like the "Main Character blank box" issue from Lesson 19 (ARES_PLUGIN_DEVELOPMENT_GUIDE.md)

---

## Future Releases (Backlog)

### Player Quality-of-Life

**Thread Search / Filter Enhancement**
- Extend current `+inkling/search` command to support status filtering
- Example: `+inkling/search submitted` finds only submitted threads
- Web equivalent: add status filter UI to the Inklings tab list

**Inkling Templates / Presets**
- Allow players to save thread templates (title structure, sections, etc.)
- Speeds up creating similar types of inklings
- Configurable per-type or per-character

**Tag Navigation and Discovery**
- Display tags as clickable links when viewing an Inkling (web and MUSH)
- Clicking a tag opens a modal/list of all Inklings with that tag (respects visibility/permissions)
- Results use standard Inkling summary/index format
- Selecting an Inkling from list opens detail modal
- Reuse existing search and modal components where practical
- MUSH command: `+inkling/bytag <tag>` returns index of visible Inklings with tag
- Both interfaces share same canonical tag lookup logic and normalization rules (case-insensitive, trimmed)
- Improves discoverability and navigation across web and MUSH

### Staff / Admin

**Bulk Actions on Inklings List**
- Select multiple threads from admin page or MUSH list
- Bulk approve, close, or reassign participants
- Reduces repetitive admin work on high-volume games

**Audit Trail / Activity Log**
- Track changes to inklings (approvals, participant additions, status changes)
- Staff can view who did what and when
- Helps resolve disputes or track plugin usage

### Reporting / Analytics

**Staff Dashboard Stats**
- Total inklings created this month/week
- Average review time (submitted → approved)
- Most common inkling type
- Player engagement metrics
- Helps staff understand game development activity

**Per-Player Development Report**
- Report showing character's inkling activity (count, types, dates, avg. review time)
- Accessible from character profile or admin area
- Useful for evaluating player engagement and activity patterns

### Integration & Interop

**Chargen Enhancement: MUSH Stage UI Improvements**
- Current MUSH chargen stage exists but UX is command-line only
- Consider adding visual cues or prompts to make it more discoverable
- Or enhance web chargen form to show a "also available via MUSH" note

**Archive Old / Closed Inklings**
- Long-running games accumulate hundreds of closed threads
- Implement soft-delete or archive mechanism
- Keeps active lists fast, preserves history for auditing
- Separate "archive" view for staff if needed

---

## Design Notes

- **Always prioritize player parity**: if a feature ships on web, ensure MUSH equivalent or document why not
- **Config over hardcoding**: new UI elements should respect game configuration (inkling types, permissions, etc.)
- **Accessibility**: all new UI elements should be keyboard-navigable and screen-reader friendly
- **Performance**: additions to admin/staff views (dashboards, bulk actions, audit trails) should paginate/lazy-load if the inkling count is large

---

## How to Use This Document

- **For next release planning**: check "Next Feature Release" section
- **For UI/UX decisions**: see "Design Notes" section
- **For long-term vision**: see "Future Releases (Backlog)"
- **When proposing a feature**: add it to the appropriate section with clear rationale
- **After implementing a feature**: move it to a "Completed" section (or remove from roadmap once released)
