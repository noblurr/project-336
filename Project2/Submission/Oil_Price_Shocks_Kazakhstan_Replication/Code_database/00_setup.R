# Shared setup for the ECON 336 replication package.

required_packages <- c(
  "tidyverse", "readxl", "lubridate", "AER", "sandwich", "lmtest",
  "broom", "scales", "knitr", "rmarkdown", "tinytex"
)

missing_packages <- setdiff(required_packages, rownames(installed.packages()))
if (length(missing_packages) > 0) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  invisible(lapply(required_packages, library, character.only = TRUE))
})

find_project_root <- function() {
  wd <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  candidates <- unique(c(wd, dirname(wd), dirname(dirname(wd))))

  for (candidate in candidates) {
    if (
      dir.exists(file.path(candidate, "Raw_data")) &&
        dir.exists(file.path(candidate, "Code_database"))
    ) {
      return(candidate)
    }
  }

  stop(
    "Could not find the project root. In RStudio, open ",
    "Oil_Price_Shocks_Kazakhstan.Rproj or set the working directory to the ",
    "folder containing Raw_data and Code_database."
  )
}

project_root <- find_project_root()

path_here <- function(...) {
  file.path(project_root, ...)
}

invisible(lapply(
  c("Derived", "Output"),
  function(folder) dir.create(path_here(folder), showWarnings = FALSE, recursive = TRUE)
))

theme_set(theme_minimal(base_size = 11))
