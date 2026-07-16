// Native AresMUSH web portal component for browsing and managing
// inklings, replacing the earlier React reference implementation.
//
// Written as a classic Ember Component (not an Octane/Glimmer
// component) to match the syntax conventions shown throughout
// AresMUSH's own "Modifying the Web Portal" tutorial series
// (curly-brace component/helper invocation, {{action}} handlers,
// this.set()/this.get() property access) - see:
//   https://www.aresmush.com/tutorials/code/add-web
//
// This component is self-contained: it talks directly to this
// plugin's own REST API (plugin/public/inklings_api.rb and
// rolls_api.rb) via fetch(), the same way the original React version
// called `api.get/post/put/delete`. Because it saves its own changes
// immediately (reply, roll, share, close, delete all fire their own
// request), it does NOT need to hook into the Profile Edit save flow
// - it only needs to be *displayed* somewhere, which is why the
// integration snippets in this folder wire it into the Profile
// Display tab (profile-custom.hbs) rather than the Edit tab.
//
// Usage once installed (see README.md "Chargen & Profile Web
// Integration"):
//   {{inklings-tab characterId=this.char.id viewerId=this.viewer.id isStaff=this.viewer.isStaff}}
//
// NOTE: this component calls the game's API directly with fetch().
// If your game's Ember app already has its own AJAX/API service
// (many classic Ember apps use one, e.g. via the ember-ajax addon),
// swap the `ajaxRequest()` method below to use it instead - the rest
// of the component doesn't need to change.

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
  shareTargetById: null,

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
    this.set('shareTargetById', {});
    // Static fallback labels in case a kind isn't found in the list
    // fetched from the server (see loadTypes below) - kept minimal
    // since +inkling/types / the types API is the source of truth.
    this.set('typeInfo', {});
  },

  didInsertElement() {
    this._super(...arguments);
    this.loadInklings();
    this.loadTypes();
  },

  // --- HTTP helper -------------------------------------------------
  // Centralized here so it's the one place to swap in a different
  // AJAX mechanism if your game's Ember app has its own service.
  ajaxRequest(url, method = 'GET', body = null) {
    let options = {
      method,
      headers: { 'Content-Type': 'application/json' }
    };
    if (body) {
      options.body = JSON.stringify(body);
    }
    return fetch(url, options).then((response) => response.json());
  },

  // --- Data loading --------------------------------------------------

  loadInklings() {
    this.set('loading', true);
    let url = `/api/characters/${this.characterId}/inklings?viewer_id=${this.viewerId}&status=${this.statusFilter}`;
    return this.ajaxRequest(url)
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
    let url = `/api/inklings/types`;
    this.ajaxRequest(url)
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

      let url = `/api/characters/${this.characterId}/inklings`;
      this.ajaxRequest(url, 'POST', {
        kind: this.newKind,
        title: this.newTitle,
        text: this.newText,
        viewer_id: this.viewerId
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.inklings.unshiftObject(data.inkling);
        this.setProperties({
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

      let url = `/api/characters/${this.characterId}/inklings/${id}?viewer_id=${this.viewerId}`;
      this.ajaxRequest(url).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        this.replaceInkling(data.inkling);
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

      let url = `/api/characters/${this.characterId}/inklings/${id}/reply`;
      this.ajaxRequest(url, 'POST', {
        text,
        is_private: isPrivate,
        viewer_id: this.viewerId
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        let detailUrl = `/api/characters/${this.characterId}/inklings/${id}?viewer_id=${this.viewerId}`;
        this.ajaxRequest(detailUrl).then((detail) => {
          this.replaceInkling(detail.inkling);
          let hash = Object.assign({}, this.replyTextById);
          hash[id] = '';
          this.set('replyTextById', hash);
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

      let payload = {
        roll_type: this.rollType,
        roll_spec: this.rollSpec,
        is_private: this.rollIsPrivate,
        viewer_id: this.viewerId
      };

      if (this.rollType === 'player') {
        // Player rolls are resolved server-side against the
        // character's own sheet; result/result_value are computed by
        // the game, not entered here.
        payload.result = '';
        payload.result_value = 0;
      } else {
        payload.result = this.rollResult;
        payload.result_value = parseInt(this.rollResult, 10) || 0;
        if (this.rollType === 'npc') {
          payload.npc_name = this.npcName || null;
        }
      }

      let url = `/api/characters/${this.characterId}/inklings/${id}/roll`;
      this.ajaxRequest(url, 'POST', payload).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        let detailUrl = `/api/characters/${this.characterId}/inklings/${id}?viewer_id=${this.viewerId}`;
        this.ajaxRequest(detailUrl).then((detail) => {
          this.replaceInkling(detail.inkling);
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
      let url = `/api/characters/${this.characterId}/inklings/${inklingId}/rolls/${rollId}/reroll`;
      this.ajaxRequest(url, 'POST', { viewer_id: this.viewerId }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        let detailUrl = `/api/characters/${this.characterId}/inklings/${inklingId}?viewer_id=${this.viewerId}`;
        this.ajaxRequest(detailUrl).then((detail) => {
          this.replaceInkling(detail.inkling);
          this.set('error', null);
        });
      });
    },

    closeInkling(id) {
      if (!window.confirm('Close this inkling? This cannot be undone.')) {
        return;
      }
      let url = `/api/characters/${this.characterId}/inklings/${id}/close`;
      this.ajaxRequest(url, 'PUT', { viewer_id: this.viewerId }).then((data) => {
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
      let url = `/api/characters/${this.characterId}/inklings/${id}?viewer_id=${this.viewerId}`;
      this.ajaxRequest(url, 'DELETE').then((data) => {
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
      let url = `/api/characters/${this.characterId}/inklings/${id}/share`;
      this.ajaxRequest(url, 'POST', {
        target_name: target,
        viewer_id: this.viewerId
      }).then((data) => {
        if (data.error) {
          this.set('error', data.error);
          return;
        }
        let hash = Object.assign({}, this.shareTargetById);
        hash[id] = '';
        this.set('shareTargetById', hash);
        let detailUrl = `/api/characters/${this.characterId}/inklings/${id}?viewer_id=${this.viewerId}`;
        this.ajaxRequest(detailUrl).then((detail) => {
          this.replaceInkling(detail.inkling);
          this.set('error', null);
        });
      });
    },

    submitInkling(id) {
      let url = `/api/characters/${this.characterId}/inklings/${id}/submit`;
      this.ajaxRequest(url, 'POST', { viewer_id: this.viewerId }).then((data) => {
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
