load '../stub'

# Generates a temporary test file with the specified number of tests.
# Each test stubs the SAME command and then unstubs to validate.
generate_stubbed_test_file() {
  local num_tests="$1"
  local cmd_to_stub="$2"
  local output_file="$3"

  echo "load $(cd .. && echo "$(pwd)/stub")" >"${output_file}"

  local test_number
  for test_number in $(seq 1 "${num_tests}"); do
    cat >>"${output_file}" <<EOF
bats_test_placeholder "Simple stub test with arg '${test_number}'" {
  stub ${cmd_to_stub} "${test_number} : echo '${cmd_to_stub} called with arg ${test_number}'"

  run ${cmd_to_stub} ${test_number}

  unstub '${cmd_to_stub}'
}

EOF
  done

  # Prevent bats from interpreting the placeholder during test generation
  sed -i '' 's/bats_test_placeholder/@test/g' "${output_file}"
}

@test "stubs do not interfere with each other when using 'bats --jobs'" {
  local test_file_to_run="${BATS_TEST_TMPDIR}/concurrent_stub_tests.bats"
  generate_stubbed_test_file 10 'mycommand' "${test_file_to_run}"

  run bats --jobs 4 "${test_file_to_run}"

  [ "${status}" -eq 0 ]
  [[ ! "${output}" =~ "unstub 'mycommand'' failed" ]]
}
