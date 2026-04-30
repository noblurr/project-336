# Robustness checks for the main IV estimate.

setup_candidates <- c(
  "Code_database/00_setup.R",
  "../Code_database/00_setup.R",
  "00_setup.R"
)
source(setup_candidates[file.exists(setup_candidates)][1])

if (!file.exists(path_here("Derived", "monthly_analysis_data.csv"))) {
  source(path_here("Code_database", "01_build_monthly_data.R"))
}

analysis_data <- read_csv(path_here("Derived", "monthly_analysis_data.csv"), show_col_types = FALSE) %>%
  mutate(
    date = as.Date(date),
    month_factor = factor(month_factor, levels = month.abb)
  )

est_data <- analysis_data %>%
  filter(
    date >= as.Date("2000-03-01"),
    date <= as.Date("2019-01-01"),
    !is.na(inflation_mom),
    !is.na(dep_kzt),
    !is.na(oil_log_change),
    !is.na(lag_inflation)
  )

nw <- function(model, lag = 4) {
  sandwich::NeweyWest(model, lag = lag, prewhite = FALSE, adjust = TRUE)
}

extract_dep <- function(model, label, outcome_label) {
  ct <- lmtest::coeftest(model, vcov. = nw(model))
  model_n <- if (!is.null(model$residuals)) {
    length(model$residuals)
  } else {
    length(stats::residuals(model))
  }
  tibble(
    specification = label,
    outcome = outcome_label,
    estimate = unname(ct["dep_kzt", 1]),
    std_error = unname(ct["dep_kzt", 2]),
    p_value = unname(ct["dep_kzt", 4]),
    conf_low = estimate - 1.96 * std_error,
    conf_high = estimate + 1.96 * std_error,
    n = model_n
  )
}

baseline <- AER::ivreg(
  inflation_mom ~ dep_kzt + lag_inflation + month_factor |
    oil_log_change + lag_inflation + month_factor,
  data = est_data
)

with_trend <- AER::ivreg(
  inflation_mom ~ dep_kzt + lag_inflation + trend + month_factor |
    oil_log_change + lag_inflation + trend + month_factor,
  data = est_data
)

with_macro_controls <- AER::ivreg(
  inflation_mom ~ dep_kzt + lag_inflation + gdp_growth + money_supply + oil_rents + month_factor |
    oil_log_change + lag_inflation + gdp_growth + money_supply + oil_rents + month_factor,
  data = est_data
)

exclude_2015_float <- AER::ivreg(
  inflation_mom ~ dep_kzt + lag_inflation + month_factor |
    oil_log_change + lag_inflation + month_factor,
  data = est_data %>%
    filter(!(date >= as.Date("2015-08-01") & date <= as.Date("2015-12-01")))
)

three_month_data <- est_data %>%
  filter(!is.na(inflation_3m))

three_month_response <- AER::ivreg(
  inflation_3m ~ dep_kzt + lag_inflation + month_factor |
    oil_log_change + lag_inflation + month_factor,
  data = three_month_data
)

robustness_results <- bind_rows(
  extract_dep(baseline, "Baseline", "Monthly inflation"),
  extract_dep(with_trend, "Add linear trend", "Monthly inflation"),
  extract_dep(with_macro_controls, "Add annual macro controls", "Monthly inflation"),
  extract_dep(exclude_2015_float, "Exclude Aug-Dec 2015", "Monthly inflation"),
  extract_dep(three_month_response, "Three-month cumulative response", "Three-month inflation")
) %>%
  mutate(
    ten_percent_effect = 10 * estimate,
    ten_percent_low = 10 * conf_low,
    ten_percent_high = 10 * conf_high
  )

write_csv(robustness_results, path_here("Output", "table4_robustness_checks.csv"))

figure4 <- ggplot(robustness_results, aes(x = reorder(specification, estimate), y = estimate)) +
  geom_hline(yintercept = 0, color = "grey65", linewidth = 0.4) +
  geom_pointrange(
    aes(ymin = conf_low, ymax = conf_high),
    color = "#1f4e79",
    linewidth = 0.75
  ) +
  coord_flip() +
  labs(
    title = "Robustness of IV pass-through estimates",
    x = NULL,
    y = "Estimated effect of 1% depreciation",
    caption = "Bars show 95% confidence intervals using Newey-West standard errors."
  ) +
  theme(plot.title = element_text(face = "bold"))

ggsave(
  path_here("Output", "figure4_robustness.png"),
  figure4,
  width = 7.2,
  height = 4.2,
  dpi = 320
)

message("Created robustness table and figure in Output.")
