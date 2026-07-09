---
toc: Inklings
summary: Threaded plot communication between staff and players.
order: 1
---
# Inklings

Inklings are threaded plot communications between staff and players.
Every inkling can carry multiple messages back and forth, and player
activity is mirrored into a job on the INKLINGS board so staff always
have a single place to track what needs a response.

## Kinds

**Staff -> player:**

- `hint` - a nudge toward something worth investigating
- `vision` - something the character glimpses, dreams, or senses
- `nudge` - a gentle push toward a plot thread
- `hook` - an open invitation into a new thread

**Player -> staff:**

- `action` - an in-character plot action you're taking
- `research` - digging into something, in character or out
- `request` - an OOC ask related to a plot
- `update` - a status update on an ongoing thread
- `pitch` - a plot idea or scene you'd like to run
- `goal` - a character goal you want staff aware of

**Either direction:**

- `secret` - something staff wants to plant on a character, or something
  a player wants to share with staff privately

## Starting a thread

Staff (targets a player):

    +inkling/hint <char>=<text>
    +inkling/vision <char>=<text>
    +inkling/nudge <char>=<text>
    +inkling/hook <char>=<text>
    +inkling/secret <char>=<text>

Players (always about yourself, no target needed):

    +inkling/action <text>
    +inkling/research <text>
    +inkling/request <text>
    +inkling/update <text>
    +inkling/pitch <text>
    +inkling/goal <text>
    +inkling/secret <text>

Note: since staff secrets use `<char>=<text>`, your own secret text
shouldn't contain a literal `=`, or it'll be misread as a target line.

## Everyone

`+inklings` - View your own open threads.

`+inklings/closed` - View your own closed threads.

`+inklings/all` - View everything.

`+inkling <id>` - View a thread's full message history.

`+inkling/reply <id>=<text>` - Add a message to a thread you're part of.

`+inkling/close <id>` - Close a thread you're part of. Closes the linked
job too, if there is one.

`+inkling/delete <id>` - Delete a thread you're part of. If you're a
player, this notifies staff via a job (opening one if the thread didn't
already have one), since the content won't be recoverable afterward.

## Staff only

`+inkling/list <char>` - View every thread a character is involved in,
along with any linked job numbers and statuses.

Staff can also `+inkling/reply`, `+inkling/close`, `+inkling/delete`,
and `+inkling <id>` on any thread, not just ones they started.

## How this ties into jobs

Whenever a player starts a thread, replies to one, or deletes one,
Inklings notifies staff by creating or updating a job in the INKLINGS
category - so nothing a player does here gets missed. Replying to that
job (staff side) should update the inkling thread in turn, and closing
an inkling closes its linked job automatically.
