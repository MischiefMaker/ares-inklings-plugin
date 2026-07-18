// Inklings web portal component.
// Automatically installed to ares-webportal/app/components/ via plugin/install.
// The web portal integration is optional - MUSH-only games do not need it.
//
// Native AresMUSH web portal component for browsing and managing inklings.
// Uses standard AresMUSH gameApi service and flashMessages for error handling.

import Component from '@ember/component';
import { A } from '@ember/array';
import { computed } from '@ember/object';
import { inject as service } from '@ember/service';

export default Component.extend({
  gameApi: service(),
  flashMessages: service(),

  // --- Required arguments (pass these in when invoking the component) ---
  characterId: null,
  viewerId: null,
  isStaff: false,
  // Array of { kind, name, color } this viewer may create, e.g.
  // typeInfo=this.char.custom.inkling_types - see
  // custom-install/custom_char_fields.snippet.rb. Supplied by the
  // character payload's get_fields_for_viewing hook rather than
  // fetched here, since it's small, viewer-scoped reference data
  // needed before the player has done anything (as soon as they open
  // the "New Inkling" form) - the same pattern other Ares plugins use
  // for profile-tab reference data (e.g. RPG's char.rpg.sheet,
  // Marque's char.custom.house_list).
  typeInfo: null,

  // --- Internal state ---
  inklings: null,
  expandedId: null,
  loading: true,
  statusFilter: 'open',

  showNewForm: false,
  newKind: '',
  newTitle: '',
  newText: '',

  replyTextById: null,
  privateReplyById: null,
  personalReplyById: null,
  shareTargetById: null,
  tagInputById: null,

  showRollForm: false,
  rollType: 'player',
  rollSpec: '',
  npcName: '',
  rollResult: '',
  rollIsPrivate: false,

  init() {
    this._super(...arguments);
    this.set('inklings', A());
    this.set('replyTextById', {});
    this.set('privateReplyById', {});
    this.set('personalReplyById', {});
    this.set('shareTargetById', {});
    this.set('tagInputById', {});
  },

  didInsertElement() {
    this._super(...arguments);
    this.loadInklings();
  },

  // --- Data loading --------------------------------------------------

  loadInklings() {
    this.set('loading', true);
    // requestOne, not requestMany - inklings_get_inklings returns a
    // composite hash ({ inklings: [...] }), and requestOne is the
    // Ares convention for that (requestMany expects the raw JSON
    // response to already be the array).
    return this.gameApi.requestOne('inklings_get_inklings', {
      char_id: this.characterId,
      status: this.statusFilter
    }, null)
      .then((response) => {
        if (response.error) {
          return;
        }
        this.set('inklings', A(response.inklings || []));
      })
      .finally(() => {
        this.set('loading', false);
      });
  },

  replaceInkling(updated) {
    let list = this.inklings;
    let idx = list.findIndex((i) => i.id === updated.id);
    if (idx > -1) {
      list.replace(idx, 1, [updated]);
    }
  },

  reloadInklingDetail(id) {
    return this.gameApi.requestOne('inklings_get_inkling', {
      char_id: this.characterId,
      inkling_id: id
    }, null).then((response) => {
      if (response.error) {
        return;
      }
      this.replaceInkling(response.inkling);
      return response.inkling;
    });
  },

  expandedInkling: computed('inklings.[]', 'expandedId', function () {
    let id = this.expandedId;
    if (!id) {
      return null;
    }
    return (this.inklings || []).find((i) => i.id === id);
  }),

  actions: {
    setStatusFilter(filter) {
      this.set('statusFilter', filter);
      this.loadInklings();
    },

    toggleNewForm() {
      this.toggleProperty('showNewForm');
    },

    setNewKind(kind) {
      this.set('newKind', kind);
    },

    createInkling() {
      if (!this.newKind) {
        this.flashMessages.danger('Please select a type');
        return;
      }
      if (!this.newTitle || !this.newTitle.trim()) {
        this.flashMessages.danger('Please enter an inkling title');
        return;
      }
      if (!this.newText || !this.newText.trim()) {
        this.flashMessages.danger('Please enter inkling text');
        return;
      }

      this.gameApi.requestOne('inklings_create_inkling', {
        char_id: this.characterId,
        kind: this.newKind,
        title: this.newTitle,
        text: this.newText
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.inklings.unshiftObject(response.inkling);
        this.setProperties({
          newKind: '',
          newTitle: '',
          newText: '',
          showNewForm: false
        });
      });
    },

    expandInkling(id) {
      if (this.expandedId === id) {
        this.set('expandedId', null);
        return;
      }

      this.reloadInklingDetail(id).then((inkling) => {
        if (!inkling) {
          this.flashMessages.danger('Failed to load inkling details');
          return;
        }
        this.set('expandedId', id);
      }).catch((error) => {
        this.flashMessages.danger('Failed to load inkling details: ' + (error.message || 'Unknown error'));
      });
    },

    updateReplyText(id, value) {
      let hash = Object.assign({}, this.replyTextById);
      hash[id] = value;
      this.set('replyTextById', hash);
    },

    togglePrivateReply(id) {
      let hash = Object.assign({}, this.privateReplyById);
      hash[id] = !hash[id];
      this.set('privateReplyById', hash);
    },

    submitReply(id) {
      let text = (this.replyTextById || {})[id];
      if (!text || !text.trim()) {
        this.flashMessages.danger('Please enter reply text');
        return;
      }
      let isPrivate = !!(this.privateReplyById || {})[id];

      this.gameApi.requestOne('inklings_reply_to_inkling', {
        char_id: this.characterId,
        inkling_id: id,
        text,
        is_private: isPrivate
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.reloadInklingDetail(id).then(() => {
          let hash = Object.assign({}, this.replyTextById);
          hash[id] = '';
          this.set('replyTextById', hash);
        });
      });
    },

    togglePersonalReply(id) {
      let hash = Object.assign({}, this.personalReplyById);
      hash[id] = !hash[id];
      this.set('personalReplyById', hash);
    },

    submitPersonalReply(id) {
      let text = (this.replyTextById || {})[id];
      if (!text || !text.trim()) {
        this.flashMessages.danger('Please enter personal entry text');
        return;
      }

      let confirmed = confirm('Personal entries are intended as private notes, but may become visible under game policies (character transfers, roster changes, or administration). Proceed?');
      if (!confirmed) {
        return;
      }

      this.gameApi.requestOne('inklings_reply_to_inkling', {
        char_id: this.characterId,
        inkling_id: id,
        text,
        is_personal: true
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.reloadInklingDetail(id).then(() => {
          let hash = Object.assign({}, this.replyTextById);
          hash[id] = '';
          this.set('replyTextById', hash);
        });
      });
    },

    updateTagInput(id, value) {
      let hash = Object.assign({}, this.tagInputById);
      hash[id] = value;
      this.set('tagInputById', hash);
    },

    addTag(id) {
      let tag = (this.tagInputById || {})[id];
      if (!tag || !tag.trim()) {
        this.flashMessages.danger('Please enter a tag');
        return;
      }

      this.gameApi.requestOne('inklings_add_tag', {
        char_id: this.characterId,
        inkling_id: id,
        tag: tag.trim()
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.reloadInklingDetail(id).then(() => {
          let hash = Object.assign({}, this.tagInputById);
          hash[id] = '';
          this.set('tagInputById', hash);
        });
      });
    },

    removeTag(id, tag) {
      this.gameApi.requestOne('inklings_remove_tag', {
        char_id: this.characterId,
        inkling_id: id,
        tag
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.reloadInklingDetail(id);
      });
    },

    addGmNote(id) {
      let text = prompt('Enter GM note:');
      if (!text || !text.trim()) {
        return;
      }

      this.gameApi.requestOne('inklings_add_gm_note', {
        char_id: this.characterId,
        inkling_id: id,
        text: text.trim()
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.reloadInklingDetail(id);
      });
    },

    approveInkling(id) {
      let confirmed = confirm('Approve this inkling?');
      if (!confirmed) {
        return;
      }

      this.gameApi.requestOne('inklings_approve_inkling', {
        inkling_id: id
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.reloadInklingDetail(id);
      });
    },

    requestChanges(id) {
      let feedback = prompt('Enter feedback for revision:');
      if (!feedback || !feedback.trim()) {
        return;
      }

      this.gameApi.requestOne('inklings_request_changes', {
        inkling_id: id,
        feedback: feedback.trim()
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.reloadInklingDetail(id);
      });
    },

    grantReward(id) {
      let rewardType = prompt('Enter reward type (xp, fs3_skill, etc):');
      if (!rewardType) {
        return;
      }

      let rewardKey = '';
      if (rewardType.toLowerCase() === 'fs3_skill') {
        rewardKey = prompt('Enter skill name:');
        if (!rewardKey) {
          return;
        }
      }

      let amount = prompt('Enter amount:');
      if (!amount) {
        return;
      }

      this.gameApi.requestOne('inklings_grant_reward', {
        inkling_id: id,
        reward_type: rewardType.trim(),
        reward_key: rewardKey.trim(),
        amount: amount.trim()
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.reloadInklingDetail(id);
      });
    },

    toggleRollForm() {
      this.toggleProperty('showRollForm');
    },

    setRollType(type) {
      this.set('rollType', type);
    },

    addRoll(id) {
      if (!this.rollSpec || !this.rollSpec.trim()) {
        this.flashMessages.danger('Please enter a roll spec');
        return;
      }
      if (this.rollType !== 'player' && (!this.rollResult || !this.rollResult.trim())) {
        this.flashMessages.danger('Please enter a result');
        return;
      }

      let args = {
        inkling_id: id,
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
        this.reloadInklingDetail(id).then(() => {
          this.setProperties({
            rollSpec: '',
            npcName: '',
            rollResult: '',
            rollIsPrivate: false,
            showRollForm: false
          });
        });
      });
    },

    rerollWithLuck(inklingId, rollId) {
      this.gameApi.requestOne('character_luck_reroll', {
        char_id: this.characterId
      }, null).then((rollData) => {
        if (rollData.error) {
          return;
        }
        this.gameApi.requestOne('inklings_reroll_with_luck', {
          inkling_id: inklingId,
          roll_id: rollId,
          new_result: rollData.result,
          new_result_value: rollData.result_value,
          luck_cost: rollData.luck_cost || 1
        }, null).then((response) => {
          if (response.error) {
            return;
          }
          this.reloadInklingDetail(inklingId);
        });
      });
    },

    closeInkling(id) {
      if (!window.confirm('Close this inkling? This cannot be undone.')) {
        return;
      }
      this.gameApi.requestOne('inklings_close_inkling', {
        char_id: this.characterId,
        inkling_id: id
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.replaceInkling(response.inkling);
        this.set('expandedId', null);
      });
    },

    deleteInkling(id) {
      let confirmMsg = this.isStaff
        ? 'Delete this inkling? This cannot be undone.'
        : 'Request deletion of this inkling? This closes the thread and asks staff to review and approve a permanent delete.';
      if (!window.confirm(confirmMsg)) {
        return;
      }
      this.gameApi.requestOne('inklings_delete_inkling', {
        char_id: this.characterId,
        inkling_id: id
      }, null).then((data) => {
        if (data.error) {
          return;
        }
        if (data.deleted) {
          this.inklings.removeObject(this.inklings.find((i) => i.id === id));
        } else if (data.inkling) {
          this.replaceInkling(data.inkling);
        }
        this.set('expandedId', null);
      });
    },

    updateShareTarget(id, value) {
      let hash = Object.assign({}, this.shareTargetById);
      hash[id] = value;
      this.set('shareTargetById', hash);
    },

    shareInkling(id) {
      let target = (this.shareTargetById || {})[id];
      if (!target || !target.trim()) {
        this.flashMessages.danger('Please enter a character name to share with');
        return;
      }
      this.gameApi.requestOne('inklings_share_inkling', {
        char_id: this.characterId,
        inkling_id: id,
        target_name: target
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        let hash = Object.assign({}, this.shareTargetById);
        hash[id] = '';
        this.set('shareTargetById', hash);
        this.reloadInklingDetail(id);
      });
    },

    submitInkling(id) {
      this.gameApi.requestOne('inklings_submit_inkling', {
        char_id: this.characterId,
        inkling_id: id
      }, null).then((response) => {
        if (response.error) {
          return;
        }
        this.replaceInkling(response.inkling);
      });
    }
  }
});
