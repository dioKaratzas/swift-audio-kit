#!/usr/bin/env bash
#
# Builds the SwiftAudioKit DocC documentation.
#
#   ./Scripts/generate_docs.sh                  # static site into ./docs
#   ./Scripts/generate_docs.sh --output build   # static site into ./build
#   ./Scripts/generate_docs.sh --preview        # local preview server
#
# Publishing is GitHub Actions' job; see .github/workflows/docs.yml. This script
# never touches git.

set -euo pipefail

# The only place the plugin version is written. Bump it here.
readonly DOCC_PLUGIN_URL="https://github.com/apple/swift-docc-plugin.git"
readonly DOCC_PLUGIN_VERSION="1.5.0"

readonly TARGET="SwiftAudioKit"
readonly HOSTING_BASE_PATH="swift-audio-kit"
readonly DEFAULT_OUTPUT="docs"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT
readonly MANIFEST="$ROOT/Package.swift"

manifest_backup=""

usage() {
    cat <<EOF
Usage: ${0##*/} [--output <dir>] [--preview] [--help]

  --output <dir>  Write a static-hosting-ready site to <dir> (default: ./$DEFAULT_OUTPUT).
                  The directory is emptied first.
  --preview       Serve the documentation locally instead of writing it out.
  --help          Show this message.

SwiftAudioKit declares no dependencies, which is deliberate. The DocC plugin is
appended to Package.swift only for the duration of this script and removed again
on every exit path, including failures and interrupts.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

# Restores Package.swift byte for byte. Runs on success, failure and interrupt.
cleanup() {
    local status=$?
    if [[ -n "$manifest_backup" && -f "$manifest_backup" ]]; then
        mv -f "$manifest_backup" "$MANIFEST"
        manifest_backup=""
    fi
    return $status
}

# Appending to the manifest needs no marker comment to anchor on, so reformatting
# Package.swift cannot break it. PackageDescription.Package is a class, which is why
# `package` can be mutated after it is declared `let`.
inject_plugin() {
    if grep -q "swift-docc-plugin" "$MANIFEST"; then
        echo "==> swift-docc-plugin already declared in Package.swift, leaving it alone"
        return
    fi

    echo "==> Adding swift-docc-plugin $DOCC_PLUGIN_VERSION to Package.swift (temporarily)"
    manifest_backup="$(mktemp "${TMPDIR:-/tmp}/Package.swift.XXXXXX")"
    cp -p "$MANIFEST" "$manifest_backup"

    cat >>"$MANIFEST" <<EOF

package.dependencies.append(
    .package(url: "$DOCC_PLUGIN_URL", from: "$DOCC_PLUGIN_VERSION")
)
EOF
}

preview() {
    echo "==> Previewing documentation for $TARGET"
    swift package --package-path "$ROOT" --disable-sandbox \
        preview-documentation --target "$TARGET"
}

generate() {
    local output="$1"

    echo "==> Generating documentation for $TARGET into $output"
    rm -rf "$output"
    mkdir -p "$output"

    swift package --package-path "$ROOT" --allow-writing-to-directory "$output" \
        generate-documentation \
        --target "$TARGET" \
        --disable-indexing \
        --transform-for-static-hosting \
        --hosting-base-path "$HOSTING_BASE_PATH" \
        --output-path "$output"

    write_landing_redirect "$output"

    echo "==> Documentation written to $output"
}

# DocC's root index.html is the app shell, which resolves to nothing when served as
# static files. Point the site root at the module page instead.
write_landing_redirect() {
    local output="$1"
    local module
    module="$(echo "$TARGET" | tr '[:upper:]' '[:lower:]')"
    local landing="/$HOSTING_BASE_PATH/documentation/$module/"

    [[ -f "$output/documentation/$module/index.html" ]] || {
        echo "warning: no page at documentation/$module, skipping root redirect" >&2
        return
    }

    cat >"$output/index.html" <<EOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>$TARGET</title>
<meta http-equiv="refresh" content="0; url=$landing">
<link rel="canonical" href="$landing">
</head>
<body><a href="$landing">$TARGET documentation</a></body>
</html>
EOF
}

main() {
    local output=""
    local mode="generate"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --output)
                [[ $# -ge 2 ]] || die "--output needs a directory"
                output="$2"
                shift 2
                ;;
            --output=*)
                output="${1#*=}"
                shift
                ;;
            --preview)
                mode="preview"
                shift
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *)
                usage >&2
                die "unknown argument: $1"
                ;;
        esac
    done

    [[ "$mode" == "generate" || -z "$output" ]] || die "--output and --preview are mutually exclusive"

    command -v swift >/dev/null 2>&1 || die "swift not found on PATH"
    [[ -f "$MANIFEST" ]] || die "no Package.swift at $ROOT"
    [[ -d "$ROOT/Sources/$TARGET/$TARGET.docc" ]] || die "no DocC catalogue at Sources/$TARGET/$TARGET.docc"

    # Interrupts exit rather than resuming, so the EXIT trap always gets to restore.
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    inject_plugin

    if [[ "$mode" == "preview" ]]; then
        preview
        return
    fi

    output="${output:-$DEFAULT_OUTPUT}"
    [[ "$output" = /* ]] || output="$ROOT/$output"
    mkdir -p "$output" || die "cannot create $output"
    # The directory is emptied before writing, so canonicalise it first: `.`, `..`
    # and symlinks must not be able to point that delete somewhere unintended.
    output="$(cd "$output" && pwd -P)"
    [[ "$output" != "/" ]] || die "refusing to write to /"
    [[ "$output" != "$(cd "$ROOT" && pwd -P)" ]] || die "refusing to write to the package root"

    generate "$output"
}

main "$@"
