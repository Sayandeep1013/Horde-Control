extends GdUnitTestSuite

## Harness check (P0.7): trivial passing suite.
##
## Demonstrates the headless gdUnit4 CLI reporting exit code 0 on a clean
## pass. Asserts a deliberately true condition; carries no gameplay meaning.

func test_true_condition_passes() -> void:
	assert_bool(true).is_true()
