---
toc: Managing the Game
summary: Managing inklings and player plot threads.
---

# Managing Inklings

Inklings are player-initiated threads for tracking character development, plot requests, and collaborative storytelling. Staff can create inklings for players, respond to player submissions, and manage the threads.

## Staff Commands

`+inkling/list <character>` - View all inklings for a specific character. Shows status, linked jobs, and message counts.

`+inkling/hint <character>=<text>` - Send a hint to a character (typically guidance or a nudge in a direction).

`+inkling/vision <character>=<text>` - Send a vision or supernatural experience to a character.

`+inkling/nudge <character>=<text>` - Send a gentle nudge to encourage RP in a certain direction.

`+inkling/hook <character>=<text>` - Send a plot hook or opportunity to a character.

`+inkling/secret <character>=<text>` - Create an IC secret inkling for a character (staff on behalf of player).

`+inkling/new <kind>=<title>/<text>` - Create a new titled inkling for yourself. Staff can still use the targeted kind commands above when opening a thread for another character.

`+inkling/share <id>=<character>,<character>` - Grant one or more characters access to an inkling thread.

`+inkling/group <id>=<group>,<group>` - Grant access to all approved characters in one or more configured groups. Use a bare group value like `Navy` or an explicit `Group:Value` like `Faction:Navy`.

`+inkling/advance <id>=<text>` - Add a new visible update to an inkling thread. This mirrors the response to any linked job.

`+inkling/private <id>=<name>/<text>` - Add a private update for a specific participant in the thread. If no name is given, it defaults to the thread owner.

`+inkling/gm <id>=<text>` - Add a staff-only reference note. GM notes are never shown to players.

`+inkling/roll <id>=<roll command>` - Attach a roll to the inkling thread. Example: `+inkling/roll 14=Bob/Firearms+Reflexes`

`+inkling/close <id>` - Close an inkling thread and its linked job (if any).

`+inkling/delete <id>` - Delete an inkling thread. Players may delete their own threads; staff may delete any thread.

## How It Works

### Automatic Job Creation

When a player creates or advances an inkling, a job is automatically created in the **INKLINGS** job category. This notifies staff through the normal job system. If staff respond via the inkling, that response mirrors back to the job.

### Private Rolls

Players and staff can add rolls (FS3 or custom) to roll-type inklings. Rolls can be marked private to hide them from other participants.

### Luck Rerolls

Players can spend luck points to reroll their rolls directly from the inkling thread on the web portal.

### Web Portal

Staff can manage inklings from the character profile **Inklings** tab on the web portal, which provides:
- Expanded view of all threads
- Easy update/share interface
- Roll management
- Link to associated jobs

## Configuration

**Job Category:** Inklings are automatically placed in the `INKLINGS` job category. Create this category in-game with: `job/category create INKLINGS`

**Permissions:** By default, staff are determined by `is_staff?` Check. Customize this in `plugins/inklings/inklings.rb` in the `can_manage_inklings?` method.

## Tips for Staff

- **Respond promptly:** Players use inklings to share ideas and requests—quick responses encourage engagement
- **Use the right kind:** Hints, nudges, and hooks are different ways to communicate
- **Link to jobs:** The automatic job creation keeps everything in one place
- **Monitor privately:** Private rolls let players and staff discuss outcomes without spoiling others
- **Close resolved threads:** Keep the list clean by closing threads once plots are complete