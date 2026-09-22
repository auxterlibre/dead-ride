#!/usr/bin/env bash
# Headless Godot verification wrapper (keeps permission prompts down: one
# allowlisted command instead of ad-hoc pipelines). Usage:
#   _tools/verify.sh import                    reimport assets
#   _tools/verify.sh scene <res://path> [N]    run a scene for N frames (default 120)
#   _tools/verify.sh script <path>             run a SceneTree --script probe
#   _tools/verify.sh probes [subject|path]     run the headless probe suite, tallied
#   _tools/verify.sh shots [subject|path]      run the WINDOWED *_shot probes, tallied
#   _tools/verify.sh shadow                    locals shadowing a base-class member
#   _tools/verify.sh errors <...>              any mode, but only error/DBG lines
# GODOT_BIN overrides the binary; PROBE_FRAMES (default 20000) is the hang backstop.
GODOT="${GODOT_BIN:-C:/Program Files/Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe}"
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
PROBES="$PROJECT/_tools/probes"
FRAMES="${PROBE_FRAMES:-20000}"
NOISE='minimal_theme|resource_format_text.cpp:1442|resource_loader.cpp:317|ObjectDB instances|resources still in use|leaked|Godot Engine|https://godotengine|^\['

run() {
  case "$1" in
    import) "$GODOT" --headless --path "$PROJECT" --import --quit 2>&1 ;;
    scene)  "$GODOT" --headless --path "$PROJECT" "$2" --quit-after "${3:-120}" 2>&1 ;;
    script) "$GODOT" --headless --path "$PROJECT" --script "$2" "${@:3}" 2>&1 ;;
    # GDScript WARNINGS are editor-only - headless prints errors alone - so a
    # local shadowing a base-class member reaches the user before it reaches us.
    shadow) "$GODOT" --headless --path "$PROJECT" --script res://_tools/shadow_check.gd 2>&1 ;;
    *) echo "usage: verify.sh import | scene <res://..> [frames] | script <path> | probes [subject] | shots [subject] | shadow"; exit 1 ;;
  esac
}

# Probe scenes matching a filter, as subject/name paths without the extension.
# No filter = every one; "world" = that folder; "world/heat_probe" = just it.
probe_list() {
  local want="$1" filter="$2" f rel
  if [ -n "$filter" ] && [ -f "$PROBES/$filter.tscn" ]; then
    echo "$filter"
    return
  fi
  for f in "$PROBES"/${filter:-*}/*.tscn; do
    [ -e "$f" ] || continue
    rel="${f#"$PROBES"/}"
    rel="${rel%.tscn}"
    case "$rel" in
      *_shot) [ "$want" = shots ] && echo "$rel" ;;
      *)      [ "$want" = probes ] && echo "$rel" ;;
    esac
  done
}

# Run one probe scene and print its own DBG lines. Windowed for the shots, since
# --headless installs a dummy rasteriser and every capture saves blank.
probe_run() {
  local rel="$1" want="$2"
  if [ "$want" = shots ]; then
    "$GODOT" --path "$PROJECT" "res://_tools/probes/$rel.tscn" --quit-after "$FRAMES" 2>&1
  else
    "$GODOT" --headless --path "$PROJECT" "res://_tools/probes/$rel.tscn" --quit-after "$FRAMES" 2>&1
  fi
}

# The suite: one line per probe, every failure quoted, non-zero exit if any
# probe failed a check, errored, or never printed a tally at all.
suite() {
  local want="$1" filter="$2" rel out tally pass fail
  local total_pass=0 total_fail=0 broken=0 ran=0
  local failures="" list
  list="$(probe_list "$want" "$filter")"
  if [ -z "$list" ]; then
    echo "no ${want} match '${filter:-*}' under _tools/probes/"
    exit 1
  fi
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    ran=$((ran + 1))
    out="$(probe_run "$rel" "$want")"
    tally="$(printf '%s\n' "$out" | grep -oE 'DBG [0-9]+ passed, [0-9]+ failed' | tail -1)"
    if [ -z "$tally" ]; then
      # No tally line: the probe crashed, hung to its frame budget, or predates
      # the convention. Either way it is not evidence of anything passing.
      echo "  ??  $rel  (no tally - crashed, hung, or never reported)"
      broken=$((broken + 1))
      failures="$failures
--- $rel (no tally) ---
$(printf '%s\n' "$out" | grep -vE "$NOISE" | grep -E 'ERROR|SCRIPT|Parse|DBG' | head -12)"
      continue
    fi
    pass="$(printf '%s' "$tally" | awk '{print $2}')"
    fail="$(printf '%s' "$tally" | awk '{print $4}')"
    total_pass=$((total_pass + pass))
    total_fail=$((total_fail + fail))
    if [ "$fail" -gt 0 ]; then
      echo "  FAIL  $rel  $pass passed, $fail failed"
      failures="$failures
--- $rel ---
$(printf '%s\n' "$out" | grep -E '^DBG FAIL|SCRIPT ERROR' | head -12)"
    else
      echo "  ok    $rel  $pass passed"
    fi
  done <<< "$list"

  echo
  local noun="${want}"
  [ "$ran" -eq 1 ] && noun="${want%s}"
  echo "$ran $noun: $total_pass checks passed, $total_fail failed, $broken without a tally"
  if [ -n "$failures" ]; then
    echo "$failures"
  fi
  [ "$total_fail" -eq 0 ] && [ "$broken" -eq 0 ]
}

case "$1" in
  probes|shots)
    suite "$1" "$2"
    ;;
  errors)
    shift
    run "$@" | grep -vE "$NOISE" | grep -E "ERROR|SCRIPT|WARNING|DBG" | head -40
    ;;
  dbg)
    shift
    run "$@" | grep -E "^DBG|SCRIPT ERROR" | head -60
    ;;
  *)
    run "$@" | grep -vE "$NOISE" | grep -v '^$' | head -40
    ;;
esac
