#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/validate-generated-configs.sh [--root <path>]
EOF
}

ROOT_DIR="$(pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT_DIR="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "Root directory not found: $ROOT_DIR" >&2
  exit 1
fi

ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
DEPENDABOT_FILE="$ROOT_DIR/.github/dependabot.yml"
CODEQL_FILE="$ROOT_DIR/.github/workflows/codeql.yml"
CI_FILE="$ROOT_DIR/.github/workflows/ci.yml"

for file in "$DEPENDABOT_FILE" "$CODEQL_FILE" "$CI_FILE"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required generated file: $file" >&2
    exit 1
  fi
done

if ! command -v ruby >/dev/null 2>&1; then
  echo "ruby is required for YAML schema validation." >&2
  exit 1
fi

ruby - "$DEPENDABOT_FILE" "$CODEQL_FILE" "$CI_FILE" <<'RUBY'
require "yaml"

def assert!(condition, message)
  raise message unless condition
end

def load_yaml(path)
  YAML.safe_load(
    File.read(path),
    permitted_classes: [],
    permitted_symbols: [],
    aliases: false
  )
end

dependabot_path, codeql_path, ci_path = ARGV

dependabot = load_yaml(dependabot_path)
assert!(dependabot.is_a?(Hash), "dependabot.yml root must be a mapping")
assert!(dependabot["version"] == 2, "dependabot.yml version must be 2")
updates = dependabot["updates"]
assert!(updates.is_a?(Array) && !updates.empty?, "dependabot.yml updates must be a non-empty array")

actions_entries = updates.select do |u|
  u.is_a?(Hash) && u["package-ecosystem"] == "github-actions" && u["directory"] == "/"
end
assert!(!actions_entries.empty?, "dependabot.yml must include github-actions update at /")

updates.each_with_index do |entry, idx|
  assert!(entry.is_a?(Hash), "dependabot.yml updates[#{idx}] must be a mapping")
  ecosystem = entry["package-ecosystem"]
  directory = entry["directory"]
  schedule = entry["schedule"]
  assert!(ecosystem.is_a?(String) && !ecosystem.empty?, "dependabot.yml updates[#{idx}] missing package-ecosystem")
  assert!(directory.is_a?(String) && directory.start_with?("/"), "dependabot.yml updates[#{idx}] directory must start with /")
  assert!(schedule.is_a?(Hash) && schedule["interval"].is_a?(String), "dependabot.yml updates[#{idx}] missing schedule.interval")
end

codeql = load_yaml(codeql_path)
assert!(codeql.is_a?(Hash), "codeql.yml root must be a mapping")
assert!(codeql["name"] == "codeql", "codeql.yml name must be codeql")
jobs = codeql["jobs"]
assert!(jobs.is_a?(Hash), "codeql.yml jobs must be a mapping")
analyze = jobs["analyze"]
assert!(analyze.is_a?(Hash), "codeql.yml jobs.analyze is required")
steps = analyze["steps"]
assert!(steps.is_a?(Array) && !steps.empty?, "codeql.yml jobs.analyze.steps must be a non-empty array")

resolve_step = steps.find { |s| s.is_a?(Hash) && s["name"] == "Resolve CodeQL mode" }
init_step = steps.find { |s| s.is_a?(Hash) && s["name"] == "Init CodeQL" }
no_lang_step = steps.find { |s| s.is_a?(Hash) && s["name"] == "No supported languages detected" }

if init_step
  assert!(resolve_step, "codeql.yml with Init CodeQL must include Resolve CodeQL mode step")
  init_with = init_step["with"]
  assert!(init_with.is_a?(Hash), "codeql.yml Init CodeQL step must include with block")
  languages = init_with["languages"]
  assert!(languages.is_a?(String) && !languages.strip.empty?, "codeql.yml Init CodeQL languages must be a non-empty string")
  language_set = languages.split(",").map(&:strip).reject(&:empty?)
  requires_autobuild = language_set.any? { |lang| %w[java-kotlin go].include?(lang) }
  has_autobuild = steps.any? { |s| s.is_a?(Hash) && s["name"] == "Autobuild" }
  assert!(requires_autobuild == has_autobuild, "codeql.yml Autobuild presence does not match detected language requirements")
else
  assert!(no_lang_step, "codeql.yml must either initialize CodeQL or include no-language fallback step")
end

ci = load_yaml(ci_path)
assert!(ci.is_a?(Hash), "ci.yml root must be a mapping")
assert!(ci["name"] == "ci", "ci.yml name must be ci")
ci_jobs = ci["jobs"]
assert!(ci_jobs.is_a?(Hash), "ci.yml jobs must be a mapping")
aggregate = ci_jobs["ci"]
assert!(aggregate.is_a?(Hash), "ci.yml jobs.ci is required")

language_jobs = ci_jobs.keys.select { |k| k.end_with?("-ci") && k != "ci" }
if language_jobs.empty?
  aggregate_steps = aggregate["steps"]
  assert!(aggregate_steps.is_a?(Array) && !aggregate_steps.empty?, "ci.yml aggregate fallback must include steps")
else
  needs = aggregate["needs"]
  assert!(needs.is_a?(Array) && !needs.empty?, "ci.yml aggregate job must declare needs for language jobs")
  language_jobs.each do |job_name|
    assert!(needs.include?(job_name), "ci.yml aggregate needs missing #{job_name}")
    job = ci_jobs[job_name]
    assert!(job.is_a?(Hash), "ci.yml #{job_name} must be a mapping")
    matrix_path = job.dig("strategy", "matrix", "path")
    assert!(matrix_path.is_a?(Array) && !matrix_path.empty?, "ci.yml #{job_name} matrix.path must be non-empty")
    steps = job["steps"]
    assert!(steps.is_a?(Array) && !steps.empty?, "ci.yml #{job_name} must include steps")
  end
end

puts "Validation passed:"
puts "- #{dependabot_path}"
puts "- #{codeql_path}"
puts "- #{ci_path}"
RUBY
