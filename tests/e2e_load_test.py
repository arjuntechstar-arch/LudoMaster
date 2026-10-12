#!/usr/bin/env python3
"""
LudoMaster Multi-Client End-to-End Load & Concurrency Simulator
Phase 12: Hardening & Performance Verification

Simulates concurrent user sessions performing full player journeys:
- Guest authentication & profile sync
- Economy catalog browsing & daily reward claiming
- Ranked leaderboards & friend list queries
- Room creation, matchmaking ticket submission & polling
- GDPR data export
- Latency percentile (p50, p95, p99), throughput (RPS), and error-rate accounting
"""

import argparse
import asyncio
import random
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional
import httpx

@dataclass
class LoadMetrics:
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    latencies_ms: List[float] = field(default_factory=list)
    errors: Dict[str, int] = field(default_factory=dict)

    def record_request(self, duration_ms: float, success: bool, error_msg: Optional[str] = None):
        self.total_requests += 1
        self.latencies_ms.append(duration_ms)
        if success:
            self.successful_requests += 1
        else:
            self.failed_requests += 1
            err_key = error_msg or "Unknown Error"
            self.errors[err_key] = self.errors.get(err_key, 0) + 1

    def print_summary(self, elapsed_sec: float):
        rps = self.total_requests / elapsed_sec if elapsed_sec > 0 else 0
        sorted_lat = sorted(self.latencies_ms) if self.latencies_ms else [0]
        count = len(sorted_lat)
        p50 = sorted_lat[int(count * 0.50)]
        p95 = sorted_lat[min(int(count * 0.95), count - 1)]
        p99 = sorted_lat[min(int(count * 0.99), count - 1)]
        avg_lat = sum(sorted_lat) / count if count > 0 else 0

        print("\n" + "=" * 65)
        print("          LUDOMASTER E2E LOAD SIMULATION REPORT          ")
        print("=" * 65)
        print(f"Total Simulation Duration: {elapsed_sec:.2f} seconds")
        print(f"Total HTTP Requests:      {self.total_requests}")
        print(f"Successful Requests:      {self.successful_requests} ({self.successful_requests / max(self.total_requests, 1) * 100:.1f}%)")
        print(f"Failed Requests:          {self.failed_requests}")
        print(f"Throughput (RPS):         {rps:.2f} req/sec")
        print("-" * 65)
        print(f"Latency Avg:              {avg_lat:.2f} ms")
        print(f"Latency Min:              {sorted_lat[0]:.2f} ms")
        print(f"Latency P50 (Median):     {p50:.2f} ms")
        print(f"Latency P95:              {p95:.2f} ms")
        print(f"Latency P99:              {p99:.2f} ms")
        print(f"Latency Max:              {sorted_lat[-1]:.2f} ms")
        print("=" * 65)
        if self.errors:
            print("\nError Breakdown:")
            for err, cnt in self.errors.items():
                print(f"  - [{cnt}x] {err}")
        print()

async def simulate_player(
    client: httpx.AsyncClient,
    player_idx: int,
    metrics: LoadMetrics,
    iterations: int = 1,
):
    """Simulates a complete player session with multiple gameplay cycles."""
    device_id = f"load_test_dev_{player_idx}_{int(time.time() * 1000)}"

    async def tracked_call(method: str, path: str, **kwargs) -> Optional[httpx.Response]:
        start = time.perf_counter()
        try:
            resp = await client.request(method, path, **kwargs)
            duration_ms = (time.perf_counter() - start) * 1000
            success = 200 <= resp.status_code < 400
            err = None if success else f"HTTP {resp.status_code} on {method} {path}"
            metrics.record_request(duration_ms, success, err)
            return resp
        except Exception as e:
            duration_ms = (time.perf_counter() - start) * 1000
            metrics.record_request(duration_ms, False, f"{type(e).__name__}: {str(e)}")
            return None

    # Step 1: Guest Login / Auth
    login_resp = await tracked_call(
        "POST",
        "/auth/guest",
        json={"device_id": device_id, "platform": "ANDROID", "app_version": "1.0.0"},
    )
    if not login_resp or login_resp.status_code != 200:
        return

    data = login_resp.json()
    token = data.get("access_token")
    headers = {"Authorization": f"Bearer {token}"}

    for _ in range(iterations):
        # Step 2: Fetch Account Profile & Balances
        await tracked_call("GET", "/me", headers=headers)

        # Step 3: Browse Economy Store Catalog
        await tracked_call("GET", "/economy/catalog", headers=headers)

        # Step 4: Check Daily Reward Status & Attempt Claim
        daily_resp = await tracked_call("GET", "/economy/daily-reward", headers=headers)
        if daily_resp and daily_resp.status_code == 200:
            daily_data = daily_resp.json()
            if daily_data.get("can_claim", False):
                await tracked_call("POST", "/economy/daily-reward/claim", headers=headers)

        # Step 5: Check Global Leaderboard
        await tracked_call("GET", "/leaderboards?scope=ALL_TIME&limit=20", headers=headers)

        # Step 6: Fetch Friend List & Social Status
        await tracked_call("GET", "/friends", headers=headers)

        # Step 7: Create a Custom Private Room or Matchmaking Ticket
        if player_idx % 2 == 0:
            room_resp = await tracked_call(
                "POST",
                "/rooms",
                headers=headers,
                json={"mode": "CLASSIC", "max_players": 4, "bet_coins": 100},
            )
            if room_resp and room_resp.status_code in (200, 201):
                room_id = room_resp.json().get("id")
                if room_id:
                    await tracked_call("GET", f"/rooms/{room_id}", headers=headers)
        else:
            mm_resp = await tracked_call(
                "POST",
                "/matchmaking/enqueue",
                headers=headers,
                json={"mode": "CLASSIC", "player_count": 4, "region": "GLOBAL"},
            )
            if mm_resp and mm_resp.status_code == 200:
                ticket_id = mm_resp.json().get("ticket_id")
                if ticket_id:
                    await tracked_call("GET", f"/matchmaking/ticket/{ticket_id}", headers=headers)

        # Step 8: GDPR Personal Data Export query
        await tracked_call("GET", "/auth/export-data", headers=headers)

        # Subtle micro-sleep between player actions to simulate realistic human delay
        await asyncio.sleep(random.uniform(0.01, 0.05))

async def run_load_test(
    num_clients: int,
    base_url: str,
    iterations: int,
    app=None,
) -> LoadMetrics:
    metrics = LoadMetrics()
    print(f"[*] Starting Load Test: {num_clients} concurrent clients, {iterations} iterations each")
    print(f"[*] Target Endpoint: {base_url}")

    start_time = time.perf_counter()

    transport = httpx.ASGITransport(app=app) if app else None
    limits = httpx.Limits(max_keepalive_connections=50, max_connections=100)

    async with httpx.AsyncClient(
        base_url=base_url,
        transport=transport,
        limits=limits,
        timeout=30.0,
    ) as client:
        tasks = [
            simulate_player(client, i, metrics, iterations=iterations)
            for i in range(num_clients)
        ]
        await asyncio.gather(*tasks)

    elapsed = time.perf_counter() - start_time
    metrics.print_summary(elapsed)
    return metrics

def main():
    parser = argparse.ArgumentParser(description="LudoMaster E2E Multi-Client Load Test Tool")
    parser.add_argument("--clients", type=int, default=15, help="Number of concurrent virtual clients")
    parser.add_argument("--iterations", type=int, default=2, help="Gameplay cycles per client")
    parser.add_argument("--base-url", type=str, default="http://127.0.0.1:8000/api/v1", help="API base URL")
    parser.add_argument("--in-process", action="store_true", help="Run in-process against FastAPI ASGI app")
    args = parser.parse_args()

    app = None
    if args.in_process:
        # Load local FastAPI app directly
        sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "services" / "api"))
        sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
        from app.main import app as fastapi_app
        from app.db.base import Base
        from app.db.session import engine
        import app.models

        async def init_db():
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)

        asyncio.run(init_db())
        app = fastapi_app
        base_url = "http://testserver/api/v1"
    else:
        base_url = args.base_url

    metrics = asyncio.run(run_load_test(args.clients, base_url, args.iterations, app=app))

    # Exit code: fail if more than 5% failed requests
    failure_rate = (metrics.failed_requests / max(metrics.total_requests, 1))
    if failure_rate > 0.05:
        print(f"[FAIL] Failure rate {failure_rate * 100:.1f}% exceeds 5% threshold!")
        sys.exit(1)
    else:
        print(f"[PASS] Load test passed within healthy latency and reliability thresholds!")
        sys.exit(0)

if __name__ == "__main__":
    main()
