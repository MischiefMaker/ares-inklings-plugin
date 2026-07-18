// Inklings web portal component.
// Automatically installed to ares-webportal/app/components/ via plugin/install.
// The web portal integration is optional - MUSH-only games do not need it.
//
// Native AresMUSH web portal component for browsing and managing
// inklings.
//
// Written as a classic Ember Component (not an Octane/Glimmer
// component) to match the syntax conventions shown throughout
// AresMUSH's own "Modifying the Web Portal" tutorial series
// (curly-brace component/helper invocation, {{action}} handlers,
// this.set()/this.get() property access) - see:
//   https://www.aresmush.com/tutorials/code/add-web
//
// SERVER CONTRACT: AresMUSH web requests are dispatched by a `cmd`
// name to a handler class with a handle(request) method
// (request.cmd / request.args), registered via
// Inklings.get_web_request_handler - see plugin/web/*.rb and
// https://www.aresmush.com/tutorials/code/plugins.html /
// https://www.aresmush.com/tutorials/code/web-debug.html. That
// server-side half is verified against AresMUSH's own docs.
//
// What is NOT independently verified: the exact transport your
// game's ares-webportal actually uses to issue a cmd-based request
// from Ember (a dedicated injected service, a specific endpoint URL,
// a particular request/response envelope shape). callServer() below
// posts { cmd, args } as JSON to a single `/api/web` endpoint as a
// reasonable default - before relying on this, check your own
// ares-webportal app for how an existing feature issues a request
// (e.g. grep for "get_web_request_handler" usage on the server, or
// use the browser Network tab per the web-debug tutorial above) and
// adjust callServer() to match if it differs.
//
// Usage once installed (see README.md "Chargen & Profile Web
// Integration"):
//   {{inklings-tab characterId=this.char.id viewerId=this.viewer.id isStaff=this.viewer.isStaff}}

import Component from '@ember/component';
import { A } from '@ember/array';
import { computed } from '@ember/object';

export default Component.extend({
  // --- Required arguments (pass these in when invoking the component) ---
  characterId: null,
  viewerId: null,
  isStaff: false,

  // --- Internal state ---
  inklings: null,
  expandedId: null,
  loading: true,
  error: null,
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

  typeInfo: null,

  init() {
    this._super(...arguments);
    this.set('inklings', A());
    this.set('replyTextById', {});
    this.set('privateReplyById', {});
    this.set('personalReplyById', {});
    this.set('shareTargetById', {});
    this.set('tagInputById', {});
    this.set('typeInfo', {});
  },

  didInsertElement() {
    this._super(...arguments);
    this.loadInklings();
    this.loadTypes();
  },

  // --- Server call helper -------------------------------------------
  // See the SERVER CONTRACT note at the top of this file - verify
  // this matches your game's actual request transport.
  callServer(cmd, args = {}) {
    return fetch('/api/web', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ cmd, args })
    }).then((response) => response.json());
  },

  // --- Data loading --------------------------------------------------

  loadInklings() {
    this.set('loading', true);
    return this.callServer('inklings_get_inklings', {
      char_id: this.characterId,
      viewer_id: this.viewerId,
      status: this.statusFilter
    })
      .then((data) => {
        this.set('inklings', A(data.inklings || []));
        this.set('error', null);
      })
      .catch(() => {
        this.set('error', 'Failed to load inklings');
      })
      .finally(() => {
        this.set('loading', false);
      });
  },

  // Pulls the live type list (name, description, category) from the
  // same config +inkling/types reads in-game, via
  // InklingApi.get_types - so the web portal never carries its own
  // hardcoded, driftable copy of the type list.
  loadTypes() {
    this.callServer('inklings_get_types', {})
      .then((data) => {
        if (data && data.types) {
          this.set('typeInfo', data.types);
        }
      })
      .catch(() => {
        // Not fatal - kind labels just fall back to the raw kind
        // string (see kindLabel below) if this request fails.
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
    return this.callServer('inklings_get_inkling', {
      char_id: this.characterId,
      inkling_id: id,
      viewer_id: this.viewerId
    }).then((detail) => {
      if (!detail.error) {
        this.replaceInkling(detail.inkling);
      }
      return detail;
    });
  },

  expandedInkling: computed('inklings.[]', 'expandedId', function () {
    let id = this.expandedId;
    if (!id) {
      return null;
    }
    return (this.inklings || []).find((i) => i.id === id);
  }),

  kindLabel(kind) {
    let types = this.typeInfo || {};
    let entry = types[kind];
    return (entry && entry.name) || kind;
  },

  kindDescription(kind) {
    let types = this.typeInfo || {};
    let entry = types[kind];
    return entry && entry.description;
  },

  // Which kinds show up in the "New Inkling" type picker: everything
  // for staff, or just "player"/"shared" category types for everyone
  // else (matching the in-game permission split - see
  // Inklings.staff_kinds/player_kinds/shared_kinds).
  availableKinds: computed('typeInfo', 'isStaff', function () {
    let types = this.typeInfo || {};
    let keys = Object.keys(types);
    if (this.isStaff) {
      return keys;
    }
    return keys.filter((k) => {
      let category = types[k] && types[k].category;
      return category === 'player' || category === 'shared';
    });
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
        this.set('error', 'Please select a type');
        return;
      }
      if (!this.newTitle || !this.newTitle.trim()) {
        this.set('error', 'Please enter an inkling title');
        return;
      }
      if (!this.newText || !this.newText.trim()) {
        this.set('error', 'Please enter inkling text');
        return;
      }

      this.callServer('inklings_create_inkling', {
        char_id: this.characterId,
        viewer_id: this.viewerId,
        kind: this.newKind,
        title: this.newTitle,
        text: this.newText
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.inklings.unshiftObject(data.inkling);
        this.setProperties({
          newKind: '',
          newTitle: '',
          newText: '',
          showNewForm: false,
          error: null
        });
      });
    },

    expandInkling(id) {
      if (this.expandedId === id) {
        this.set('expandedId', null);
        return;
      }

      this.reloadInklingDetail(id).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.set('expandedId', id);
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
        this.set('error', 'Please enter reply text');
        return;
      }
      let isPrivate = !!(this.privateReplyById || {})[id];

      this.callServer('inklings_reply_to_inkling', {
        char_id: this.characterId,
        inkling_id: id,
        viewer_id: this.viewerId,
        text,
        is_private: isPrivate
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.reloadInklingDetail(id).then(() => {
          let hash = Object.assign({}, this.replyTextById);
          hash[id] = '';
          this.set('replyTextById', hash);
          this.set('error', null);
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
        this.set('error', 'Please enter personal entry text');
        return;
      }

      let confirmed = confirm('Personal entries are intended as private notes, but may become visible under game policies (character transfers, roster changes, or administration). Proceed?');
      if (!confirmed) {
        return;
      }

      this.callServer('inklings_reply_to_inkling', {
        char_id: this.characterId,
        inkling_id: id,
        viewer_id: this.viewerId,
        text,
        is_personal: true
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.reloadInklingDetail(id).then(() => {
          let hash = Object.assign({}, this.replyTextById);
          hash[id] = '';
          this.set('replyTextById', hash);
          this.set('error', null);
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
        this.set('error', 'Please enter a tag');
        return;
      }

      this.callServer('inklings_add_tag', {
        char_id: this.characterId,
        inkling_id: id,
        viewer_id: this.viewerId,
        tag: tag.trim()
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.reloadInklingDetail(id).then(() => {
          let hash = Object.assign({}, this.tagInputById);
          hash[id] = '';
          this.set('tagInputById', hash);
          this.set('error', null);
        });
      });
    },

    removeTag(id, tag) {
      this.callServer('inklings_remove_tag', {
        char_id: this.characterId,
        inkling_id: id,
        viewer_id: this.viewerId,
        tag
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.reloadInklingDetail(id).then(() => {
          this.set('error', null);
        });
      });
    },

    addGmNote(id) {
      let text = prompt('Enter GM note:');
      if (!text || !text.trim()) {
        return;
      }

      this.callServer('inklings_add_gm_note', {
        char_id: this.characterId,
        inkling_id: id,
        viewer_id: this.viewerId,
        text: text.trim()
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.reloadInklingDetail(id).then(() => {
          this.set('error', null);
        });
      });
    },

    approveInkling(id) {
      let confirmed = confirm('Approve this inkling?');
      if (!confirmed) {
        return;
      }

      this.callServer('inklings_approve_inkling', {
        inkling_id: id,
        viewer_id: this.viewerId,
        message: null
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.reloadInklingDetail(id).then(() => {
          this.set('error', null);
        });
      });
    },

    requestChanges(id) {
      let feedback = prompt('Enter feedback for revision:');
      if (!feedback || !feedback.trim()) {
        return;
      }

      this.callServer('inklings_request_changes', {
        inkling_id: id,
        viewer_id: this.viewerId,
        feedback: feedback.trim()
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.reloadInklingDetail(id).then(() => {
          this.set('error', null);
        });
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

      this.callServer('inklings_grant_reward', {
        inkling_id: id,
        viewer_id: this.viewerId,
        reward_type: rewardType.trim(),
        reward_key: rewardKey.trim(),
        amount: amount.trim()
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.reloadInklingDetail(id).then(() => {
          this.set('error', null);
        });
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
        this.set('error', 'Please enter a roll spec');
        return;
      }
      if (this.rollType !== 'player' && (!this.rollResult || !this.rollResult.trim())) {
        this.set('error', 'Please enter a result');
        return;
      }

      let args = {
        inkling_id: id,
        viewer_id: this.viewerId,
        roll_type: this.rollType,
        roll_spec: this.rollSpec,
        is_private: this.rollIsPrivate
      };

      if (this.rollType === 'player') {
        // Player rolls are resolved server-side against the
        // character's own sheet; result/result_value are computed by
        // the game, not entered here.
        args.result = '';
        args.result_value = 0;
      } else {
        args.result = this.rollResult;
        args.result_value = parseInt(this.rollResult, 10) || 0;
        if (this.rollType === 'npc') {
          args.npc_name = this.npcName || null;
        }
      }

      this.callServer('inklings_add_roll', args).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.reloadInklingDetail(id).then(() => {
          this.setProperties({
            rollSpec: '',
            npcName: '',
            rollResult: '',
            rollIsPrivate: false,
            showRollForm: false,
            error: null
          });
        });
      });
    },

    rerollWithLuck(inklingId, rollId) {
      // Rerolling spends a character's luck against their own sheet,
      // which is FS3Skills' functionality, not this plugin's - we
      // don't own an endpoint that computes the actual reroll result.
      // "inklings_character_luck_reroll" below is a GUESS at what
      // FS3Skills' own web handler cmd is named; it was never
      // independently verified (unlike the inklings_* cmds in this
      // file, which are). Check FS3Skills' plugin/web/ handlers on
      // your install and correct this cmd name if it differs.
      this.callServer('character_luck_reroll', {
        char_id: this.characterId,
        viewer_id: this.viewerId
      }).then((rollData) => {
        if (rollData.error) {
          this.set('error', rollData.error);
          return;
        }
        this.callServer('inklings_reroll_with_luck', {
          inkling_id: inklingId,
          roll_id: rollId,
          viewer_id: this.viewerId,
          new_result: rollData.result,
          new_result_value: rollData.result_value,
          luck_cost: rollData.luck_cost || 1
        }).then((data) => {
          if (data.error) {
            this.set('error', data.error);
            return;
          }
          this.reloadInklingDetail(inklingId).then(() => {
            this.set('error', null);
          });
        });
      });
    },

    closeInkling(id) {
      if (!window.confirm('Close this inkling? This cannot be undone.')) {
        return;
      }
      this.callServer('inklings_close_inkling', {
        char_id: this.characterId,
        inkling_id: id,
        viewer_id: this.viewerId
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.replaceInkling(data.inkling);
        this.set('expandedId', null);
        this.set('error', null);
      });
    },

    deleteInkling(id) {
      let confirmMsg = this.isStaff
        ? 'Delete this inkling? This cannot be undone.'
        : 'Request deletion of this inkling? This closes the thread and asks staff to review and approve a permanent delete.';
      if (!window.confirm(confirmMsg)) {
        return;
      }
      this.callServer('inklings_delete_inkling', {
        char_id: this.characterId,
        inkling_id: id,
        viewer_id: this.viewerId
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        if (data.deleted) {
          this.inklings.removeObject(this.inklings.find((i) => i.id === id));
        } else if (data.inkling) {
          this.replaceInkling(data.inkling);
        }
        this.set('expandedId', null);
        this.set('error', null);
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
        this.set('error', 'Please enter a character name to share with');
        return;
      }
      this.callServer('inklings_share_inkling', {
        char_id: this.characterId,
        inkling_id: id,
        viewer_id: this.viewerId,
        target_name: target
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        let hash = Object.assign({}, this.shareTargetById);
        hash[id] = '';
        this.set('shareTargetById', hash);
        this.reloadInklingDetail(id).then(() => {
          this.set('error', null);
        });
      });
    },

    submitInkling(id) {
      this.callServer('inklings_submit_inkling', {
        char_id: this.characterId,
        inkling_id: id,
        viewer_id: this.viewerId
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.replaceInkling(data.inkling);
        this.set('error', null);
      });
    }
  }
});
