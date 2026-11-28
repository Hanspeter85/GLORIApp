# =============================================================================
# R/share.R  -  Share a compiled GLORIA and use a compiled GLORIA from a folder
# =============================================================================
# Compiling GLORIA from Google Drive takes hours. A compiled ("parsed") GLORIA
# can therefore also be passed on, e.g. via Box, a network drive or an
# external disk, and used directly:
#
#   1. The person who compiled it runs  write_manifest()  once. This writes
#      parsed/manifest.csv with every file, its size and an MD5 checksum.
#   2. The folder  <data_root>/v60  (with sub folder parsed/) is uploaded.
#   3. Users download the folder v60 and put it into any folder, e.g.
#      D:/GLORIA/v60. In the app (tab "Data & updates", option B) they enter
#      that folder; check_installation() verifies that everything is complete
#      (all years, file sizes) and the folder is saved as data folder.
# =============================================================================

# Write parsed/manifest.csv (file, bytes, md5) for the given version folder.
# md5 = FALSE skips the checksums (much faster; sizes are still checked).
write_manifest <- function(version_dir = file.path(data_root, sprintf("v%02d", gloria_version)),
                           md5 = TRUE) {
  parsed <- file.path(version_dir, "parsed")
  files <- list.files(parsed, recursive = TRUE, all.files = FALSE)
  files <- setdiff(files, "manifest.csv")
  man <- data.table(file = files, bytes = file.size(file.path(parsed, files)))
  if (md5) man[, md5 := unname(tools::md5sum(file.path(parsed, file)))]
  fwrite(man, file.path(parsed, "manifest.csv"))
  invisible(man)
}

# Find the data root (the folder that contains v60, v61, ...) from whatever
# folder the user entered: the data root itself, a version folder (v60) or a
# parsed folder. Returns NA if no compiled GLORIA is found.
find_gloria_root <- function(path) {
  path <- normalizePath(trimws(path), winslash = "/", mustWork = FALSE)
  if (!dir.exists(path)) return(NA_character_)
  has_meta <- function(v) file.exists(file.path(v, "parsed", "meta", "meta.rds"))
  if (basename(path) == "parsed" && has_meta(dirname(path))) return(dirname(dirname(path)))
  if (grepl("^v[0-9]+$", basename(path)) && has_meta(path)) return(dirname(path))
  v <- list.dirs(path, recursive = FALSE)
  if (any(grepl("/v[0-9]+$", v) & vapply(v, has_meta, TRUE))) return(path)
  NA_character_
}

# Check a compiled GLORIA version folder. Returns a list with
#   ok        TRUE if usable
#   years     years that are complete
#   problems  character vector of problems found (empty if none)
# With check_md5 = TRUE the checksums of the manifest are verified (slow:
# ~1 minute per 10 GB).
check_installation <- function(version_dir, check_md5 = FALSE) {
  parsed <- file.path(version_dir, "parsed")
  problems <- character(0)
  if (!file.exists(file.path(parsed, "meta", "meta.rds"))) problems <- c(problems, "meta/meta.rds is missing")
  yrs <- suppressWarnings(as.integer(list.dirs(parsed, full.names = FALSE, recursive = FALSE)))
  yrs <- sort(yrs[!is.na(yrs)])
  need <- c("Y.rds", "V.rds", "x.rds", "Q.rds", "QY.rds", "L.arrow", "_DONE")
  complete <- yrs[vapply(yrs, function(y) all(file.exists(file.path(parsed, y, need))), TRUE)]
  if (length(complete) == 0) problems <- c(problems, "no complete year found")
  incomplete <- setdiff(yrs, complete)
  if (length(incomplete)) problems <- c(problems, paste("incomplete years:", paste(incomplete, collapse = ", ")))
  man_file <- file.path(parsed, "manifest.csv")
  if (file.exists(man_file)) {
    man <- fread(man_file)
    f <- file.path(parsed, man$file)
    missing <- man$file[!file.exists(f)]
    if (length(missing)) problems <- c(problems, sprintf("%d files missing, e.g. %s", length(missing), missing[1]))
    present <- file.exists(f)
    wrong <- man$file[present][file.size(f[present]) != man$bytes[present]]
    if (length(wrong)) problems <- c(problems, sprintf("%d files incomplete (wrong size), e.g. %s", length(wrong), wrong[1]))
    if (check_md5 && "md5" %in% names(man)) {
      bad <- man$file[present][unname(tools::md5sum(f[present])) != man$md5[present]]
      if (length(bad)) problems <- c(problems, sprintf("%d files damaged (checksum), e.g. %s", length(bad), bad[1]))
    }
  }
  # incomplete years only give a warning; everything else makes the folder unusable
  fatal <- grepl("meta|no complete year|missing|wrong size|damaged", problems)
  list(ok = !any(fatal),
       years = complete, problems = problems)
}
