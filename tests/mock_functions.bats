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
