#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/compile-al.sh [options] [-- <extra compiler args>]

Options:
  -p, --project <dir>     AL project directory (default: current directory)
  -o, --out <file>        Output .app file (default: <project>/.output/<project>.app)
  -k, --packages <dir>    Package cache path (default: <project>/.alpackages)
  -c, --compiler <path>   Explicit compiler binary path (same as ELC_BIN)
  -h, --help              Show this help

Environment:
  ELC_BIN                 Explicit compiler binary path.
USAGE
}

err() {
  printf 'Error: %s\n' "$*" >&2
}

info() {
  printf '%s\n' "$*"
}

project_dir="$(pwd)"
out_file=""
package_dir=""
compiler_bin="${ELC_BIN:-}"
extra_args=()

while (($#)); do
  case "$1" in
    -p|--project)
      [[ $# -ge 2 ]] || { err "Missing value for $1"; exit 2; }
      project_dir="$2"
      shift 2
      ;;
    -o|--out)
      [[ $# -ge 2 ]] || { err "Missing value for $1"; exit 2; }
      out_file="$2"
      shift 2
      ;;
    -k|--packages)
      [[ $# -ge 2 ]] || { err "Missing value for $1"; exit 2; }
      package_dir="$2"
      shift 2
      ;;
    -c|--compiler)
      [[ $# -ge 2 ]] || { err "Missing value for $1"; exit 2; }
      compiler_bin="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      extra_args=("$@")
      break
      ;;
    *)
      extra_args+=("$1")
      shift
      ;;
  esac
done

project_dir="$(cd "$project_dir" && pwd)"

if [[ ! -f "$project_dir/app.json" ]]; then
  err "No app.json found in project directory: $project_dir"
  exit 1
fi

if [[ -z "$out_file" ]]; then
  project_name="$(basename "$project_dir")"
  out_file="$project_dir/.output/${project_name}.app"
fi

if [[ -z "$package_dir" ]]; then
  package_dir="$project_dir/.alpackages"
fi

mkdir -p "$(dirname "$out_file")"
mkdir -p "$package_dir"

platform="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$platform" in
  darwin) platform="darwin" ;;
  linux) platform="linux" ;;
  *) err "Unsupported OS: $(uname -s)"; exit 1 ;;
esac

find_compiler() {
  local root dir candidate

  if [[ -n "$compiler_bin" ]]; then
    printf '%s\n' "$compiler_bin"
    return 0
  fi

  if command -v elc >/dev/null 2>&1; then
    command -v elc
    return 0
  fi

  if command -v alc >/dev/null 2>&1; then
    command -v alc
    return 0
  fi

  local roots=(
    "$HOME/.cursor/extensions"
    "$HOME/.vscode/extensions"
    "$HOME/Library/Application Support/Cursor/User/globalStorage"
  )

  for root in "${roots[@]}"; do
    [[ -d "$root" ]] || continue

    while IFS= read -r dir; do
      for candidate in \
        "$dir/bin/$platform/elc" \
        "$dir/bin/$platform/alc"; do
        if [[ -f "$candidate" ]]; then
          printf '%s\n' "$candidate"
          return 0
        fi
      done
    done < <(find "$root" -maxdepth 1 -type d -name 'ms-dynamics-smb.al-*' | sort -r)
  done

  return 1
}

compiler_bin="$(find_compiler)" || {
  err "Could not locate the AL compiler binary (elc/alc)."
  err "Set ELC_BIN or pass --compiler with the full path."
  exit 1
}

if [[ ! -x "$compiler_bin" ]]; then
  chmod +x "$compiler_bin" 2>/dev/null || true
fi

if [[ ! -x "$compiler_bin" ]]; then
  err "Compiler exists but is not executable: $compiler_bin"
  exit 1
fi

run_prefix=()
if [[ "$(uname -m)" == "arm64" ]]; then
  compiler_file_info="$(file "$compiler_bin" 2>/dev/null || true)"
  if [[ "$compiler_file_info" == *x86_64* && "$compiler_file_info" != *arm64* ]]; then
    run_prefix=(arch -x86_64)
  fi
fi

compiler_args=(
  "/project:$project_dir"
  "/out:$out_file"
  "/packagecachepath:$package_dir"
)

info "Using compiler: $compiler_bin"
info "Project:        $project_dir"
info "Output:         $out_file"
info "Packages:       $package_dir"

"${run_prefix[@]}" "$compiler_bin" "${compiler_args[@]}" "${extra_args[@]}"
