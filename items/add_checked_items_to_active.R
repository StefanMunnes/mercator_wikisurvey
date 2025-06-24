### add ckecked user input statements to active items excel list

library(dplyr)

# 0. set date time and valid questions
date_time <- format(Sys.time(), "%Y%m%d_%H%M")

questions <- c("society", "region", "work")

file_check <- "items/items_check.xlsx"
file_active <- "survey/items_active.xlsx"
files_check_backup <- list.files(
  "items/backup",
  "^items_check_",
  full.names = TRUE
)


# check if check file exists, then process inputs and create backup
if (!file.exists(file_check)) {
  stop("Check file does not exist.")
} else {
  # 1. load checked items and prepare the once to add to active items list
  message("Load checked items and prepare for adding to active items list.")

  # load checked items (if available for question)
  items_check_all <- lapply(questions, function(q) {
    tryCatch(
      {
        openxlsx::read.xlsx(file_check, q, detectDates = TRUE) |>
          mutate(across(everything(), as.character))
      },
      error = function(e) {
        message(paste0("No checked items for question: ", q))
        data.frame()
      }
    )
  }) |>
    bind_rows()

  # error message if no add_to and no reason provided against add
  if (nrow(filter(items_check_all, is.na(add_to) & is.na(reason))) > 0) {
    stop("Provide a reason, if new items should not be added to any question.")
  }

  # prepare items for active items list
  items_check_keep <- items_check_all |>
    # keep just statements that should be added to at least one question
    filter(!is.na(add_to)) |>
    # use corrected statement instead of original one, if provided
    mutate(label = ifelse(is.na(label_new), label, label_new)) |>
    select(add_to, label) |>
    # add helper columns for active items list
    mutate(
      prob = 1,
      time_added = date_time,
    ) |>
    tidyr::separate_rows(add_to, sep = ",") |>
    mutate(add_to = trimws(add_to)) |>
    distinct(add_to, label, .keep_all = TRUE)

  # error message if include not match question names
  if (!all(unique(items_check_keep$add_to) %in% questions)) {
    stop(
      "Invalid entry in add_to column (needs to be one of: ",
      paste0(questions, collapse = ", "),
      ")."
    )
  }

  # just write items to add to active items list if there are any
  if (nrow(items_check_keep) > 0) {
    message("Add new items to active items list.")

    # 1.2 load and add new checked items to keep to active items exel files
    items_active_new_3 <- lapply(questions, function(q) {
      # 1.2 load and add new checked items to active items exel files
      items_active <- readxl::read_xlsx(file_active, sheet = q)

      items_active_new <- bind_rows(
        items_active,
        items_check_keep[items_check_keep$add_to == q, ]
      ) |>
        distinct(label, .keep_all = TRUE) |>
        mutate(item = ifelse(is.na(item), row_number(), item)) |>
        select(!add_to)

      # check if item numbers are unique
      if (length(unique(items_active_new$item)) != nrow(items_active_new)) {
        stop("Item numbers are not unique.")
      }

      return(items_active_new)
    })

    names(items_active_new_3) <- questions

    # create backup before adding new items to active
    message("Create backup of active items before adding new items to active.")

    file.copy(
      file_active,
      paste0("items/backup/items_active_", date_time, ".xlsx")
    )

    # write new items to active
    writexl::write_xlsx(items_active_new_3, file_active)
  } else {
    message("No new items to add to active items list.")
  }

  # 2. write all checked items to backup
  items_backup_new <- lapply(questions, function(q) {
    # load checked items (if available for question)
    items_check <- tryCatch(
      {
        openxlsx::read.xlsx(file_check, q, detectDates = TRUE) |>
          mutate(across(everything(), as.character))
      },
      error = function(e) {
        data.frame()
      }
    )

    # load most recent backup file
    items_backup <- openxlsx::read.xlsx(
      sort(files_check_backup, decreasing = TRUE)[1],
      q,
      detectDates = TRUE
    )

    # combine backup and checked items to write again in file
    items_backup_new <- bind_rows(items_backup, items_check) |>
      mutate(
        time_processed = ifelse(
          is.na(time_processed),
          date_time,
          time_processed
        )
      )

    return(items_backup_new)
  })

  names(items_backup_new) <- questions

  message("Write processed checked items to backup and remvove check file.")

  writexl::write_xlsx(
    items_backup_new,
    paste0("items/backup/items_check_", date_time, ".xlsx")
  )

  file.remove(file_check)
}
