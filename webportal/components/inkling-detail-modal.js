// Inkling detail modal component.
// Automatically installed to ares-webportal/app/components/ via plugin/install.
//
// Renders a single inkling's full detail (messages, rolls, staff controls)
// inside an ember-bootstrap modal, and owns every action that mutates an
// inkling - replies, tags, rolls, approval, sharing, closing, deletion.
// Invoked by inklings-tab.js, which only tracks which inkling is selected;
// this component fetches its own detail whenever inklingId changes and
// reports changes back via the onUpdate/onDelete closure actions so the
// list can stay in sync without ever handling detail-shaped data itself.

import Component from '@ember/component';
import { inject as service } from '@ember/service';
import { next } from '@ember/runloop';

export default Component.extend({
  gameApi: service(),
  flashMessages: service(),

  // --- Required arguments ---
  inklingId: null,
  characterId: null,
  viewerId: null,
  isStaff: false,
  // Whether the viewer's own character is approved. Only meaningful for
  // non-staff (staff bypass the approval requirement everywhere server-side -
  // see Inklings.can_manage_inklings? / can_manage_inklings? checks in
  // InklingApi/RollsApi). Used purely to hide reply/roll/submit controls a
  // non-staff, unapproved viewer couldn't actually use - the server-side
  // checks are the real enforcement (e.g. InklingApi.reply_to_inkling,
  // RollsApi.add_roll both reject unapproved non-staff callers regardless
  // of what the client sends).
  isApproved: false,
  onClose: null,
  onUpdate: null,
  onDelete: null,

  // --- Internal state ---
  // isOpen is deliberately internal rather than a passed-in attribute -
  // see didReceiveAttrs/loadDetail below for why it only flips true once
  // detail has actually loaded, instead of tracking inklingId directly.
  isOpen: false,
  detail: null,
  loading: false,
  reopenSubmitting: false,

  replyText: '',
  replyIsPrivate: false,
  replyIsPersonal: false,
  // Staff-only: who a private reply's recipient should be, mirroring
  // +inkling/private <id>=<name>/<text>'s optional target on the MUSH side
  // (InklingPrivateCmd). Defaulted to the inkling's owner once detail loads
  // (see loadDetail) - matches the server's own default when no explicit
  // target is sent (InklingApi.reply_to_inkling).
  replyPrivateTarget: null,
  tagInput: '',
  shareTarget: '',
  shareGroupTarget: '',

  showRollForm: false,
  rollType: 'player',
  rollSpec: '',
  npcName: '',
  rollResult: '',
  rollIsPrivate: false,

  // Staff review form (approve/needs-changes) - one unified control instead
  // of two separate window.prompt-driven buttons, so the decision and its
  // explanation are entered together, in the same place, before submitting.
  reviewDecision: 'approve',
  reviewMessage: '',
  reviewSubmitting: false,

  didReceiveAttrs() {
    this._super(...arguments);

    if (!this.inklingId) {
      // Parent cleared selection (user closed, or the inkling was
      // deleted) - close and reset so a later re-open starts fresh.
      this._loadedId = null;
      if (this.isOpen) {
        this.set('isOpen', false);
      }
      return;
    }

    if (this.inklingId !== this._loadedId) {
      // Mark synchronously so a second didReceiveAttrs firing before the
      // deferred load below runs doesn't queue a duplicate fetch.
      this._loadedId = this.inklingId;
      this.resetFormState();
      // gameApi.requestOne is RSVP-backed, and RSVP promises can resolve
      // synchronously enough to flush within the *same* render transaction
      // that's still processing this didReceiveAttrs call - Ember then
      // flags the resulting this.set() as a "modified twice in a single
      // render" violation. Deferring the fetch (and its state updates) to
      // the next run loop keeps it safely outside that transaction - and
      // isOpen only flips true once the fetch actually resolves (see
      // loadDetail below), so ember-bootstrap's own open-animation work
      // never fires in the same tick as ours either.
      next(this, 'loadDetail');
    }
  },

  resetFormState() {
    this.setProperties({
      replyText: '',
      replyIsPrivate: false,
      replyIsPersonal: false,
      replyPrivateTarget: null,
      tagInput: '',
      shareTarget: '',
      shareGroupTarget: '',
      showRollForm: false,
      rollType: 'player',
      rollSpec: '',
      npcName: '',
      rollResult: '',
      rollIsPrivate: false,
      reviewDecision: 'approve',
      reviewMessage: '',
      reviewSubmitting: false,
      reopenSubmitting: false
    });
  },

  loadDetail() {
    let id = this.inklingId;
    this._loadedId = id;
    this.set('loading', true);
    return this.gameApi.requestOne('inklings_get_inkling', {
      char_id: this.characterId,
      inkling_id: id
    }, null).then((response) => {
      if (response.error) {
        return;
      }
      this.setProperties({ detail: response.inkling, isOpen: true });
      // Default the private-reply target to the owner, same as the
      // server does when no explicit target is sent - only set once per
      // load (resetFormState already cleared it) so re-selecting a
      // different participant isn't clobbered by a later loadDetail call
      // triggered by some other action in this same open modal.
      if (!this.replyPrivateTarget && response.inkling.character_id) {
        this.set('replyPrivateTarget', response.inkling.character_id);
      }
      if (this.onUpdate) {
        this.onUpdate(response.inkling);
      }
    }).finally(() => {
      this.set('loading', false);
    });
  },

  actions: {
    // Private and Personal are mutually exclusive visibility levels (see
    // InklingApi.reply_to_inkling's matching server-side rejection) -
    // checking one clears the other, so the two checkboxes can never both
    // end up checked in the UI.
    toggleReplyPrivate() {
      this.toggleProperty('replyIsPrivate');
      if (this.replyIsPrivate) {
        this.set('replyIsPersonal', false);
      }
    },

    toggleReplyPersonal() {
      this.toggleProperty('replyIsPersonal');
      if (this.replyIsPersonal) {
        this.set('replyIsPrivate', false);
      }
    },

    setReplyPrivateTarget(id) {
      this.set('replyPrivateTarget', id);
    },

    close() {
      this.setProperties({ isOpen: false, detail: null });
      this._loadedId = null;
      if (this.onClose) {
        this.onClose();
      }
    },

    // Single entry point for both "reply" and "personal entry" - the two
    // share one textarea in the template now, distinguished only by the
    // Personal Entry checkbox (replyIsPersonal). Personal entries are a
    // stricter visibility level (author only, hidden even from staff) than
    // a private reply (author + staff), so when Personal is checked it
    // takes priority over the Private checkbox's value.
    submitReply() {
      if (!this.replyText || !this.replyText.trim()) {
        this.flashMessages.danger('Please enter reply text');
        return;
      }

      if (this.replyIsPersonal) {
        if (!window.confirm('Personal entries are intended as private notes, but may become visible under game policies (character transfers, roster changes, or administration). Proceed?')) {
          return;
        }
        this.gameApi.requestOne('inklings_reply_to_inkling', {
          char_id: this.characterId,
          inkling_id: this.inklingId,
          text: this.replyText,
          is_personal: true
        }, null).then((response) => {
          if (response.error) {
            return;
          }
          this.setProperties({ replyText: '', replyIsPersonal: false });
          this.loadDetail();
        });
        return;
      }

      this.gameApi.requestOne('inklings_reply_to_inkling', {
        char_id: this.characterId,
        inkling_id: this.inklingId,
        text: this.replyText,
        is_private: this.replyIsPrivate,
        private_target_id: (this.isStaff && this.replyIsPrivate) ? this.replyPrivateTarget : null
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.setProperties({ replyText: '', replyIsPrivate: false });
        this.loadDetail();
      });
    },

    addTag() {
      if (!this.tagInput || !this.tagInput.trim()) {
        this.flashMessages.danger('Please enter a tag');
        return;
      }
      this.gameApi.requestOne('inklings_add_tag', {
        char_id: this.characterId,
        inkling_id: this.inklingId,
        tag: this.tagInput.trim()
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.set('tagInput', '');
        this.loadDetail();
      });
    },

    removeTag(tag) {
      this.gameApi.requestOne('inklings_remove_tag', {
        char_id: this.characterId,
        inkling_id: this.inklingId,
        tag
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.loadDetail();
      });
    },

    addGmNote() {
      let text = window.prompt('Enter GM note:');
      if (!text || !text.trim()) {
        return;
      }
      this.gameApi.requestOne('inklings_add_gm_note', {
        char_id: this.characterId,
        inkling_id: this.inklingId,
        text: text.trim()
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.loadDetail();
      });
    },

    setReviewDecision(decision) {
      this.set('reviewDecision', decision);
    },

    // Single entry point for the staff review form - decision (Approved /
    // Needs Changes) plus one message field, submitted together. Needs
    // Changes requires non-blank explanatory text (mirrors
    // InklingNeedsChangesCmd's required_args on the MUSH side, which
    // already requires feedback); an approval message is optional, same
    // as +inkling/approve.
    submitReview() {
      // Guards against a duplicate approval/needs-changes submission from
      // a repeated click or a slow retry while the first request is still
      // in flight (v5 Bug 001) - the button is disabled via
      // this.reviewSubmitting in the template while this is true. The
      // server independently rejects a genuine duplicate too (approve_inkling/
      // request_changes_inkling both require approval_state == "submitted",
      // which only the first call still sees), so this is belt-and-suspenders
      // UX rather than the only thing preventing a duplicate.
      if (this.reviewSubmitting) {
        return;
      }

      let decision = this.reviewDecision;
      let message = (this.reviewMessage || '').trim();

      if (decision === 'needs_changes' && !message) {
        this.flashMessages.danger('Please explain what needs to change before submitting.');
        return;
      }

      this.set('reviewSubmitting', true);

      let request = decision === 'needs_changes'
        ? this.gameApi.requestOne('inklings_request_changes', {
          inkling_id: this.inklingId,
          feedback: message
        }, null)
        : this.gameApi.requestOne('inklings_approve_inkling', {
          inkling_id: this.inklingId,
          message: message || null
        }, null);

      request.then((response) => {
        if (response.error) {
          return;
        }
        this.setProperties({ reviewDecision: 'approve', reviewMessage: '' });
        this.loadDetail();
      }).finally(() => {
        this.set('reviewSubmitting', false);
      });
    },

    grantReward() {
      let rewardType = window.prompt('Enter reward type (xp, fs3_skill, etc):');
      if (!rewardType) {
        return;
      }
      let rewardKey = '';
      if (rewardType.toLowerCase() === 'fs3_skill') {
        rewardKey = window.prompt('Enter skill name:');
        if (!rewardKey) {
          return;
        }
      }
      let amount = window.prompt('Enter amount:');
      if (!amount) {
        return;
      }
      this.gameApi.requestOne('inklings_grant_reward', {
        inkling_id: this.inklingId,
        reward_type: rewardType.trim(),
        reward_key: rewardKey.trim(),
        amount: amount.trim()
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.loadDetail();
      });
    },

    toggleRollForm() {
      this.toggleProperty('showRollForm');
    },

    setRollType(type) {
      this.set('rollType', type);
    },

    addRoll() {
      if (!this.rollSpec || !this.rollSpec.trim()) {
        this.flashMessages.danger('Please enter a roll spec');
        return;
      }
      if (this.rollType !== 'player' && (!this.rollResult || !this.rollResult.trim())) {
        this.flashMessages.danger('Please enter a result');
        return;
      }

      let args = {
        inkling_id: this.inklingId,
        roll_type: this.rollType,
        roll_spec: this.rollSpec,
        is_private: this.rollIsPrivate
      };

      if (this.rollType === 'player') {
        // For player rolls, pass roll_spec to backend and let it perform the FS3 roll
        this.gameApi.requestOne('inklings_add_roll', args, null).then((response) => {
          if (response.error) {
            return;
          }
          this.setProperties({
            rollSpec: '',
            npcName: '',
            rollResult: '',
            rollIsPrivate: false,
            showRollForm: false
          });
          this.loadDetail();
        });
      } else {
        args.result = this.rollResult;
        args.result_value = parseInt(this.rollResult, 10) || 0;
        if (this.rollType === 'npc') {
          args.npc_name = this.npcName || null;
        }
        this.gameApi.requestOne('inklings_add_roll', args, null).then((response) => {
          if (response.error) {
            return;
          }
          this.setProperties({
            rollSpec: '',
            npcName: '',
            rollResult: '',
            rollIsPrivate: false,
            showRollForm: false
          });
          this.loadDetail();
        });
      }
    },


    submitInkling() {
      this.gameApi.requestOne('inklings_submit_inkling', {
        char_id: this.characterId,
        inkling_id: this.inklingId
      }, null).then((response) => {
        if (response.error) {
          this.flashMessages.danger(response.error);
          return;
        }
        this.loadDetail();
      });
    },

    closeInkling() {
      if (!window.confirm('Close this inkling? Staff can reopen it later with the Reopen Inkling button if needed.')) {
        return;
      }
      this.gameApi.requestOne('inklings_close_inkling', {
        char_id: this.characterId,
        inkling_id: this.inklingId
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.set('detail', response.inkling);
        if (this.onUpdate) {
          this.onUpdate(response.inkling);
        }
      });
    },

    // Staff-only (v5) - reopens a closed inkling via the same canonical
    // Inklings.reopen_inkling service +inkling/reopen uses. reopenSubmitting
    // guards the button against a duplicate reopen from a repeated click
    // or slow retry, mirroring submitReview's reviewSubmitting guard -
    // the server independently rejects a genuine duplicate too, since
    // reopen_inkling requires the inkling to still be closed.
    reopenInkling() {
      if (this.reopenSubmitting) {
        return;
      }
      this.set('reopenSubmitting', true);

      this.gameApi.requestOne('inklings_reopen_inkling', {
        inkling_id: this.inklingId
      }, null).then((response) => {
        if (response.error) {
          this.flashMessages.danger(response.error);
          return;
        }
        this.flashMessages.success('Inkling reopened.');
        this.set('detail', response.inkling);
        if (this.onUpdate) {
          this.onUpdate(response.inkling);
        }
      }).finally(() => {
        this.set('reopenSubmitting', false);
      });
    },

    shareInkling() {
      if (!this.shareTarget || !this.shareTarget.trim()) {
        this.flashMessages.danger('Please enter a character name to share with');
        return;
      }
      this.gameApi.requestOne('inklings_share_inkling', {
        char_id: this.characterId,
        inkling_id: this.inklingId,
        target_name: this.shareTarget
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.set('shareTarget', '');
        this.loadDetail();
      });
    },

    shareGroup() {
      if (!this.shareGroupTarget || !this.shareGroupTarget.trim()) {
        this.flashMessages.danger('Please enter a group to share with');
        return;
      }
      this.gameApi.requestOne('inklings_share_group', {
        char_id: this.characterId,
        inkling_id: this.inklingId,
        group_spec: this.shareGroupTarget
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.set('shareGroupTarget', '');
        this.loadDetail();
      });
    },

    requestUnlock() {
      let reason = window.prompt('Enter a reason for requesting unlock:');
      if (!reason || !reason.trim()) {
        return;
      }
      this.gameApi.requestOne('inklings_request_unlock', {
        char_id: this.characterId,
        inkling_id: this.inklingId,
        reason: reason.trim()
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.flashMessages.success('Unlock request sent to staff.');
        this.loadDetail();
      });
    },

    unlockInkling() {
      if (!window.confirm('Unlock this inkling for further editing?')) {
        return;
      }
      this.gameApi.requestOne('inklings_unlock_inkling', {
        inkling_id: this.inklingId
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.loadDetail();
      });
    },

    deleteInkling() {
      let confirmMsg = this.isStaff
        ? 'Delete this inkling? This cannot be undone.'
        : 'Request deletion of this inkling? This closes the thread and asks staff to review and approve a permanent delete.';
      if (!window.confirm(confirmMsg)) {
        return;
      }
      let id = this.inklingId;
      this.gameApi.requestOne('inklings_delete_inkling', {
        char_id: this.characterId,
        inkling_id: id
      }, null).then((data) => {
        if (data.error) {
          return;
        }
        if (data.deleted) {
          if (this.onDelete) {
            this.onDelete(id);
          }
        } else if (data.inkling) {
          this.set('detail', data.inkling);
          if (this.onUpdate) {
            this.onUpdate(data.inkling);
          }
        }
      });
    }
  }
});
