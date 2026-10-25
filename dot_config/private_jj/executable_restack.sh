#!/usr/bin/env bash
# Incrementally restack every mutable stack onto trunk().
#
#   restack.sh safe            rebase each stack onto the newest trunk() revision that applies cleanly
#   restack.sh first-conflict  rebase each stack onto the first trunk() revision that introduces a conflict
#
# Each independent mutable stack (a root of `roots(trunk()..) & mutable()`) is restacked on its own, so
# a stack that clashes with trunk() no longer drags the others down to a shared revision. A stack
# already based on trunk() is left untouched. For a conflicting stack, trunk() history is bisected for
# the first revision whose rebase reports "New conflicts"; `first-conflict` materializes that conflict
# so it can be resolved, then the stack can be rebased one conflicting trunk() revision further on each
# re-run, walking the stack to trunk().
set -euo pipefail

mode=${1:-safe}

rebase_onto() { # src target
  jj rebase -s "$1" -o "$2" --simplify-parents
}

restack_stack() { # root
  local src=$1 base pre bisect_out bad

  precheck=$(jj --no-integrate-operation rebase -s "$src" -o 'trunk()' 2>&1 || true)
  case "$precheck" in
    *"New conflicts"*) ;;
    *) rebase_onto "$src" 'trunk()'; return 0 ;;
  esac

  base=$(jj log -r "fork_point($src | trunk())" --no-graph -T 'change_id')
  if [ -z "$(jj log -r "$base..trunk()" --no-graph -n1 -T 'change_id')" ]; then
    echo "restack: no trunk() revisions after $src's fork point; rebasing onto trunk()" >&2
    rebase_onto "$src" 'trunk()'
    return 0
  fi

  pre=$(jj op log -n1 --no-graph -T 'id')
  bisect_out=$(jj bisect run --range "$base..trunk()" -- bash -c "o=\$(jj --no-integrate-operation rebase -s '$src' -o \"\$JJ_BISECT_TARGET\" 2>&1); case \"\$o\" in *\"New conflicts\"*) exit 1;; *) exit 0;; esac" 2>&1 || true)
  jj op restore "$pre" >/dev/null 2>&1
  bad=$(printf '%s\n' "$bisect_out" | sed -nE 's/^The first bad revision is: ([^ ]+).*/\1/p')

  if [ -z "$bad" ]; then
    printf '%s\n' "$bisect_out" >&2
    echo "restack: bisect found no conflicting trunk() revision for $src; rebasing onto trunk()" >&2
    rebase_onto "$src" 'trunk()'
    return 0
  fi

  case "$mode" in
    first-conflict)
      echo "restack: rebasing $src onto $bad, the first conflicting trunk() revision (resolve the conflicts, then re-run)" >&2
      rebase_onto "$src" "$bad"
      ;;
    *)
      echo "restack: rebasing $src onto $bad- ($bad is the first trunk() revision that conflicts)" >&2
      rebase_onto "$src" "$bad-"
      ;;
  esac
}

while read -r root; do
  [ -n "$root" ] || continue
  if [ -n "$(jj log -r "parents($root) & trunk()" --no-graph -n1 -T 'change_id')" ]; then
    echo "restack: $root is already on top of trunk(), leaving it" >&2
    continue
  fi
  restack_stack "$root"
done < <(jj log -r 'roots(trunk()..) & mutable()' --no-graph -T 'change_id ++ "\n"')
