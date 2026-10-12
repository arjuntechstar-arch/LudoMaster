import React, { useState } from 'react';
import { Lock, User, Gamepad2, AlertCircle } from 'lucide-react';
import { adminClient } from '../api/adminClient';
import { AdminUser } from '../types/admin';

interface LoginModalProps {
  onLoginSuccess: (admin: AdminUser) => void;
}

export const LoginModal: React.FC<LoginModalProps> = ({ onLoginSuccess }) => {
  const [username, setUsername] = useState('admin');
  const [password, setPassword] = useState('AdminPass123!');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    try {
      const data = await adminClient.login(username, password);
      onLoginSuccess(data.admin);
    } catch (err: any) {
      setError(err.message || 'Authentication failed. Please check credentials.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal-card" style={{ maxWidth: '420px', padding: '12px' }}>
        <div style={{ textAlign: 'center', padding: '24px 16px 16px' }}>
          <div
            className="logo-icon"
            style={{ width: '56px', height: '56px', margin: '0 auto 16px', fontSize: '28px' }}
          >
            <Gamepad2 size={32} />
          </div>
          <h2 style={{ fontSize: '22px', fontWeight: 800, letterSpacing: '-0.5px' }}>
            LudoMaster
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            Live Ops &amp; Admin Control Center
          </p>
        </div>

        {error && (
          <div
            style={{
              margin: '0 16px 16px',
              padding: '12px 14px',
              borderRadius: '8px',
              backgroundColor: 'rgba(239, 68, 68, 0.15)',
              color: 'var(--accent-rose)',
              fontSize: '13px',
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
            }}
          >
            <AlertCircle size={16} />
            <span>{error}</span>
          </div>
        )}

        <form onSubmit={handleSubmit} style={{ padding: '0 16px 20px' }}>
          <div style={{ marginBottom: '16px' }}>
            <label className="kpi-label">Admin Username</label>
            <div style={{ position: 'relative', marginTop: '6px' }}>
              <User
                size={16}
                style={{ position: 'absolute', left: '12px', top: '12px', color: 'var(--text-muted)' }}
              />
              <input
                type="text"
                required
                className="search-input"
                style={{ width: '100%', paddingLeft: '38px' }}
                placeholder="Username"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
              />
            </div>
          </div>

          <div style={{ marginBottom: '20px' }}>
            <label className="kpi-label">Password</label>
            <div style={{ position: 'relative', marginTop: '6px' }}>
              <Lock
                size={16}
                style={{ position: 'absolute', left: '12px', top: '12px', color: 'var(--text-muted)' }}
              />
              <input
                type="password"
                required
                className="search-input"
                style={{ width: '100%', paddingLeft: '38px' }}
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
          </div>

          <div
            style={{
              padding: '10px 12px',
              background: 'rgba(255, 255, 255, 0.04)',
              borderRadius: '6px',
              fontSize: '12px',
              color: 'var(--text-muted)',
              marginBottom: '20px',
            }}
          >
            Default Dev Credentials: <code>admin</code> / <code>AdminPass123!</code>
          </div>

          <button
            type="submit"
            className="btn btn-primary"
            style={{ width: '100%', padding: '12px' }}
            disabled={isLoading}
          >
            {isLoading ? 'Verifying...' : 'Sign In to Control Center'}
          </button>
        </form>
      </div>
    </div>
  );
};
