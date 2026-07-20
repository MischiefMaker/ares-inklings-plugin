---
title: Inklings
---

# Inklings

Inklings are a system for tracking character development, plot threads, and important notes about your character. They're private conversations between you and staff, or between you and other players in a shared thread.

> **Note:** Most inkling commands require an approved character. Before you're approved, `+inkling/goal` and `+inkling/secret` instead save draft text (the same thing the web chargen "Secret & Goal" tab does) - it becomes a real inkling automatically once your character is approved. After approval, those two commands work like any other inkling command.

> **Staff won't see your inkling until you submit it.** You can freely add updates, private notes, and rolls to build up a thread on your own time - none of that reaches staff by itself. When you're ready for staff input, run `+inkling/submit <id>`. That locks the thread and sends everything in it to staff as a single request. The thread stays locked (you can't add more) until a staff member makes a decision: they can approve it (ending the review), or send it back with feedback for you to revise and resubmit.

## Types of Inklings

**Your own:**
- **Initiative** - Something your character is actively doing that requires staff feedback — an action they're taking, something they're researching, or anything they're pursuing that touches the wider game world
- **Request** - A request for staff assistance or plot
- **Pitch** - A pitch for a scene, plot arc, or event you'd like to happen
- **Goal** - A long-term goal your character is working toward *(available during chargen)*
- **Secret** - An IC secret your character holds (shareable with other players) *(available during chargen)*
- **Progress** - A personal record of your character's development, important events, growth, discoveries, relationships, and ongoing history. Use this to maintain a chronicle of significant moments and changes.

**From staff:**
- **Hint** - A hint or guidance from staff about something
- **Vision** - An in-character vision or supernatural experience
- **Nudge** - A gentle nudge from staff to encourage RP in a certain direction
- **Hook** - A plot hook or opportunity from staff

## Commands

**`+inklings`** 
Show all your open inklings. Use `/closed` to see closed threads, or `/all` to see everything.

**`+inkling/types`**
List every available inkling type with a short description.

**`+inkling <id>`**
View a specific inkling thread and all messages in it. Mark it as read when you view it. Each message and roll appears as its own block with a permanent reference number (like `14.3`) for pointing back at it later.

**`+inkling/new`**
With no arguments, shows the oldest inkling you have unread updates on and marks it read - run it again to see the next one, like the bulletin board's `+bbnew`. Tells you when you're caught up.

**`+inkling/new <kind>=<title>/<text>`**
Create a new inkling with a title and opening text. For example: `+inkling/new goal=Learn to Sail/Work toward buying lessons this month.`

**`+inkling/share <id>=<character>,<character>`**
Share an inkling with one or more players, granting them read and reply access. Example: `+inkling/share 14=Bob,Alice`

**`+inkling/group <id>=<group>,<group>`**
Share an inkling with everyone in one or more existing groups. You can use a bare group value like `Navy` or an explicit `Group:Value` like `Faction:Navy`.

**`+inkling/advance <id>=<text>`**
Add a new update to the inkling thread. This does *not* notify staff by itself - use `+inkling/submit` when you're ready for them to see it.

**`+inkling/roll <id>=<roll command>`**
Attach a roll to the inkling thread. Example: `+inkling/roll 14=Firearms+Reflexes`

**`+inkling/private <id>=<text>`**
Add a private entry to any inkling thread. Private entries are visible only to you and staff — other participants in the thread cannot see them. Like `+inkling/advance`, this doesn't notify staff by itself.

**`+inkling/personal <id>=<text>`**
Add a personal note to any inkling thread. Personal notes are visible only to you, even staff can't see them. Use this for OOC thoughts, session notes, or reminders you want to keep with the thread.

**`+inkling/submit <id>`**
Lock the thread and send everything in it to staff as a single request. This is the only thing that actually gets a thread in front of staff - do this whenever you want a response. The thread stays locked until a staff member makes a decision via `+inkling/approve` (approved) or `+inkling/needschanges` (sent back for revisions). While locked, you can view it and read staff replies, but can't add new updates unless staff sends it back for changes.

**`+inkling/close <id>`**
Close an inkling thread (you can do this for your own threads).

**`+inkling/delete <id>`**
Request that an inkling thread be permanently deleted. This closes the thread and sends staff a job to review and approve the deletion - it does not delete the thread immediately.

**`+inkling/requestunlock <id>=<reason>`**
Request that staff reopen a completed inkling so you can make further edits. This sends a notification to staff with your reason but does NOT unlock the inkling - staff must approve the unlock with `+inkling/unlock` before you can edit again.

You can also manage your inklings through the character profile on the web portal. The **Inklings** tab lets you create titled inklings, expand threads to read the full conversation, share them with other characters, and add updates or rolls directly from the web.

## Tips

- **Don't forget to submit:** Building up a thread doesn't notify staff - run `+inkling/submit <id>` when you actually want a response
- **Be specific:** Include details about what you're working on or what you need
- **Check regularly:** Staff may reply to your requests with guidance or plot opportunities
- **Use the right type:** Choosing the appropriate inkling type helps staff prioritize
- **Privacy matters:** Mark sensitive rolls or information as private if you want only staff to see them
