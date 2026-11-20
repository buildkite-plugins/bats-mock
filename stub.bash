BATS_MOCK_TMPDIR="${BATS_TEST_TMPDIR}"
BATS_MOCK_BINDIR="${BATS_MOCK_TMPDIR}/bin"

BATS_MOCK_REAL_mkdir=$(which mkdir)
export BATS_MOCK_REAL_mkdir
BATS_MOCK_REAL_ln=$(which ln)
export BATS_MOCK_REAL_ln
BATS_MOCK_REAL_touch=$(which touch)
export BATS_MOCK_REAL_touch
BATS_MOCK_REAL_rm=$(which rm)
export BATS_MOCK_REAL_rm

PATH="$BATS_MOCK_BINDIR:$PATH"

stub() {
  local program="$1"
  local builtin_name
  local function_file="${BATS_MOCK_TMPDIR}/${program}-stub-function"
  "$BATS_MOCK_REAL_mkdir" -p "${BATS_MOCK_BINDIR}" || return "$?"

  if builtin declare -F "$program" >/dev/null; then
    while builtin read -r builtin_name; do
      if [[ "$builtin_name" == "$program" ]]; then
        builtin printf "Cannot stub function '%s': it masks a shell builtin\n" "$program" >&2
        return 1
      fi
    done < <(builtin compgen -b)

    if [[ -e "$function_file" || -L "$function_file" ]]; then
      builtin printf "Cannot save function '%s': backup path already exists\n" "$program" >&2
      return 1
    fi
    if ! builtin declare -pf "$program" > "$function_file" ||
      ! builtin unset -f "$program"; then
      "$BATS_MOCK_REAL_rm" -f "$function_file"
      builtin printf "Cannot prepare function '%s' for stubbing\n" "$program" >&2
      return 1
    fi
  fi

  local prefix
  # shellcheck disable=SC2018,SC2019  # anything not A-Z0-9 will be _
  # the "\n" is necessary to avoid adding a trailing _ to the name
  prefix="$(echo "$program" | tr a-z A-Z | tr -C "A-Z0-9\n" '_')"
  shift


  if [[ "$prefix" =~ ^[^A-Z_]+(.*)$ ]]; then
    # remove leading non A-Z_ characters to make a valid variable name
    prefix="${BASH_REMATCH[1]}"
  fi

  export "${prefix}_STUB_PLAN"="${BATS_MOCK_TMPDIR}/${program}-stub-plan"
  export "${prefix}_STUB_RUN"="${BATS_MOCK_TMPDIR}/${program}-stub-run"
  export "${prefix}_STUB_END"=

  local STATUS=0
  "$BATS_MOCK_REAL_ln" -sf "${BASH_SOURCE[0]%stub.bash}binstub" "${BATS_MOCK_BINDIR}/${program}" &&
    "$BATS_MOCK_REAL_touch" "${BATS_MOCK_TMPDIR}/${program}-stub-plan" && {
      if [ "$#" -gt 0 ]; then
        printf "%s\n" "$@" >> "${BATS_MOCK_TMPDIR}/${program}-stub-plan"
      fi
    } || STATUS="$?"
  if [ "$STATUS" -ne 0 ] && [ -f "$function_file" ]; then
    builtin source "$function_file" || return "$?"
    "$BATS_MOCK_REAL_rm" -f "$function_file"
  fi
  return "$STATUS"
}

unstub() {
  local allow_missing=0
  if [ "$1" == "--allow-missing" ]; then
    allow_missing=1
    shift
  fi
  local program="$1"
  local path="${BATS_MOCK_BINDIR}/${program}"
  local function_file="${BATS_MOCK_TMPDIR}/${program}-stub-function"
  local prefix
  # shellcheck disable=SC2018,SC2019  # anything not A-Z0-9 will be _
  # the "\n" is necessary to avoid adding a trailing _ to the name
  prefix="$(echo "${program}" | tr a-z A-Z | tr -C "A-Z0-9\n" '_')"

  if [[ "$prefix" =~ ^[^A-Z_]+(.*)$ ]]; then
    # remove leading non A-Z_ characters to make a valid variable name
    prefix="${BASH_REMATCH[1]}"
  fi

  export "${prefix}_STUB_END"=1

  local STATUS=0
  if [ -f "$path" ]; then
    "$path" || STATUS="$?"
  elif [ $allow_missing -eq 0 ]; then
    echo "$program is not stubbed" >&2
    STATUS=1
  fi

  "$BATS_MOCK_REAL_rm" -f "$path"
  "$BATS_MOCK_REAL_rm" -f "${BATS_MOCK_TMPDIR}/${program}-stub-plan" "${BATS_MOCK_TMPDIR}/${program}-stub-run"
  if [ -f "$function_file" ]; then
    builtin source "$function_file" || return "$?"
    "$BATS_MOCK_REAL_rm" -f "$function_file"
  fi
  return "$STATUS"
}
