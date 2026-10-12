export interface AdminUser {
  id: string;
  username: string;
  email: string;
  role: 'SUPER_ADMIN' | 'MODERATOR' | 'SUPPORT';
  is_active: boolean;
  last_login_at?: string;
  created_at: string;
}

export interface AdminKpiOverview {
  total_users: number;
  active_users_today: number;
  active_rooms: number;
  total_matches: number;
  total_coins_in_circulation: number;
  total_gems_in_circulation: number;
  pending_reports_count: number;
  active_tournaments_count: number;
}

export interface AdminUserSummary {
  id: string;
  player_id: string;
  display_name: string;
  level: number;
  status: 'ACTIVE' | 'SUSPENDED' | 'BANNED';
  is_guest: boolean;
  is_verified: boolean;
  coins: number;
  gems: number;
  matches_played: number;
  matches_won: number;
  created_at: string;
}

export interface AdminUserDetail {
  id: string;
  status: string;
  is_guest: boolean;
  is_verified: boolean;
  created_at: string;
  updated_at: string;
  profile?: {
    player_id: string;
    display_name: string;
    avatar_id: string;
    level: number;
    xp: number;
    country_code: string;
  };
  stats?: {
    matches_played: number;
    matches_won: number;
    win_streak: number;
    best_streak: number;
    total_captures: number;
    total_tokens_home: number;
  };
  wallet?: {
    coins: number;
    gems: number;
  };
  devices: Array<{
    device_id: string;
    platform: string;
    app_version?: string;
    last_active_at: string;
  }>;
  identities: Array<{
    provider: string;
    provider_user_id: string;
    created_at: string;
  }>;
}

export interface AdminReport {
  id: string;
  reporter_id: string;
  reported_user_id: string;
  match_id?: string;
  category: string;
  reason: string;
  description: string;
  status: 'OPEN' | 'PENDING' | 'RESOLVED' | 'DISMISSED';
  created_at: string;
}

export interface AdminMatchSummary {
  id: string;
  room_id: string;
  mode: string;
  ruleset_version: string;
  status: string;
  winning_color?: string;
  winning_user_id?: string;
  player_count: number;
  players: Array<{
    user_id: string;
    color: string;
    seat_index: number;
    is_bot: boolean;
    rank?: number;
  }>;
  created_at: string;
  finished_at?: string;
}

export interface AdminMatchDetail {
  id: string;
  mode: string;
  status: string;
  winning_color?: string;
  winning_user_id?: string;
  created_at: string;
  finished_at?: string;
  players: Array<{
    user_id: string;
    color: string;
    seat_index: number;
    is_bot: boolean;
    rank?: number;
  }>;
  events: Array<{
    sequence: number;
    event_type: string;
    payload: any;
    created_at: string;
  }>;
  snapshots_count: number;
}

export interface CatalogItem {
  id: string;
  name: string;
  category: string;
  price_coins: number;
  price_gems: number;
  is_active: boolean;
  rarity: string;
  asset_path?: string;
}

export interface AdminAuditLog {
  id: string;
  admin_id: string;
  admin_username: string;
  action: string;
  target_type: string;
  target_id?: string;
  details?: string;
  ip_address?: string;
  created_at: string;
}
