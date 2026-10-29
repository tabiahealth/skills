#!/usr/bin/env bash
# Fails when a pull request changes the "version" of an existing plugin manifest. Release
# branches (release/<plugin>, pushed from this repository) are the exception, because changing
# the version is their whole purpose. A new plugin sets its first version freely.
#
# Runs in GitHub Actions from a full-history checkout. Requires bash, git and jq, and the
# environment variables BASE_SHA, HEAD_SHA, HEAD_REF and SAME_REPOSITORY ("true" or "false").
set -euo pipefail

for tool in git jq; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done
: "${BASE_SHA:?}" "${HEAD_SHA:?}" "${HEAD_REF:?}" "${SAME_REPOSITORY:?}"

if [[ "$HEAD_REF" == release/* && "$SAME_REPOSITORY" == "true" ]]; then
  echo "Release branch $HEAD_REF: version changes are expected."
  exit 0
fi

manifest_version() {
  git show "$1:$2" 2>/dev/null | jq -r '.version // empty' 2>/dev/null || true
}

# Comparing against the merge base, not the base tip, keeps a release merged to the base after
# this branch was cut from reading as a version change made by this pull request.
merge_base=$(git merge-base "$BASE_SHA" "$HEAD_SHA")

failed=0
while IFS= read -r manifest; do
  git cat-file -e "$merge_base:$manifest" 2>/dev/null || continue
  git cat-file -e "$HEAD_SHA:$manifest" 2>/dev/null || continue
  if ! git show "$HEAD_SHA:$manifest" | jq empty 2>/dev/null; then
    echo "::error file=$manifest::$manifest is not valid JSON."
    failed=1
    continue
  fi
  before=$(manifest_version "$merge_base" "$manifest")
  after=$(manifest_version "$HEAD_SHA" "$manifest")
  if [ "$before" != "$after" ]; then
    echo "::error file=$manifest::This pull request changes \"version\" from ${before:-(none)} to ${after:-(none)}. Leave the version alone; the release PR bumps it after merge. Add a 'release: patch' or 'release: major' label to this pull request to ask for a different bump than the default minor."
    failed=1
  fi
done < <(git diff --name-only "$merge_base" "$HEAD_SHA" -- 'plugins/*/.claude-plugin/plugin.json')

if [ "$failed" -eq 0 ]; then
  echo "No plugin version changed."
fi
exit "$failed"
