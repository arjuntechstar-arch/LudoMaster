import {
  AdminAuditLog,
  AdminKpiOverview,
  AdminMatchDetail,
  AdminMatchSummary,
  AdminReport,
  AdminUser,
  AdminUserDetail,
  AdminUserSummary,
  CatalogItem,
} from '../types/admin';

const BASE_URL = '/api/v1/admin';

class AdminApiClient {
  private token: string | null = null;

  constructor() {
    this.token = localStorage.getItem('lm_admin_token');
  }

  setToken(token: string | null) {
    this.token = token;
    if (token) {
      localStorage.setItem('lm_admin_token', token);
    } else {
      localStorage.removeItem('lm_admin_token');
    }
  }

  getToken(): string | null {
    return this.token;
  }

  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...(options.headers as Record<string, string> || {}),
    };

    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }

    const response = await fetch(`${BASE_URL}${endpoint}`, {
      ...options,
      headers,
    });

    if (!response.ok) {
      if (response.status === 401) {
        this.setToken(null);
      }
      let errorMsg = `HTTP Error ${response.status}`;
      try {
        const errorData = await response.json();
        errorMsg = errorData.detail || errorMsg;
      } catch (_) {}
      throw new Error(errorMsg);
    }

    return response.json();
  }

  async login(username: string, password: string): Promise<{ access_token: string; admin: AdminUser }> {
    const data = await this.request<{ access_token: string; token_type: string; admin: AdminUser }>(
      '/auth/login',
      {
        method: 'POST',
        body: JSON.stringify({ username, password }),
      }
    );
    this.setToken(data.access_token);
    return data;
  }

  async getMe(): Promise<AdminUser> {
    return this.request<AdminUser>('/auth/me');
  }

  async getKpis(): Promise<AdminKpiOverview> {
    return this.request<AdminKpiOverview>('/dashboard/kpis');
  }

  async listUsers(query?: string, status?: string, limit = 50, offset = 0): Promise<AdminUserSummary[]> {
    const params = new URLSearchParams({ limit: String(limit), offset: String(offset) });
    if (query) params.append('query', query);
    if (status) params.append('status', status);
    return this.request<AdminUserSummary[]>(`/users?${params.toString()}`);
  }

  async getUserDetail(userId: string): Promise<AdminUserDetail> {
    return this.request<AdminUserDetail>(`/users/${userId}`);
  }

  async suspendUser(userId: string, reason: string, durationDays?: number): Promise<any> {
    return this.request(`/users/${userId}/suspend`, {
      method: 'POST',
      body: JSON.stringify({ reason, duration_days: durationDays }),
    });
  }

  async unsuspendUser(userId: string): Promise<any> {
    return this.request(`/users/${userId}/unsuspend`, {
      method: 'POST',
    });
  }

  async adjustUserWallet(userId: string, amount: number, currency: 'COINS' | 'GEMS', reason: string): Promise<any> {
    return this.request(`/users/${userId}/wallet-adjust`, {
      method: 'POST',
      body: JSON.stringify({ amount, currency, reason }),
    });
  }

  async listMatches(status?: string, mode?: string, limit = 50, offset = 0): Promise<AdminMatchSummary[]> {
    const params = new URLSearchParams({ limit: String(limit), offset: String(offset) });
    if (status) params.append('status', status);
    if (mode) params.append('mode', mode);
    return this.request<AdminMatchSummary[]>(`/matches?${params.toString()}`);
  }

  async getMatchDetail(matchId: string): Promise<AdminMatchDetail> {
    return this.request<AdminMatchDetail>(`/matches/${matchId}`);
  }

  async listReports(status?: string, limit = 50, offset = 0): Promise<AdminReport[]> {
    const params = new URLSearchParams({ limit: String(limit), offset: String(offset) });
    if (status) params.append('status', status);
    return this.request<AdminReport[]>(`/reports?${params.toString()}`);
  }

  async actionReport(reportId: string, action: 'DISMISS' | 'SUSPEND_USER' | 'WARN', notes?: string): Promise<any> {
    return this.request(`/reports/${reportId}/action`, {
      method: 'POST',
      body: JSON.stringify({ action, notes }),
    });
  }

  async listCatalog(): Promise<CatalogItem[]> {
    return this.request<CatalogItem[]>('/catalog');
  }

  async upsertCatalogItem(item: Partial<CatalogItem> & { id: string; name: string; category: string }): Promise<any> {
    return this.request('/catalog', {
      method: 'POST',
      body: JSON.stringify(item),
    });
  }

  async getConfigAndFlags(): Promise<{
    remote_config: Record<string, { value: string; description?: string }>;
    feature_flags: Record<string, { enabled: boolean; description?: string }>;
  }> {
    return this.request('/config');
  }

  async updateRemoteConfig(key: string, value: string, description?: string): Promise<any> {
    return this.request('/config/remote-config', {
      method: 'POST',
      body: JSON.stringify({ key, value, description }),
    });
  }

  async toggleFeatureFlag(name: string, enabled: boolean, description?: string): Promise<any> {
    return this.request('/config/feature-flags', {
      method: 'POST',
      body: JSON.stringify({ name, enabled, description }),
    });
  }

  async listAuditLogs(limit = 50, offset = 0): Promise<AdminAuditLog[]> {
    const params = new URLSearchParams({ limit: String(limit), offset: String(offset) });
    return this.request<AdminAuditLog[]>(`/audit-logs?${params.toString()}`);
  }

  logout() {
    this.setToken(null);
  }
}

export const adminClient = new AdminApiClient();
