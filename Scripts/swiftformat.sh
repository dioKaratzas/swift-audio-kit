#!/usr/bin/env bash
set -euo pipefail

SWIFTFORMAT_VERSION="0.63.0"
SWIFTFORMAT_ARTIFACT_URL="https://github.com/nicklockwood/SwiftFormat/releases/download/${SWIFTFORMAT_VERSION}/swiftformat.artifactbundle.zip"
SWIFTFORMAT_LINUX_URL="https://github.com/nicklockwood/SwiftFormat/releases/download/${SWIFTFORMAT_VERSION}/swiftformat_linux.zip"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIG_PATH="${SCRIPT_DIR}/Configs/config.swiftformat"
BINARIES_DIR="${SCRIPT_DIR}/Binaries"
SWIFTFORMAT_ARTIFACT_ZIP="${BINARIES_DIR}/swiftformat.artifactbundle.zip"
SWIFTFORMAT_ARTIFACT_DIR="${BINARIES_DIR}/swiftformat.artifactbundle"
SWIFTFORMAT_ARTIFACT_BIN="${BINARIES_DIR}/swiftformat-artifactbundle"
SWIFTFORMAT_LINUX_ZIP="${BINARIES_DIR}/swiftformat_linux.zip"
SWIFTFORMAT_LINUX_DIR="${BINARIES_DIR}/swiftformat_linux"
SWIFTFORMAT_LINUX_BIN="${BINARIES_DIR}/swiftformat-linux"

log() {
    printf '[swiftformat] %s\n' "$*" >&2
}

fail() {
    printf '[swiftformat] %s\n' "$*" >&2
    exit 1
}

git_repo() {
    git -C "${PROJECT_ROOT}" "$@"
}

detect_os() {
    case "$(uname -s)" in
        Linux)
            printf 'linux\n'
            ;;
        Darwin)
            printf 'darwin\n'
            ;;
        *)
            fail "Unsupported OS: $(uname -s)"
            ;;
    esac
}

ensure_artifact_binary() {
    if [ -x "${SWIFTFORMAT_ARTIFACT_BIN}" ]; then
        return
    fi

    mkdir -p "${BINARIES_DIR}"

    if [ ! -f "${SWIFTFORMAT_ARTIFACT_ZIP}" ]; then
        log "Downloading SwiftFormat ${SWIFTFORMAT_VERSION} artifact bundle"
        curl -fL "${SWIFTFORMAT_ARTIFACT_URL}" -o "${SWIFTFORMAT_ARTIFACT_ZIP}"
    else
        log "Using cached archive ${SWIFTFORMAT_ARTIFACT_ZIP}"
    fi

    log "Extracting artifact bundle"
    unzip -qo "${SWIFTFORMAT_ARTIFACT_ZIP}" -d "${BINARIES_DIR}"

    local found_binary
    found_binary="$(find "${SWIFTFORMAT_ARTIFACT_DIR}" -type f -name swiftformat | head -n 1 || true)"
    if [ -z "${found_binary}" ]; then
        fail "Could not find swiftformat binary in ${SWIFTFORMAT_ARTIFACT_DIR}"
    fi

    cp "${found_binary}" "${SWIFTFORMAT_ARTIFACT_BIN}"
    chmod +x "${SWIFTFORMAT_ARTIFACT_BIN}"
}

ensure_linux_binary() {
    if [ -x "${SWIFTFORMAT_LINUX_BIN}" ]; then
        return
    fi

    mkdir -p "${BINARIES_DIR}"

    if [ ! -f "${SWIFTFORMAT_LINUX_ZIP}" ]; then
        log "Downloading SwiftFormat ${SWIFTFORMAT_VERSION} linux binary zip"
        curl -fL "${SWIFTFORMAT_LINUX_URL}" -o "${SWIFTFORMAT_LINUX_ZIP}"
    else
        log "Using cached archive ${SWIFTFORMAT_LINUX_ZIP}"
    fi

    mkdir -p "${SWIFTFORMAT_LINUX_DIR}"
    log "Extracting linux binary zip"
    unzip -qo "${SWIFTFORMAT_LINUX_ZIP}" -d "${SWIFTFORMAT_LINUX_DIR}"

    local found_binary
    found_binary="$(find "${SWIFTFORMAT_LINUX_DIR}" -type f -name swiftformat | head -n 1 || true)"
    if [ -z "${found_binary}" ]; then
        fail "Could not find swiftformat binary in ${SWIFTFORMAT_LINUX_DIR}"
    fi

    cp "${found_binary}" "${SWIFTFORMAT_LINUX_BIN}"
    chmod +x "${SWIFTFORMAT_LINUX_BIN}"
}

resolve_swiftformat_binary() {
    local os

    os="$(detect_os)"
    if [ "${os}" = "linux" ]; then
        ensure_linux_binary
        printf '%s\n' "${SWIFTFORMAT_LINUX_BIN}"
        return
    fi

    ensure_artifact_binary
    printf '%s\n' "${SWIFTFORMAT_ARTIFACT_BIN}"
}

resolve_base_ref() {
    if [ -n "${SWIFTFORMAT_BASE_REF:-}" ]; then
        printf '%s\n' "${SWIFTFORMAT_BASE_REF}"
        return
    fi

    if git_repo rev-parse --verify --quiet origin/master >/dev/null; then
        printf 'origin/master\n'
        return
    fi

    if git_repo rev-parse --verify --quiet master >/dev/null; then
        printf 'master\n'
        return
    fi

    if git_repo rev-parse --verify --quiet origin/main >/dev/null; then
        printf 'origin/main\n'
        return
    fi

    if git_repo rev-parse --verify --quiet main >/dev/null; then
        printf 'main\n'
        return
    fi

    fail "Could not resolve base branch. Set SWIFTFORMAT_BASE_REF or ensure master/main exists."
}

format_all() {
    local swiftformat_bin="$1"
    log "Formatting all Swift files"
    "${swiftformat_bin}" "${PROJECT_ROOT}" --config "${CONFIG_PATH}"
}

lint_changed() {
    local swiftformat_bin="$1"
    local base_ref
    local merge_base
    local changed_count

    base_ref="$(resolve_base_ref)"
    merge_base="$(git_repo merge-base HEAD "${base_ref}")"
    changed_count="$(git_repo diff --name-only --diff-filter=ACMR "${merge_base}" HEAD -- '*.swift' | wc -l | tr -d ' ')"

    if [ "${changed_count}" = "0" ]; then
        log "No changed Swift files to lint against ${base_ref}"
        return
    fi

    log "Linting ${changed_count} changed Swift file(s) against ${base_ref}"
    git_repo diff --name-only --diff-filter=ACMR -z "${merge_base}" HEAD -- '*.swift' \
        | xargs -0 "${swiftformat_bin}" --config "${CONFIG_PATH}" --lint
}

usage() {
    cat <<'EOF'
Usage: Scripts/swiftformat.sh <command>

Commands:
  format-all     Download (if needed) and format all Swift files in the repository.
  lint-changed   Download (if needed) and lint changed Swift files.
  ensure-binary  Download and prepare the local SwiftFormat binary for this OS.
EOF
}

main() {
    local command="${1:-format-all}"
    local swiftformat_bin

    if [ ! -f "${CONFIG_PATH}" ]; then
        fail "Missing config: ${CONFIG_PATH}"
    fi

    case "${command}" in
        format-all|format)
            swiftformat_bin="$(resolve_swiftformat_binary)"
            format_all "${swiftformat_bin}"
            ;;
        lint-changed|lint)
            swiftformat_bin="$(resolve_swiftformat_binary)"
            lint_changed "${swiftformat_bin}"
            ;;
        ensure-binary)
            swiftformat_bin="$(resolve_swiftformat_binary)"
            log "SwiftFormat binary ready at ${swiftformat_bin}"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
