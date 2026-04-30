# Clean raw data and construct the monthly analysis dataset.

setup_candidates <- c(
  "Code_database/00_setup.R",
  "../Code_database/00_setup.R",
  "00_setup.R"
)
source(setup_candidates[file.exists(setup_candidates)][1])

month_lookup <- tibble(
  month_name = month.name,
  month_num = seq_along(month.name)
)

cpi_monthly <- read_csv(
  path_here("Raw_data", "kazakhstan_indexcpi_statbureau.csv"),
  show_col_types = FALSE
) %>%
  pivot_longer(
    cols = -Year,
    names_to = "month_name",
    values_to = "cpi_index"
  ) %>%
  mutate(month_name = str_trim(month_name)) %>%
  left_join(month_lookup, by = "month_name") %>%
  mutate(
    date = as.Date(sprintf("%04d-%02d-01", Year, month_num)),
    cpi_index = as.numeric(cpi_index),
    inflation_mom = 100 * log(cpi_index / 100),
    inflation_pct = cpi_index - 100
  ) %>%
  filter(!is.na(date), !is.na(cpi_index)) %>%
  arrange(date) %>%
  select(date, year = Year, month_num, month_name, cpi_index, inflation_mom, inflation_pct)

brent_monthly <- read_csv(
  path_here("Raw_data", "fred_dcoilbrenteu.csv"),
  na = c(".", ""),
  show_col_types = FALSE
) %>%
  transmute(
    date = as.Date(observation_date),
    brent_usd = as.numeric(DCOILBRENTEU)
  ) %>%
  filter(!is.na(date), !is.na(brent_usd)) %>%
  mutate(month_date = floor_date(date, "month")) %>%
  group_by(date = month_date) %>%
  summarise(
    brent_price = mean(brent_usd, na.rm = TRUE),
    brent_price_end_month = dplyr::last(brent_usd[order(date)]),
    .groups = "drop"
  ) %>%
  arrange(date) %>%
  mutate(
    oil_log_change = 100 * (log(brent_price) - lag(log(brent_price))),
    oil_pct_change = 100 * (brent_price / lag(brent_price) - 1)
  )

fx_raw <- read_excel(
  path_here("Raw_data", "nationalbank_usd_kzt_exchange_rate.xlsx"),
  sheet = "Exchange Rates"
)

fx_monthly <- fx_raw %>%
  mutate(
    date = if (inherits(Date, "Date")) Date else dmy(as.character(Date)),
    usd_kzt = as.numeric(USD)
  ) %>%
  filter(!is.na(date), !is.na(usd_kzt)) %>%
  mutate(month_date = floor_date(date, "month")) %>%
  group_by(date = month_date) %>%
  summarise(
    usd_kzt = mean(usd_kzt, na.rm = TRUE),
    usd_kzt_end_month = dplyr::last(usd_kzt[order(date)]),
    .groups = "drop"
  ) %>%
  arrange(date) %>%
  mutate(
    dep_kzt = 100 * (log(usd_kzt) - lag(log(usd_kzt))),
    dep_kzt_end_month = 100 * (log(usd_kzt_end_month) - lag(log(usd_kzt_end_month)))
  )

worldbank_annual <- read_csv(
  path_here("Raw_data", "worldbank_kazakhstan_macro.csv"),
  show_col_types = FALSE
) %>%
  mutate(year = as.integer(year)) %>%
  select(year, gdp_growth, money_supply, gdp_deflator, oil_rents)

analysis_data <- cpi_monthly %>%
  inner_join(brent_monthly, by = "date") %>%
  inner_join(fx_monthly, by = "date") %>%
  left_join(worldbank_annual, by = "year") %>%
  arrange(date) %>%
  filter(date >= as.Date("2000-01-01")) %>%
  mutate(
    trend = row_number(),
    month_factor = factor(month_num, levels = 1:12, labels = month.abb),
    lag_inflation = lag(inflation_mom),
    lag_dep_kzt = lag(dep_kzt),
    lag_oil_log_change = lag(oil_log_change),
    inflation_3m = inflation_mom + lead(inflation_mom, 1) + lead(inflation_mom, 2)
  )

data_dictionary <- tribble(
  ~variable, ~description,
  "date", "First day of the month used as the monthly date.",
  "cpi_index", "Consumer price index, previous month = 100.",
  "inflation_mom", "Monthly CPI inflation, 100 * log(CPI index / 100).",
  "inflation_pct", "Monthly CPI inflation in simple percent points, CPI index - 100.",
  "brent_price", "Average daily Brent crude oil price in USD during the month.",
  "oil_log_change", "Monthly log change in average Brent price, in percent.",
  "usd_kzt", "Average daily nominal exchange rate, Kazakhstani tenge per US dollar.",
  "dep_kzt", "Monthly log change in USD/KZT, in percent; positive means tenge depreciation.",
  "gdp_growth", "Annual real GDP growth from the World Bank file.",
  "money_supply", "Annual money supply variable from the World Bank file.",
  "gdp_deflator", "Annual GDP deflator inflation from the World Bank file.",
  "oil_rents", "Annual oil rents variable from the World Bank file.",
  "lag_inflation", "One-month lag of monthly CPI inflation.",
  "inflation_3m", "Current plus next two months of CPI inflation, used in robustness checks."
)

write_csv(analysis_data, path_here("Derived", "monthly_analysis_data.csv"))
write_csv(worldbank_annual, path_here("Derived", "worldbank_context.csv"))
write_csv(data_dictionary, path_here("Derived", "data_dictionary.csv"))

message("Created Derived/monthly_analysis_data.csv with ", nrow(analysis_data), " rows.")

