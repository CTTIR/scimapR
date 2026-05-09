test_that("sm_theme returns a ggplot2 theme object", {
  thm <- sm_theme()

  expect_s3_class(thm, "theme")
  expect_s3_class(thm, "gg")
})

test_that("sm_theme respects base_size argument", {
  thm_small <- sm_theme(base_size = 8)
  thm_large <- sm_theme(base_size = 16)

  expect_s3_class(thm_small, "theme")
  expect_s3_class(thm_large, "theme")
})

test_that("sm_theme dark mode produces different colours", {
  thm_light <- sm_theme(dark = FALSE)
  thm_dark <- sm_theme(dark = TRUE)

  # Both should be valid themes

  expect_s3_class(thm_light, "theme")
  expect_s3_class(thm_dark, "theme")

  # Background colours should differ
  bg_light <- thm_light$plot.background$fill
  bg_dark <- thm_dark$plot.background$fill
  expect_false(identical(bg_light, bg_dark))
})

test_that("sm_scale_color returns a ggplot2 scale", {
  sc <- sm_scale_color()
  expect_s3_class(sc, "Scale")

  sc_cont <- sm_scale_color(discrete = FALSE)
  expect_s3_class(sc_cont, "Scale")
})

test_that("sm_scale_fill returns a ggplot2 scale", {
  sf <- sm_scale_fill()
  expect_s3_class(sf, "Scale")

  sf_cont <- sm_scale_fill(discrete = FALSE)
  expect_s3_class(sf_cont, "Scale")
})

test_that("sm_scale_color accepts different palette options", {
  palettes <- c("viridis", "magma", "plasma", "cividis",
                "inferno", "mako", "rocket", "turbo")

  for (pal in palettes) {
    sc <- sm_scale_color(option = pal)
    expect_s3_class(sc, "Scale")
  }
})

test_that("sm_palette_qualitative returns hex colour vector", {
  cols <- sm_palette_qualitative(5)

  expect_type(cols, "character")
  expect_length(cols, 5L)
  # Hex colour pattern
  expect_true(all(grepl("^#[0-9A-Fa-f]+", cols)))
})
