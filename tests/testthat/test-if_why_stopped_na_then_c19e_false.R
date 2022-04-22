test_that("All trials with NA for why_stopped should be covid19_explicit FALSE", {
    c19e_but_na_why_stopped <- c19stoppedtrials %>%
        dplyr::filter(is.na(why_stopped)) %>%
        dplyr::filter(covid19_explicit)

    expect_equal(
        nrow(c19e_but_na_why_stopped),
        0
    )
})
