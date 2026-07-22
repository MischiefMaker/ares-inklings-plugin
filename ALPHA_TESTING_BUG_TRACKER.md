# Alpha Testing — Bug Tracker

## Introduction

This document tracks all issues discovered during alpha testing of the Inklings plugin, across every round of testing. It replaces the separate `BUGS_v1.md` / `BUGS_v2.md` documents, which are now folded in below as Round 1 and Round 2.

The project is feature frozen during alpha testing. Items here represent defects, missing MUSH/web parity, or incomplete implementations that should be resolved before release. Enhancements and new functionality belong in `FEATURE_ROADMAP.md`, not here.

When practical, implementations should:

* Reuse existing service-layer logic rather than duplicating behavior.
* Maintain parity between MUSH and web interfaces.
* Hide unavailable actions rather than presenting nonfunctional controls.
* Continue enforcing all permissions server-side.
* Follow existing AresMUSH conventions.
* Where both MUSH and web perform the same workflow, ensure they call the same canonical implementation.

### Status key

* **Fixed** — code changed, confirmed working on the live server.
* **Fixed (unconfirmed)** — code changed, not yet re-verified live.
* **Verified correct (no fix needed)** — cross-referenced against source and found already correct; not reimplemented. A live-server symptom matching one of these most likely reflects a deployment lag (`plugin/install` not re-run, or MUSH/web-portal not restarted) rather than a code defect.
* **Open** — not yet addressed.

New bugs found during ongoing alpha testing should be appended to the current round (or a new round, once the current one closes out) with a status of **Open**, then updated in place as they're triaged and fixed.

---

## Round 1 (v1)

Issues discovered during functional testing of the Inklings plugin prior to the v1 release.

### Bug 001 — Offline Notifications

**Status: Fixed**

New Inklings should generate offline notifications visible in the web Notifications tab using the same AresMUSH notification infrastructure as Jobs.

### Bug 002 — Hidden Actions for Unapproved Players

**Status: Fixed**

Unapproved players currently see Add Reply and Add Roll even though those actions cannot be used. Hide unavailable actions and continue enforcing permissions server-side.

### Bug 003 — Personal vs Private Replies

**Status: Fixed**

Personal and Private are mutually exclusive visibility states. Selecting one should deselect the other, with server-side validation preventing invalid combinations.

### Bug 004 — Require Inkling Titles

**Status: Fixed**

Require a non-blank title when creating Inklings from both Chargen and the standard Add Inkling workflow.

### Bug 005 — Chargen Secret/Goal Review

**Status: Fixed**

Players need a documented way to review the complete contents of chargen Secrets and Goals before submission. Prefer displaying the full text in the web chargen draft review.

### Bug 006 — Roll Results Missing from Web Modal

**Status: Fixed**

Rolls appear in `inkling #` on the MUSH but are missing from the web Inkling modal.

### Bug 007 — Shared Web Inkling Modal

**Status: Fixed**

The profile and admin pages currently expose different Inkling functionality.

Refactor the web interface so both pages use the same Inkling modal, with controls shown or hidden based on permissions and Inkling state.

Includes:

* Shared modal implementation.
* View/Add/Remove tags.
* Close.
* Delete.
* Unlock.
* Approve.
* Needs Changes.
* Private reply to one participant.
* Proper permission precedence (Unlock instead of Request Unlock, Delete instead of Request Delete, etc.).

For review:

* One Reply interface.
* Radio buttons:
   * Approved
   * Needs Changes
* Selecting Needs Changes requires explanatory text before Reply may be submitted.

### Bug 008 — Missing New Inkling Button

**Status: Fixed**

Approved players should have a New Inkling button on their profile page.

The button should appear only when the current viewer is eligible to create an Inkling.

### Bug 009 — Search Layout

**Status: Fixed**

Reduce unnecessary whitespace around the search controls.

* Remove the extra bottom padding.
* Place the Search button beside the search field.
* Maintain responsive layout.

### Bug 010 — Tag Visibility

**Status: Fixed**

Tags already exist but are inconsistently displayed.

**Web:** Extend the existing admin modal implementation to the profile modal.

* Display tags beside Owner/Access.
* Smaller font.
* Comma-separated.
* Allow Add/Remove Tag for authorized users.
* Structure the markup so clickable tags can be added later without major refactoring.

**MUSH:** Display tags in the full `inkling #` view.

### Bug 011 — inkling/submit Doesn't Create Review Job

**Status: Fixed**

Submitting an Inkling should:

* Create a standard AresMUSH review job.
* Associate the job with the Inkling.
* Notify staff.
* Prevent duplicate jobs.
* Handle failures gracefully.

### Bug 012 — Missing MUSH Private Roll Command

**Status: Fixed**

The web supports private Inkling rolls but there is no equivalent MUSH command.

Add a command (or equivalent naming):

```
inkling/rollprivate <id>=<roll>
```

using the same visibility, permissions, storage, and roll services as the web implementation.

### Round 1 deferred features

The following items were intentionally left out of the Round 1 bug list and belong in `FEATURE_ROADMAP.md` instead:

* Clickable tags on the web.
* Tag search modal.
* `inklings/bytag`.

---

## Round 2 (v2)

Defects discovered during the second round of alpha testing, after Round 1 fixes were deployed.

### Bug 001 — Admin `inklings/list` Missing Shared Inklings

**Status: Fixed**

The admin `inklings/list` command did not include Inklings that had been shared with the viewed character, even though those same Inklings appeared correctly on the character's web profile.

Resolution: aligned the MUSH command with the web profile via the shared `Inklings.accessible_inklings_for` canonical retrieval logic (owned + shared + group-matched).

### Bug 002 — Display Inkling Owner in Web Modal

**Status: Fixed (unconfirmed)**

The web modal displayed Shared With, but not the Inkling's owner.

Resolution: added an always-visible Owner line immediately above Shared With in the modal's metadata section.

### Bug 003 — New Inkling Web Notifications Still Missing

**Status: Fixed**

Receiving a new Inkling did not generate a web notification. Unlike MUSH messages, web notifications should exist regardless of whether the player is currently online.

Verified correct against source (mirrors the Jobs/Achievements `Login.notify` pattern) - no code change was needed. Confirmed working live after redeploy.

### Bug 004 — Clarify Player Mode Messaging

**Status: Fixed (unconfirmed)**

The prior warning implied every Inkling should eventually be submitted.

Resolution: reworded to "This Inkling is currently in player mode. Use the Submit button (or `+inkling/submit` on the MUSH) if this Inkling requires a staff response," and reviewed other submission-related messages for the same assumption.

### Bug 005 — Submission Still Doesn't Create Linked Job

**Status: Verified correct (no fix needed)**

Submitting from either web or `inkling/submit` appeared not to create a linked review job.

Verified correct against source (`Inklings.submit_inkling` creates the job, links it, notifies staff, and now returns an error if job creation fails) - no code change was needed.

### Bug 006 — Staff Cannot Approve or Request Changes from the Web

**Status: Verified correct (no fix needed)**

There appeared to be no web interface for staff review.

Verified correct against source and against the Round 2 Bug 007 unified review UI (approve/needs-changes radio buttons, required explanatory text for Needs Changes, same review service as MUSH) - no additional code change was needed beyond Bug 007's work.

### Bug 007 — `inkling/approve` Does Not Unlock the Inkling

**Status: Fixed (unconfirmed)**

Approving an Inkling left it locked.

Resolution: `approve_inkling` now unlocks the Inkling (`locked: "false"`) on approval, restoring normal player interaction. This reflects the clarified workflow model: approval signs off on the most recent round, not the Inkling as a whole - `+inkling/close` is the actual "nothing more to do" signal, allowing an ongoing back-and-forth between player and staff.

---

## Round 3 (v3)

Defects discovered during the third round of alpha testing. Closed out as of this round - Round 4 starts a fresh Bug 001.

### Bug 001 — Private and Personal Checkboxes Render Incorrectly

**Status: Fixed (unconfirmed)**

The Private and Personal Entry checkboxes in the web reply form rendered stretched, with incorrect dimensions and poor label alignment.

Root cause: the Round 1 Bug 007 refactor that made Private/Personal mutually exclusive switched these two checkboxes from Ember's `{{input}}` helper to raw `<input>` tags (to attach an `onclick` handler). The structurally-identical roll-private checkbox a few lines above, which was never reported broken, still uses `{{input}}` - the strongest signal that the helper (which auto-adds an `ember-checkbox` class the theme likely keys off of) is what the raw tags were missing.

Resolution: reverted both checkboxes to the `{{input}}` helper, using its `change=` closure-action hook to keep the existing mutual-exclusivity logic (`toggleReplyPrivate`/`toggleReplyPersonal`) instead of the raw `onclick` attribute. Also added an explicit `.form-check-input { width: 1em; height: 1em; flex-shrink: 0; }` rule scoped to `.inklings-tab` in `inklings.scss` as a defensive backstop against this class of regression recurring.

### Bug 002 — `inkling/search` Not Recognized

**Status: Fixed (unconfirmed)**

`+inkling/search <text>` returned "Command ... is not recognized" even though `InklingSearchCmd` existed, was fully implemented, and was documented in the help file.

Root cause: `InklingSearchCmd` was written but its switch was never added to `Inklings.get_cmd_handler`'s dispatch chain - the command class existed but nothing routed to it.

Resolution: added `elsif cmd.switch_is?("search"); return InklingSearchCmd` to the dispatcher.

### Bug 003 — Web Submit for Review Regressed

**Status: Fixed (unconfirmed)**

The web Submit for Review button stopped working; confirmed as a regression (previously worked).

### Bug 004 — MUSH Submission Fails While Notifying Staff

**Status: Fixed (unconfirmed)**

`inkling/submit` failed with a generic "Could not notify staff of this submission" error.

**Bugs 003 and 004 share one root cause**, per this round's instruction to refactor shared causes rather than patch symptoms: both the web Submit button and `+inkling/submit` route through the same `Inklings.submit_inkling` → `ensure_job` → `Jobs.create_job` path. `Jobs.create_job` validates its `category` argument against the game's actually-configured job categories and returns an error if it doesn't match (confirmed against AresMUSH core source) - and a prior "Release polish" commit (`e37b00f`) silently changed the plugin's default `job_category` from `"INKLINGS"` to `"Plots"`. A server that had already created the old `INKLINGS` category (per the plugin's own old setup instructions) but never separately ran `job/createcategory Plots` would have every submission fail category validation from that point on - explaining both the web regression and the MUSH failure with the same generic, unhelpful error message on both sides.

Resolution:

* `ensure_job` now returns `{ job:, error: }` instead of just a job-or-nil, so its one real caller (`submit_inkling`) can propagate the *actual* reason (e.g. "Invalid job category Plots. Valid options are: ...") instead of a generic message. The other two fire-and-forget call sites (delete-request flows) were unaffected since they already ignored the return value.
* `submit_inkling`'s error message now includes that real reason in parentheses, surfaced automatically on both MUSH (`InklingSubmitCmd` already forwards `result[:error]` via `client.emit_failure`) and web.
* The web `submitInkling` action now shows the returned error via the existing `flashMessages` service (matching the pattern already used elsewhere in this component) instead of silently doing nothing on failure - the missing piece that made the button look "broken" rather than just failing quietly.
* Server-side logging (`Global.logger.error`) now includes the submitter's name alongside the inkling ID for faster diagnosis.
* Added `plugin/spec/submit_inkling_spec.rb` as the requested regression coverage: pins both the success path (job linked, thread locked, submission marker left) and the failure path (real error reason surfaced, thread left unlocked/unsubmitted with no partial state, failure logged).

This does not by itself guarantee `job/createcategory Plots` has been run on any given live server - that remains a documented one-time setup step (see README's Job Category section) - but a misconfigured category (or any other `Jobs.create_job` failure) is no longer a silent, undiagnosable dead end on either interface.

---

## Round 4 (v4)

Defects discovered during the fourth round of alpha testing. Closed out as of this round - Round 5 starts a fresh Bug 001.

### Bug 001 — Outdated Help Reference in `inkling/list` Error Message

**Status: Fixed (unconfirmed)**

`+inkling/list` with an invalid format returned "See `help inkling/list`" - a topic that doesn't exist. The plugin consolidates player docs into `help inklings` and staff docs into `help manage_inklings`.

Audited the whole plugin: 21 of 25 command classes relied on the bare `required_args` check, whose generic framework failure message points at a nonexistent per-switch topic (`help inkling/<switch>`) - only `InklingStartCmd` and `InklingCreateCmd` had already worked around this (from an earlier round), by omitting `required_args` entirely and adding an explicit `check_valid_format` that calls `t('dispatcher.invalid_syntax', :cmd => 'inklings')` instead. Applied that same established pattern to all 21 remaining commands, routing each to the correct real topic - `manage_inklings` for the 6 staff-only commands (`approve`, `gm`, `list`, `needschanges`, `reward`, `unlock`), `inklings` for the other 15. Also fixed `InklingCommentCmd`, which had both `required_args` *and* its own better custom message - the generic one was winning for blank input since `required_args` is checked first; removed `required_args` there too. Fixed a second bare `dispatcher.invalid_syntax` call (no `:cmd` at all) in `InklingPrivateCmd`.

### Bug 002 — Incorrect Default Job Category

**Status: Fixed (unconfirmed)**

The default `job_category` was `"Plots"` (title case); AresMUSH's real default category is `"PLOT"` (upper-case), and the lookup is an exact, case-sensitive match - `Jobs.create_job` rejects anything that doesn't match exactly.

Changed the default in `Inklings.job_category`, `game/config/inklings.yml`'s shipped sample, and every README reference to `PLOT`. Did **not** add any runtime uppercasing/transformation of the configured value - an admin's exact configuration is always respected as-is. Added an explicit note to the README and to `game/config/inklings.yml`'s own comments telling upgraders not to blindly re-copy the sample value over an already-customized config (config isn't reliably re-merged - see Round 3's Lesson 26). The diagnostic-on-failure work from Round 3 Bug 004 already covers "log a clear diagnostic warning when the category can't be found." Added Lesson 27 to the dev guide.

### Bug 003 — Admin Review Buttons Still Missing on Web Modal

**Status: Fixed (unconfirmed)**

Approve/Needs Changes were reported missing specifically on the admin page, "despite the previous implementation attempt." Audited the full rendering pipeline (permissions reaching the client, status serialization, component identity, template presence, action wiring, server-side handlers) rather than re-guessing at a targeted fix.

**Root cause, and it wasn't admin-specific:** `InklingApi.format_inkling_summary` - the one serializer both `format_inkling_detail` and every list endpoint build on - never included `approval_state` in its output. `this.detail.approval_state` was `undefined` on every page, always, for every inkling - so `{{#if (eq this.detail.approval_state "submitted")}}` silently never matched, with no console error or server error to point at it (same failure shape as Round 2's Lesson 24, one level removed - see the new Lesson 28). This also explains two other conditions that were quietly dead the whole time: the player's "Request Unlock" button and staff's own "Unlock" button, both gated on `approval_state == "approved"`.

Fixed by adding `approval_state: inkling.approval_state` to `format_inkling_summary` - the single shared serializer, so every consumer (admin list, profile list, search results, and both detail views) inherits the fix at once instead of patching the admin page in isolation. The review card's own action wiring, permission checks, and server-side handlers (`inklings_approve_inkling`/`inklings_request_changes` → `InklingApi.approve_inkling`/`request_changes_inkling`, both already `can_manage_inklings?`-gated and already re-validating `approval_state == "submitted"` server-side against duplicate/stale submissions) were already correct from the prior round's work - nothing else needed to change. Added `plugin/spec/format_inkling_summary_spec.rb` pinning the field's presence on both the summary and merged detail payloads. Added Lesson 28 to the dev guide.

### Bug 004 — `inkling/admin` Should Display Pagination Hint

**Status: Fixed (unconfirmed)**

`+inkling/admin` gave no indication further pages existed. Added a hint line after the rendered list - "More pages are available (page X of Y). Use `+inkling/adminN` to view page N." (no space before the page number, matching the actual command syntax) - shown only when `cmd.page` is less than the total page count computed from the same line-based pagination `BorderedPagedListTemplate` already uses, so it's never wrong relative to what the template just rendered, and never shown on the final page or for an out-of-range page.

---

## Round 5 (v5)

Defects and one explicitly-approved workflow addition from the fifth round of alpha testing (the general feature freeze does not apply to Bug 002, per this round's own instructions).

### Bug 001 — Web Approval Comment Creates Duplicate Inkling Entries

**Status: Fixed (unconfirmed)**

Approving with a comment created the comment twice: once as the canonical `[Approved]` entry, once again moments later as a generic `[staff]` reply with identical text.

**Root cause, confirmed against real AresMUSH core source:** `Inklings.approve_inkling` (the one canonical service both MUSH's `InklingApproveCmd` and the web's `InklingApi.approve_inkling` already called - no duplicate business logic between the two interfaces to begin with) creates exactly one `[Approved]` `InklingMessage`, then calls `Jobs.close_job(staff, inkling.job, close_message)` to close the linked job. `Jobs.close_job` posts that same `close_message` as a job comment (a `JobReply`) as a side effect (`Jobs.change_job_status` → `Jobs.comment`, confirmed against source). The next time the inkling is viewed - which happens immediately when the web modal reloads after approval - `Inklings.sync_job_replies` (called on every view, MUSH and web alike) mirrors any not-yet-mirrored `JobReply` into the thread as a new, generic message. That mirrored copy of the same text was the duplicate. This affected both interfaces equally; it just surfaced first on web because the modal reloads (and therefore re-syncs) right after the action, where MUSH would only show it on the next `+inkling <id>`.

Fixed by capturing the `[Approved]` message `approve_inkling` already creates, and after `Jobs.close_job` returns, linking the `JobReply` it just posted to that message via `source_job_reply` - `sync_job_replies`' own dedup check (`InklingMessage.find(source_job_reply_id:)`) then correctly treats it as already-mirrored instead of creating a second copy. No change was needed to `Jobs.close_job` itself or to either caller. Also added a `reviewSubmitting` guard (disables the Submit Review button and ignores a re-click while a request is in flight) as the requested protection against a duplicate submission from repeated clicks - server-side, `approve_inkling`'s existing `approval_state == "submitted"` precondition already rejected a genuine duplicate attempt on its own. Added `plugin/spec/approve_inkling_spec.rb` covering the with-comment, without-comment, and post-fix-reload cases, plus that status/approval_state/job only change once.

### Bug 002 — Add Admin Reopen Action and Remove Irreversibility Warning

**Status: Fixed (unconfirmed)**

Explicitly approved as a workflow addition despite the feature freeze. Staff had no way to reopen a closed Inkling, and the web close confirmation claimed closing "cannot be undone."

Added one canonical `Inklings.reopen_inkling(inkling, staff)` service, invoked from both a new MUSH command and a new web handler - same pattern as every other staff review action in this plugin (approve/needschanges/unlock all already work this way):

* **MUSH:** `+inkling/reopen <id>` (`InklingReopenCmd`) - staff-only (`can_manage_inklings?`), validates the Inkling exists and is currently closed (rejects an already-open Inkling with a clear message), documented under the existing `help manage_inklings` topic (no new command-specific topic created).
* **Web:** a "Reopen Inkling" button in the shared detail modal, shown only for staff and only when `status == "closed"`, disabled and re-entrancy-guarded while the request is in flight, refreshing both the modal and the surrounding list on success via the same `onUpdate` mechanism every other action already uses, with `flashMessages` success/error feedback.
* **What reopening touches:** only `Inkling#status` (back to `"open"`) plus one new `message_type: "reopened"` audit entry naming who did it. `locked`/`approval_state` are deliberately left exactly as they were at closure - they already correctly describe whatever review round was last in progress, and reopening doesn't re-litigate that round's outcome. No prior messages, rolls, participants, tags, or sharing are touched.
* **Linked job:** if the job was closed along with the Inkling, reopening moves it back to the game's configured `jobs.default_status` via `Jobs.change_job_status` (the standard Ares status-transition API, also used internally by `Jobs.close_job`) - the same job stays linked, a second one is never created. If no default status is configured, the Inkling still reopens; the job's status is left alone and a diagnostic is logged and posted to the job rather than guessing a status name that might not exist for that game.
* **Duplicate-mirroring, again:** `Jobs.change_job_status` (and the no-default-status fallback's `mirror_to_job`) both post a job comment exactly like `Jobs.close_job` does, which would have reintroduced Bug 001's exact failure mode for the reopen entry - caught before shipping and fixed with the same `source_job_reply` linking technique.
* **Irreversibility wording:** the only place in the plugin that claimed closing "cannot be undone" was the web close confirmation dialog (`inkling-detail-modal.js`) - reworded to mention the Reopen Inkling button instead. Audited the rest of the plugin (MUSH messages, other confirm dialogs, help files, README, locale strings) for the same phrasing - the only other "cannot be undone" is Delete's, which is intentionally left as-is since deletion remains genuinely permanent and was never in scope here.
* **Also fixed as part of this work:** README.md's in-game help pointer read `help managing inklings`, which was never a real topic (the real one, used consistently everywhere else in the codebase, is `help manage_inklings`) - corrected. The Inkling model's `status` doc comment referenced a nonexistent `close_inkling` method - corrected to name the real command/API and mention reopening.

**Also discovered and fixed while wiring up the new REOPENED badge (not part of the original bug list, but directly blocking it):** `InklingApi.format_message` never included `message_type` in its serialized output at all - meaning the SUBMITTED/APPROVED/NEEDS CHANGES/REWARD badges in the web modal have silently never rendered, on any inkling, ever (same missing-serializer-field shape as Round 4's Lesson 28). Fixed by adding the field; covered by `plugin/spec/format_message_spec.rb`.

Added `plugin/spec/reopen_inkling_spec.rb` covering: status restored to open, locked/approval_state untouched, exactly one reopen audit entry, prior messages preserved, the linked job reopening (not duplicating), no duplicate mirrored reply from either job-update path, and the no-default-status diagnostic fallback. Added Lesson 29 to the dev guide.

**Known follow-up (not fixed, out of scope for this round):** `Inklings.unlock_inkling` and `Inklings.request_changes` both call `mirror_to_job` with a real comment the same way `approve_inkling` used to - they likely have the identical latent duplicate-mirroring bug Bug 001 fixed for approval, just not yet reported. Worth auditing in a future round.
