# Inklings

Inklings is a plugin for [AresMUSH](https://aresmush.com) that provides players and staff with a modern, structured system for tracking character development, goals, secrets, plot hooks, and personal notes in threaded conversations — separate from but integrated with the job/ticket system.

## Status

This plugin is complete and fully supported.

## Overview

### For Players

Inklings gives you a private space to develop your character through threaded conversations:

- **Create personal threads** about your character's goals, secrets, motivations, plot hooks, or anything else you want to track
- **Build threads freely** — No one sees your work until you submit it for staff review with `+inkling/submit`
- **Request feedback** — Submit to staff and they can approve, request changes, or provide feedback
- **Track character development** — Keep a permanent record of your character's arc and evolution
- **Attach dice rolls** — Include FS3 rolls, custom rolls, or NPC rolls directly in your threads
- **Share selectively** — Grant access to specific characters or groups who should see your thread
- **Reroll with luck** — If your character has luck points, use them to reroll attached dice from the web portal

### For Staff

Inklings gives staff a structured approval workflow for character development submissions:

- **Review submissions** — Players submit complete threads as single jobs; all context is in one place
- **Approve or request changes** — Either close the thread as approved or send it back for revisions
- **Provide feedback** — Add private notes that only specific players see, or staff-only GM notes
- **Grant rewards** — Award XP, FS3 skills, or custom rewards tied to character development milestones
- **Track development** — View which players are actively developing their characters and what they're working on
- **Enforce requirements** — Configure which inkling types are required before character approval (e.g., secret + goal)

### Key Features

- **Fully configurable inkling types** — Define your own types (secret, goal, hint, vision, progress, etc.) in configuration; no code changes needed
- **Structured approval workflow** — Draft → Submitted → Approved/Needs Changes
- **Permanent reference numbers** — Every message and roll gets a permanent `<inkling_id>.<sequence>` number (e.g., `14.3`) for easy reference
- **Message visibility tiers** — Public (all participants), private (selected participants + staff), or GM-only notes
- **Web portal integration** — Full Ember component for browsing, managing, and rolling in-game without command syntax
- **Optional bonus XP** — Automatically award XP to characters who create designated inkling types (e.g., Progress entries), via scheduled Cron job
- **Optional chargen integration** — During character creation, players can optionally fill in Secret and Goal drafts that convert to real Inklings on approval; can be disabled if not needed
- **Structured rewards** — Award XP, FS3 skills, or custom rewards with configurable visibility

## Web Portal

The plugin provides web portal integration for both character profiles and chargen:

### Profile Tab

The Inklings tab provides a modern web interface for:

- **Browsing your threads** — Full thread view with all messages, rolls, and sharing information
- **Creating and editing** — Start new threads or add messages without command syntax
- **Rolling dice** — Attach FS3, custom, or NPC rolls directly; reroll with luck points if available
- **Sharing threads** — Grant access to specific characters or demographics groups
- **Submitting for review** — Submit your complete thread to staff with one action
- **Staff reviews** — View submitted threads, approve/request changes, add GM notes, and grant rewards

The profile tab uses two components: `inklings-tab` (the list and "New Inkling" form) and 
`inkling-detail-modal` (the full thread view, opened by clicking a row). Both install 
automatically via `plugin/install` and are styled entirely with Bootstrap 5.

"New Inkling" only appears when the viewer could actually create something — it's hidden
for an unapproved character viewing their own tab, since they have no real Inklings to
create yet (see Chargen Integration below). Staff viewing an unapproved character's tab
still see it, since staff can always create any type.

If that character has unsubmitted chargen draft text (from the "Secret & Goal" chargen
tab or the MUSH `+inkling/secret` / `+inkling/goal` commands - see Chargen Integration),
staff see it in a highlighted "Chargen Drafts (not yet approved)" section at the top of
the tab, clearly marked with a **DRAFT** badge and separate from the real inkling list -
it isn't a real Inkling yet and isn't clickable. It disappears automatically once the
character is approved and the draft becomes a real Inkling.

### Chargen Integration

During character generation, players see a **"Secret & Goal"** tab with two sections —
one for a Secret, one for a Goal — each with a title and a description. What they enter
is saved as a draft on the character, survives navigating away and coming back, and can
be edited later from their profile. When the character is approved, each filled-in draft
is converted into a real Inkling automatically.

Players who prefer the MUSH client over the web portal can fill in the same draft with
`+inkling/secret <title>/<text>` and `+inkling/goal <title>/<text>` — before approval,
these two commands write to the same draft used by the web form (not a real Inkling).
After approval they behave like any other inkling command. Unapproved characters have
no real Inklings for these two types at any point; only the draft exists until
approval converts it.

**Chargen is completely optional.** It can be turned on or off with a single setting,
`chargen_enabled` (defaults to on, see [Configuration](#chargen-integration-on-off));
when off, the feature goes completely dormant and nothing else in the plugin is affected.
Staff viewing an unapproved player's profile see chargen drafts in a distinct section
marked "DRAFT", and in the MUSH `+inkling/list`, drafts appear before the list of real
Inklings. The drafts disappear automatically once the character is approved.

**Important:** Chargen is limited to these **two fixed types (secret and goal)** — it is not
a general, configurable list. **If you enable chargen, you MUST define both `secret` and
`goal` type definitions in your `inklings.yml` configuration.** If either type is missing,
character approval will fail. If you do not need chargen, disable it with `chargen_enabled: false`
rather than deleting one of these types.

Unlike the profile components, the chargen form does **not** fully auto-install: its
markup lives in shared web-portal files that other plugins may also extend, so it is
provided as manual snippets (Step 3 in Installation).

## Installation

### Step 1: Install Core Plugin (Automatic)

**From the MUSH, run:**

```
plugin/install https://github.com/MischiefMaker/ares-inklings-plugin
```

This automatically:
- Installs plugin code to `plugins/inklings/`
- Merges configuration into `game/config/inklings.yml`
- Installs web portal components to `ares-webportal/app/` (components, templates, and `webportal/styles/inklings.scss`, copied to `ares-webportal/app/styles/`)

**Result:** MUSH commands and web portal components are ready. The Inklings tab will appear on character profiles once you complete the optional Step 2 below - **including Step 2c**, or the tab will render with broken layout (bullets, unstyled hover, missing spacing) despite Bootstrap 5 handling most of the styling.

**If `plugin/install` is unavailable**, manually copy the `plugin/` folder to `plugins/inklings/` and copy `game/config/inklings.yml` to `game/config/`, then restart with `@restart`.

### Step 2: Enable Web Portal Features (Optional, Manual)

If you want players to see the Inklings tab on character profiles:

**Step 2a: Add the Inklings tab to the profile page**

1. Open `ares-webportal/app/components/profile-custom-tabs.hbs`
   - Paste the `<li>` from `custom-install/profile-custom-tabs.snippet.hbs` into this file

2. Open `ares-webportal/app/components/profile-custom.hbs`
   - Paste the `<div class="tab-pane">` from `custom-install/profile-custom.snippet.hbs` into this file

**Step 2b: Add the type-picker backend hook (Required)**

The Inklings tab's "New Inkling" type dropdown is populated from the character
payload (`char.custom.inkling_types`), not fetched separately by the component -
this matches how other Ares plugins expose profile-tab reference data (e.g. the
RPG plugin's `char.rpg.sheet`). Without this step the dropdown will be empty:

1. Open `custom-install/custom_char_fields.snippet.rb` in this plugin
2. Open `plugins/profile/custom_char_fields.rb` in your **aresmush** folder (not ares-webportal)
3. Follow **Step 2** in the snippet file (the `get_fields_for_viewing` addition) and paste it at the marked location
4. Save the file

(If you're also setting up chargen in Step 3 below, you'll come back to this same
file for its other steps - Step 2 here can be done now regardless.)

**Step 2c: Import the Inklings stylesheet (Required)**

`plugin/install` copies `inklings.scss` into `ares-webportal/app/styles/`, but a
copied `.scss` file is inert until something actually imports it - Ember's Sass
build only compiles files that `app.scss` references. Without this step, the
Inklings tab and modal will render using Bootstrap defaults only: no bullet
removal on the list, no hover highlight, no header/metadata layout, no
scrollable message pane.

1. Open `ares-webportal/app/styles/app.scss`
2. Add this line alongside the other `@use` lines already at the top of the file:
   ```scss
   @use "inklings";
   ```
3. Rebuild/restart the web portal (see "Restart the Web Portal" below)

### Step 3: Configure Character Generation (Optional)

If you want players to create Secret and Goal Inklings as part of character generation,
complete both the backend and web portal integration steps below. Chargen is disabled by
default (or enable it explicitly with `chargen_enabled: true` in `game/config/inklings.yml`);
if you don't need this feature, skip this entire step.

**Step 3a: Backend Hook (Required if using chargen):**

1. Open `custom-install/custom_char_fields.snippet.rb` in this plugin
2. Open `plugins/profile/custom_char_fields.rb` in your **aresmush** folder (not ares-webportal)
3. Follow Steps 1, 3, 4, 5, and 6 in the snippet file and paste the code at the marked locations
   (Step 2 is shared with the profile tab's type picker - see Step 2b above; if you already did that, 
   just add the chargen-required-fields line to the same hash)
4. Save the file
5. Restart the game with `@restart`

**Step 3b: Web Portal Form (Required if using chargen):**

The chargen form requires manual integration into your game's webportal chargen files:

1. Open `custom-install/chargen-custom-tabs.snippet.hbs` and paste into `ares-webportal/app/components/chargen-custom-tabs.hbs` at the marked location
2. Open `custom-install/chargen-custom.snippet.hbs` and paste into `ares-webportal/app/components/chargen-custom.hbs` at the marked location
3. Open `custom-install/chargen-custom.snippet.js` and paste into `ares-webportal/app/components/chargen-custom.js` at the marked location

**Important:** These are game-owned customization files, not plugin files:
- `chargen-custom-tabs.hbs`, `chargen-custom.hbs`, and `chargen-custom.js` already exist in your webportal
- Each snippet file includes detailed instructions showing exactly where to paste its code
- Do not overwrite the entire file — only add the specific lines at the marked locations
- Do not simply append to the end of files — follow the location comments in each snippet

### Step 4: Post-Installation Setup

**In-game:**

```
job/createcategory INKLINGS
job/categoryroles INKLINGS=<staff roles that should see inkling jobs>
```

**Verify permissions:**

Confirm that your Coder role has the `manage_game` permission (used by the `+inkling/reset` command). See [Using Permissions in Code](https://aresmush.com/tutorials/manage/roles.html#using-permissions-in-code) if you need to add it.

(Note: The Inklings tab on the character profile was added in Step 3 above if you followed those instructions.)

### Restart the Web Portal

After completing any manual Steps 2 or 3 above, restart the web portal:

```
website/deploy
```

**Note:** If you completed Step 3 (chargen integration), the game must also be restarted with `@restart` for the backend custom_char_fields changes to take effect.

## Configuration

Edit `game/config/inklings.yml` to customize the plugin. Key settings:

### Inkling Types

Define what types of Inklings your players can create. Each type has a category (player, staff, or shared), a display name, and optional description:

```yaml
types:
  goal: { category: player, name: Goal, description: "Long-term character goal or ambition" }
  secret: { category: player, name: Secret, description: "Character secret or hidden motivation" }
  hint: { category: staff, name: Hint, description: "Plot hook for staff to use" }
  vision: { category: staff, name: Vision, description: "Staff-created vision or prophecy" }
```

- **player** — Players can create these
- **staff** — Only staff can create these
- **shared** — Both can create these

### Chargen Integration (Optional, On/Off)

Chargen is completely optional and is turned on or off with a single boolean. It defaults to on if the setting is omitted:

```yaml
chargen_enabled: true   # set to false to disable the chargen Secret & Goal feature
```

**Requirements for chargen:**

If `chargen_enabled: true`, **you must have both `secret` and `goal` types defined** in your
`types:` list. If either is missing, character approval will fail when trying to convert
the draft to a real Inkling. There is no workaround; the types must exist.

**To disable chargen**, simply set `chargen_enabled: false`. When disabled, the feature
goes fully dormant: no chargen tab, no draft fields, no approval requirement, and the
profile/chargen custom fields return nothing. The rest of the plugin (commands, staff
threads, rewards, the profile Inklings browser) is unaffected.

The set of chargen types is intentionally **not** configurable — the web form and the
character draft fields are built specifically for secret and goal. This keeps the design
simple and prevents configuration errors. If you need different chargen behavior, disable
chargen and let players create those Inklings normally after approval.

### Job Category

The job category Inklings uses for submitted threads:

```yaml
job_category: INKLINGS
```

### Bonus XP (Optional)

Configure optional periodic XP awards for characters who create certain inkling types:

```yaml
inkling_type_xp: progress
xp_amount: 1
award_cron:
  day_of_week: [Sat]
  hour: [21]
  minute: [0]
```

Set `award_cron: {}` to disable this feature.

## Commands

### Player Commands

| Command | Purpose |
|---|---|
| `+inklings` | List your open Inklings (`/closed` flag for closed, `/all` for both) |
| `+inkling/types` | Show available inkling types with descriptions |
| `+inkling <id>` | View a thread |
| `+inkling/new <type>=<title>/<text>` | Create a new inkling |
| `+inkling/advance <id>=<text>` | Add a public message |
| `+inkling/private <id>=<text>` | Add a message visible to specific participants + staff |
| `+inkling/roll <id>=<roll>` | Attach a dice roll |
| `+inkling/submit <id>` | Submit to staff for review (locks the thread) |
| `+inkling/share <id>=<char>,<char>` | Grant access to specific characters |
| `+inkling/group <id>=<group>` | Grant access to a demographics group |
| `+inkling/close <id>` | Close the thread |
| `+inkling/delete <id>` | Request staff approval to delete (closes thread and creates staff job) |
| `+inkling/requestunlock <id>=<reason>` | Request staff to reopen a completed inkling |

### Staff Commands

| Command | Purpose |
|---|---|
| `+inkling/hint <char>=<title>/<text>` | Create a staff-only plot hint for a character |
| `+inkling/vision <char>=<title>/<text>` | Create a staff vision for a character |
| `+inkling/gm <id>=<text>` | Add a staff-only GM note to a thread |
| `+inkling/advance <id>=<text>` | Reply to a thread (visible to participants) |
| `+inkling/private <id>=<name>/<text>` | Add a private message to a specific participant |
| `+inkling/approve <id>` | Approve a submitted inkling and close the job |
| `+inkling/needschanges <id>=<feedback>` | Send back for revisions |
| `+inkling/unlock <id>` | Reopen a completed inkling for further editing |
| `+inkling/reward <id>=<type>:<amount>` | Award XP, FS3 skills, or custom rewards (e.g., `xp:5` or `fs3_skill:Occult:1`) — XP is applied automatically; FS3 skills must be applied manually |
| `+inkling/list <char>` | List all of a character's threads |
| `+inkling/reset` | Wipe the entire system (confirmation required; use only during testing/development) |

See `help inklings` and `help managing inklings` in-game for full command details.

## How the Approval Workflow Works

1. **Draft** — Player creates an inkling and builds it freely. Staff cannot see it. Player can add messages, rolls, and share access anytime.

2. **Submitted** — Player runs `+inkling/submit` to lock the thread and send its full contents to staff as a single job. Thread is now read-only for the player.

3. **Under Review** — Staff can:
   - Reply via `+inkling/advance` or `+inkling/private` for discussion
   - Add GM notes via `+inkling/gm`
   - Approve via `+inkling/approve` to close the job and mark as approved
   - Request changes via `+inkling/needschanges` to unlock the thread for revisions

4. **If Sent Back for Changes** — Thread unlocks, player can edit and resubmit, repeating the review cycle

5. **If Approved** — Thread remains locked (review complete), linked job closes

Staff can award rewards during or after review.

## Known Limitations

- **Locks block building, not management** — A locked thread blocks `+inkling/advance`, `+inkling/private`, and `+inkling/roll`, but players can still share, close, or request deletion. This allows players to request staff to close/delete a submitted thread without waiting for approval.

- **Resubmission repeats all content** — When a player resubmits after revisions, the entire thread is sent again, not just the new content. The job's comment history will include repeated messages.

- **NPC rolls don't need a character sheet** — You can attach rolls for NPCs without creating character records, using just a name.

- **Bonus XP is "approved characters" only** — The optional XP award system doesn't exclude staff PCs, assuming staff characters deserve XP for roleplay too.

- **FS3 skill rewards require manual application** — When granting FS3 skill rewards via `+inkling/reward`, the plugin records the reward but does not apply it automatically. Staff must apply it manually using `+skill/level` or your game's FS3 skill system. The amount specified (e.g., `fs3_skill:Occult:1`) is the number of dots to add, not the new total.

- **Luck point rerolls require `char.luck`** — If your game doesn't track luck points on the Character model, the web portal's reroll button won't work (the rest of rolls work fine).

- **FS3 rolling is optional** — `+inkling/roll` reports rolling unavailable if FS3Skills isn't installed; other features work normally without it.

- **Chargen requires both secret and goal types** — If you enable chargen (`chargen_enabled: true`), you must have both `secret` and `goal` type definitions in `types:`. If either is missing when a character is approved, approval will fail. Disable chargen with `chargen_enabled: false` if you don't need this feature, rather than deleting one of these type definitions.

- **Requires manual chargen snippet merging** — Chargen integration requires copying snippet code into your game's shared chargen files, since other plugins may also extend chargen. This cannot be automated without risk of breaking other plugins.

- **Reference numbers (`seq`) aren't backfilled** — Threads created before this update won't have sequence numbers. If upgrading an existing game, you can run a migration to backfill them (ask a developer for help if needed).

- **Reset is permanent** — `+inkling/reset` deletes all inkling data across all characters. Linked jobs are preserved. Use only during development/testing. Confirmation uses a one-time token (5-minute expiry).

## License

Add your license of choice here before publishing.
