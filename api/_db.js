// Each Vercel preview deployment talks to its OWN pgoverlay database branch.
// No per-PR secrets, no injection step: Vercel already exposes the git ref
// and the repository (VERCEL_GIT_COMMIT_REF, VERCEL_GIT_REPO_OWNER/SLUG), and
// the pgoverlay proxy routes by database name — so the connection is fully
// derived from three static env vars (PGOVERLAY_HOST, PGOVERLAY_PORT,
// PGPASSWORD) plus what Vercel sets.
const crypto = require('crypto');
const { Pool } = require('pg');

// pgoverlay-github (git-branch naming) names a PR's branch after its head
// ref, and VERCEL_GIT_COMMIT_REF is present from the very first preview
// build — no PR-association timing race, nothing injected per deployment.
// The name is gh-<repo-key>-<sanitized ref>, where <repo-key> is 6 hex chars
// of sha256(lowercased "owner/name"): the exact rule of pgoverlay-connect's
// refBranchName (and scripts/pgoverlay-branch.sh), pinned by pgoverlay's
// pgoverlayconnect/testdata/branch_names.json.
const sha6 = (s) => crypto.createHash('sha256').update(s, 'utf8').digest('hex').slice(0, 6);
const lowerASCII = (s) => s.replace(/[A-Z]/g, (c) => c.toLowerCase());

function refBranchName(repo, ref) {
  let s = lowerASCII(ref).replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
  if (!s) return '';
  const prefix = `gh-${sha6(lowerASCII(repo))}-`;
  const budget = 41 - prefix.length;
  // a long ref is cut and suffixed with its own hash, so two long refs with
  // a common start (dependabot's, say) get different branches
  if (s.length > budget) s = `${s.slice(0, budget - 7).replace(/-+$/, '')}-${sha6(ref)}`;
  return prefix + s;
}

const repo = `${process.env.VERCEL_GIT_REPO_OWNER}/${process.env.VERCEL_GIT_REPO_SLUG}`;
const ref = process.env.VERCEL_GIT_COMMIT_REF;
const isPreview = process.env.VERCEL_ENV === 'preview';
const branch = (isPreview && ref && refBranchName(repo, ref))
  || process.env.PGOVERLAY_DEFAULT_BRANCH || 'main-stable';

const pool = new Pool({
  host: process.env.PGOVERLAY_HOST,
  port: Number(process.env.PGOVERLAY_PORT || 6432),
  user: process.env.PGUSER || 'postgres',
  password: process.env.PGPASSWORD,
  database: `postgres@${branch}`,
  max: 3,
  connectionTimeoutMillis: 8000,
  // serverless + tunneled TCP: don't keep idle connections around
  idleTimeoutMillis: 1000,
});

// An idle pooled connection dying (branch reset, tunnel drop) emits 'error'
// on the pool; unhandled, that crashes the function process. Log and let the
// next query open a fresh connection instead.
pool.on('error', (err) => console.error('idle client error', err.message));

module.exports = { pool, branch };
