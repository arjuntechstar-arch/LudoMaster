import React, { useState, useEffect } from 'react';
import {
  Search,
  UserX,
  UserCheck,
  Coins,
  Smartphone,
  Eye,
  X,
} from 'lucide-react';
import { adminClient } from '../api/adminClient';
import { AdminUser, AdminUserDetail, AdminUserSummary } from '../types/admin';

interface UsersTabProps {
  admin: AdminUser | null;
  onActionComplete: () => void;
}

export const UsersTab: React.FC<UsersTabProps> = ({ admin, onActionComplete }) => {
  const [users, setUsers] = useState<AdminUserSummary[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  // Modals state
  const [selectedUser, setSelectedUser] = useState<AdminUserDetail | null>(null);
  const [suspendModalUserId, setSuspendModalUserId] = useState<string | null>(null);
  const [suspendReason, setSuspendReason] = useState('');
  const [suspendDays, setSuspendDays] = useState<number>(7);

  const [walletModalUserId, setWalletModalUserId] = useState<string | null>(null);
  const [walletAmount, setWalletAmount] = useState<number>(500);
  const [walletCurrency, setWalletCurrency] = useState<'COINS' | 'GEMS'>('COINS');
  const [walletReason, setWalletReason] = useState('');

  const [message, setMessage] = useState<{ text: string; type: 'success' | 'error' } | null>(null);

  const loadUsers = async () => {
    setIsLoading(true);
    try {
      const data = await adminClient.listUsers(searchQuery || undefined, statusFilter || undefined);
      setUsers(data);
    } catch (err: any) {
      setMessage({ text: err.message || 'Failed to load users', type: 'error' });
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadUsers();
  }, [statusFilter]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    loadUsers();
  };

  const handleViewDetail = async (userId: string) => {
    try {
      const detail = await adminClient.getUserDetail(userId);
      setSelectedUser(detail);
    } catch (err: any) {
      setMessage({ text: err.message || 'Failed to load user details', type: 'error' });
    }
  };

  const handleSuspendSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!suspendModalUserId || !suspendReason) return;
    try {
      await adminClient.suspendUser(suspendModalUserId, suspendReason, suspendDays);
      setMessage({ text: `User ${suspendModalUserId} has been suspended`, type: 'success' });
      setSuspendModalUserId(null);
      setSuspendReason('');
      loadUsers();
      onActionComplete();
    } catch (err: any) {
      setMessage({ text: err.message || 'Failed to suspend user', type: 'error' });
    }
  };

  const handleUnsuspend = async (userId: string) => {
    try {
      await adminClient.unsuspendUser(userId);
      setMessage({ text: `User ${userId} has been unsuspended`, type: 'success' });
      loadUsers();
      onActionComplete();
    } catch (err: any) {
      setMessage({ text: err.message || 'Failed to unsuspend user', type: 'error' });
    }
  };

  const handleWalletSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!walletModalUserId || !walletReason) return;
    try {
      await adminClient.adjustUserWallet(walletModalUserId, walletAmount, walletCurrency, walletReason);
      setMessage({
        text: `Wallet adjusted successfully: ${walletAmount > 0 ? '+' : ''}${walletAmount} ${walletCurrency}`,
        type: 'success',
      });
      setWalletModalUserId(null);
      setWalletReason('');
      loadUsers();
      onActionComplete();
    } catch (err: any) {
      setMessage({ text: err.message || 'Failed to adjust wallet', type: 'error' });
    }
  };

  const isSuperAdmin = admin?.role === 'SUPER_ADMIN';

  return (
    <div className="panel">
      <div className="panel-header">
        <h2 className="panel-title">Players &amp; Account Management</h2>

        <form onSubmit={handleSearch} className="panel-controls">
          <input
            type="text"
            className="search-input"
            placeholder="Search Player ID or Name..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
          <select
            className="select-input"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="">All Statuses</option>
            <option value="ACTIVE">Active</option>
            <option value="SUSPENDED">Suspended</option>
          </select>
          <button type="submit" className="btn btn-primary btn-sm">
            <Search size={14} />
            <span>Search</span>
          </button>
        </form>
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
              <th>Player</th>
              <th>Status</th>
              <th>Level / XP</th>
              <th>Coins / Gems</th>
              <th>Win Ratio</th>
              <th>Type</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr>
                <td colSpan={7} style={{ textAlign: 'center', padding: '32px' }}>
                  Loading players...
                </td>
              </tr>
            ) : users.length === 0 ? (
              <tr>
                <td colSpan={7} style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>
                  No players found matching your criteria.
                </td>
              </tr>
            ) : (
              users.map((u) => {
                const winRate =
                  u.matches_played > 0
                    ? `${Math.round((u.matches_won / u.matches_played) * 100)}%`
                    : '0%';
                return (
                  <tr key={u.id}>
                    <td>
                      <div style={{ fontWeight: 600 }}>{u.display_name}</div>
                      <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                        ID: <code>{u.player_id}</code>
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${u.status === 'ACTIVE' ? 'badge-active' : 'badge-suspended'}`}>
                        {u.status}
                      </span>
                    </td>
                    <td>Level {u.level}</td>
                    <td>
                      <span style={{ color: 'var(--accent-amber)', fontWeight: 600 }}>
                        {u.coins.toLocaleString()} C
                      </span>
                      {' / '}
                      <span style={{ color: 'var(--accent-purple)', fontWeight: 600 }}>
                        {u.gems.toLocaleString()} G
                      </span>
                    </td>
                    <td>
                      {u.matches_won} / {u.matches_played} ({winRate})
                    </td>
                    <td>
                      <span className="badge badge-cyan">{u.is_guest ? 'Guest' : 'Verified'}</span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '6px' }}>
                        <button
                          className="btn btn-secondary btn-sm"
                          title="View Details"
                          onClick={() => handleViewDetail(u.id)}
                        >
                          <Eye size={13} />
                        </button>

                        {u.status === 'ACTIVE' ? (
                          <button
                            className="btn btn-danger btn-sm"
                            title="Suspend Player"
                            onClick={() => {
                              setSuspendModalUserId(u.id);
                              setSuspendReason('');
                            }}
                          >
                            <UserX size={13} />
                          </button>
                        ) : (
                          <button
                            className="btn btn-primary btn-sm"
                            title="Unsuspend Player"
                            onClick={() => handleUnsuspend(u.id)}
                          >
                            <UserCheck size={13} />
                          </button>
                        )}

                        {isSuperAdmin && (
                          <button
                            className="btn btn-secondary btn-sm"
                            title="Adjust Wallet"
                            onClick={() => {
                              setWalletModalUserId(u.id);
                              setWalletAmount(500);
                              setWalletReason('');
                            }}
                          >
                            <Coins size={13} />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {/* User Details Modal */}
      {selectedUser && (
        <div className="modal-overlay" onClick={() => setSelectedUser(null)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Player Details: {selectedUser.profile?.display_name || selectedUser.id}</h3>
              <button
                onClick={() => setSelectedUser(null)}
                style={{ background: 'transparent', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer' }}
              >
                <X size={20} />
              </button>
            </div>
            <div className="modal-body">
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <div className="kpi-label">Account UUID</div>
                  <code style={{ fontSize: '12px' }}>{selectedUser.id}</code>
                </div>
                <div>
                  <div className="kpi-label">Player ID</div>
                  <strong>{selectedUser.profile?.player_id}</strong>
                </div>
                <div>
                  <div className="kpi-label">Country</div>
                  <span>{selectedUser.profile?.country_code || 'N/A'}</span>
                </div>
                <div>
                  <div className="kpi-label">Status</div>
                  <span className={`badge ${selectedUser.status === 'ACTIVE' ? 'badge-active' : 'badge-suspended'}`}>
                    {selectedUser.status}
                  </span>
                </div>
              </div>

              <hr style={{ borderColor: 'var(--border-color)' }} />

              <h4 style={{ fontSize: '15px', color: 'var(--accent-cyan)' }}>Gameplay Stats</h4>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '10px' }}>
                <div className="kpi-card" style={{ padding: '12px' }}>
                  <div className="kpi-label">Played</div>
                  <strong>{selectedUser.stats?.matches_played || 0}</strong>
                </div>
                <div className="kpi-card" style={{ padding: '12px' }}>
                  <div className="kpi-label">Won</div>
                  <strong>{selectedUser.stats?.matches_won || 0}</strong>
                </div>
                <div className="kpi-card" style={{ padding: '12px' }}>
                  <div className="kpi-label">Captures</div>
                  <strong>{selectedUser.stats?.total_captures || 0}</strong>
                </div>
              </div>

              <h4 style={{ fontSize: '15px', color: 'var(--accent-cyan)' }}>Registered Devices</h4>
              {selectedUser.devices.length === 0 ? (
                <div style={{ color: 'var(--text-muted)', fontSize: '13px' }}>No active devices recorded</div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  {selectedUser.devices.map((d, i) => (
                    <div
                      key={i}
                      style={{
                        padding: '10px 14px',
                        background: 'var(--bg-card)',
                        borderRadius: 'var(--radius-md)',
                        fontSize: '13px',
                      }}
                    >
                      <Smartphone size={14} style={{ marginRight: '6px', verticalAlign: 'middle' }} />
                      <strong>{d.platform}</strong> - App {d.app_version || '1.0.0'} (Device: <code>{d.device_id.slice(0, 16)}...</code>)
                    </div>
                  ))}
                </div>
              )}
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setSelectedUser(null)}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Suspend Modal */}
      {suspendModalUserId && (
        <div className="modal-overlay" onClick={() => setSuspendModalUserId(null)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <form onSubmit={handleSuspendSubmit}>
              <div className="modal-header">
                <h3>Suspend Player Account</h3>
                <button
                  type="button"
                  onClick={() => setSuspendModalUserId(null)}
                  style={{ background: 'transparent', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer' }}
                >
                  <X size={20} />
                </button>
              </div>
              <div className="modal-body">
                <p style={{ color: 'var(--text-secondary)', fontSize: '14px' }}>
                  Suspended accounts are locked immediately and all active sessions are revoked.
                </p>
                <div>
                  <label className="kpi-label">Reason for suspension (Audit logged)</label>
                  <textarea
                    required
                    className="search-input"
                    style={{ width: '100%', minHeight: '80px', marginTop: '6px' }}
                    placeholder="e.g. Inappropriate language in match #104..."
                    value={suspendReason}
                    onChange={(e) => setSuspendReason(e.target.value)}
                  />
                </div>
                <div>
                  <label className="kpi-label">Duration (Days)</label>
                  <input
                    type="number"
                    className="search-input"
                    style={{ width: '100%', marginTop: '6px' }}
                    value={suspendDays}
                    min={1}
                    max={365}
                    onChange={(e) => setSuspendDays(parseInt(e.target.value) || 7)}
                  />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setSuspendModalUserId(null)}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-danger">
                  Confirm Suspension
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Wallet Adjust Modal */}
      {walletModalUserId && (
        <div className="modal-overlay" onClick={() => setWalletModalUserId(null)}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()}>
            <form onSubmit={handleWalletSubmit}>
              <div className="modal-header">
                <h3>Adjust Player Balance (Super Admin)</h3>
                <button
                  type="button"
                  onClick={() => setWalletModalUserId(null)}
                  style={{ background: 'transparent', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer' }}
                >
                  <X size={20} />
                </button>
              </div>
              <div className="modal-body">
                <div>
                  <label className="kpi-label">Currency</label>
                  <select
                    className="select-input"
                    style={{ width: '100%', marginTop: '6px' }}
                    value={walletCurrency}
                    onChange={(e) => setWalletCurrency(e.target.value as any)}
                  >
                    <option value="COINS">Coins (Soft Currency)</option>
                    <option value="GEMS">Gems (Premium Currency)</option>
                  </select>
                </div>
                <div>
                  <label className="kpi-label">Adjustment Amount (Negative to deduct)</label>
                  <input
                    type="number"
                    required
                    className="search-input"
                    style={{ width: '100%', marginTop: '6px' }}
                    value={walletAmount}
                    onChange={(e) => setWalletAmount(parseInt(e.target.value) || 0)}
                  />
                </div>
                <div>
                  <label className="kpi-label">Reason / Justification</label>
                  <input
                    type="text"
                    required
                    className="search-input"
                    style={{ width: '100%', marginTop: '6px' }}
                    placeholder="e.g. Tournament compensation, Disconnect refund"
                    value={walletReason}
                    onChange={(e) => setWalletReason(e.target.value)}
                  />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setWalletModalUserId(null)}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary">
                  Apply Adjustment
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
