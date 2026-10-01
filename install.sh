#!/usr/bin/env bash
# Install ml-messenger (the Messenger and Messenger_extra libraries) into the
# current opam switch, so applications in other directories can use it:
#
#   (libraries ml-messenger ml-messenger.extra regl_js)       ; browser
#   (libraries ml-messenger ml-messenger.extra regl_desktop)  ; native
#
# The ml-regl packages must be installed first (../ml-regl/install.sh). As
# with ml-regl, the package is pinned to this git checkout, so opam installs
# the current branch's last commit: commit, then rerun to update it.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package=ml-messenger
regl_packages=(ml_regl_core regl_backend)

if ! command -v opam >/dev/null 2>&1; then
    echo "error: opam was not found" >&2
    exit 1
fi

cd "$repo_root"
eval "$(opam env)"

installed() {
    opam list --installed --short "$1" 2>/dev/null | grep -Fxq "$1"
}

missing=()
for regl_package in "${regl_packages[@]}"; do
    if ! installed "$regl_package"; then
        missing+=("$regl_package")
    fi
done
if (( ${#missing[@]} > 0 )); then
    echo "error: ${missing[*]} not installed; run ../ml-regl/install.sh first" >&2
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "warning: uncommitted changes are not installed; opam installs the last commit" >&2
fi

# Messenger_extra used to be a separate opam package; it is now the
# ml-messenger.extra library inside ml-messenger.
if opam pin list --short 2>/dev/null | grep -Fxq ml-messenger-extra; then
    echo "==> Removing the old ml-messenger-extra pin"
    opam pin remove -y --no-action ml-messenger-extra
fi

echo "==> Checking that $package builds"
dune build -p "$package" @install

echo "==> Pinning $package to $repo_root"
opam pin add -y --no-action "$package" "$repo_root"

echo "==> Installing $package"
if installed "$package"; then
    opam reinstall -y "$package"
else
    opam install -y "$package"
fi
