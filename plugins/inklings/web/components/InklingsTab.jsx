import React, { useState, useEffect } from 'react';
import { api } from '@/api';
import './InklingsTab.css';

export const InklingsTab = ({ characterId, viewerId, isStaff }) => {
  const [inklings, setInklings] = useState([]);
  const [expandedId, setExpandedId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showNewForm, setShowNewForm] = useState(false);
  const [newInkling, setNewInkling] = useState({ kind: 'goal', text: '' });
  const [replyText, setReplyText] = useState({});
  const [fs3Attributes, setFs3Attributes] = useState([]);
  const [showRollForm, setShowRollForm] = useState(false);
  const [newRoll, setNewRoll] = useState({
    rollType: 'player',
    rollSpec: '',
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
    goal: 'Goal',
    roll: 'Roll'
  };

  const staffKinds = ['hint', 'vision', 'nudge', 'hook'];
  const playerKinds = ['action', 'research', 'request', 'update', 'pitch', 'goal'];
  const allKinds = [...staffKinds, ...playerKinds, 'secret', 'roll'];

  useEffect(() => {
    loadInklings();
    loadFS3Attributes();
  }, [characterId]);

  const loadInklings = async () => {
    try {
      setLoading(true);
      const response = await api.get(`/api/characters/${characterId}/inklings?viewer_id=${viewerId}`);
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
    if (!newInkling.text.trim()) {
      setError('Please enter inkling text');
      return;
    }

    try {
      const response = await api.post(`/api/characters/${characterId}/inklings`, {
        kind: newInkling.kind,
        text: newInkling.text,
        viewer_id: viewerId
      });
      setInklings([response.data.inkling, ...inklings]);
      setNewInkling({ kind: 'goal', text: '' });
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

  const handleReplyToInkling = async (id) => {
    const text = replyText[id];
    if (!text || !text.trim()) {
      setError('Please enter reply text');
      return;
    }

    try {
      const response = await api.post(`/api/characters/${characterId}/inklings/${id}/reply`, {
        text: text,
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

    try {
      // For player rolls, we need to actually roll
      let result, resultValue;
      
      if (newRoll.rollType === 'player') {
        // Call FS3 API to roll the skill/attribute
        const rollResponse = await api.post(`/api/characters/${characterId}/roll`, {
          attribute: newRoll.rollSpec,
          viewer_id: viewerId
        });
        result = rollResponse.data.result;
        resultValue = rollResponse.data.result_value;
      } else {
        // Staff is entering the result manually
        result = newRoll.rollSpec;
        resultValue = parseInt(newRoll.rollSpec) || 0;
      }

      const response = await api.post(
        `/api/characters/${characterId}/inklings/${inklingId}/roll`,
        {
          roll_type: newRoll.rollType,
          roll_spec: newRoll.rollSpec,
          result: result,
          result_value: resultValue,
          is_private: newRoll.isPrivate,
          viewer_id: viewerId
        }
      );

      // Reload the expanded inkling
      const fullResponse = await api.get(`/api/characters/${characterId}/inklings/${inklingId}?viewer_id=${viewerId}`);
      setInklings(inklings.map(i => i.id === inklingId ? fullResponse.data.inkling : i));
      setNewRoll({ rollType: 'player', rollSpec: '', isPrivate: false });
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

  const expandedInkling = expandedId ? inklings.find(i => i.id === expandedId) : null;

  if (loading) {
    return <div className="inklings-tab">Loading inklings...</div>;
  }

  return (
    <div className="inklings-tab">
      {error && <div className="error-message">{error}</div>}

      <div className="inklings-header">
        <h2>Inklings</h2>
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
              {allKinds.map(kind => (
                <option key={kind} value={kind}>
                  {kindDisplayNames[kind]}
                </option>
              ))}
            </select>
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
                  <span className={`inkling-status ${inkling.status}`}>
                    {inkling.status}
                  </span>
                  {inkling.player_unread && (
                    <span className="unread-badge">unread</span>
                  )}
                  <span className="message-count">
                    {inkling.message_count} message{inkling.message_count !== 1 ? 's' : ''}
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
                  {/* Display rolls if this is a roll inkling */}
                  {expandedInkling.kind === 'roll' && expandedInkling.rolls && expandedInkling.rolls.length > 0 && (
                    <div className="rolls-section">
                      <h3>Rolls</h3>
                      {expandedInkling.rolls.map(roll => (
                        <div key={roll.id} className={`roll ${roll.private ? 'private' : 'public'}`}>
                          <div className="roll-header">
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
                          {roll.roll_type === 'player' && roll.character === roll.creator && expandedInkling.status === 'open' && (
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
                      <div key={msg.id} className={`message ${msg.is_staff ? 'staff' : 'player'}`}>
                        <div className="message-header">
                          <strong>{msg.author}</strong>
                          {msg.is_staff && <span className="staff-badge">STAFF</span>}
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
                      {expandedInkling.kind === 'roll' && (
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

                              {(newRoll.rollType === 'npc' || newRoll.rollType === 'static') && (
                                <div className="form-group">
                                  <label>{newRoll.rollType === 'npc' ? 'Character / Result' : 'Number'}</label>
                                  <input
                                    type="text"
                                    value={newRoll.rollSpec}
                                    onChange={(e) => setNewRoll({ ...newRoll, rollSpec: e.target.value })}
                                    placeholder={newRoll.rollType === 'npc' ? 'NPC name or ID' : 'Enter a number'}
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
                      )}

                      <div className="reply-section">
                        <textarea
                          value={replyText[expandedInkling.id] || ''}
                          onChange={(e) => setReplyText({ ...replyText, [expandedInkling.id]: e.target.value })}
                          placeholder="Add a reply..."
                          rows="3"
                        />
                        <button
                          className="btn btn-success"
                          onClick={() => handleReplyToInkling(expandedInkling.id)}
                        >
                          Add Reply
                        </button>
                      </div>
                    </>
                  )}

                  {(expandedInkling.status === 'open' && isStaff) && (
                    <div className="inkling-actions">
                      <button
                        className="btn btn-danger"
                        onClick={() => handleCloseInkling(expandedInkling.id)}
                      >
                        Close Inkling
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
