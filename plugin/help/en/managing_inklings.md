---
toc: Managing the Game
summary: Managing inklings and player plot threads.
---

# Managing Inklings

Inklings are player-initiated threads for tracking character development, plot requests, and collaborative storytelling. Staff can create inklings for players, respond to player submissions, and manage the threads.

## Staff Commands

`+inkling/list <character>` - View all inklings for a specific character. Shows status, linked jobs, and message counts.

`+inkling/hint <character>=<title>/<text>` - Send a hint to a character (typically guidance or a nudge in a direction).

`+inkling/vision <character>=<title>/<text>` - Send a vision or supernatural experience to a character.

`+inkling/nudge <character>=<title>/<text>` - Send a gentle nudge to encourage RP in a certain direction.

`+inkling/hook <character>=<title>/<text>` - Send a plot hook or opportunity to a character.

`+inkling/secret <character>=<title>/<text>` - Create an IC secret inkling for a character (staff on behalf of player). A title is required.

`+inkling/new <kind>=<title>/<text>` - Create a new titled inkling for yourself. Staff can still use the targeted kind commands above when opening a thread for another character.

`+inkling/share <id>=<character>,<character>` - Grant one or more characters access to an inkling thread.

`+inkling/group <id>=<group>,<group>` - Grant access to all approved characters in one or more configured groups. Use a bare group value like `Navy` or an explicit `Group:Value` like `Faction:Navy`.

`+inkling/advance <id>=<text>` - Add a new visible update to an inkling thread. This mirrors the response to any linked job.

`+inkling/private <id>=<name>/<text>` - Add a private update for a specific participant in the thread. If no name is given, it defaults to the thread owner.

`+inkling/gm <id>=<text>` - Add a staff-only reference note. GM notes are never shown to players.

`+inkling/roll <id>=<roll command>` - Attach a roll to the inkling thread. Example: `+inkling/roll 14=Bob/Firearms+Reflexes`

`+inkling/submit <id>` - Players use this to lock a thread and send its full contents to a single staff job - see "Submission Workflow" below. Staff can also run it on a player's behalf.

`+inkling/close <id>` - Close an inkling thread and its linked job (if any).

`+inkling/delete <id>` - Staff: deletes an inkling thread immediately and permanently. Players: closes the thread and files a job requesting staff approve a permanent deletion, rather than deleting directly.

`+inkling/reset` - Permanently deletes every inkling thread, message, and roll for every character. Restricted to the `manage_game` permission (Coders/Admins). Must be entered twice within 60 seconds to confirm.

## How It Works

### Message & Roll References

Every message and roll in a thread gets a permanent reference number, `<inkling id>.<sequence>` (e.g. `14.3`), shown in the thread view for pointing back at a specific entry later.

### Shared With

The thread view includes a "Shared With" section listing non-staff characters and groups with access to the thread. Staff members are never listed, since they always have access.

### Submission Workflow

Players can freely build up a thread (updates, private notes, rolls) without notifying staff or creating a job - nothing reaches staff until the player runs `+inkling/submit <id>`. That locks the thread (blocking further player replies/rolls) and sends its *entire* current contents to a single job in the **INKLINGS** category, titled `[ACTION] <Player> submitted a <Kind> inkling for review.` A second round of submission after staff reply adds the updated full thread as a comment on the same job if it's still open, rather than creating a second one.

A staff reply via `+inkling/advance` or `+inkling/private` automatically unlocks the thread. Replying through the linked job instead of in-game also unlocks it once pulled into the thread. `+inkling/gm` notes do not unlock a thread, since they never reach the player.

### Deletion Requests

Players can no longer delete their own inkling outright. `+inkling/delete` on a player's own thread closes it and files a job titled `<Player> is requesting to delete inkling #<id>.` Approving the request means a staff member then carries out the actual deletion themselves.

### Private Rolls

Players and staff can add rolls (FS3 or custom) to roll-type inklings. Rolls can be marked private to hide them from other participants. Staff can attach NPC rolls with a custom free-text name, with no character record required.

### Luck Rerolls

Players can spend luck points to reroll their rolls directly from the inkling thread on the web portal.

### Web Portal

Staff can manage inklings from the character profile **Inklings** tab on the web portal, which provides:
- Expanded view of all threads
- Easy update/share interface
- Roll management
- Link to associated jobs

## Configuration

**Job Category:** Inklings are automatically placed in the `INKLINGS` job category. Create this category in-game with: `job/createcategory INKLINGS`

**Types:** Inkling types (hint, vision, goal, secret, etc.) are defined in `game/config/inklings.yml` under `types`, not hardcoded - add, remove, rename, or redescribe them there without touching code. Run `+inkling/types` in-game to see the current live listing.

**Bonus XP:** Optionally, a weekly (configurable) Cron job can award bonus XP to characters who've submitted a configured inkling type. Requires the FS3Skills plugin. Configure `inkling_type_xp`, `xp_amount`, and `award_cron` in `game/config/inklings.yml`.

**Permissions:** By default, staff are determined by the `Jobs.can_manage_jobs?` check. Customize this in `plugin/inklings.rb` in the `can_manage_inklings?` method. The `+inkling/reset` command uses a separate, narrower `manage_game` permission check.

## Tips for Staff

- **Respond promptly:** Once a player submits, quick responses encourage engagement - and unlock the thread so they can keep working
- **Use the right kind:** Hints, nudges, and hooks are different ways to communicate
- **Nothing arrives until they submit:** Players can work on a thread indefinitely without it becoming a job
- **Monitor privately:** Private rolls let players and staff discuss outcomes without spoiling others
- **Close resolved threads:** Keep the list clean by closing threads once plots are complete
- **Reset with care:** There is no undo for `+inkling/reset`.
