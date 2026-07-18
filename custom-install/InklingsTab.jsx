// INSTALLATION: Copy these files to your ares-webportal:
//   custom-install/InklingsTab.jsx → app/components/InklingsTab.jsx
//   custom-install/InklingsTab.css → app/components/InklingsTab.css
//
// This is part of Step 2 (Install Web Portal Components) in the README.
// The web portal integration is optional - MUSH-only games do not need it.
// IMPORTANT: Do not copy this file to the web portal unless you complete
// ALL steps in Step 2. Incomplete installation breaks the web portal.
//
// This is the React/modern version of the Inklings component.
// For Ember-based web portals, use the Ember version instead (inklings-tab.js).

import React, { useState, useEffect } from 'react';
import { api } from '@/api';
import './InklingsTab.css';

export const InklingsTab = ({ characterId, viewerId, isStaff }) => {
  const [inklings, setInklings] = useState([]);
  const [expandedId, setExpandedId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showNewForm, setShowNewForm] = useState(false);
  const [newInkling, setNewInkling] = useState({ kind: 'goal', title: '', text: '' });
  const [replyText, setReplyText] = useState({});
  const [privateReply, setPrivateReply] = useState({});
  const [statusFilter, setStatusFilter] = useState('open');
  const [shareTarget, setShareTarget] = useState({});
  const [fs3Attributes, setFs3Attributes] = useState([]);
  const [showRollForm, setShowRollForm] = useState(false);
  const [newRoll, setNewRoll] = useState({
    rollType: 'player',
    rollSpec: '',
    npcCharId: '',
    npcResult: '',
    isPrivate: false
  });

  const kindDisplayNames = {
    hint: 'Hint',
    vision: 'Vision',
    nudge: 'Nudge',
    hook: 'Hook',
    secret: 'Secret',
    action: 'Plot Action',
    research: 'Research',
    request: 'Request',
    update: 'Update',
    pitch: 'Pitch',
    goal: 'Goal'
  };

  const staffKinds = ['hint', 'vision', 'nudge', 'hook'];
  const playerKinds = ['action', 'research', 'request', 'update', 'pitch', 'goal'];
  const allKinds = [...staffKinds, ...playerKinds, 'secret'];

  useEffect(() => {
    loadInklings();
    loadFS3Attributes();
  }, [characterId, statusFilter]);

  const loadInklings = async () => {
    try {
      setLoading(true);
      const response = await api.get(`/api/characters/${characterId}/inklings?viewer_id=${viewerId}&status=${statusFilter}`);
      setInklings(response.data.inklings || []);
      setError(null);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to load inklings');
    } finally {
      setLoading(false);
    }
  };

  const loadFS3Attributes = async () => {
    try {
      // Try to load FS3 attributes for the character
      const response = await api.get(`/api/characters/${characterId}/fs3?viewer_id=${viewerId}`);
      if (response.data && response.data.attributes) {
        setFs3Attributes(response.data.attributes);
      }
    } catch (err) {
      // FS3 may not be available, that's okay
      console.log('FS3 not available');
    }
  };

  const handleCreateInkling = async () => {
    if (!newInkling.title.trim()) {
      setError('Please enter an inkling title');
      return;
    }

    if (!newInkling.text.trim()) {
      setError('Please enter inkling text');
      return;
    }

    try {
      const response = await api.post(`/api/characters/${characterId}/inklings`, {
        kind: newInkling.kind,
        title: newInkling.title,
        text: newInkling.text,
        viewer_id: viewerId
      });
      setInklings([response.data.inkling, ...inklings]);
      setNewInkling({ kind: 'goal', title: '', text: '' });
      setShowNewForm(false);
      setError(null);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to create inkling');
    }
  };

  const handleExpandInkling = async (id) => {
    if (expandedId === id) {
      setExpandedId(null);
      return;
    }

    try {
      const response = await api.get(`/api/characters/${characterId}/inklings/${id}?viewer_id=${viewerId}`);
      // Update the inkling in the list with the detailed version
      setInklings(inklings.map(i => i.id === id ? response.data.inkling : i));
      setExpandedId(id);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to load inkling details');
    }
  };

  const handleReplyToInkling = async (id, isPrivate = false) => {
    const text = replyText[id];
    if (!text || !text.trim()) {
      setError('Please enter reply text');
      return;
    }

    try {
      const response = await api.post(`/api/characters/${characterId}/inklings/${id}/reply`, {
        text: text,
        is_private: isPrivate,
        viewer_id: viewerId
      });
      // Reload the expanded inkling
      const fullResponse = await api.get(`/api/characters/${characterId}/inklings/${id}?viewer_id=${viewerId}`);
      setInklings(inklings.map(i => i.id === id ? fullResponse.data.inkling : i));
      setReplyText({ ...replyText, [id]: '' });
      setError(null);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to add reply');
    }
  };

  const handleAddRoll = async (inklingId) => {
    if (!newRoll.rollSpec || !newRoll.rollSpec.trim()) {
      setError('Please select or enter a roll spec');
      return;
    }
    if ((newRoll.rollType === 'npc' || newRoll.rollType === 'static') && !newRoll.npcResult.trim()) {
      setError('Please enter a result');
      return;
    }

    try {
      let result, resultValue, rollPayload;

      if (newRoll.rollType === 'player') {
        const rollResponse = await api.post(`/api/characters/${characterId}/roll`, {
          attribute: newRoll.rollSpec,
          viewer_id: viewerId
        });
        result = rollResponse.data.result;
        resultValue = rollResponse.data.result_value;
        rollPayload = { roll_type: 'player', roll_spec: newRoll.rollSpec, result, result_value: resultValue };
      } else if (newRoll.rollType === 'npc') {
        result = newRoll.npcResult;
        resultValue = parseInt(result) || 0;
        rollPayload = {
          roll_type: 'npc',
          roll_spec: newRoll.rollSpec,
          npc_char_id: newRoll.npcCharId || null,
          result,
          result_value: resultValue
        };
      } else {
        result = newRoll.npcResult;
        resultValue = parseInt(result) || 0;
        rollPayload = { roll_type: 'static', roll_spec: newRoll.rollSpec, result, result_value: resultValue };
      }

      await api.post(
        `/api/characters/${characterId}/inklings/${inklingId}/roll`,
        { ...rollPayload, is_private: newRoll.isPrivate, viewer_id: viewerId }
      );

      const fullResponse = await api.get(`/api/characters/${characterId}/inklings/${inklingId}?viewer_id=${viewerId}`);
      setInklings(inklings.map(i => i.id === inklingId ? fullResponse.data.inkling : i));
      setNewRoll({ rollType: 'player', rollSpec: '', npcCharId: '', npcResult: '', isPrivate: false });
      setShowRollForm(false);
      setError(null);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to add roll');
    }
  };

  const handleRerollWithLuck = async (inklingId, rollId) => {
    try {
      // Call FS3 API to reroll the skill/attribute
      const rollResponse = await api.post(`/api/characters/${characterId}/roll`, {
        attribute: 'luck_reroll',
        viewer_id: viewerId
      });
      const result = rollResponse.data.result;
      const resultValue = rollResponse.data.result_value;
      const luckCost = rollResponse.data.luck_cost || 1;

      const response = await api.post(
        `/api/characters/${characterId}/inklings/${inklingId}/rolls/${rollId}/reroll`,
        {
          new_result: result,
          new_result_value: resultValue,
          luck_cost: luckCost,
          viewer_id: viewerId
        }
      );

      // Reload the expanded inkling
      const fullResponse = await api.get(`/api/characters/${characterId}/inklings/${inklingId}?viewer_id=${viewerId}`);
      setInklings(inklings.map(i => i.id === inklingId ? fullResponse.data.inkling : i));
      setError(null);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to reroll');
    }
  };

  const handleCloseInkling = async (id) => {
    if (!window.confirm('Close this inkling? This cannot be undone.')) return;

    try {
      const response = await api.put(`/api/characters/${characterId}/inklings/${id}/close`, {
        viewer_id: viewerId
      });
      setInklings(inklings.map(i => i.id === id ? response.data.inkling : i));
      setExpandedId(null);
      setError(null);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to close inkling');
    }
  };

  const handleDeleteInkling = async (id) => {
    if (!window.confirm('Delete this inkling? This cannot be undone.')) return;

    try {
      await api.delete(`/api/characters/${characterId}/inklings/${id}`, {
        data: { viewer_id: viewerId }
      });
      setInklings(inklings.filter(i => i.id !== id));
      setExpandedId(null);
      setError(null);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to delete inkling');
    }
  };

  const handleShareInkling = async (id) => {
    const target = shareTarget[id];
    if (!target || !target.trim()) {
      setError('Please enter a character name to share with');
      return;
    }

    try {
      await api.post(`/api/characters/${characterId}/inklings/${id}/share`, {
        target_name: target,
        viewer_id: viewerId
      });
      setShareTarget({ ...shareTarget, [id]: '' });
      setError(null);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to share inkling');
    }
  };

  const availableKinds = isStaff ? allKinds : playerKinds.concat(['secret']);

  const expandedInkling = expandedId ? inklings.find(i => i.id === expandedId) : null;
  if (loading) {
    return <div className="inklings-tab">Loading inklings...</div>;
  }

  return (
    <div className="inklings-tab">
      {error && <div className="error-message">{error}</div>}

      <div className="inklings-header">
        <h2>Inklings</h2>
        <div className="inklings-filters">
          {['open', 'closed', 'all'].map(f => (
            <button
              key={f}
              className={`btn btn-filter ${statusFilter === f ? 'active' : ''}`}
              onClick={() => setStatusFilter(f)}
            >
              {f.charAt(0).toUpperCase() + f.slice(1)}
            </button>
          ))}
        </div>
        <button
          className="btn btn-primary"
          onClick={() => setShowNewForm(!showNewForm)}
        >
          {showNewForm ? 'Cancel' : '+ New Inkling'}
        </button>
      </div>

      {showNewForm && (
        <div className="new-inkling-form">
          <div className="form-group">
            <label>Type</label>
            <select
              value={newInkling.kind}
              onChange={(e) => setNewInkling({ ...newInkling, kind: e.target.value })}
            >
              {availableKinds.map(kind => (
                <option key={kind} value={kind}>
                  {kindDisplayNames[kind]}
                </option>
              ))}
            </select>
          </div>
          <div className="form-group">
            <label>Title</label>
            <input
              type="text"
              value={newInkling.title}
              onChange={(e) => setNewInkling({ ...newInkling, title: e.target.value })}
              placeholder="Enter a short title"
            />
          </div>
          <div className="form-group">
            <label>Text</label>
            <textarea
              value={newInkling.text}
              onChange={(e) => setNewInkling({ ...newInkling, text: e.target.value })}
              placeholder="Enter your inkling..."
              rows="4"
            />
          </div>
          <button className="btn btn-success" onClick={handleCreateInkling}>
            Create Inkling
          </button>
        </div>
      )}

      {inklings.length === 0 ? (
        <div className="no-inklings">
          <p>No inklings yet.</p>
        </div>
      ) : (
        <div className="inklings-list">
          {inklings.map(inkling => (
            <div key={inkling.id} className="inkling-item">
              <div
                className={`inkling-header ${expandedId === inkling.id ? 'expanded' : ''}`}
                onClick={() => handleExpandInkling(inkling.id)}
              >
                <div className="inkling-summary">
                  <span className={`inkling-kind ${inkling.kind}`}>
                    {kindDisplayNames[inkling.kind]}
                  </span>
                  <span className="inkling-title">{inkling.title}</span>
                  <span className={`inkling-status ${inkling.status}`}>
                    {inkling.status}
                  </span>
                  {inkling.character_id !== viewerId && inkling.character_name && (
                    <span className="inkling-owner">for {inkling.character_name}</span>
                  )}
                  {inkling.player_unread && (
                    <span className="unread-badge">unread</span>
                  )}
                  <span className="message-count">
                    {inkling.message_count} message{inkling.message_count !== 1 ? 's' : ''}
                    {inkling.player_unread && <span className="unread-asterisk">*</span>}
                  </span>
                  <span className="created-date">
                    {new Date(inkling.created_at).toLocaleDateString()}
                  </span>
                  {inkling.linked_job && (
                    <span className="linked-job">
                      Job #{inkling.linked_job.id} ({inkling.linked_job.status})
                    </span>
                  )}
                </div>
                <span className={`expand-icon ${expandedId === inkling.id ? 'open' : ''}`}>
                  ▼
                </span>
              </div>

              {expandedId === inkling.id && expandedInkling && (
                <div className="inkling-detail">
                  {/* Shared With - non-staff participants and shared groups */}
                  {expandedInkling.shared_with &&
                    (expandedInkling.shared_with.players.length > 0 || expandedInkling.shared_with.groups.length > 0) && (
                    <div className="shared-with-section">
                      <h3>Shared With</h3>
                      {expandedInkling.shared_with.players.length > 0 && (
                        <div className="shared-with-row">
                          <span className="shared-with-label">Players:</span> {expandedInkling.shared_with.players.join(', ')}
                        </div>
                      )}
                      {expandedInkling.shared_with.groups.length > 0 && (
                        <div className="shared-with-row">
                          <span className="shared-with-label">Groups:</span> {expandedInkling.shared_with.groups.join(', ')}
                        </div>
                      )}
                    </div>
                  )}

                  {/* Rolls — available on any inkling */}
                  {expandedInkling.rolls && expandedInkling.rolls.length > 0 && (
                    <div className="rolls-section">
                      <h3>Rolls</h3>
                      {expandedInkling.rolls.map(roll => (
                        <div key={roll.id} className={`roll ${roll.private ? 'private' : 'public'}`}>
                          <div className="roll-header">
                            <span className="message-ref">#{roll.ref}</span>
                            <strong>{roll.roll_spec}</strong>
                            {roll.private && <span className="private-badge">PRIVATE</span>}
                            <span className="roll-result">{roll.result}</span>
                            <span className="roll-meta">by {roll.creator}</span>
                          </div>
                          {roll.reroll_count > 0 && (
                            <div className="roll-reroll-info">
                              Rerolled {roll.reroll_count} time{roll.reroll_count !== 1 ? 's' : ''}
                              {roll.luck_cost > 0 && ` (cost: ${roll.luck_cost} luck)`}
                            </div>
                          )}
                          {roll.roll_type === 'player' && roll.character_id && roll.character_id === roll.creator_id && expandedInkling.status === 'open' && (
                            <button
                              className="btn btn-small btn-secondary"
                              onClick={() => handleRerollWithLuck(expandedInkling.id, roll.id)}
                            >
                              Reroll with Luck
                            </button>
                          )}
                        </div>
                      ))}
                    </div>
                  )}

                  <div className="messages-section">
                    {expandedInkling.messages && expandedInkling.messages.map(msg => (
                      <div key={msg.id} className={`message ${msg.is_staff ? 'staff' : 'player'} ${msg.is_private ? 'private' : ''}`}>
                        <div className="message-header">
                          <span className="message-ref">#{msg.ref}</span>
                          <strong>{msg.author}</strong>
                          {msg.is_staff && <span className="staff-badge">STAFF</span>}
                          {msg.is_gm_note && <span className="staff-badge">GM</span>}
                          {msg.is_private && (
                            <span className="private-badge">
                              {msg.private_recipient_names && msg.private_recipient_names.length > 0
                                ? `PRIVATE TO ${msg.private_recipient_names.join(', ').toUpperCase()}`
                                : !msg.is_staff
                                  ? 'PRIVATE TO STAFF'
                                  : 'PRIVATE'}
                            </span>
                          )}
                          <span className="message-time">
                            {new Date(msg.created_at).toLocaleString()}
                          </span>
                        </div>
                        <div className="message-text">{msg.text}</div>
                      </div>
                    ))}
                  </div>

                  {expandedInkling.status === 'open' && (
                    <>
                      <div className="roll-form-section">
                          {!showRollForm ? (
                            <button
                              className="btn btn-success"
                              onClick={() => setShowRollForm(true)}
                            >
                              + Add Roll
                            </button>
                          ) : (
                            <div className="roll-form">
                              <div className="form-group">
                                <label>Roll Type</label>
                                <select
                                  value={newRoll.rollType}
                                  onChange={(e) => setNewRoll({ ...newRoll, rollType: e.target.value })}
                                >
                                  <option value="player">My Roll</option>
                                  {isStaff && <option value="npc">NPC Roll</option>}
                                  {isStaff && <option value="static">Static Number</option>}
                                </select>
                              </div>

                              {newRoll.rollType === 'player' && (
                                <div className="form-group">
                                  <label>Attribute/Skill</label>
                                  {fs3Attributes.length > 0 ? (
                                    <select
                                      value={newRoll.rollSpec}
                                      onChange={(e) => setNewRoll({ ...newRoll, rollSpec: e.target.value })}
                                    >
                                      <option value="">Select an attribute</option>
                                      {fs3Attributes.map(attr => (
                                        <option key={attr} value={attr}>
                                          {attr}
                                        </option>
                                      ))}
                                    </select>
                                  ) : (
                                    <input
                                      type="text"
                                      value={newRoll.rollSpec}
                                      onChange={(e) => setNewRoll({ ...newRoll, rollSpec: e.target.value })}
                                      placeholder="Enter attribute/skill name"
                                    />
                                  )}
                                </div>
                              )}

                               {newRoll.rollType === 'npc' && (
                                <div className="form-group">
                                  <label>Character (optional)</label>
                                  <input
                                    type="text"
                                    value={newRoll.npcCharId}
                                    onChange={(e) => setNewRoll({ ...newRoll, npcCharId: e.target.value })}
                                    placeholder="Character name or ID"
                                  />
                                </div>
                              )}

                              {(newRoll.rollType === 'npc' || newRoll.rollType === 'static') && (
                                <div className="form-group">
                                  <label>Skill / Attribute</label>
                                  <input
                                    type="text"
                                    value={newRoll.rollSpec}
                                    onChange={(e) => setNewRoll({ ...newRoll, rollSpec: e.target.value })}
                                    placeholder={newRoll.rollType === 'static' ? 'Description' : 'Skill or attribute rolled'}
                                  />
                                </div>
                              )}

                              {(newRoll.rollType === 'npc' || newRoll.rollType === 'static') && (
                                <div className="form-group">
                                  <label>{newRoll.rollType === 'static' ? 'Number' : 'Result'}</label>
                                  <input
                                    type="text"
                                    value={newRoll.npcResult}
                                    onChange={(e) => setNewRoll({ ...newRoll, npcResult: e.target.value })}
                                    placeholder={newRoll.rollType === 'static' ? 'Enter a number' : 'e.g. Good (7)'}
                                  />
                                </div>
                              )}

                              <div className="form-group checkbox">
                                <label>
                                  <input
                                    type="checkbox"
                                    checked={newRoll.isPrivate}
                                    onChange={(e) => setNewRoll({ ...newRoll, isPrivate: e.target.checked })}
                                  />
                                  Private (only visible to player and staff)
                                </label>
                              </div>

                              <div className="form-actions">
                                <button
                                  className="btn btn-success"
                                  onClick={() => handleAddRoll(expandedInkling.id)}
                                >
                                  Add Roll
                                </button>
                                <button
                                  className="btn btn-secondary"
                                  onClick={() => setShowRollForm(false)}
                                >
                                  Cancel
                                </button>
                              </div>
                            </div>
                          )}
                        </div>
                      </div>

                      <div className="reply-section">
                        <textarea
                          value={replyText[expandedInkling.id] || ''}
                          onChange={(e) => setReplyText({ ...replyText, [expandedInkling.id]: e.target.value })}
                          placeholder="Add a reply..."
                          rows="3"
                        />
                        <div className="reply-actions">
                          <label className="private-checkbox">
                            <input
                              type="checkbox"
                              checked={privateReply[expandedInkling.id] || false}
                              onChange={(e) => setPrivateReply({ ...privateReply, [expandedInkling.id]: e.target.checked })}
                            />
                            Private (only you and staff can see this)
                          </label>
                          <button
                            className="btn btn-success"
                            onClick={() => handleReplyToInkling(expandedInkling.id, privateReply[expandedInkling.id] || false)}
                          >
                            Add Reply
                          </button>
                        </div>
                      </div>
                    </>
                  )}

                  {(expandedInkling.status === 'open' && (isStaff || expandedInkling.character_id === viewerId)) && (
                    <div className="inkling-actions">
                      <div className="share-form">
                        <input
                          type="text"
                          value={shareTarget[expandedInkling.id] || ''}
                          onChange={(e) => setShareTarget({ ...shareTarget, [expandedInkling.id]: e.target.value })}
                          placeholder="Share with character(s)..."
                        />
                        <button
                          className="btn btn-secondary"
                          onClick={() => handleShareInkling(expandedInkling.id)}
                        >
                          Share
                        </button>
                      </div>
                      <button
                        className="btn btn-warning"
                        onClick={() => handleCloseInkling(expandedInkling.id)}
                      >
                        Close Inkling
                      </button>
                    </div>
                  )}

                  {(isStaff || expandedInkling.character_id === viewerId) && (
                    <div className="inkling-actions inkling-actions-danger">
                      <button
                        className="btn btn-danger"
                        onClick={() => handleDeleteInkling(expandedInkling.id)}
                      >
                        Delete Inkling
                      </button>
                    </div>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
