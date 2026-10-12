import React from 'react';
import {
  LayoutDashboard,
  Users,
  ShieldAlert,
  Swords,
  ShoppingBag,
  Sliders,
  FileText,
  LogOut,
  Gamepad2,
} from 'lucide-react';
import { AdminUser } from '../types/admin';

export type ActiveTab = 'kpis' | 'users' | 'moderation' | 'matches' | 'catalog' | 'config' | 'audit';

interface SidebarProps {
  currentTab: ActiveTab;
  onSelectTab: (tab: ActiveTab) => void;
  admin: AdminUser | null;
  pendingReportsCount: number;
  onLogout: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  currentTab,
  onSelectTab,
  admin,
  pendingReportsCount,
  onLogout,
}) => {
  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        <div className="logo-icon">
          <Gamepad2 size={24} />
        </div>
        <div className="brand-text">
          <h1>LudoMaster</h1>
          <span className="brand-badge">Control Center</span>
        </div>
      </div>

      <nav className="sidebar-nav">
        <button
          className={`nav-item ${currentTab === 'kpis' ? 'active' : ''}`}
          onClick={() => onSelectTab('kpis')}
        >
          <LayoutDashboard size={18} />
          <span>Dashboard Overview</span>
        </button>

        <button
          className={`nav-item ${currentTab === 'users' ? 'active' : ''}`}
          onClick={() => onSelectTab('users')}
        >
          <Users size={18} />
          <span>User Lookup &amp; Safety</span>
        </button>

        <button
          className={`nav-item ${currentTab === 'moderation' ? 'active' : ''}`}
          onClick={() => onSelectTab('moderation')}
        >
          <ShieldAlert size={18} />
          <span>Reports &amp; Moderation</span>
          {pendingReportsCount > 0 && (
            <span className="nav-counter">{pendingReportsCount}</span>
          )}
        </button>

        <button
          className={`nav-item ${currentTab === 'matches' ? 'active' : ''}`}
          onClick={() => onSelectTab('matches')}
        >
          <Swords size={18} />
          <span>Match Review &amp; Timeline</span>
        </button>

        <button
          className={`nav-item ${currentTab === 'catalog' ? 'active' : ''}`}
          onClick={() => onSelectTab('catalog')}
        >
          <ShoppingBag size={18} />
          <span>Economy &amp; Catalog</span>
        </button>

        <button
          className={`nav-item ${currentTab === 'config' ? 'active' : ''}`}
          onClick={() => onSelectTab('config')}
        >
          <Sliders size={18} />
          <span>Remote Config &amp; Flags</span>
        </button>

        <button
          className={`nav-item ${currentTab === 'audit' ? 'active' : ''}`}
          onClick={() => onSelectTab('audit')}
        >
          <FileText size={18} />
          <span>Audit Logs</span>
        </button>
      </nav>

      {admin && (
        <div className="sidebar-footer">
          <div className="admin-card">
            <div className="admin-avatar">
              {admin.username.charAt(0).toUpperCase()}
            </div>
            <div className="admin-info">
              <div className="admin-name">{admin.username}</div>
              <div className="admin-role">{admin.role}</div>
            </div>
            <button
              onClick={onLogout}
              className="btn btn-secondary btn-sm"
              title="Logout"
            >
              <LogOut size={14} />
            </button>
          </div>
        </div>
      )}
    </aside>
  );
};
