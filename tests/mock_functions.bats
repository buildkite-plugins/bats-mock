#!/usr/bin/env bats
# shellcheck disable=SC2329
# because we are declaring functions inside the setup function itself

load '../stub'

setup() {
  function rm {
    return 10
  }
  function mkdir {
    return 20
  }
  function ln {
    return 30
  }
  function touch {
    return 40
  }
}

teardown() {
  unset rm mkdir ln touch
}


@test "Stubbing still works when some util binaries are mock functions" {
  run rm ../README.md
  [ "$status" -eq 10 ]

  run mkdir new-test
  [ "$status" -eq 20 ]
  [ ! -e new-test ]

  run ln dest orig
  [ "$status" -eq 30 ]
  [ ! -e orig ]

  run touch test-file
  [ "$status" -eq 40 ]
  [ ! -e test-file ]

  stub mycommand " : echo OK"
  run mycommand
  [ "$status" -eq 0 ]
  [ "$output" == "OK" ]
  unstub mycommand

  unset rm mkdir ln touch
}

@test "Stubbing a shell function restores it on unstub" {
  myfunction() {
    printf 'original:%s\n' "$*"
  }

  stub myfunction "argument : echo stubbed"
  run myfunction argument
  [ "$status" -eq 0 ]
  [ "$output" == "stubbed" ]

  unstub myfunction
  run myfunction argument
  [ "$status" -eq 0 ]
  [ "$output" == "original:argument" ]
}

@test "First function stub creates a missing mock temp directory" {
  BATS_MOCK_TMPDIR="${BATS_TEST_TMPDIR}/missing/mock"
  BATS_MOCK_BINDIR="${BATS_MOCK_TMPDIR}/bin"
  PATH="${BATS_MOCK_BINDIR}:$PATH"
  [ ! -e "$BATS_MOCK_TMPDIR" ]
  myfunction() {
    printf 'original:%s\n' "$*"
  }

  stub myfunction "argument : echo stubbed"
  run myfunction argument
  [ "$status" -eq 0 ]
  [ "$output" == "stubbed" ]

  unstub myfunction
  run myfunction argument
  [ "$status" -eq 0 ]
  [ "$output" == "original:argument" ]
}

@test "Directory creation failure leaves the original function intact" {
  BATS_MOCK_TMPDIR="${BATS_TEST_TMPDIR}/not-a-directory"
  BATS_MOCK_BINDIR="${BATS_MOCK_TMPDIR}/bin"
  "$BATS_MOCK_REAL_touch" "$BATS_MOCK_TMPDIR"
  myfunction() {
    printf 'original\n'
  }

  run stub myfunction " : echo stubbed"
  [ "$status" -ne 0 ]
  [ -n "$output" ]
  run myfunction
  [ "$status" -eq 0 ]
  [ "$output" == "original" ]
}

@test "Failed stub setup restores the original function" {
  myfunction() {
    printf 'original\n'
  }
  "$BATS_MOCK_REAL_mkdir" -p "${BATS_MOCK_TMPDIR}/myfunction-stub-plan"

  stub myfunction " : echo stubbed" 2>/dev/null && return 1
  run myfunction
  [ "$status" -eq 0 ]
  [ "$output" == "original" ]
  [ ! -e "${BATS_MOCK_TMPDIR}/myfunction-stub-function" ]
}

@test "Failed function restoration preserves the backup for retry" {
  shopt -s extglob
  eval 'myfunction() { case "$1" in @(argument)) printf "original\n";; esac; }'
  stub myfunction "argument : echo stubbed"
  myfunction argument
  shopt -u extglob

  run unstub myfunction
  [ "$status" -ne 0 ]
  [ -f "${BATS_MOCK_TMPDIR}/myfunction-stub-function" ]

  shopt -s extglob
  unstub --allow-missing myfunction
  run myfunction argument
  [ "$status" -eq 0 ]
  [ "$output" == "original" ]
  [ ! -e "${BATS_MOCK_TMPDIR}/myfunction-stub-function" ]
}

@test "Stubbing a function that masks a builtin is rejected" {
  cd() {
    printf 'function cd called\n'
  }

  run stub cd " : echo stubbed"
  [ "$status" -eq 1 ]
  [ "$output" == "Cannot stub function 'cd': it masks a shell builtin" ]
  [ ! -e "${BATS_MOCK_BINDIR}/cd" ]

  run cd
  [ "$status" -eq 0 ]
  [ "$output" == "function cd called" ]
}

@test "Stubbing a readonly function is rejected without changing it" {
  myreadonly() {
    printf 'readonly function called\n'
  }
  readonly -f myreadonly

  run stub myreadonly " : echo stubbed"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Cannot prepare function 'myreadonly' for stubbing"* ]]

  run myreadonly
  [ "$status" -eq 0 ]
  [ "$output" == "readonly function called" ]
  [ ! -e "${BATS_MOCK_BINDIR}/myreadonly" ]
}

@test "Stubbing fails safely when the function backup cannot be written" {
  myfunction() {
    printf 'original:%s\n' "$*"
  }
  function_file="${BATS_MOCK_TMPDIR}/myfunction-stub-function"
  "$BATS_MOCK_REAL_mkdir" -p "$function_file"

  run stub myfunction " : echo stubbed"
  [ "$status" -eq 1 ]
  [[ "$output" == *"backup path already exists"* ]]

  run myfunction argument
  [ "$status" -eq 0 ]
  [ "$output" == "original:argument" ]
  [ -d "$function_file" ]
  [ ! -e "${BATS_MOCK_BINDIR}/myfunction" ]
}

@test "Stubbing an undefined function leaves it undefined after unstub" {
  [ -z "$(declare -F mycommand)" ]

  stub mycommand " : echo stubbed"
  run mycommand
  [ "$status" -eq 0 ]
  [ "$output" == "stubbed" ]

  unstub mycommand
  [ -z "$(declare -F mycommand)" ]
}
