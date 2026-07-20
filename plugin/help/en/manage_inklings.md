---
title: Manage Inklings
---

> Permission Required: These commands require the Admin role or the permission: manage_jobs

# Manage Inklings

Inklings are player-initiated threads for tracking character development, plot requests, and collaborative storytelling. Use these commands to review submissions, provide feedback, and manage the approval workflow.

## Staff-Only Commands

**`+inkling/list <character>`**
View all inklings for a specific character. Shows status, linked jobs, and message counts.

**`+inkling/admin [/closed|/all]`** 
List every inkling in the game, for every character - not scoped to one character the way `+inkling/list` is. Each entry displays as two lines (title/status + owner/access details) with blank lines between entries for readability. Default shows open threads only. Use `/closed` to see closed threads, or `/all` to see every inkling (all statuses). Paginated, newest first. The web portal has an equivalent admin page (Inklings tab under Admin, once your game owner completes the optional setup in the plugin README) with the same list plus an Add Inkling form for creating an inkling on any character's behalf.

**`+inkling/hint <character>=<title>/<text>`**
Send a hint to a character (typically guidance or a nudge in a direction).

**`+inkling/vision <character>=<title>/<text>`**
Send a vision or supernatural experience to a character.

**`+inkling/nudge <character>=<title>/<text>`**
Send a gentle nudge to encourage RP in a certain direction.

**`+inkling/hook <character>=<title>/<text>`**
Send a plot hook or opportunity to a character.

**`+inkling/secret <character>=<title>/<text>`**
Share an IC secret with a character (staff creating a secret on a player's behalf). A title is required.

**`+inkling/personal <id>=<text>`**
Add a personal note to an inkling thread. Personal notes are visible only to the author, even other staff can't see them. Useful for staff-only observations or session notes.

**`+inkling/gm <id>=<text>`**
Add a staff-only reference note. GM notes are never shown to players.

**`+inkling/roll <id>=<roll command>`**
Attach a roll to the inkling thread. Example: `+inkling/roll 14=Bob/Firearms+Reflexes`

**`+inkling/submit <id>`**
Players use this to lock a thread and send its full contents to a single staff job - see "Submission & Approval Workflow" below. Staff can also run it (e.g. on a player's behalf).

**`+inkling/approve <id>[=<message>]`**
Approve a submitted inkling. Sets it to approved status, closes the linked job, and notifies the player. Optional message is added to thread history.

**`+inkling/needschanges <id>=<feedback>`**
Send an inkling back to the player for revisions. Feedback is added to thread history as a visible message, the inkling is unlocked for editing, and the player is notified.

**`+inkling/unlock <id>`**
Reopen a completed inkling for further editing. Sets it back to needs_changes status and unlocks the thread. Use when a player requests to make changes to a completed inkling.

**`+inkling/reward <id>=<reward_type>:<amount>`**
Grant a reward to the inkling's subject character. Examples: `+inkling/reward 14=xp:5` or `+inkling/reward 14=fs3_skill:Medicine:1`. Use `/all` flag to make the reward visible to all participants: `+inkling/reward 14/all=xp:5`. Rewards default to private (visible only to recipient + staff).

**`+inkling/close <id>`**
Close an inkling thread and its linked job (if any).

**`+inkling/delete <id>`**
Staff: deletes an inkling thread immediately and permanently. Players: no longer deletes directly - instead closes the thread and files a job asking staff to review and approve a permanent deletion. Approving the job means a staff member then runs `+inkling/delete` themselves to actually carry it out.

**`+inkling/reset`**
Permanently deletes every inkling thread, message, and roll for every character. Restricted to the `manage_game` permission (Coders/Admins only), not general Inklings staff. Must be entered twice within 60 seconds to confirm - the first entry just arms it and shows a warning.

## How It Works

## Shared Commands

The following commands work for both staff and players. See `help inklings` for full details:
- `+inkling/advance <id>=<text>` — Reply to a thread (visible to participants)
- `+inkling/private <id>=<name>/<text>` — Add a private message for specific participant (staff) or staff-only (players)
- `+inkling/roll <id>=<roll command>` — Attach a roll
- `+inkling/share <id>=<character>,<character>` — Grant access
- `+inkling/group <id>=<group>` — Grant group access
- `+inkling/close <id>` — Close a thread

## Submission & Approval Workflow

Players submit via `+inkling/submit <id>`, which locks the thread and sends its full contents to a job in the **INKLINGS** job category. Once submitted, staff can:

- **Reply via `+inkling/advance` or `+inkling/private`** for discussion (does NOT unlock the thread)
- **`+inkling/approve <id>`** to approve and close the review
- **`+inkling/needschanges <id>=<feedback>`** to send back for revisions (unlocks thread)

Replying through the job itself has the same effect as in-game commands but does not change lock/approval status.

## Tips for Staff

- **Respond promptly:** Quick responses encourage engagement
- **Use the right kind:** Hints, nudges, and hooks are different ways to communicate
- **Close resolved threads:** Keep the list clean
- **Reset with care:** `+inkling/reset` wipes every thread for every character. There is no undo.
