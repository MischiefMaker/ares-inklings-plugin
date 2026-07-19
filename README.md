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
- **Chargen & approval integration** — Require secret and goal inklings before a character can be approved
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

### Chargen Integration

During character generation, players see a "Secrets & Goals" tab where they create
inkling entries for the types configured in `chargen_required_types` (typically secret 
and goal). The chargen form auto-installs with the plugin and requires no manual web 
portal setup—only the backend hook (Step 3 in Installation).

## Installation

### Step 1: Install Core Plugin (Automatic)

**From the MUSH, run:**

```
plugin/install https://github.com/MischiefMaker/ares-inklings-plugin
```

This automatically:
- Installs plugin code to `plugins/inklings/`
- Merges configuration into `game/config/inklings.yml`
- Installs web portal components to `ares-webportal/app/` (components and templates - styled entirely with Bootstrap 5, already loaded by `ares-webportal`, so there's no plugin stylesheet to import)

**Result:** MUSH commands and web portal components are ready. The Inklings tab will appear on character profiles once you complete the optional Step 2 below.

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

### Step 3: Configure Character Generation (Optional)

If you want players to create required Inklings during character generation:

**Backend Hook (Required if using chargen):**

The Chargen form fields auto-install with the plugin, but the backend integration requires a manual code merge:

1. Open `custom-install/custom_char_fields.snippet.rb` in this plugin
2. Open `plugins/profile/custom_char_fields.rb` in your **aresmush** folder (not ares-webportal)
3. Follow Steps 1, 3, 4, 5, and 6 in the snippet file and paste the code at the marked locations
   (Step 2 is shared with the profile tab's type picker - see Step 2b above; if you already did that, 
   just add the chargen-required-fields line to the same hash)
4. Save the file
5. Restart the game with `@restart`

**Web Portal Customization (Optional):**

The chargen form fields automatically appear during character generation. If you want to customize the form labels or placeholders:

1. Open `custom-install/chargen-custom.snippet.hbs` to see how to customize the form field labels and descriptions
2. Edit `ares-webportal/app/templates/components/chargen-custom.hbs` directly if you want to change the form
3. To add a tab label in the chargen step list, open `custom-install/chargen-custom-tabs.snippet.hbs` for instructions

**Important:** The snippet files include detailed instructions showing exactly where to make changes. Do not simply copy the entire snippet into your files.

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

If you followed any of the optional manual Steps 2 or 3 above, restart the web portal once:

```
website/deploy
```

**Note:** The chargen form fields auto-install with the plugin (Step 1), but the backend integration (Step 3's Backend Hook) requires a game restart with `@restart` for the custom_char_fields changes to take effect.

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

### Required Types for Chargen

Configure which inkling types are required before a character can be approved:

```yaml
chargen_required_types: [goal, secret]
```

Players will be prompted during chargen to create these types.

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

- **Requires manual chargen snippet merging** — Chargen integration requires copying snippet code into your game's shared chargen files, since other plugins may also extend chargen. This cannot be automated without risk of breaking other plugins.

- **Reference numbers (`seq`) aren't backfilled** — Threads created before this update won't have sequence numbers. If upgrading an existing game, you can run a migration to backfill them (ask a developer for help if needed).

- **Reset is permanent** — `+inkling/reset` deletes all inkling data across all characters. Linked jobs are preserved. Use only during development/testing. Confirmation uses a one-time token (5-minute expiry).

## License

Add your license of choice here before publishing.
