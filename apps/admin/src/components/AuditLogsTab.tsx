import React, { useState, useEffect } from 'react';
import { adminClient } from '../api/adminClient';
import { AdminAuditLog } from '../types/admin';

export const AuditLogsTab: React.FC = () => {
  const [logs, setLogs] = useState<AdminAuditLog[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const loadLogs = async () => {
    setIsLoading(true);
    try {
      const data = await adminClient.listAuditLogs();
      setLogs(data);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadLogs();
  }, []);

  return (
    <div className="panel">
      <div className="panel-header">
        <div>
          <h2 className="panel-title">Administrative Audit Trail</h2>
          <div style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '2px' }}>
            Immutable record of all privileged administrative actions and moderation events
          </div>
        </div>
      </div>

      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>Timestamp</th>
              <th>Admin</th>
              <th>Action</th>
              <th>Target Type</th>
              <th>Target ID</th>
              <th>Details</th>
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr>
                <td colSpan={6} style={{ textAlign: 'center', padding: '32px' }}>
                  Loading audit logs...
                </td>
              </tr>
            ) : logs.length === 0 ? (
              <tr>
                <td colSpan={6} style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>
                  No audit logs recorded yet.
                </td>
              </tr>
            ) : (
              logs.map((log) => (
                <tr key={log.id}>
                  <td style={{ fontSize: '12px', color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                    {new Date(log.created_at).toLocaleString()}
                  </td>
                  <td>
                    <strong>{log.admin_username}</strong>
                  </td>
                  <td>
                    <span className="badge badge-purple">{log.action}</span>
                  </td>
                  <td>
                    <span className="badge badge-cyan">{log.target_type}</span>
                  </td>
                  <td>
                    {log.target_id ? <code>{log.target_id.slice(0, 16)}...</code> : '-'}
                  </td>
                  <td style={{ maxWidth: '350px' }}>
                    <code style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                      {log.details || '-'}
                    </code>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};
