import React from 'react';
import { RefreshCw, ShieldCheck } from 'lucide-react';
import { AdminUser } from '../types/admin';

interface NavbarProps {
  title: string;
  admin: AdminUser | null;
  onRefresh: () => void;
  isLoading: boolean;
}

export const Navbar: React.FC<NavbarProps> = ({
  title,
  admin,
  onRefresh,
  isLoading,
}) => {
  return (
    <header className="top-navbar">
      <div className="page-title">
        <span>{title}</span>
      </div>

      <div className="navbar-actions">
        <button
          onClick={onRefresh}
          className="btn btn-secondary btn-sm"
          disabled={isLoading}
        >
          <RefreshCw size={14} className={isLoading ? 'animate-spin' : ''} />
          <span>Refresh</span>
        </button>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span className="badge badge-cyan">
            <ShieldCheck size={12} />
            <span>Environment: Production Dev</span>
          </span>
          {admin && (
            <span className="badge badge-purple">
              <span>RBAC: {admin.role}</span>
            </span>
          )}
        </div>
      </div>
    </header>
  );
};
