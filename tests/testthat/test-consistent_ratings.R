test_that("ratings are applied consistently", {
    
    rationales_with_inconsistent_ratings <- c19stoppedtrials %>%
        dplyr::group_by(why_stopped) %>%
        dplyr::count(paste(covid19_explicit, restart_expected)) %>%
        dplyr::mutate(ratings_per_rationale = dplyr::n()) %>%
        dplyr::filter(ratings_per_rationale > 1)

    expect_equal(
        nrow(rationales_with_inconsistent_ratings),
        0
    )
    
})
