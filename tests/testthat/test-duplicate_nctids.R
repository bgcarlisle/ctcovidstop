test_that("There should be no duplicated NCT numbers", {
    expect_equal(
        sum(duplicated(c19stoppedtrials$nctid)),
        0
    )
})
