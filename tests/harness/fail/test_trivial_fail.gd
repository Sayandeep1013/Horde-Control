extends GdUnitTestSuite

## Harness check (P0.7): trivial failing suite.
##
## Demonstrates the headless gdUnit4 CLI reporting exit code 100 on a real
## assertion failure. Asserts a deliberately false condition; carries no
## gameplay meaning. Kept in a separate directory from
## tests/harness/pass so a run can point -a at one directory without the
## other, per PLAN.md P0.7 step 5.

func test_false_condition_fails() -> void:
	assert_bool(true).is_false()
