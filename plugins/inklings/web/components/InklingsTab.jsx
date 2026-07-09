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
