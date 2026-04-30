Oil Price Shocks, Exchange Rate, and Inflation in Kazakhstan
ECON 336 - Programming for Economics

Research question:
Does depreciation of the Kazakhstani tenge, predicted by changes in global Brent crude oil prices, increase consumer price inflation?

Main finding:
The OLS relationship between tenge depreciation and monthly inflation is positive. The role of oil price as an IV is negative, however statistically insignificant and has a small effect at first stage model, thus we can conclude that our data does not support our hypothesis.

How to run the replication package:
1. Open Oil_Price_Shocks_Kazakhstan.Rproj in RStudio.
2. Run source("run_all.R") from the project root.
3. The script rebuilds the cleaned data, estimation tables, figures, robustness checks and the paper PDF.

Required R packages:
tidyverse, readxl, lubridate, AER, sandwich, lmtest, broom, scales, knitr, rmarkdown, tinytex.
The setup script installs missing packages from CRAN if needed.

PDF rendering note:
The replication code does not use specific directory path. It searches for Pandoc through RStudio/Quarto/PATH and searches for LaTeX through PATH or an installed TinyTeX distribution. If the tables and figures run but the PDF does not render, please, install TinyTeX once in R with tinytex::install_tinytex(), then rerun source("run_all.R").

Folder guide:

Raw_data:
Contains the unmodified files that we use.
- fred_dcoilbrenteu.csv: daily Brent crude oil prices from FRED.
- nationalbank_usd_kzt_exchange_rate.xlsx: daily USD/KZT exchange rates from the National Bank of Kazakhstan.
- kazakhstan_indexcpi_statbureau.csv: monthly Kazakhstan CPI index, previous month = 100.
- worldbank_kazakhstan_macro.csv: annual macro variables for Kazakhstan from the World Bank.
- statgiv_cpi_regions.xlsx and statgov_index_of_price.xlsx: additional CPI/statistical source files.

Code_database and Derived:
- Code_database/01_build_monthly_data.R reads the raw Brent, exchange-rate, CPI and World Bank files.
- It writes Derived/monthly_analysis_data.csv, Derived/worldbank_context.csv, and Derived/data_dictionary.csv.
- The monthly dataset aggregates daily oil and exchange-rate data to monthly averages, reshapes CPI from wide to long format, and creates log changes.

Code_estimation:
- Code_estimation/02_estimate_results.R reads Derived/monthly_analysis_data.csv.
- It estimates the first stage, OLS comparison, and baseline IV model.
- It writes tables and figures to Output:
  table1_descriptive_stats.csv
  table1_sample_summary_wide.csv
  table2_first_stage_full.csv
  table2_first_stage_summary.csv
  table3_regression_results.csv
  figure1_time_series.png
  figure2_first_stage.png
  figure3_pass_through_estimates.png

Code_appendix:
- Code_appendix/03_robustness_checks.R runs robustness specifications.
- It writes Output/table4_robustness_checks.csv and Output/figure4_robustness.png.

Report:
- Report/Oil_Price_Shocks_Kazakhstan.Rmd is the source file for the written project.
- run_all.R renders Oil_Price_Shocks_Kazakhstan.pdf in the project root when Pandoc and LaTeX are available.

Main model design:
The package estimates a two-stage least squares model. The endogenous variable is monthly tenge depreciation, measured as the monthly log change in average USD/KZT. The instrumental variable is the monthly log change in average crude oil prices. The outcome is monthly CPI inflation, measured as 100 * log(CPI index / 100). The baseline controls are monthly fixed effects and lagged inflation.
