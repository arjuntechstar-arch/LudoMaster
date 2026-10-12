import React from 'react';
import {
  Users,
  Coins,
  Gem,
  Swords,
  Trophy,
  AlertTriangle,
} from 'lucide-react';
import { AdminKpiOverview } from '../types/admin';

interface KpiCardsProps {
  kpis: AdminKpiOverview | null;
}

export const KpiCards: React.FC<KpiCardsProps> = ({ kpis }) => {
  if (!kpis) return null;

  const cards = [
    {
      label: 'Registered Players',
      value: kpis.total_users.toLocaleString(),
      subtext: 'Total accounts registered',
      icon: Users,
      color: '#3b82f6',
    },
    {
      label: 'Active Matches & Rooms',
      value: `${kpis.active_rooms} Rooms`,
      subtext: `${kpis.total_matches} Total matches recorded`,
      icon: Swords,
      color: '#06b6d4',
    },
    {
      label: 'Coins in Circulation',
      value: kpis.total_coins_in_circulation.toLocaleString(),
      subtext: 'Immutable ledger balance',
      icon: Coins,
      color: '#f59e0b',
    },
    {
      label: 'Gems in Circulation',
      value: kpis.total_gems_in_circulation.toLocaleString(),
      subtext: 'Premium currency balance',
      icon: Gem,
      color: '#8b5cf6',
    },
    {
      label: 'Active Tournaments',
      value: kpis.active_tournaments_count.toString(),
      subtext: 'Open & running brackets',
      icon: Trophy,
      color: '#10b981',
    },
    {
      label: 'Pending Moderation',
      value: kpis.pending_reports_count.toString(),
      subtext: kpis.pending_reports_count > 0 ? 'Requires attention' : 'All clear',
      icon: AlertTriangle,
      color: kpis.pending_reports_count > 0 ? '#ef4444' : '#10b981',
    },
  ];

  return (
    <div className="kpi-grid">
      {cards.map((c, i) => {
        const Icon = c.icon;
        return (
          <div key={i} className="kpi-card" style={{ '--card-icon-color': c.color } as any}>
            <div>
              <div className="kpi-label">{c.label}</div>
              <div className="kpi-value">{c.value}</div>
              <div className="kpi-subtext">{c.subtext}</div>
            </div>
            <div className="kpi-icon-wrap">
              <Icon size={22} />
            </div>
          </div>
        );
      })}
    </div>
  );
};
