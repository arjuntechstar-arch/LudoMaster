import React, { useState, useEffect } from 'react';
import { Ban, XCircle, AlertTriangle, X } from 'lucide-react';
import { adminClient } from '../api/adminClient';
import { AdminReport, AdminUser } from '../types/admin';

interface ModerationTabProps {
  admin: AdminUser | null;
  onActionComplete: () => void;
}

export const ModerationTab: React.FC<ModerationTabProps> = ({ admin, onActionComplete }) => {
  const [reports, setReports] = useState<AdminReport[]>([]);
  const [statusFilter, setStatusFilter] = useState<'PENDING' | 'RESOLVED' | 'DISMISSED' | ''>('PENDING');
  const [isLoading, setIsLoading] = useState(false);
  const [message, setMessage] = useState<{ text: string; type: 'success' | 'error' } | null>(null);

  const loadReports = async () => {
    setIsLoading(true);
    try {
      const data = await adminClient.listReports(statusFilter || undefined);
      setReports(data);
    } catch (err: any) {
      setMessage({ text: err.message || 'Failed to load reports', type: 'error' });
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadReports();
  }, [statusFilter]);

  const handleAction = async (reportId: string, action: 'DISMISS' | 'SUSPEND_USER' | 'WARN') => {
    try {
      await adminClient.actionReport(reportId, action, `Actioned by ${admin?.username || 'admin'}`);
      setMessage({
        text: `Report ${action === 'DISMISS' ? 'dismissed' : 'resolved with ' + action}`,
        type: 'success',
      });
      loadReports();
      onActionComplete();
    } catch (err: any) {
      setMessage({ text: err.message || 'Failed to process report', type: 'error' });
    }
  };

  return (
    <div className="panel">
      <div className="panel-header">
        <h2 className="panel-title">Reports &amp; Moderation Queue</h2>

        <div className="panel-controls">
          <select
            className="select-input"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as any)}
          >
            <option value="PENDING">Pending &amp; Open</option>
            <option value="RESOLVED">Resolved</option>
            <option value="DISMISSED">Dismissed</option>
            <option value="">All Reports</option>
          </select>
        </div>
      </div>

      {message && (
        <div
          style={{
            margin: '16px 24px 0',
            padding: '12px 16px',
            borderRadius: '8px',
            backgroundColor: message.type === 'success' ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
            color: message.type === 'success' ? 'var(--accent-emerald)' : 'var(--accent-rose)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <span>{message.text}</span>
          <button
            onClick={() => setMessage(null)}
            style={{ background: 'transparent', border: 'none', color: 'inherit', cursor: 'pointer' }}
          >
            <X size={16} />
          </button>
        </div>
      )}

      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>Report ID</th>
              <th>Category</th>
              <th>Reported Player</th>
              <th>Description / Reason</th>
              <th>Status</th>
              <th>Date</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr>
                <td colSpan={7} style={{ textAlign: 'center', padding: '32px' }}>
                  Loading moderation reports...
                </td>
              </tr>
            ) : reports.length === 0 ? (
              <tr>
                <td colSpan={7} style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>
                  No reports in this queue. Great job!
                </td>
              </tr>
            ) : (
              reports.map((r) => {
                const isOpen = r.status === 'OPEN' || r.status === 'PENDING';
                return (
                  <tr key={r.id}>
                    <td>
                      <code>{r.id.slice(0, 8)}...</code>
                    </td>
                    <td>
                      <span className="badge badge-purple">{r.category}</span>
                    </td>
                    <td>
                      <div style={{ fontWeight: 600 }}><code>{r.reported_user_id.slice(0, 12)}...</code></div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
                        By: <code>{r.reporter_id.slice(0, 8)}...</code>
                      </div>
                    </td>
                    <td style={{ maxWidth: '280px' }}>
                      <div style={{ fontSize: '13px', color: 'var(--text-primary)' }}>
                        {r.description || r.reason || 'No description provided.'}
                      </div>
                      {r.match_id && (
                        <div style={{ fontSize: '11px', color: 'var(--accent-cyan)' }}>
                          Match ID: <code>{r.match_id.slice(0, 8)}...</code>
                        </div>
                      )}
                    </td>
                    <td>
                      <span
                        className={`badge ${
                          isOpen ? 'badge-suspended' : r.status === 'RESOLVED' ? 'badge-active' : 'badge-pending'
                        }`}
                      >
                        {r.status}
                      </span>
                    </td>
                    <td style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                      {new Date(r.created_at).toLocaleString()}
                    </td>
                    <td>
                      {isOpen ? (
                        <div style={{ display: 'flex', gap: '6px' }}>
                          <button
                            className="btn btn-danger btn-sm"
                            title="Suspend Player"
                            onClick={() => handleAction(r.id, 'SUSPEND_USER')}
                          >
                            <Ban size={13} />
                            <span>Suspend</span>
                          </button>
                          <button
                            className="btn btn-primary btn-sm"
                            title="Issue Warning"
                            onClick={() => handleAction(r.id, 'WARN')}
                          >
                            <AlertTriangle size={13} />
                            <span>Warn</span>
                          </button>
                          <button
                            className="btn btn-secondary btn-sm"
                            title="Dismiss Report"
                            onClick={() => handleAction(r.id, 'DISMISS')}
                          >
                            <XCircle size={13} />
                            <span>Dismiss</span>
                          </button>
                        </div>
                      ) : (
                        <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Actioned</span>
                      )}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};
