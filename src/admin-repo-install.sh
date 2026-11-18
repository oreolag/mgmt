#!/usr/bin/env bash
set -euo pipefail

destination="$1"
github_user="$2"
gh_path="$3"
repo="$github_user/my_oreol_mgmt"
repo_url="https://github.com/$repo.git"

github_git() {
    git -c credential.helper= \
        -c "credential.https://github.com.helper=!\"$gh_path\" auth git-credential" "$@"
}

if [[ -e "$destination" || -L "$destination" ]]; then
    origin="$(git -C "$destination" config --get remote.origin.url 2>/dev/null || true)"
    case "$origin" in
        "$repo_url"|"https://github.com/$repo"|"git@github.com:$repo.git")
            if [[ -d "$destination/.git" || -f "$destination/.git" ]]; then
                git -C "$destination" submodule update --init --recursive
                exit 0
            fi
            ;;
    esac
    printf 'Destination already exists and is not a checkout of %s: %s\n' "$repo" "$destination" >&2
    exit 1
fi

if ! visibility="$("$gh_path" api --hostname github.com --paginate \
    'user/repos?affiliation=owner&per_page=100' | python3 -c '
import json
import sys

decoder = json.JSONDecoder()
pages = sys.stdin.read().lstrip()
visibility = ""
while pages:
    repositories, end = decoder.raw_decode(pages)
    for repository in repositories:
        if repository["full_name"] == sys.argv[1]:
            visibility = repository["visibility"]
    pages = pages[end:].lstrip()
print(visibility)
' "$repo")"; then
    printf 'Could not check GitHub repository %s.\n' "$repo" >&2
    exit 1
fi

staging="$(mktemp -d "$(dirname "$destination")/.omgmt-install.XXXXXXXX")"
trap 'rm -rf "$staging"' EXIT
checkout="$staging/my_oreol_mgmt"

if [[ -n "$visibility" ]]; then
    github_git clone "$repo_url" "$checkout"
fi

# A previously interrupted first push can leave an empty GitHub repository.
if [[ -z "$visibility" ]] || ! git -C "$checkout" rev-parse --verify HEAD >/dev/null 2>&1; then
    if [[ -n "$visibility" ]]; then
        if [[ "$visibility" != private ]]; then
            echo "Refusing to seed a non-private GitHub repository: $repo" >&2
            exit 1
        fi
        # Keep the empty clone inside staging until the installer exits.
        mv "$checkout" "$staging/empty"
    fi
    git init -q "$checkout"
    git -C "$checkout" symbolic-ref HEAD refs/heads/main
    git -C "$checkout" remote add origin "$repo_url"
    mkdir -p "$checkout/clusters" "$checkout/playbooks" "$checkout/roles"
    touch "$checkout/clusters/.gitkeep" "$checkout/playbooks/.gitkeep" "$checkout/roles/.gitkeep"
    git -C "$checkout" add -- clusters playbooks roles
    git -C "$checkout" \
        -c "user.name=$github_user" -c "user.email=$github_user@users.noreply.github.com" \
        commit -m "Initialize management repository"

    if [[ -z "$visibility" ]]; then
        "$gh_path" repo create "$repo" --private
    fi
    github_git -C "$checkout" push -u origin HEAD:refs/heads/main
else
    git -C "$checkout" submodule update --init --recursive

fi

# Reserve the destination so a concurrent install cannot overwrite a checkout.
mkdir "$destination"
shopt -s dotglob
mv "$checkout"/* "$destination/"
