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
