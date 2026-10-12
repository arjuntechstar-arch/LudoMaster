# Admin Dashboard & Live Ops Control Center (Phase 10)

## Overview
A production-grade, responsive control center built with React 18, TypeScript, and Vite. Designed for game operations, customer support, moderation, economy balancing, and live feature management.

## Tech Stack
- **Framework**: React 18 + TypeScript + Vite
- **Icons**: `lucide-react`
- **Styling**: Vanilla CSS Design System with dark mode glassmorphism and glowing accent themes
- **API**: FastAPI `/api/v1/admin/*`

## Features Implemented
1. **Executive Dashboard & KPIs**: Real-time view of player registrations, active rooms, circulating coins & gems, open reports, and active tournament brackets.
2. **User Lookup & Safety Actions**: Search by ID or username; inspect player profile, match stats, devices, and wallet; suspend/unsuspend with duration and audit reason; grant/deduct currency with ledger tracking.
3. **Safety & Moderation Queue**: Review player reports, inspect reported reasons and match IDs, and take instant actions (suspend, warn, dismiss).
4. **Match Review & Event Timeline**: Review finished and in-progress matches, investigate player moves and rolls via step-by-step authoritative event sequence for dispute resolution.
5. **Economy & Catalog Manager**: Create and update catalog items (dice skins, token skins, board themes, avatars) and configure coin/gem pricing and active statuses.
6. **Live Remote Config & Feature Flags**: Real-time feature flag toggles and key-value config parameters without client app updates.
7. **System Audit Trail**: Complete immutable log of administrative activities, target entities, IP addresses, and timestamps.

## Running Locally
```bash
# In apps/admin
npm install
npm run dev     # Starts dev server on http://localhost:3000
npm run build   # Production bundle in /dist
```
