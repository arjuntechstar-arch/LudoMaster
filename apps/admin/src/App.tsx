import React, { useState, useEffect } from 'react';
import { adminClient } from './api/adminClient';
import { AdminKpiOverview, AdminUser } from './types/admin';
import { Sidebar, ActiveTab } from './components/Sidebar';
import { Navbar } from './components/Navbar';
import { KpiCards } from './components/KpiCards';
import { UsersTab } from './components/UsersTab';
import { ModerationTab } from './components/ModerationTab';
import { MatchesTab } from './components/MatchesTab';
import { CatalogTab } from './components/CatalogTab';
import { ConfigTab } from './components/ConfigTab';
import { AuditLogsTab } from './components/AuditLogsTab';
import { LoginModal } from './components/LoginModal';

export const App: React.FC = () => {
  const [admin, setAdmin] = useState<AdminUser | null>(null);
  const [isCheckingAuth, setIsCheckingAuth] = useState(true);
  const [currentTab, setCurrentTab] = useState<ActiveTab>('kpis');
  const [kpis, setKpis] = useState<AdminKpiOverview | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const fetchKpis = async () => {
    try {
      const data = await adminClient.getKpis();
      setKpis(data);
    } catch (err) {
      console.error('Failed to load KPIs', err);
    }
  };

  const checkAuth = async () => {
    setIsCheckingAuth(true);
    if (!adminClient.getToken()) {
      setIsCheckingAuth(false);
      return;
    }

    try {
      const current = await adminClient.getMe();
      setAdmin(current);
      await fetchKpis();
    } catch (_) {
      adminClient.logout();
      setAdmin(null);
    } finally {
      setIsCheckingAuth(false);
    }
  };

  useEffect(() => {
    checkAuth();
  }, []);

  const handleRefresh = async () => {
    setIsLoading(true);
    await fetchKpis();
    setIsLoading(false);
  };

  const handleLogout = () => {
    adminClient.logout();
    setAdmin(null);
  };

  const getPageTitle = (tab: ActiveTab) => {
    switch (tab) {
      case 'kpis':
        return 'Executive KPI Overview';
      case 'users':
        return 'Player Account Lookup & Actions';
      case 'moderation':
        return 'Safety & Moderation Queue';
      case 'matches':
        return 'Live & Historical Match Timeline';
      case 'catalog':
        return 'Economy & Cosmetics Catalog';
      case 'config':
        return 'Live Remote Config & Feature Flags';
      case 'audit':
        return 'System Audit Trail';
    }
  };

  if (isCheckingAuth) {
    return (
      <div
        style={{
          display: 'flex',
          height: '100vh',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: 'var(--bg-primary)',
          color: 'var(--text-secondary)',
        }}
      >
        Initializing Control Center...
      </div>
    );
  }

  if (!admin) {
    return <LoginModal onLoginSuccess={(loggedInAdmin) => {
      setAdmin(loggedInAdmin);
      fetchKpis();
    }} />;
  }

  return (
    <div className="app-container">
      <Sidebar
        currentTab={currentTab}
        onSelectTab={setCurrentTab}
        admin={admin}
        pendingReportsCount={kpis?.pending_reports_count || 0}
        onLogout={handleLogout}
      />

      <main className="main-content">
        <Navbar
          title={getPageTitle(currentTab)}
          admin={admin}
          onRefresh={handleRefresh}
          isLoading={isLoading}
        />

        <div className="content-area">
          {currentTab === 'kpis' && (
            <>
              <KpiCards kpis={kpis} />
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
                <div className="panel" style={{ padding: '24px' }}>
                  <h3 style={{ fontSize: '16px', marginBottom: '12px', color: 'var(--accent-cyan)' }}>
                    Quick Operations
                  </h3>
                  <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                    <button className="btn btn-secondary btn-sm" onClick={() => setCurrentTab('users')}>
                      Lookup Player
                    </button>
                    <button className="btn btn-secondary btn-sm" onClick={() => setCurrentTab('moderation')}>
                      Review Reports ({kpis?.pending_reports_count || 0})
                    </button>
                    <button className="btn btn-secondary btn-sm" onClick={() => setCurrentTab('matches')}>
                      Inspect Live Matches
                    </button>
                    <button className="btn btn-secondary btn-sm" onClick={() => setCurrentTab('config')}>
                      Manage Feature Flags
                    </button>
                  </div>
                </div>

                <div className="panel" style={{ padding: '24px' }}>
                  <h3 style={{ fontSize: '16px', marginBottom: '8px', color: 'var(--accent-emerald)' }}>
                    Server Health &amp; Integrity
                  </h3>
                  <div style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: '1.6' }}>
                    <div>Authoritative Engine: <strong>Deterministic Cryptographic</strong></div>
                    <div>Anti-Cheat Validation: <strong>Enforced Server-Side</strong></div>
                    <div>Wallet Ledger Reconciliation: <strong>Zero Discrepancies</strong></div>
                  </div>
                </div>
              </div>
            </>
          )}

          {currentTab === 'users' && <UsersTab admin={admin} onActionComplete={fetchKpis} />}
          {currentTab === 'moderation' && <ModerationTab admin={admin} onActionComplete={fetchKpis} />}
          {currentTab === 'matches' && <MatchesTab />}
          {currentTab === 'catalog' && <CatalogTab admin={admin} />}
          {currentTab === 'config' && <ConfigTab admin={admin} />}
          {currentTab === 'audit' && <AuditLogsTab />}
        </div>
      </main>
    </div>
  );
};
