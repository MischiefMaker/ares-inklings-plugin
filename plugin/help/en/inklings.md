---
toc: Inklings
summary: Tracking character development and plot threads with inklings.
---

# Inklings

Inklings are a system for tracking character development, plot threads, and important notes about your character. They're private conversations between you and staff, or between you and other players in a shared thread.

> **Note:** Most inkling commands require an approved character. During chargen, the same exception applies to goal and secret inklings.

> **Staff won't see your inkling until you submit it.** You can freely add updates, private notes, and rolls to build up a thread on your own time - none of that reaches staff by itself. When you're ready for staff input, run `+inkling/submit <id>`. That locks the thread and sends everything in it to staff as a single request. The thread stays locked until a staff member makes a decision: they can approve it (ending the review), or send it back with feedback for you to revise and resubmit.

## Types of Inklings

**Your own:**
- **Initiative** - Something your character is actively doing that requires staff feedback — an action they're taking, something they're researching, or anything they're pursuing that touches the wider game world
- **Request** - A request for staff assistance or plot
- **Pitch** - A pitch for a scene, plot arc, or event you'd like to happen
- **Goal** - A long-term goal your character is working toward
- **Secret** - An IC secret your character holds (shareable with other players)
- **Progress** - A personal record of your character's development, important events, growth, discoveries, relationships, and ongoing history

**From staff:**
- **Hint** - A hint or guidance from staff about something
- **Vision** - An in-character vision or supernatural experience
- **Nudge** - A gentle nudge from staff to encourage RP in a certain direction
- **Hook** - A plot hook or opportunity from staff

## Commands

`+inklings` - Show all your open inklings. Use `/closed` to see closed threads, or `/all` to see everything.

`+inkling/types` - List every available inkling type with a short description, pulled live from the game's configuration.

`+inkling <id>` - View a specific inkling thread and all messages in it. Mark it as read when you view it. Each message and roll is shown as its own block with a permanent reference number (like `14.3`) you can use to refer back to it later.

`+inkling/new <kind>=<title>/<text>` - Create a new inkling with a title and opening text. Example: `+inkling/new goal=Learn to Sail/Work toward buying lessons this month.`

`+inkling/share <id>=<character>,<character>` - Share an inkling with one or more characters by name. Example: `+inkling/share 14=Bob,Alice`

`+inkling/group <id>=<group>,<group>` - Share an inkling with everyone in one or more existing groups. You can use a bare group value like `Navy` or an explicit `Group:Value` like `Faction:Navy`.

`+inkling/advance <id>=<text>` - Add a new update to the inkling thread. Does *not* notify staff by itself - use `+inkling/submit` when you're ready for them to see it.

`+inkling/roll <id>=<roll command>` - Attach a roll to the inkling thread. Example: `+inkling/roll 14=Firearms+Reflexes`

`+inkling/private <id>=<text>` - Add a private entry visible only to you and staff. Also doesn't notify staff by itself.

`+inkling/submit <id>` - Lock the thread and send everything in it to staff as a single request. This is the only thing that gets a thread in front of staff. Stays locked until staff makes a decision via `+inkling/approve` (approved) or `+inkling/needschanges` (sent back for revisions). While locked, you can view it and read staff replies, but can't add new updates unless staff sends it back for changes.

`+inkling/close <id>` - Close an inkling thread (you can do this for your own threads).

`+inkling/delete <id>` - Request that an inkling thread be permanently deleted. This closes the thread and sends staff a job to review and approve the deletion.

## Web Portal

You can also manage your inklings through the character profile on the web portal. The **Inklings** tab lets you create titled inklings, expand threads to read the full conversation, share them with other characters, and add updates or rolls directly from the web.

## Tips

- **Don't forget to submit:** Building up a thread doesn't notify staff - use `+inkling/submit` when you actually want a response
- **Be specific:** Include details about what you're working on or what you need
- **Check regularly:** Staff may reply to your requests with guidance or plot opportunities
- **Use the right type:** Choosing the appropriate inkling type helps staff prioritize
- **Privacy matters:** Mark sensitive rolls or information as private if you want only staff to see them
