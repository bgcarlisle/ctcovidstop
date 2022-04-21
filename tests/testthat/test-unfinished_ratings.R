test_that("No unfinished ratings", {

    unfinished_rows <- c19stoppedtrials %>%
        dplyr::filter(covid19_explicit) %>%
        dplyr::filter(is.na(restart_expected)) %>%
        nrow()
    
    expect_equal(
        unfinished_rows,
        0
    )
    
})
