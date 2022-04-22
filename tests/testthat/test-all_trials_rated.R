test_that("Check that all stopped trials are manually rated", {
    expect_equal(
       sum(is.na(c19stoppedtrials$covid19_explicit)),
       0
    )
})
