# Run the full replication package from raw data to paper PDF.

setup_candidates <- c(
  "Code_database/00_setup.R",
  "../Code_database/00_setup.R",
  "00_setup.R"
)
source(setup_candidates[file.exists(setup_candidates)][1])

source(path_here("Code_database", "01_build_monthly_data.R"))
source(path_here("Code_estimation", "02_estimate_results.R"))
source(path_here("Code_appendix", "03_robustness_checks.R"))

add_to_path <- function(directory) {
  if (length(directory) == 0 || is.na(directory) || !nzchar(directory) || !dir.exists(directory)) {
    return(invisible(FALSE))
  }

  current_path <- strsplit(Sys.getenv("PATH"), .Platform$path.sep, fixed = TRUE)[[1]]
  if (!normalizePath(directory, winslash = "/", mustWork = TRUE) %in%
      normalizePath(current_path[file.exists(current_path)], winslash = "/", mustWork = FALSE)) {
    Sys.setenv(PATH = paste(directory, Sys.getenv("PATH"), sep = .Platform$path.sep))
  }

  invisible(TRUE)
}

configure_pandoc <- function() {
  if (rmarkdown::pandoc_available()) {
    return(invisible(TRUE))
  }

  pandoc_candidates <- c(
    Sys.which("pandoc"),
    file.path(Sys.getenv("ProgramFiles"), "RStudio", "resources", "app", "bin", "quarto", "bin", "tools", "pandoc.exe"),
    file.path(Sys.getenv("ProgramFiles"), "RStudio", "bin", "pandoc", "pandoc.exe"),
    file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "Quarto", "bin", "tools", "pandoc.exe"),
    file.path(Sys.getenv("ProgramFiles"), "Quarto", "bin", "tools", "pandoc.exe"),
    "/usr/lib/rstudio/resources/app/bin/quarto/bin/tools/pandoc",
    "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools/pandoc"
  )

  pandoc_candidates <- pandoc_candidates[nzchar(pandoc_candidates) & file.exists(pandoc_candidates)]
  if (length(pandoc_candidates) > 0) {
    Sys.setenv(RSTUDIO_PANDOC = dirname(pandoc_candidates[1]))
    rmarkdown::find_pandoc(cache = FALSE)
  }

  invisible(rmarkdown::pandoc_available())
}

configure_latex <- function() {
  if (nzchar(Sys.which("pdflatex"))) {
    return(invisible(TRUE))
  }

  if (requireNamespace("tinytex", quietly = TRUE)) {
    tinytex_root <- tryCatch(tinytex::tinytex_root(), error = function(e) "")
    if (nzchar(tinytex_root) && dir.exists(tinytex_root)) {
      tinytex_dirs <- c(
        file.path(tinytex_root, "bin", "windows"),
        file.path(tinytex_root, "bin", "win32"),
        list.dirs(file.path(tinytex_root, "bin"), recursive = FALSE, full.names = TRUE)
      )
      invisible(lapply(tinytex_dirs, add_to_path))
    }
  }

  invisible(nzchar(Sys.which("pdflatex")))
}

has_pandoc <- configure_pandoc()
has_latex <- configure_latex()

if (has_pandoc && has_latex) {
  rmarkdown::render(
    input = path_here("Report", "Oil_Price_Shocks_Kazakhstan.Rmd"),
    output_format = "pdf_document",
    output_dir = project_root,
    output_file = "Oil_Price_Shocks_Kazakhstan.pdf",
    clean = TRUE,
    envir = new.env(parent = globalenv())
  )
} else {
  warning(
    "Tables and figures were created, but the PDF was not rendered because ",
    if (!has_pandoc) "Pandoc " else "",
    if (!has_pandoc && !has_latex) "and " else "",
    if (!has_latex) "LaTeX/pdflatex " else "",
    "was not found. In RStudio, install a TeX distribution such as TinyTeX ",
    "with tinytex::install_tinytex() if PDF rendering is needed."
  )
}

message("Replication run complete.")
