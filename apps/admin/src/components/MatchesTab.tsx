import React, { useState, useEffect } from 'react';
import { Eye, X, Trophy } from 'lucide-react';
import { adminClient } from '../api/adminClient';
import { AdminMatchDetail, AdminMatchSummary } from '../types/admin';

export const MatchesTab: React.FC = () => {
  const [matches, setMatches] = useState<AdminMatchSummary[]>([]);
  const [modeFilter, setModeFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [selectedMatch, setSelectedMatch] = useState<AdminMatchDetail | null>(null);

  const loadMatches = async () => {
    setIsLoading(true);
    try {
      const data = await adminClient.listMatches(statusFilter || undefined, modeFilter || undefined);
      setMatches(data);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadMatches();
  }, [modeFilter, statusFilter]);

  const handleInspectMatch = async (matchId: string) => {
    try {
      const detail = await adminClient.getMatchDetail(matchId);
      setSelectedMatch(detail);
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <div className="panel">
      <div className="panel-header">
        <h2 className="panel-title">Matches &amp; Game Timeline Inspection</h2>

        <div className="panel-controls">
          <select
            className="select-input"
            value={modeFilter}
            onChange={(e) => setModeFilter(e.target.value)}
          >
            <option value="">All Modes</option>
            <option value="CLASSIC">Classic (2-6P)</option>
            <option value="QUICK">Quick Mode</option>
            <option value="TEAM">2v2 Team Mode</option>
          </select>

          <select
            className="select-input"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="">All Statuses</option>
            <option value="IN_PROGRESS">In Progress</option>
            <option value="FINISHED">Finished</option>
            <option value="ABANDONED">Abandoned</option>
          </select>
        </div>
      </div>

      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>Match ID</th>
              <th>Mode</th>
              <th>Players</th>
              <th>Status</th>
              <th>Winner</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr>
                <td colSpan={7} style={{ textAlign: 'center', padding: '32px' }}>
                  Loading matches...
                </td>
              </tr>
            ) : matches.length === 0 ? (
              <tr>
                <td colSpan={7} style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>
                  No matches found.
                </td>
              </tr>
            ) : (
              matches.map((m) => (
                <tr key={m.id}>
                  <td>
                    <code>{m.id.slice(0, 8)}...</code>
                  </td>
                  <td>
                    <span className="badge badge-cyan">{m.mode}</span>
                  </td>
                  <td>
                    {m.player_count} Players
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                      Seats: {m.players.map((p) => p.color).join(', ')}
                    </div>
                  </td>
                  <td>
                    <span
                      className={`badge ${
                        m.status === 'FINISHED'
                          ? 'badge-active'
                          : m.status === 'IN_PROGRESS'
                          ? 'badge-pending'
                          : 'badge-suspended'
                      }`}
                    >
                      {m.status}
                    </span>
                  </td>
                  <td>
                    {m.winning_color ? (
                      <span style={{ color: 'var(--accent-amber)', fontWeight: 600 }}>
                        <Trophy size={13} style={{ verticalAlign: 'middle', marginRight: '4px' }} />
                        {m.winning_color}
                      </span>
                    ) : (
                      <span style={{ color: 'var(--text-muted)' }}>In progress</span>
                    )}
                  </td>
                  <td style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                    {new Date(m.created_at).toLocaleTimeString()}
                  </td>
                  <td>
                    <button
                      className="btn btn-secondary btn-sm"
                      title="Inspect Match Timeline"
                      onClick={() => handleInspectMatch(m.id)}
                    >
                      <Eye size={13} />
                      <span>Timeline</span>
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Match Timeline Modal */}
      {selectedMatch && (
        <div className="modal-overlay" onClick={() => setSelectedMatch(null)}>
          <div className="modal-card" style={{ maxWidth: '750px' }} onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <div>
                <h3>Match Review: <code>{selectedMatch.id.slice(0, 12)}...</code></h3>
                <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
                  Mode: <strong>{selectedMatch.mode}</strong> | Status: <strong>{selectedMatch.status}</strong> | Winner: <strong>{selectedMatch.winning_color || 'None'}</strong>
                </div>
              </div>
              <button
                onClick={() => setSelectedMatch(null)}
                style={{ background: 'transparent', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer' }}
              >
                <X size={20} />
              </button>
            </div>

            <div className="modal-body" style={{ maxHeight: '600px', overflowY: 'auto' }}>
              <h4 style={{ fontSize: '15px', color: 'var(--accent-cyan)' }}>Authoritative Event Timeline ({selectedMatch.events.length} Events)</h4>
              
              {selectedMatch.events.length === 0 ? (
                <div style={{ color: 'var(--text-muted)', fontSize: '13px', padding: '16px 0' }}>
                  No realtime events recorded for this match.
                </div>
              ) : (
                <div className="timeline">
                  {selectedMatch.events.map((e, idx) => {
                    const isCapture = e.event_type === 'TOKEN_CAPTURED';
                    const isHome = e.event_type === 'TOKEN_HOME';
                    const isWin = e.event_type === 'MATCH_FINISHED';

                    return (
                      <div key={idx} className="timeline-item">
                        <div className="timeline-dot" style={{
                          backgroundColor: isWin ? 'var(--accent-amber)' : isCapture ? 'var(--accent-rose)' : isHome ? 'var(--accent-emerald)' : 'var(--accent-cyan)'
                        }} />
                        <div className="timeline-content">
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                            <strong style={{ fontSize: '13px', color: 'var(--text-primary)' }}>
                              #{e.sequence} - {e.event_type}
                            </strong>
                            <span style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                              {new Date(e.created_at).toLocaleTimeString()}
                            </span>
                          </div>

                          <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '6px', fontFamily: 'monospace' }}>
                            {JSON.stringify(e.payload)}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>

            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setSelectedMatch(null)}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
