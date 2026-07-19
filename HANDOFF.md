# Inklings Plugin - Cloud Instance Handoff Guide

**Date:** 2026-07-19  
**Previous Session:** Local development and debugging  
**Status:** Feature-complete; ready for final testing, tweaking, and release  

---

## Overview

The Inklings plugin is a complete character development system for AresMUSH featuring:
- Threaded inkling management (goals, secrets, plot hooks, character progression)
- MUSH commands and web portal integration
- Approval workflow, rewards, and auditing
- AresMUSH plugin installer support via `.ares-manifest.yml`

**Current state:** All major features implemented and working. The web portal UI is functional with proper theme colors and styling. Ready for final testing, UX tweaks, and release.

---

## What's Working

### Backend (MUSH Commands)
- ✅ Full inkling CRUD operations
- ✅ Threading/replies with visibility (public/private/staff/personal)
- ✅ FS3 skill rolls attached to inklings
- ✅ Approval workflow (submitted → approved/needs changes)
- ✅ Rewards system (XP, FS3 skills)
- ✅ Job integration (create jobs from inklings)
- ✅ Sharing with other characters
- ✅ Tagging system

### Web Portal
- ✅ Inkling list with filtering (open/closed/all)
- ✅ Detail modal showing full thread, rolls, messages
- ✅ Create new inkling form (type picker, title, description)
- ✅ Reply/personal entry textarea with checkboxes
- ✅ FS3 roll button (performs actual FS3 rolls via `FS3Skills.one_shot_roll`)
- ✅ Roll display with metadata
- ✅ Staff-only controls (approve, request changes, grant reward)
- ✅ Share dialog
- ✅ Tag management
- ✅ Theme-aware CSS (uses AresMUSH color variables)
- ✅ Chargen integration (required inkling types as custom fields)
- ✅ Profile tab showing all inklings

### Installation
- ✅ Manifest-based installer support (`.ares-manifest.yml`)
- ✅ Custom char fields snippet (auto-install friendly)
- ✅ Profile custom snippet (manual copy-paste)
- ✅ Chargen integration snippet
- ✅ All file paths and folder names correct

---

## Outstanding / Areas for Tweaking

### Fixed Issues

**Chargen Tab Loading** — The chargen form fields now auto-install with the plugin as Ember components (`chargen-custom.js` and `chargen-custom.hbs`), following the same pattern as the profile tab components. Previously, the chargen tab required manual file creation via error-prone snippets. Users still need to paste the backend `custom_char_fields.rb` hook to wire up the data, but the form rendering is now automatic and compatible with any `chargen_required_types` configuration without modification.

### Known Limitations
1. **Reroll with Luck** - Temporarily disabled (was causing complexity). Can be re-implemented if needed using `character_luck_reroll` API.
2. **Rolls don't capture skill modifier context** - Roll result shows success level but not the specific skill rolled. Consider if more detail needed.
3. **Personal entries** - Still new feature; behavior on transfers/roster changes may need review.

### Potential UX Tweaks
- Roll display could show more detail (skill name, dice rolled, successes breakdown)
- "Reroll with Luck" button could be re-enabled if user requests it
- Personal entry confirmation dialog could be more prominent
- Timestamp formatting could be customized per-game
- Tag input could have autocomplete or suggestions

### Testing Areas
- Test on installation with minimal setup
- Verify chargen required fields work with different config values
- Test permission edge cases (viewer not on inkling, deleted characters, etc.)
- Test with various FS3 skills (attributes, action skills, background skills, languages)
- Verify theme color responsiveness with custom color schemes
- Test on mobile viewport
- Test browser cache/session issues

---

## Architecture & Key Decisions

### Web Portal Pattern
**Decision:** Follows AresMUSH conventions (Route + Controller + Template, component-based Ember)

**Key files:**
- `webportal/routes/inklings.js` - Route that loads character inklings
- `webportal/controllers/inklings.js` - Controller for route state
- `webportal/components/inklings-tab.js` - List component (manages selectedInklingId, showDetailModal)
- `webportal/components/inkling-detail-modal.js` - Detail modal (manages loadDetail, all mutations)
- `webportal/templates/components/inklings-tab.hbs` - List template
- `webportal/templates/components/inkling-detail-modal.hbs` - Modal template
- `webportal/styles/inklings.scss` - Theme-aware styling

**Why:** Separates concerns cleanly. List component only manages selection; modal manages its own state and detail loading. Avoids `{{#with}}` block helper on async data (was causing "resolvedDefinition is null" crashes).

### FS3 Rolling
**Decision:** Backend performs rolls using `FS3Skills.one_shot_roll(char, roll_params)`

**Key files:**
- `plugin/public/rolls_api.rb` - RollsApi.add_roll() - creates InklingRoll with FS3 result
- `plugin/web/inklings_add_roll_web_handler.rb` - Web handler for add_roll
- `webportal/components/inkling-detail-modal.js` - addRoll action calls handler with roll_spec

**Why:** Matches AresMUSH pattern (addSceneRoll, addJobRoll). Frontend passes skill name, backend does actual FS3 rolling and logging. Ensures FS3 system stays authoritative.

### Custom Character Fields Hook
**Decision:** Uses standard Ares `custom_char_fields.rb` hook with chargen-required inkling types

**Key files:**
- `custom-install/custom_char_fields.snippet.rb` - Snippet user integrates into their custom_char_fields.rb
- Adds chargen-required types as profile fields
- Embeds `char.custom.inkling_types` on character payload (avoids separate API fetch for type picker)

**Why:** No custom solution needed; Ares hook handles everything. Chargen fields show on profile page. Type list embedded on payload means web portal component never needs separate request.

### CSS & Theming
**Decision:** Uses AresMUSH CSS theme variables (`--primary-color`, `--text-color`, etc.)

**Key files:**
- `webportal/styles/inklings.scss` - All colors use var(--primary-color), var(--text-color), etc.
- Fallbacks to reasonable defaults if variables missing
- Uses Bootstrap semantic classes (`.text-secondary`, `.text-dark`) for text that works on light/dark backgrounds

**Why:** Respects game's skin. Works with any color scheme without modification.

---

## How to Test

### Prerequisites
- AresMUSH installation running
- Plugin installed via manifest or manual install
- Web portal running and accessible
- At least one test character (approved)

### Quick Start
1. Log in as test character
2. Go to profile → Inklings tab
3. Create new inkling (type: Goal, title: "Test Goal")
4. Add reply/personal entry
5. Add FS3 roll (should see actual FS3 result)
6. Verify modal shows all data correctly
7. Filter open/closed/all
8. Create inkling, submit for review as staff

### Test Checklist
- [ ] Create/edit/delete inkling
- [ ] Reply and personal entry both work
- [ ] FS3 roll returns actual result (not error)
- [ ] Roll shows success level correctly
- [ ] Share inkling with another character
- [ ] Add/remove tags
- [ ] Staff approve/request changes/grant reward
- [ ] All text is readable (check theme colors)
- [ ] Modal closes/opens correctly
- [ ] Chargen shows required inkling fields
- [ ] Profile shows all inkling types
- [ ] Test with small viewport (mobile)

---

## Common Issues & Fixes

### "Something went wrong when the website talked to the game"
**Cause:** Backend exception (usually in rolling or custom field code)
**Fix:** Check server logs for full error. Likely issues:
- `FS3Skills.one_shot_roll` called with wrong parameters
- `RollParams` initialized incorrectly
- Character not approved (`viewer.is_approved?` check failed)

### Modal not opening / "resolvedDefinition is null" crash
**Cause:** Template using `{{#with}}` block helper on async data
**Status:** Fixed. Current template avoids `{{#with}}` and references `this.detail.*` directly
**Fix:** Never use `{{#with}}` with data populated by async API calls

### Type picker empty in "New Inkling" form
**Cause:** `char.custom.inkling_types` not set on character payload
**Fix:** Verify custom_char_fields.rb snippet adds inkling_types to `get_fields_for_viewing` return hash

### CSS not showing up on install
**Cause:** CSS file not copied from plugin to webportal; webportal not rebuilt
**Fix:**
```bash
cp /path/to/plugin/webportal/styles/inklings.scss /path/to/ares-webportal/app/styles/
cd /path/to/ares-webportal && npm run build
```

### Roll button appears but doesn't add roll
**Cause:** Wrong FS3 API being called or handler not registered
**Status:** Fixed (was using `character_luck_reroll` for initial rolls; now uses `FS3Skills.one_shot_roll`)
**Fix:** Verify `RollsApi.add_roll` is calling `FS3Skills.one_shot_roll(viewer, roll_params)`

---

## Development Workflow

### Git Workflow (from CLAUDE.md)
```bash
# After completing code:
git status                    # Review changes
git add <files>              # Stage
git commit -m "message"      # Commit with description
git push origin main         # Push immediately
```

**Important:** Always push after commit. Don't leave work only in local checkout.

### Commit Message Format
- Start with action: "Fix:", "Add:", "Refactor:", "Docs:", "Style:"
- Describe what changed and why
- Include `Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>` line

### File Structure
```
ares-inklings-plugin/
├── README.md                          # User install guide
├── CLAUDE.md                          # Standing instructions
├── HANDOFF.md                         # This file
├── ARES_PLUGIN_DEVELOPMENT_GUIDE.md   # Lessons learned (for future plugins)
├── .ares-manifest.yml                 # Plugin installer manifest
├── plugin/                            # Backend MUSH code
│   ├── commands/                      # MUSH commands
│   ├── events/                        # Event handlers
│   ├── models/                        # Data models
│   ├── public/                        # Public APIs
│   ├── web/                           # Web handlers
│   └── inklings.rb                    # Main module
├── webportal/                         # Frontend Ember code
│   ├── components/                    # Ember components
│   ├── routes/                        # Routes
│   ├── controllers/                   # Controllers
│   ├── styles/                        # SCSS files
│   └── templates/                     # HBS templates
└── custom-install/                    # User snippets
    ├── custom_char_fields.snippet.rb
    ├── profile-custom.snippet.hbs
    └── chargen-custom.snippet.*
```

### Key Files for Modifications

**If tweaking FS3 rolling:**
- `plugin/public/rolls_api.rb` - RollsApi.add_roll method
- `webportal/components/inkling-detail-modal.js` - addRoll action

**If tweaking UI/styling:**
- `webportal/templates/components/inkling-detail-modal.hbs` - Modal layout
- `webportal/templates/components/inklings-tab.hbs` - List layout
- `webportal/styles/inklings.scss` - Theme colors

**If tweaking chargen integration:**
- `custom-install/custom_char_fields.snippet.rb` - User snippet
- `webportal/components/inkling-chargen.hbs` - Chargen template (if exists)

**If tweaking chargen or profile display:**
- `custom-install/chargen-custom.snippet.*` - Chargen form fields
- `custom-install/profile-custom.snippet.hbs` - Profile tab template

---

## Standing Instructions

### After Any Changes
1. Commit with message following format above
2. Push to origin main immediately
3. If modifying `ARES_PLUGIN_DEVELOPMENT_GUIDE.md`, add lessons learned from debugging
4. Test the feature in browser before considering it done

### Before Finishing a Session
1. Run `git status` to confirm no uncommitted work
2. All changes should be pushed to origin
3. If waiting for testing/installation, document expected next steps

### File Path Caution
- **Always double-check file paths** when creating snippets (user correction history shows this is error-prone)
- Prefer absolute paths over "ares folder" vs "aresmush folder" distinctions
- Test snippet paths against real Ares installations before committing

---

## Documentation to Update

These files should be kept current as you make changes:

- **README.md** - Install steps, features list, known limitations
- **ARES_PLUGIN_DEVELOPMENT_GUIDE.md** - Add any new lessons learned
- **Inline code comments** - Only for non-obvious WHY logic, not WHAT logic
- **Commit messages** - Should capture intent and decision

---

## Next Steps for Cloud Instance

1. **Install fresh** - Clone repo, install to test AresMUSH instance
2. **Smoke test** - Walk through test checklist above
3. **Identify tweaks** - Document any UX improvements or bugs found
4. **Polish** - Fix bugs, improve UX based on testing
5. **Final docs** - Update README with any changes to install/usage
6. **Release** - Final push and any release documentation

---

## Questions or Blockers?

- If you find bugs, create a minimal test case in a comment
- If you find the need for new features, document in README under "Future Enhancements"
- If you can't replicate an issue, note the environment (Ares version, Ruby version, browser)
- Commit early and often; push after each commit

---

**End of Handoff Guide**

Good luck with testing and final tweaks!
