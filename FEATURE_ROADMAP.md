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
