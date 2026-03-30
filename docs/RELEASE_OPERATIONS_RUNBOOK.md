# EBS Lite Release Operations Runbook

Date: 2026-03-30  
Scope: backend, Flutter client, and SMB Edition operational release

## 1. Backup SOP

Minimum posture:
- PostgreSQL backup daily
- keep at least 7 daily copies
- keep one off-device copy
- verify restore at least once per release candidate

Backend command:

```powershell
$d = Get-Date -Format yyyy-MM-dd
pg_dump --format=custom --no-owner --file "ebs_lite_$d.dump" "$env:DATABASE_URL"
```

Operator steps:
1. Confirm `DATABASE_URL` points to the production database.
2. Run the backup command from a secured admin workstation or scheduled job.
3. Copy the resulting dump to NAS, cloud storage, or encrypted removable media.
4. Record the backup timestamp, operator, and destination in the release log.

## 2. Restore SOP

Restore validation command:

```powershell
createdb ebs_lite_restore_verify
pg_restore --no-owner --clean --if-exists --dbname "$env:DATABASE_URL" "ebs_lite_YYYY-MM-DD.dump"
```

Restore steps:
1. Restore to a new empty database first.
2. Start the backend against the restored database.
3. Run `/health` and `/ready`.
4. Smoke test login, dashboard, one sale lookup, and one accounting report.
5. Mark the restore as verified before accepting the backup as valid.

## 3. Monitoring and alerting SOP

Required signals:
- `/health` availability
- `/ready` database and Redis readiness
- backend error logs
- outbox backlog or repeated sync failures
- support bundle health flags
- cash close or reconciliation exceptions raised by operators

Recommended alert thresholds:
- `/ready` failing for more than 2 consecutive checks
- repeated `429` bursts indicating abusive traffic or mis-sized limits
- any production readiness issue appearing in a support bundle
- outbox failed items growing beyond operator tolerance

## 4. Incident and support SOP

First response:
1. Capture exact time, company, location, user, and document number.
2. Generate the in-app support bundle.
3. If available, capture backend `/api/v1/support/bundle`.
4. Classify severity:
   - P1: cannot transact, cannot log in, data corruption suspected
   - P2: major workflow degraded, workaround exists
   - P3: cosmetic or low-impact issue
5. Preserve logs and screenshots before retrying destructive actions.

Escalation:
- P1 issues escalate immediately to backend owner and release owner.
- Finance drift, stock integrity, or reconciliation issues escalate to product owner and finance/operator lead.
- Do not edit production data manually unless rollback or support approval is documented.

## 5. Deployment and rollback SOP

Deployment order:
1. Verify release checklist.
2. Take and validate a fresh backup.
3. Apply backend release and migrations.
4. Confirm `/health` and `/ready`.
5. Smoke test login, dashboard, POS product load, one report, and support bundle.
6. Roll out Flutter build with explicit production `API_BASE_URL`.

Rollback triggers:
- failed smoke test in a blocker path
- migration problem
- authentication failure after deploy
- financial or stock posting regression

Rollback sequence:
1. Stop new client rollout.
2. Restore last known-good backend artifact and configuration.
3. If schema or data corruption occurred, restore the validated backup to a controlled recovery database first.
4. Re-run smoke tests before reopening the system.

## 6. Release checklist

- Production secrets are real and rotated.
- `FRONTEND_BASE_URL` is the deployed host, not localhost.
- `ALLOWED_ORIGINS` lists only deployed origins.
- `RATE_LIMIT_FAIL_OPEN=false` in production.
- `SUPPORT_BUNDLE_ENABLED` is explicitly approved for the target environment.
- Required command gates pass.
- API parity report is regenerated and clean.
- UAT evidence is current for the intended release candidate.
