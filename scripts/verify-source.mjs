import fs from 'node:fs';
import path from 'node:path';
const required = ['README.md', '.env.example', 'package.json', 'apps/web/package.json', 'apps/web/app/page.tsx', 'apps/web/app/layout.tsx', 'apps/mobile/app/index.tsx', 'packages/shared/src/index.ts', '.github/workflows/ci.yml'];
const errors = required.filter((p) => !fs.existsSync(path.resolve(p))).map((p) => `Missing required file: ${p}`);
const envExample = fs.readFileSync('.env.example', 'utf8');
if (!envExample.includes('NEXT_PUBLIC_SUPABASE_URL=')) errors.push('Missing Supabase URL placeholder.');
if (!envExample.includes('SUPABASE_SERVICE_ROLE_KEY=')) errors.push('Missing server-only service role placeholder.');
for (const file of ['.env', '.env.local', '.env.production']) if (fs.existsSync(file)) errors.push(`Refusing to verify with local secret file present: ${file}`);
if (errors.length) { console.error('YourTaste source verification failed:'); for (const e of errors) console.error(`- ${e}`); process.exitCode = 1; } else console.log(`YourTaste repository structure verified (${required.length} required files).`);
