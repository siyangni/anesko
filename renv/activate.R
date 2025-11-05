local({
  # the requested version of renv
  version <- "1.0.3"

  # the project directory
  project <- getwd()

  # avoid recursion
  if (!is.na(Sys.getenv("RENV_R_INITIALIZING", unset = NA)))
    return(invisible(TRUE))

  # signal that we're loading renv during R startup
  Sys.setenv("RENV_R_INITIALIZING" = "true")
  on.exit(Sys.unsetenv("RENV_R_INITIALIZING"), add = TRUE)

  # signal that we've consented to use renv
  options(renv.consent = TRUE)

  # load the 'utils' package eagerly -- this ensures that renv shims, which
  # mask 'utils' packages, will come first on the search path
  library(utils, lib.loc = .Library)

  # check to see if renv has already been loaded
  if ("renv" %in% loadedNamespaces()) {

    # if renv has already been loaded, and it's the requested version of renv,
    # nothing to do
    spec <- .getNamespaceInfo(.getNamespace("renv"), "spec")
    if (identical(spec[["version"]], version))
      return(invisible(TRUE))

    # otherwise, unload and attempt to load the correct version of renv
    unloadNamespace("renv")

  }

  # load bootstrap tools   
  bootstrap <- function(version, library) {

    # attempt to download renv
    tarball <- tryCatch(renv_bootstrap_download(version), error = identity)
    if (inherits(tarball, "error"))
      stop("failed to download renv ", version)

    # now attempt to install
    status <- tryCatch(renv_bootstrap_install(version, tarball, library), error = identity)
    if (inherits(status, "error"))
      stop("failed to install renv ", version)

  }

  renv_bootstrap_tests_running <- function() {
    getOption("renv.tests.running", default = FALSE)
  }

  renv_bootstrap_repos <- function() {

    # check for repos override
    repos <- Sys.getenv("RENV_CONFIG_REPOS_OVERRIDE", unset = NA)
    if (!is.na(repos))
      return(repos)

    # if we're testing, re-use the test repositories
    if (renv_bootstrap_tests_running())
      return(getOption("renv.tests.repos"))

    # retrieve current repos
    repos <- getOption("repos")

    # ensure @CRAN@ entries are resolved
    repos[repos == "@CRAN@"] <- "https://cloud.r-project.org"

    # add in renv.bootstrap.repos if set
    default <- c(CRAN = "https://cloud.r-project.org")
    extra <- getOption("renv.bootstrap.repos", default = default)
    repos <- c(repos, extra)

    # remove duplicates that might've snuck in
    dupes <- duplicated(repos) | duplicated(names(repos))
    repos[!dupes]

  }

  renv_bootstrap_download <- function(version) {

    # if the renv version number has 4 components, assume it must
    # be retrieved via github
    nv <- numeric_version(version)
    components <- unclass(nv)[[1]]

    methods <- if (length(components) == 4L) {
      list(
        renv_bootstrap_download_github
      )
    } else {
      list(
        renv_bootstrap_download_cran_latest,
        renv_bootstrap_download_cran_archive
      )
    }

    for (method in methods) {
      path <- tryCatch(method(version), error = identity)
      if (is.character(path) && file.exists(path))
        return(path)
    }

    stop("failed to download renv ", version)

  }

  renv_bootstrap_download_impl <- function(url, destfile) {

    mode <- "wb"

    # https://bugs.r-project.org/bugzilla/show_bug.cgi?id=17715
    fixup <-
      Sys.info()[["sysname"]] == "Windows" &&
      substring(url, 1L, 5L) == "file:"

    if (fixup)
      mode <- "w+b"

    download.file(
      url      = url,
      destfile = destfile,
      mode     = mode,
      quiet    = TRUE
    )

  }

  renv_bootstrap_download_cran_latest <- function(version) {

    repos <- renv_bootstrap_download_cran_latest_find(version)

    message("* Downloading renv ", version, " from CRAN ... ", appendLF = FALSE)

    baseurl <- utils::contrib.url(repos = repos, type = "source")
    ext <- if (Sys.info()[["sysname"]] == "Windows") ".zip" else ".tar.gz"
    name <- sprintf("renv_%s%s", version, ext)
    url <- paste(baseurl, name, sep = "/")

    destfile <- file.path(tempdir(), name)
    on.exit(unlink(destfile), add = TRUE)

    renv_bootstrap_download_impl(url, destfile)

    message("OK")
    destfile

  }

  renv_bootstrap_download_cran_latest_find <- function(version) {

    all <- renv_bootstrap_repos()

    for (repos in all) {

      url <- file.path(repos, "src/contrib/PACKAGES")
      packages <- tryCatch(
        suppressWarnings(readLines(url, warn = FALSE)),
        error = identity
      )

      if (inherits(packages, "error"))
        next

      # check for renv entry
      entry <- c(
        grep("^Package: renv$", packages),
        grep("^Version: ", packages)
      )

      if (length(entry) < 2)
        next

      # check for version match
      line <- packages[[entry[[2]]]]
      pattern <- "^Version: ([0-9]+[.-])*[0-9]+$"
      if (!grepl(pattern, line))
        next

      # extract version
      ver <- sub("^Version: ", "", line)
      if (ver == version)
        return(repos)

    }

    fmt <- "renv %s is not available from your declared package repositories"
    stop(sprintf(fmt, version))

  }

  renv_bootstrap_download_cran_archive <- function(version) {

    repos <- renv_bootstrap_repos()
    urls <- file.path(repos, "src/contrib/Archive/renv", sprintf("renv_%s.tar.gz", version))
    destfile <- file.path(tempdir(), sprintf("renv_%s.tar.gz", version))
    on.exit(unlink(destfile), add = TRUE)

    message("* Downloading renv ", version, " from CRAN archive ... ", appendLF = FALSE)

    for (url in urls) {

      status <- tryCatch(
        renv_bootstrap_download_impl(url, destfile),
        condition = identity
      )

      if (identical(status, 0L)) {
        message("OK")
        return(destfile)
      }

    }

    message("FAILED")
    return(FALSE)

  }

  renv_bootstrap_download_github <- function(version) {

    enabled <- Sys.getenv("RENV_BOOTSTRAP_FROM_GITHUB", unset = "TRUE")
    if (!identical(enabled, "TRUE"))
      return(FALSE)

    # prepare download options
    pat <- Sys.getenv("GITHUB_PAT")
    if (nzchar(Sys.which("curl")) && nzchar(pat)) {
      fmt <- "--location --fail --header \"Authorization: token %s\""
      extra <- sprintf(fmt, pat)
      saved <- options("download.file.method", "download.file.extra")
      options(download.file.method = "curl", download.file.extra = extra)
      on.exit(do.call(base::options, saved), add = TRUE)
    } else if (nzchar(Sys.which("wget")) && nzchar(pat)) {
      fmt <- "--header=\"Authorization: token %s\""
      extra <- sprintf(fmt, pat)
      saved <- options("download.file.method", "download.file.extra")
      options(download.file.method = "wget", download.file.extra = extra)
      on.exit(do.call(base::options, saved), add = TRUE)
    }

    message("* Downloading renv ", version, " from GitHub ... ", appendLF = FALSE)

    url <- file.path("https://api.github.com/repos/rstudio/renv/tarball", version)
    name <- sprintf("renv_%s.tar.gz", version)
    destfile <- file.path(tempdir(), name)
    on.exit(unlink(destfile), add = TRUE)

    renv_bootstrap_download_impl(url, destfile)

    message("OK")
    destfile

  }

  renv_bootstrap_install <- function(version, tarball, library) {

    # attempt to install it into project library
    message("* Installing renv ", version, " ... ", appendLF = FALSE)
    dir.create(library, showWarnings = FALSE, recursive = TRUE)

    # invoke using system2 so we can capture and report output
    bin <- R.home("bin")
    exe <- if (Sys.info()[["sysname"]] == "Windows") "R.exe" else "R"
    r <- file.path(bin, exe)
    args <- c("--vanilla", "CMD", "INSTALL", "-l", shQuote(library), shQuote(tarball))
    output <- system2(r, args, stdout = TRUE, stderr = TRUE)
    message("OK")

    # check for successful install
    status <- attr(output, "status")
    if (is.numeric(status) && !identical(status, 0L)) {
      text <- paste("Failed to install renv ", version, ".", sep = "")
      print(output)
      stop(text)
    }

  }

  renv_bootstrap_prefix <- function() {

    # construct version prefix
    version <- paste(R.version$major, R.version$minor, sep = ".")
    prefix <- paste("R", numeric_version(version)[1, 1:2], sep = "-")

    # include SVN revision for development versions of R
    # (to avoid sharing platform-specific artefacts with released versions of R)
    devel <-
      identical(R.version[["status"]],   "Under development (unstable)") ||
      identical(R.version[["nickname"]], "Unsuffered Consequences")

    if (devel)
      prefix <- paste(prefix, R.version[["svn rev"]], sep = "-r")

    # build list of path components
    components <- c(prefix, R.version$platform)

    # include prefix if provided by user
    prefix <- renv_bootstrap_platform_prefix()
    if (!is.na(prefix) && nzchar(prefix))
      components <- c(prefix, components)

    # build prefix
    paste(components, collapse = "/")

  }

  renv_bootstrap_platform_prefix <- function() {
    Sys.getenv("RENV_PATHS_PREFIX", unset = NA)
  }

  renv_bootstrap_library_root_name <- function(project) {

    # use project name as-is if requested
    asis <- Sys.getenv("RENV_PATHS_LIBRARY_ROOT_ASIS", unset = "FALSE")
    if (asis)
      return(basename(project))

    # otherwise, disambiguate based on project's path
    id <- substring(renv_bootstrap_hash_text(project), 1L, 8L)
    paste(basename(project), id, sep = "-")

  }

  renv_bootstrap_library_root <- function(project) {

    prefix  <- renv_bootstrap_profile_prefix()
    path <- Sys.getenv("RENV_PATHS_LIBRARY", unset = NA)
    if (!is.na(path))
      return(paste(c(path, prefix), collapse = "/"))

    path <- renv_bootstrap_library_root_impl(project)
    if (!is.null(path)) {
      name <- renv_bootstrap_library_root_name(project)
      return(paste(c(path, prefix, name), collapse = "/"))
    }

    renv_bootstrap_paths_renv("library", project = project)

  }

  renv_bootstrap_library_root_impl <- function(project) {

    root <- Sys.getenv("RENV_PATHS_LIBRARY_ROOT", unset = NA)
    if (!is.na(root))
      return(root)

    type <- renv_bootstrap_project_type(project)
    if (identical(type, "package")) {
      userdir <- renv_bootstrap_user_dir()
      return(file.path(userdir, "library"))
    }

  }

  renv_bootstrap_validate_version <- function(version, description = NULL) {

    # resolve description file
    description <- description %||% {

      # if we have an activated project, use that
      project <- Sys.getenv("RENV_PROJECT", unset = NA)
      if (!is.na(project)) {
        path <- renv_bootstrap_paths_renv("activate.R", project = project)
        if (file.exists(path))
          return(path)
      }

      # otherwise, look on the search path for an activate.R
      scripts <- c("renv/activate.R", "renv.R")
      for (script in scripts) {
        for (path in .libPaths()) {
          candidate <- file.path(path, script)
          if (file.exists(candidate))
            return(candidate)
        }
      }

    }

    # read the version from the activate script
    if (is.null(description))
      return(FALSE)

    contents <- readLines(description, warn = FALSE)

    # find version field
    pattern <- "^[[:space:]]*version[[:space:]]*<-[[:space:]]*[\"]"
    index <- grep(pattern, contents)
    if (length(index) == 0)
      return(FALSE)

    # extract version
    line <- contents[[index]]
    text <- sub(".*\"", "", sub("\".*", "", line))
    version == text

  }

  renv_bootstrap_hash_text <- function(text) {

    hashfile <- tempfile("renv-hash-")
    on.exit(unlink(hashfile), add = TRUE)

    writeLines(text, con = hashfile)
    tools::md5sum(hashfile)

  }

  renv_bootstrap_load <- function(project, libpath, version) {

    # try to load renv from the project library
    if (!requireNamespace("renv", lib.loc = libpath, quietly = TRUE))
      return(FALSE)

    # warn if the version of renv loaded does not match
    if (!renv_bootstrap_validate_version(version))
      return(FALSE)

    # execute renv load hooks, if any
    hooks <- getHook("renv::autoload")
    for (hook in hooks)
      if (is.function(hook))
        tryCatch(hook(), error = warnify)

    # load the project
    renv::load(project)

    TRUE

  }

  renv_bootstrap_profile_load <- function(project) {

    # if RENV_PROFILE is already set, just use that
    profile <- Sys.getenv("RENV_PROFILE", unset = NA)
    if (!is.na(profile) && nzchar(profile))
      return(profile)

    # check for a profile file (nothing to do if it doesn't exist)
    path <- renv_bootstrap_paths_renv("profile", project = project)
    if (!file.exists(path))
      return(NULL)

    # read the profile, and set it if it exists
    contents <- readLines(path, warn = FALSE)
    if (length(contents) == 0L)
      return(NULL)

    # set RENV_PROFILE
    profile <- contents[[1L]]
    if (!profile %in% c("", "default"))
      Sys.setenv(RENV_PROFILE = profile)

    profile

  }

  renv_bootstrap_profile_prefix <- function() {
    profile <- renv_bootstrap_profile_get()
    if (!is.null(profile))
      return(file.path("profiles", profile, "renv"))
  }

  renv_bootstrap_profile_get <- function() {
    profile <- Sys.getenv("RENV_PROFILE", unset = "")
    renv_bootstrap_profile_normalize(profile)
  }

  renv_bootstrap_profile_set <- function(profile) {
    profile <- renv_bootstrap_profile_normalize(profile)
    if (is.null(profile))
      Sys.unsetenv("RENV_PROFILE")
    else
      Sys.setenv(RENV_PROFILE = profile)
  }

  renv_bootstrap_profile_normalize <- function(profile) {

    if (is.null(profile) || profile %in% c("", "default"))
      return(NULL)

    profile

  }

  renv_bootstrap_project_type <- function(path) {

    descpath <- file.path(path, "DESCRIPTION")
    if (!file.exists(descpath))
      return("unknown")

    desc <- tryCatch(
      read.dcf(descpath, all = TRUE),
      error = identity
    )

    if (inherits(desc, "error"))
      return("unknown")

    type <- desc$Type
    if (!is.null(type))
      return(tolower(type))

    package <- desc$Package
    if (!is.null(package))
      return("package")

    "unknown"

  }

  renv_bootstrap_user_dir <- function() {
    rappdirs::user_data_dir("renv", "rstudio")
  }

  renv_bootstrap_rstudio_project <- function() {
    Sys.getenv("RSTUDIO_PROJECT", unset = NA)
  }

  renv_bootstrap_download_methods <- function() {
    c("internal", "libcurl", "auto", "wget", "curl")
  }

  renv_bootstrap_download_method <- function() {

    # check for custom downloader
    downloader <- Sys.getenv("RENV_DOWNLOAD_METHOD", unset = NA)
    if (!is.na(downloader))
      return(downloader)

    # check for global option
    downloader <- getOption("download.file.method")
    if (!is.null(downloader))
      return(downloader)

    # check for RStudio
    if (renv_bootstrap_rstudio_available())
      return("internal")

    # check for curl
    if (renv_bootstrap_download_method_find("curl"))
      return("curl")

    # check for wget
    if (renv_bootstrap_download_method_find("wget"))
      return("wget")

    # fall back to default
    "auto"

  }

  renv_bootstrap_download_method_find <- function(program) {
    nzchar(Sys.which(program))
  }

  renv_bootstrap_rstudio_available <- function() {
    identical(.Platform$GUI, "RStudio")
  }

  renv_bootstrap_exec <- function(project, libpath, version) {
    if (!renv_bootstrap_load(project, libpath, version))
      renv_bootstrap_run(version, libpath)
  }

  renv_bootstrap_run <- function(version, libpath) {

    # perform bootstrap
    bootstrap(version, libpath)

    # exit early if we're just testing bootstrap
    if (!is.na(Sys.getenv("RENV_BOOTSTRAP_INSTALL_ONLY", unset = NA)))
      return(TRUE)

    # try again to load
    if (requireNamespace("renv", lib.loc = libpath, quietly = TRUE)) {
      return(renv::load(project = getwd()))
    }

    # failed to download or load renv; warn the user
    msg <- c(
      "Failed to find an renv installation: the project will not be loaded.",
      "Use `renv::activate()` to re-initialize the project."
    )

    warning(paste(msg, collapse = "\n"), call. = FALSE)

  }

  renv_json_read <- function(file = NULL, text = NULL) {

    jlerr <- NULL

    # if jsonlite is loaded, use that instead
    if ("jsonlite" %in% loadedNamespaces()) {

      json <- tryCatch(renv_json_read_jsonlite(file, text), error = identity)
      if (!inherits(json, "error"))
        return(json)

      jlerr <- json

    }

    # otherwise, fall back to the renv JSON reader
    json <- tryCatch(renv_json_read_default(file, text), error = identity)
    if (!inherits(json, "error"))
      return(json)

    # report an error
    if (!is.null(jlerr))
      stop(jlerr)
    else
      stop(json)

  }

  renv_json_read_jsonlite <- function(file = NULL, text = NULL) {
    text <- paste(text %||% readLines(file, warn = FALSE), collapse = "\n")
    jsonlite::fromJSON(txt = text, simplifyVector = FALSE)
  }

  renv_json_read_default <- function(file = NULL, text = NULL) {

    # find strings in the JSON
    text <- paste(text %||% readLines(file, warn = FALSE), collapse = "\n")
    pattern <- '["](?:(?:\\\\.)|(?:[^"\\\\]))*?["]'
    locs <- gregexpr(pattern, text, perl = TRUE)[[1]]

    # if any are found, replace them with placeholders
    replaced <- text
    strings <- character()
    replacements <- character()

    if (!identical(c(locs), -1L)) {

      # get the string values
      starts <- locs
      ends <- locs + attr(locs, "match.length") - 1L
      strings <- substring(text, starts, ends)

      # only keep those requiring escaping
      strings <- grep("[[\\]{}:]", strings, perl = TRUE, value = TRUE)

      # compute replacements
      replacements <- sprintf('"\032%i\032"', seq_along(strings))

      # replace the strings
      mapply(function(string, replacement) {
        replaced <<- sub(string, replacement, replaced, fixed = TRUE)
      }, strings, replacements)

    }

    # transform the JSON into something the R parser understands
    transformed <- replaced
    transformed <- gsub("{}", "`names<-`(list(), character())", transformed, fixed = TRUE)
    transformed <- gsub("[[{]", "list(", transformed, perl = TRUE)
    transformed <- gsub("[]}]", ")",    transformed, perl = TRUE)
    transformed <- gsub(":", "=",     transformed, fixed = TRUE)
    text <- paste(transformed, collapse = "\n")

    # parse it
    json <- parse(text = text, keep.source = FALSE, srcfile = NULL)[[1L]]

    # construct map between source strings, replaced strings
    map <- as.character(parse(text = strings))
    names(map) <- as.character(parse(text = replacements))

    # convert to list
    map <- as.list(map)

    # remap strings in object
    remapped <- renv_json_read_remap(json, map)

    # evaluate
    eval(remapped, envir = baseenv())

  }

  renv_json_read_remap <- function(json, map) {

    # fix names
    if (!is.null(names(json))) {
      lhs <- match(names(json), names(map), nomatch = 0L)
      rhs <- match(names(map), names(json), nomatch = 0L)
      names(json)[rhs] <- map[lhs]
    }

    # fix values
    if (is.character(json))
      return(map[[json]] %||% json)

    # handle true, false, null
    if (is.name(json)) {
      text <- as.character(json)
      if (text == "true")
        return(TRUE)
      else if (text == "false")
        return(FALSE)
      else if (text == "null")
        return(NULL)
    }

    # recurse
    if (is.recursive(json)) {
      for (i in seq_along(json)) {
        json[i] <- list(renv_json_read_remap(json[[i]], map))
      }
    }

    json

  }

  # load the renv profile, if any
  renv_bootstrap_profile_load(project)

  # construct path to library root
  root <- renv_bootstrap_library_root(project)

  # construct library prefix for platform
  prefix <- renv_bootstrap_prefix()

  # construct full libpath
  libpath <- file.path(root, prefix)

  # run bootstrap code
  renv_bootstrap_exec(project, libpath, version)

  invisible()

})
