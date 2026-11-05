#!/usr/bin/env bash
# Keeps one release pull request open per plugin that has unreleased changes on the base branch.
#
# A plugin's last release is the newest commit that changed the "version" field of its
# .claude-plugin/plugin.json. Every commit under the plugin directory after that one is
# unreleased. For each such plugin this script rebuilds the branch release/<plugin> from the
# base branch with only the version bumped, force-pushes it, and opens or updates its pull
# request.
#
# Runs in GitHub Actions from a full-history checkout of the base branch. Requires bash 4.4+,
# git, jq and gh, and the environment variables GH_TOKEN and GITHUB_REPOSITORY.
set -euo pipefail

for tool in git jq gh; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set to owner/repo}"
: "${GH_TOKEN:?GH_TOKEN must be set}"

readonly BASE_BRANCH="${BASE_BRANCH:-main}"
readonly MAJOR_LABEL='release: major'
readonly PATCH_LABEL='release: patch'
readonly BOT_NAME='github-actions[bot]'
readonly BOT_EMAIL='41898282+github-actions[bot]@users.noreply.github.com'

base_sha=$(git rev-parse HEAD)
readonly base_sha
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

# Prints the "version" of the manifest at <rev>, or nothing when the file or the field is absent.
manifest_version() {
  git show "$1:$2" 2>/dev/null | jq -r '.version // empty' 2>/dev/null || true
}

# Prints the newest commit that changed the manifest's "version", including the commit that
# created the manifest.
last_release_commit() {
  local manifest="$1" sha
  while IFS= read -r sha; do
    if [ "$(manifest_version "$sha" "$manifest")" != "$(manifest_version "$sha^" "$manifest")" ]; then
      printf '%s\n' "$sha"
      return 0
    fi
  done < <(git log --format=%H "$base_sha" -- "$manifest")
  return 1
}

next_version() {
  local version="$1" bump="$2"
  if ! [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    return 1
  fi
  local major="${BASH_REMATCH[1]}" minor="${BASH_REMATCH[2]}" patch="${BASH_REMATCH[3]}"
  case "$bump" in
    major) printf '%s.0.0\n' "$((major + 1))" ;;
    minor) printf '%s.%s.0\n' "$major" "$((minor + 1))" ;;
    patch) printf '%s.%s.%s\n' "$major" "$minor" "$((patch + 1))" ;;
    *) return 1 ;;
  esac
}

changed_line_count() {
  diff "$1" "$2" | grep -c '^>' || true
}

# jq rewrites the whole document, so this keeps whichever of jq's two string encodings
# (literal UTF-8 or \u escapes) leaves the rest of the file as it was.
set_manifest_version() {
  local manifest="$1" version="$2"
  local literal="$work_dir/literal.json" escaped="$work_dir/escaped.json"
  jq --indent 2 --arg v "$version" '.version = $v' "$manifest" >"$literal"
  jq --indent 2 --ascii-output --arg v "$version" '.version = $v' "$manifest" >"$escaped"
  if [ "$(changed_line_count "$manifest" "$escaped")" -lt "$(changed_line_count "$manifest" "$literal")" ]; then
    cp "$escaped" "$manifest"
  else
    cp "$literal" "$manifest"
  fi
}

# Appends one JSON object per merged pull request behind <sha> to <out>, or one for the commit
# itself when it reached the base branch without a pull request.
collect_pull_requests() {
  local sha="$1" out="$2" found
  found=$(gh api "repos/$GITHUB_REPOSITORY/commits/$sha/pulls" \
    --jq ".[] | select(.merged_at != null and .base.ref == \"$BASE_BRANCH\")
               | {number, title, merged_at, labels: [.labels[].name]}")
  if [ -n "$found" ]; then
    printf '%s\n' "$found" >>"$out"
  else
    git show -s --format='%H%x09%cI%x09%s' "$sha" \
      | jq -R 'split("\t") | {number: null, sha: .[0][0:7], merged_at: .[1], title: (.[2:] | join("\t")), labels: []}' \
      >>"$out"
  fi
}

# Prints the bump size followed by a tab and the sentence that explains it.
choose_bump() {
  jq -r --arg major "$MAJOR_LABEL" --arg patch "$PATCH_LABEL" '
    def asking($wanted): [.[] | select(any(.labels[]; . == $wanted)) | "#\(.number)"] | join(", ");
    asking($major) as $majors
    | asking($patch) as $patches
    | if $majors != "" then "major\tMajor, asked for by `\($major)` on \($majors)."
      elif $patches != "" then "patch\tPatch, asked for by `\($patch)` on \($patches); no included pull request carries `\($major)`."
      else "minor\tMinor, the default: no included pull request carries `\($major)` or `\($patch)`."
      end' "$1"
}

# The backticks are Markdown code spans in the pull request body.
# shellcheck disable=SC2016
write_body() {
  local plugin="$1" from="$2" to="$3" reason="$4" prs="$5"
  printf 'Bumps `%s` from %s to %s.\n\n' "$plugin" "$from" "$to"
  printf '**Bump:** %s\n\n' "$reason"
  printf '## Included\n\n'
  jq -r '.[] | if .number then "- #\(.number) \(.title)" else "- \(.sha) \(.title)" end' "$prs"
  printf '\n'
  printf 'Claude Code delivers a plugin update only when its `version` changes, so merging this pull request is what ships these changes to users. '
  printf 'The `release/%s` branch is rebuilt from `%s` after every merge that touches the plugin, so this pull request always covers everything unreleased.\n\n' "$plugin" "$BASE_BRANCH"
  printf 'To ask for a different bump, add `%s` or `%s` to one of the included pull requests and re-run the release workflow.\n' "$PATCH_LABEL" "$MAJOR_LABEL"
}

# Pull requests opened with GITHUB_TOKEN do not trigger pull_request workflows, so the
# version-guard check would never report on a release pull request and a required check would
# block it. The guard always passes on release/ branches, so this records that result directly.
report_version_guard() {
  gh api "repos/$GITHUB_REPOSITORY/check-runs" --silent \
    -f name=version-guard \
    -f head_sha="$1" \
    -f status=completed \
    -f conclusion=success \
    -f 'output[title]=Release branch' \
    -f 'output[summary]=Release branches are the one place the plugin version is expected to change.'
}

open_or_update_pull_request() {
  local branch="$1" title="$2" body_file="$3" number
  number=$(gh api "repos/$GITHUB_REPOSITORY/pulls?state=open&base=$BASE_BRANCH&head=${GITHUB_REPOSITORY%%/*}:$branch" \
    --jq '.[0].number // empty')
  if [ -n "$number" ]; then
    gh api -X PATCH "repos/$GITHUB_REPOSITORY/pulls/$number" --silent \
      -f title="$title" -F body=@"$body_file"
    echo "Updated pull request #$number: $title"
  else
    number=$(gh api "repos/$GITHUB_REPOSITORY/pulls" --jq '.number' \
      -f title="$title" -f head="$branch" -f base="$BASE_BRANCH" -F body=@"$body_file")
    echo "Opened pull request #$number: $title"
  fi
}

release_plugin() {
  local manifest="$1"
  local plugin_dir="${manifest%/.claude-plugin/plugin.json}"
  local plugin="${plugin_dir#plugins/}"
  local branch="release/$plugin"

  local current_version
  current_version=$(manifest_version "$base_sha" "$manifest")
  if [ -z "$current_version" ]; then
    echo "::warning file=$manifest::No \"version\" field; skipping $plugin."
    return 0
  fi

  local release_sha
  release_sha=$(last_release_commit "$manifest")

  local prs_raw="$work_dir/$plugin.jsonl" prs="$work_dir/$plugin.json" sha count=0
  : >"$prs_raw"
  while IFS= read -r sha; do
    collect_pull_requests "$sha" "$prs_raw"
    count=$((count + 1))
  done < <(git log --format=%H "$release_sha..$base_sha" -- "$plugin_dir")

  if [ "$count" -eq 0 ]; then
    echo "$plugin $current_version: nothing unreleased since $(git rev-parse --short "$release_sha")."
    return 0
  fi

  jq -s 'unique_by(.number // .sha) | sort_by(.merged_at) | reverse' "$prs_raw" >"$prs"

  local decision bump reason next
  decision=$(choose_bump "$prs")
  bump="${decision%%$'\t'*}"
  reason="${decision#*$'\t'}"
  if ! next=$(next_version "$current_version" "$bump"); then
    echo "::error file=$manifest::\"version\" is $current_version, which is not MAJOR.MINOR.PATCH."
    return 1
  fi

  local title="Release $plugin $next"
  git checkout --quiet -B "$branch" "$base_sha"
  set_manifest_version "$manifest" "$next"
  git add "$manifest"
  git -c user.name="$BOT_NAME" -c user.email="$BOT_EMAIL" commit --quiet -m "$title"
  git push --quiet --force origin "$branch"
  report_version_guard "$(git rev-parse HEAD)"

  local body_file="$work_dir/$plugin-body.md"
  write_body "$plugin" "$current_version" "$next" "$reason" "$prs" >"$body_file"
  open_or_update_pull_request "$branch" "$title" "$body_file"

  git checkout --quiet --detach "$base_sha"
}

for manifest in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$manifest" ] || continue
  release_plugin "$manifest"
done
