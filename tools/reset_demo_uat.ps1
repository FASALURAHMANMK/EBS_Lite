param(
  [switch]$AllowRemote
)

$argsList = @(
  "run",
  "./go_backend_rmt/cmd/demo_uat_seed",
  "--migrations-dir", "go_backend_rmt/migrations",
  "--report-out", "docs/DEMO_DATASET_REPORT.md"
)

if ($AllowRemote) {
  $argsList += "--allow-remote"
}

go @argsList
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
