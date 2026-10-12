import React, { useState, useEffect } from 'react';
import { ToggleLeft, ToggleRight, X } from 'lucide-react';
import { adminClient } from '../api/adminClient';
import { AdminUser } from '../types/admin';

interface ConfigTabProps {
  admin: AdminUser | null;
}

export const ConfigTab: React.FC<ConfigTabProps> = ({ admin }) => {
  const [remoteConfig, setRemoteConfig] = useState<Record<string, { value: string; description?: string }>>({});
  const [featureFlags, setFeatureFlags] = useState<Record<string, { enabled: boolean; description?: string }>>({});
  const [editingKey, setEditingKey] = useState<string | null>(null);
  const [editValue, setEditValue] = useState('');
  const [editDesc, setEditDesc] = useState('');

  const [message, setMessage] = useState<{ text: string; type: 'success' | 'error' } | null>(null);

  const loadConfig = async () => {
    try {
      const data = await adminClient.getConfigAndFlags();
      setRemoteConfig(data.remote_config || {});
      setFeatureFlags(data.feature_flags || {});
    } catch (err: any) {
      setMessage({ text: err.message || 'Failed to load config', type: 'error' });
    }
  };

  useEffect(() => {
    loadConfig();
  }, []);

  const handleToggleFlag = async (flagName: string, currentEnabled: boolean, desc?: string) => {
    try {
      await adminClient.toggleFeatureFlag(flagName, !currentEnabled, desc);
      setFeatureFlags((prev) => ({
        ...prev,
        [flagName]: { ...prev[flagName], enabled: !currentEnabled },
      }));
      setMessage({ text: `Feature flag "${flagName}" set to ${!currentEnabled}`, type: 'success' });
    } catch (err: any) {
      setMessage({ text: err.message || 'Failed to toggle flag', type: 'error' });
    }
  };

  const handleSaveConfig = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingKey) return;
    try {
      await adminClient.updateRemoteConfig(editingKey, editValue, editDesc);
      setRemoteConfig((prev) => ({
        ...prev,
        [editingKey]: { value: editValue, description: editDesc },
      }));
      setMessage({ text: `Remote config "${editingKey}" updated`, type: 'success' });
      setEditingKey(null);
    } catch (err: any) {
      setMessage({ text: err.message || 'Failed to update remote config', type: 'error' });
    }
  };

  const isSuperAdmin = admin?.role === 'SUPER_ADMIN';

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      {message && (
        <div
          style={{
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

      {/* Feature Flags Section */}
      <div className="panel">
        <div className="panel-header">
          <div>
            <h2 className="panel-title">Live Feature Flags</h2>
            <div style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '2px' }}>
              Instantly toggle live functionality without client updates
            </div>
          </div>
        </div>

        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Flag Name</th>
                <th>Description</th>
                <th>Status</th>
                {isSuperAdmin && <th>Toggle</th>}
              </tr>
            </thead>
            <tbody>
              {Object.keys(featureFlags).length === 0 ? (
                <tr>
                  <td colSpan={4} style={{ textAlign: 'center', padding: '24px', color: 'var(--text-muted)' }}>
                    No feature flags defined.
                  </td>
                </tr>
              ) : (
                Object.entries(featureFlags).map(([name, flag]) => (
                  <tr key={name}>
                    <td>
                      <code>{name}</code>
                    </td>
                    <td style={{ color: 'var(--text-secondary)' }}>{flag.description || '-'}</td>
                    <td>
                      <span className={`badge ${flag.enabled ? 'badge-active' : 'badge-suspended'}`}>
                        {flag.enabled ? 'Enabled' : 'Disabled'}
                      </span>
                    </td>
                    {isSuperAdmin && (
                      <td>
                        <button
                          className={`btn btn-sm ${flag.enabled ? 'btn-danger' : 'btn-primary'}`}
                          onClick={() => handleToggleFlag(name, flag.enabled, flag.description)}
                        >
                          {flag.enabled ? (
                            <>
                              <ToggleLeft size={14} /> Disable
                            </>
                          ) : (
                            <>
                              <ToggleRight size={14} /> Enable
                            </>
                          )}
                        </button>
                      </td>
                    )}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Remote Config Section */}
      <div className="panel">
        <div className="panel-header">
          <div>
            <h2 className="panel-title">Remote Configuration Parameters</h2>
            <div style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '2px' }}>
              App version minimums, announcement banners, turn timeout parameters
            </div>
          </div>
        </div>

        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Config Key</th>
                <th>Value</th>
                <th>Description</th>
                {isSuperAdmin && <th>Edit</th>}
              </tr>
            </thead>
            <tbody>
              {Object.keys(remoteConfig).length === 0 ? (
                <tr>
                  <td colSpan={4} style={{ textAlign: 'center', padding: '24px', color: 'var(--text-muted)' }}>
                    No remote configs defined.
                  </td>
                </tr>
              ) : (
                Object.entries(remoteConfig).map(([key, item]) => (
                  <tr key={key}>
                    <td>
                      <code>{key}</code>
                    </td>
                    <td>
                      <code style={{ color: 'var(--accent-cyan)' }}>{item.value}</code>
                    </td>
                    <td style={{ color: 'var(--text-secondary)' }}>{item.description || '-'}</td>
                    {isSuperAdmin && (
                      <td>
                        <button
                          className="btn btn-secondary btn-sm"
                          onClick={() => {
                            setEditingKey(key);
                            setEditValue(item.value);
                            setEditDesc(item.description || '');
                          }}
                        >
                          Edit
                        </button>
                      </td>
                    )}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Edit Config Modal */}
      {editingKey && (
        <div className="modal-overlay" onClick={() => setEditingKey(null)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <form onSubmit={handleSaveConfig}>
              <div className="modal-header">
                <h3>Edit Remote Config: <code>{editingKey}</code></h3>
                <button
                  type="button"
                  onClick={() => setEditingKey(null)}
                  style={{ background: 'transparent', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer' }}
                >
                  <X size={20} />
                </button>
              </div>

              <div className="modal-body">
                <div>
                  <label className="kpi-label">Value</label>
                  <textarea
                    required
                    className="search-input"
                    style={{ width: '100%', minHeight: '80px', marginTop: '6px', fontFamily: 'monospace' }}
                    value={editValue}
                    onChange={(e) => setEditValue(e.target.value)}
                  />
                </div>

                <div>
                  <label className="kpi-label">Description</label>
                  <input
                    type="text"
                    className="search-input"
                    style={{ width: '100%', marginTop: '6px' }}
                    value={editDesc}
                    onChange={(e) => setEditDesc(e.target.value)}
                  />
                </div>
              </div>

              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setEditingKey(null)}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary">
                  Save Changes
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
