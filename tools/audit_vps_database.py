"""Run on the VPS as root. Outputs schema metadata, never credentials."""
import asyncio
import os
from pathlib import Path
import subprocess
import sys

pid = subprocess.check_output(['systemctl', 'show', 'api-ludo', '-p', 'MainPID', '--value'], text=True).strip()
for item in Path(f'/proc/{pid}/environ').read_bytes().split(b'\0'):
    if b'=' in item:
        key, value = item.split(b'=', 1)
        os.environ[key.decode()] = value.decode()
sys.path.insert(0, '/opt/api-ludo/services/api')
sys.path.insert(0, '/opt/api-ludo')
from sqlalchemy import inspect, text
from sqlalchemy.ext.asyncio import create_async_engine

async def main():
    engine = create_async_engine(os.environ['DATABASE_URL'])
    async with engine.connect() as conn:
        tables = await conn.run_sync(lambda c: inspect(c).get_table_names())
        print('DATABASE_TYPE:', engine.url.get_backend_name())
        print('TABLES:', ','.join(sorted(tables)))
        if 'alembic_version' in tables:
            print('MIGRATION:', (await conn.execute(text('select version_num from alembic_version'))).scalars().all())
        print('PROFILE_COLUMNS:', await conn.run_sync(lambda c: [x['name'] for x in inspect(c).get_columns('profiles')]))
    await engine.dispose()

asyncio.run(main())
