test_that("Only C19-explicit trials were rated for expecting restart", {
    
    rated_non_c19 <- c19stoppedtrials %>%
        dplyr::filter(! covid19_explicit) %>%
        dplyr::filter(! is.na(restart_expected)) %>%
        nrow()
    
    expect_equal(
        rated_non_c19,
        0
    )
    
})
