#!/usr/bin/env bash
# Run this plugin's tests inside the official redmine:7.0.1 image (SQLite).
# The image omits the Gemfile :test group; this script installs it.
# When redmine_issue_checklists is available (sibling directory or
# CHECKLISTS_PLUGIN_DIR), it is mounted too so checklist rows are real.
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${REDMINE_IMAGE:-redmine:7.0.1}"
CHECKLISTS="${CHECKLISTS_PLUGIN_DIR:-}"

if [[ -z "$CHECKLISTS" && -f "$PLUGIN_DIR/../redmine_issue_checklists/init.rb" ]]; then
  CHECKLISTS="$PLUGIN_DIR/../redmine_issue_checklists"
fi

DOCKER=(docker)
if ! docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
fi

MOUNTS=(-v "$PLUGIN_DIR:/opt/plugin:ro")
if [[ -n "$CHECKLISTS" && -f "$CHECKLISTS/init.rb" ]]; then
  echo "Including Issue Checklists from ${CHECKLISTS}"
  MOUNTS+=(-v "$CHECKLISTS:/opt/checklists:ro")
else
  echo "Issue Checklists is not mounted. Seed tests use stubs for that branch."
fi

"${DOCKER[@]}" run --rm --user root \
  -e SECRET_KEY_BASE=issue-templates-test-secret \
  -e REDMINE_LANG=en \
  "${MOUNTS[@]}" \
  --entrypoint bash \
  "$IMAGE" \
  -lc 'set -euo pipefail
cd /usr/src/redmine
rm -rf plugins/redmine_issue_templates plugins/redmine_issue_checklists
cp -a /opt/plugin plugins/redmine_issue_templates
if [[ -f /opt/checklists/init.rb ]]; then
  cp -a /opt/checklists plugins/redmine_issue_checklists
fi
mkdir -p db tmp log
cat > config/database.yml <<YAML
production:
  adapter: sqlite3
  database: db/redmine.sqlite3
development:
  adapter: sqlite3
  database: db/redmine_dev.sqlite3
test:
  adapter: sqlite3
  database: db/redmine_test.sqlite3
YAML
# The image pins BUNDLE without to development:test. Install the test group.
bundle config unset --local without || true
bundle config unset --global without || true
rm -f .bundle/config
bundle config set --local without development
bundle install
export RAILS_ENV=test
bundle exec rake db:migrate redmine:plugins:migrate
bundle exec rake redmine:plugins:test NAME=redmine_issue_templates
'
