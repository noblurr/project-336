# Estimate the main OLS and IV specifications and create reported outputs.

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

coef_row <- function(model, vcov_mat, term, model_name, outcome_name) {
  ct <- lmtest::coeftest(model, vcov. = vcov_mat)
  r_squared <- summary(model)$r.squared
  if (is.null(r_squared)) {
    r_squared <- NA_real_
  }
  model_n <- if (!is.null(model$residuals)) {
    length(model$residuals)
  } else {
    length(stats::residuals(model))
  }
  tibble(
    model = model_name,
    outcome = outcome_name,
    term = term,
    estimate = unname(ct[term, 1]),
    std_error = unname(ct[term, 2]),
    statistic = unname(ct[term, 3]),
    p_value = unname(ct[term, 4]),
    conf_low = estimate - 1.96 * std_error,
    conf_high = estimate + 1.96 * std_error,
    n = model_n,
    r_squared = unname(r_squared)
  )
}

descriptive_stats <- est_data %>%
  summarise(
    observations = n(),
    start_month = min(date),
    end_month = max(date),
    across(
      c(inflation_mom, dep_kzt, oil_log_change, brent_price, usd_kzt),
      list(
        mean = ~ mean(.x, na.rm = TRUE),
        sd = ~ sd(.x, na.rm = TRUE),
        min = ~ min(.x, na.rm = TRUE),
        median = ~ median(.x, na.rm = TRUE),
        max = ~ max(.x, na.rm = TRUE)
      ),
      .names = "{.col}_{.fn}"
    )
  )

descriptive_long <- est_data %>%
  select(inflation_mom, dep_kzt, oil_log_change, brent_price, usd_kzt) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "value") %>%
  group_by(variable) %>%
  summarise(
    n = sum(!is.na(value)),
    mean = mean(value, na.rm = TRUE),
    sd = sd(value, na.rm = TRUE),
    min = min(value, na.rm = TRUE),
    p25 = quantile(value, 0.25, na.rm = TRUE),
    median = median(value, na.rm = TRUE),
    p75 = quantile(value, 0.75, na.rm = TRUE),
    max = max(value, na.rm = TRUE),
    .groups = "drop"
  )

first_stage <- lm(
  dep_kzt ~ oil_log_change + lag_inflation + month_factor,
  data = est_data
)

ols_model <- lm(
  inflation_mom ~ dep_kzt + lag_inflation + month_factor,
  data = est_data
)

iv_model <- AER::ivreg(
  inflation_mom ~ dep_kzt + lag_inflation + month_factor |
    oil_log_change + lag_inflation + month_factor,
  data = est_data
)

first_stage_terms <- broom::tidy(lmtest::coeftest(first_stage, vcov. = nw(first_stage))) %>%
  mutate(
    conf_low = estimate - 1.96 * std.error,
    conf_high = estimate + 1.96 * std.error
  )

first_stage_ct <- lmtest::coeftest(first_stage, vcov. = nw(first_stage))
first_stage_f_value <- unname(first_stage_ct["oil_log_change", "t value"]^2)
first_stage_p_value <- unname(first_stage_ct["oil_log_change", "Pr(>|t|)"])

first_stage_summary <- coef_row(
  first_stage, nw(first_stage), "oil_log_change",
  "First stage", "Tenge depreciation"
) %>%
  mutate(
    first_stage_f = first_stage_f_value,
    first_stage_p = first_stage_p_value
  )

main_results <- bind_rows(
  coef_row(ols_model, nw(ols_model), "dep_kzt", "OLS", "Monthly CPI inflation"),
  coef_row(iv_model, nw(iv_model), "dep_kzt", "IV: Brent instrument", "Monthly CPI inflation")
) %>%
  mutate(
    ten_percent_effect = 10 * estimate,
    ten_percent_low = 10 * conf_low,
    ten_percent_high = 10 * conf_high
  )

write_csv(descriptive_stats, path_here("Output", "table1_sample_summary_wide.csv"))
write_csv(descriptive_long, path_here("Output", "table1_descriptive_stats.csv"))
write_csv(first_stage_terms, path_here("Output", "table2_first_stage_full.csv"))
write_csv(first_stage_summary, path_here("Output", "table2_first_stage_summary.csv"))
write_csv(main_results, path_here("Output", "table3_regression_results.csv"))

series_plot_data <- analysis_data %>%
  filter(date >= as.Date("2000-01-01"), date <= as.Date("2019-01-01")) %>%
  select(date, inflation_mom, usd_kzt, brent_price) %>%
  pivot_longer(
    cols = -date,
    names_to = "series",
    values_to = "value"
  ) %>%
  mutate(series = dplyr::recode(
    series,
    inflation_mom = "Monthly CPI inflation (log percent)",
    usd_kzt = "USD/KZT exchange rate",
    brent_price = "Brent oil price, USD"
  ))

figure1 <- ggplot(series_plot_data, aes(x = date, y = value)) +
  geom_line(color = "#1f4e79", linewidth = 0.55) +
  facet_wrap(~series, scales = "free_y", ncol = 1) +
  labs(
    title = "Kazakhstan inflation, exchange rate, and Brent oil prices",
    x = NULL,
    y = NULL,
    caption = "Sources: Bureau of National Statistics, National Bank of Kazakhstan, FRED."
  ) +
  theme(
    strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold")
  )

ggsave(
  path_here("Output", "figure1_time_series.png"),
  figure1,
  width = 8,
  height = 6,
  dpi = 320
)

figure2 <- ggplot(est_data, aes(x = oil_log_change, y = dep_kzt)) +
  geom_hline(yintercept = 0, color = "grey75", linewidth = 0.3) +
  geom_vline(xintercept = 0, color = "grey75", linewidth = 0.3) +
  geom_point(color = "#3b6ea8", alpha = 0.7, size = 1.8) +
  geom_smooth(method = "lm", se = TRUE, color = "#9c3d2e", fill = "#d8b2aa") +
  labs(
    title = "First stage: Brent price shocks predict tenge depreciation",
    x = "Monthly log change in Brent price, percent",
    y = "Monthly log change in USD/KZT, percent",
    caption = "Positive USD/KZT changes mean depreciation of the tenge."
  ) +
  theme(plot.title = element_text(face = "bold"))

ggsave(
  path_here("Output", "figure2_first_stage.png"),
  figure2,
  width = 7.2,
  height = 4.8,
  dpi = 320
)

coef_plot_data <- main_results %>%
  mutate(model = factor(model, levels = c("OLS", "IV: Brent instrument")))

figure3 <- ggplot(coef_plot_data, aes(x = model, y = estimate)) +
  geom_hline(yintercept = 0, color = "grey65", linewidth = 0.4) +
  geom_pointrange(
    aes(ymin = conf_low, ymax = conf_high),
    color = "#1f4e79",
    linewidth = 0.8
  ) +
  coord_flip() +
  labs(
    title = "Estimated pass-through from tenge depreciation to monthly inflation",
    x = NULL,
    y = "Percentage-point change in monthly inflation from 1% depreciation",
    caption = "Bars show 95% confidence intervals using Newey-West standard errors."
  ) +
  theme(plot.title = element_text(face = "bold"))

ggsave(
  path_here("Output", "figure3_pass_through_estimates.png"),
  figure3,
  width = 7.2,
  height = 3.8,
  dpi = 320
)

message("Created main estimation tables and figures in Output.")
