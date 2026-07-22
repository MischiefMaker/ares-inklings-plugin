# Bugs for Claude v1

## Introduction

This document contains all issues discovered during functional testing of the Inklings plugin prior to the v1 release.

The project is currently feature frozen. The items below represent defects, missing parity between the MUSH and web interfaces, or incomplete implementations that should be resolved before release. Enhancements and new functionality have been deferred to the project's New Features Roadmap.

When practical, implementations should:

* Reuse existing service-layer logic rather than duplicating behavior.
* Maintain parity between MUSH and web interfaces.
* Hide unavailable actions rather than presenting nonfunctional controls.
* Continue enforcing all permissions server-side.
* Follow existing AresMUSH conventions.

---

## Bug 001 — Offline Notifications

(As previously documented.)

New Inklings should generate offline notifications visible in the web Notifications tab using the same AresMUSH notification infrastructure as Jobs.

---

## Bug 002 — Hidden Actions for Unapproved Players

(As previously documented.)

Unapproved players currently see Add Reply and Add Roll even though those actions cannot be used. Hide unavailable actions and continue enforcing permissions server-side.

---

## Bug 003 — Personal vs Private Replies

(As previously documented.)

Personal and Private are mutually exclusive visibility states. Selecting one should deselect the other, with server-side validation preventing invalid combinations.

---

## Bug 004 — Require Inkling Titles

(As previously documented.)

Require a non-blank title when creating Inklings from both Chargen and the standard Add Inkling workflow.

---

## Bug 005 — Chargen Secret/Goal Review

(As previously documented.)

Players need a documented way to review the complete contents of chargen Secrets and Goals before submission. Prefer displaying the full text in the web chargen draft review.

---

## Bug 006 — Roll Results Missing from Web Modal

(As previously documented.)

Rolls appear in `inkling #` on the MUSH but are missing from the web Inkling modal.

---

## Bug 007 — Shared Web Inkling Modal

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

---

## Bug 008 — Missing New Inkling Button

Approved players should have a New Inkling button on their profile page.

The button should appear only when the current viewer is eligible to create an Inkling.

---

## Bug 009 — Search Layout

Reduce unnecessary whitespace around the search controls.

* Remove the extra bottom padding.
* Place the Search button beside the search field.
* Maintain responsive layout.

---

## Bug 010 — Tag Visibility

Tags already exist but are inconsistently displayed.

### Web

Extend the existing admin modal implementation to the profile modal.

* Display tags beside Owner/Access.
* Smaller font.
* Comma-separated.
* Allow Add/Remove Tag for authorized users.
* Structure the markup so clickable tags can be added later without major refactoring.

### MUSH

Display tags in the full `inkling #` view.

---

## Bug 011 — inkling/submit Doesn't Create Review Job

Submitting an Inkling should:

* Create a standard AresMUSH review job.
* Associate the job with the Inkling.
* Notify staff.
* Prevent duplicate jobs.
* Handle failures gracefully.

---

## Bug 012 — Missing MUSH Private Roll Command

The web supports private Inkling rolls but there is no equivalent MUSH command.

Add a command (or equivalent naming):

```
inkling/rollprivate <id>=<roll>
```

using the same visibility, permissions, storage, and roll services as the web implementation.

---

## Deferred Features

The following items are intentionally not part of the v1 bug list:

* Clickable tags on the web.
* Tag search modal.
* `inklings/bytag`.

These belong in the New Features Roadmap for a future release.
