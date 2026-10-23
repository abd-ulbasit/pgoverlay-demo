// Upserts env vars on the linked Vercel project (preview + production) and
// prints the latest preview/production deployment URLs for redeploys.
// Usage: node scripts/vercel-env-upsert.js KEY=value [KEY=value ...]
const fs = require('fs'), os = require('os'), path = require('path');

const proj = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '.vercel', 'project.json'), 'utf8'));
const auth = JSON.parse(fs.readFileSync(
  path.join(os.homedir(), 'Library', 'Application Support', 'com.vercel.cli', 'auth.json'), 'utf8'));
const qs = `teamId=${proj.orgId}`;
const hdrs = { Authorization: `Bearer ${auth.token}`, 'Content-Type': 'application/json' };

(async () => {
  for (const arg of process.argv.slice(2)) {
    const [key, ...rest] = arg.split('=');
    const value = rest.join('=');
    for (const target of ['preview', 'production']) {
      const r = await fetch(`https://api.vercel.com/v10/projects/${proj.projectId}/env?${qs}&upsert=true`, {
        method: 'POST', headers: hdrs,
        body: JSON.stringify({ key, value, type: 'encrypted', target: [target] }),
      });
      if (!r.ok) throw new Error(`${key} (${target}): ${r.status} ${await r.text()}`);
    }
    console.error(`env ${key} updated (preview+production)`);
  }
  const r = await fetch(`https://api.vercel.com/v6/deployments?projectId=${proj.projectId}&${qs}&limit=20`, { headers: hdrs });
  const { deployments } = await r.json();
  const latest = {};
  for (const d of deployments || []) {
    const env = d.target === 'production' ? 'production' : 'preview';
    if (!latest[env] && d.state === 'READY') latest[env] = d.url;
  }
  // stdout: one "env url" per line (tunnel-up.sh, now removed, redeployed each)
  for (const [env, url] of Object.entries(latest)) console.log(`${env} https://${url}`);
})();
