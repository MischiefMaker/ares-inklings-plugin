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
  open: false,
  inklingId: null,
  characterId: null,
  viewerId: null,
  isStaff: false,
  onClose: null,
  onUpdate: null,
  onDelete: null,

  // --- Internal state ---
  detail: null,
  loading: false,

  replyText: '',
  replyIsPrivate: false,
  tagInput: '',
  shareTarget: '',

  showRollForm: false,
  rollType: 'player',
  rollSpec: '',
  npcName: '',
  rollResult: '',
  rollIsPrivate: false,

  didReceiveAttrs() {
    this._super(...arguments);
    if (this.inklingId && this.inklingId !== this._loadedId) {
      // Mark synchronously so a second didReceiveAttrs firing before the
      // deferred load below runs doesn't queue a duplicate fetch.
      this._loadedId = this.inklingId;
      this.resetFormState();
      // gameApi.requestOne is RSVP-backed, and RSVP promises can resolve
      // synchronously enough to flush within the *same* render transaction
      // that's still processing this didReceiveAttrs call - Ember then
      // flags the resulting this.set() as a "modified twice in a single
      // render" violation. Deferring the fetch (and its state updates) to
      // the next run loop keeps it safely outside that transaction.
      next(this, 'loadDetail');
    }
  },

  resetFormState() {
    this.setProperties({
      replyText: '',
      replyIsPrivate: false,
      tagInput: '',
      shareTarget: '',
      showRollForm: false,
      rollType: 'player',
      rollSpec: '',
      npcName: '',
      rollResult: '',
      rollIsPrivate: false
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
        this.flashMessages.danger(response.error);
        return;
      }
      this.set('detail', response.inkling);
      if (this.onUpdate) {
        this.onUpdate(response.inkling);
      }
    }).finally(() => {
      this.set('loading', false);
    });
  },

  actions: {
    close() {
      this.set('detail', null);
      this._loadedId = null;
      if (this.onClose) {
        this.onClose();
      }
    },

    submitReply() {
      if (!this.replyText || !this.replyText.trim()) {
        this.flashMessages.danger('Please enter reply text');
        return;
      }
      this.gameApi.requestOne('inklings_reply_to_inkling', {
        char_id: this.characterId,
        inkling_id: this.inklingId,
        text: this.replyText,
        is_private: this.replyIsPrivate
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.setProperties({ replyText: '', replyIsPrivate: false });
        this.loadDetail();
      });
    },

    submitPersonalReply() {
      if (!this.replyText || !this.replyText.trim()) {
        this.flashMessages.danger('Please enter personal entry text');
        return;
      }
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
        this.set('replyText', '');
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

    approveInkling() {
      if (!window.confirm('Approve this inkling?')) {
        return;
      }
      this.gameApi.requestOne('inklings_approve_inkling', {
        inkling_id: this.inklingId
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.loadDetail();
      });
    },

    requestChanges() {
      let feedback = window.prompt('Enter feedback for revision:');
      if (!feedback || !feedback.trim()) {
        return;
      }
      this.gameApi.requestOne('inklings_request_changes', {
        inkling_id: this.inklingId,
        feedback: feedback.trim()
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.loadDetail();
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
        args.result = '';
        args.result_value = 0;
      } else {
        args.result = this.rollResult;
        args.result_value = parseInt(this.rollResult, 10) || 0;
        if (this.rollType === 'npc') {
          args.npc_name = this.npcName || null;
        }
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
    },

    rerollWithLuck(rollId) {
      this.gameApi.requestOne('character_luck_reroll', {
        char_id: this.characterId
      }, null).then((rollData) => {
        if (rollData.error) {
          return;
        }
        this.gameApi.requestOne('inklings_reroll_with_luck', {
          inkling_id: this.inklingId,
          roll_id: rollId,
          new_result: rollData.result,
          new_result_value: rollData.result_value,
          luck_cost: rollData.luck_cost || 1
        }, null).then((response) => {
          if (response.error) {
            return;
          }
          this.loadDetail();
        });
      });
    },

    submitInkling() {
      this.gameApi.requestOne('inklings_submit_inkling', {
        char_id: this.characterId,
        inkling_id: this.inklingId
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.loadDetail();
      });
    },

    closeInkling() {
      if (!window.confirm('Close this inkling? This cannot be undone.')) {
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
