# Goal: get new items from supabase database and add for check to excel file
# active check file should just have statements that were not processed before
# after manual check of statements: run add_checked_items_to_active.R to add to survey
# this will also move the checked items to a backup file with time processed to survey
# before creating new check file: check for active check file (not processed yet)
# if this is the case, add most recent inputs to check file
# if no active check file: create new check file with most recent inputs (not in backup)

library(dplyr)

# 0. set date time for variable and backup and define file paths

date_time <- format(Sys.time(), "%Y%m%d_%H%M")

questions <- c("society", "region", "work")

file_check <- "items/items_check.xlsx"

files_check_backup <- list.files("items/backup", "^items_check_", full.names = TRUE)



# 1. load and prepare respondents inputs of items from supabase database

# get data from database
source("results/get_db_data.R")

# prepare data (add times; long format of inputs; add helper variables)
items_input_long <- data |>
  mutate(
    time_input = format(as.POSIXct(time_start), "%Y%m%d_%H%M"),
    time_download = date_time
  ) |>
  select(question, time_input, time_download, starts_with("input")) |>
    tidyr::pivot_longer(
      cols = starts_with("input"),
      names_to = "input", values_to = "label"
    ) |>
  filter(!is.na(label)) |> 
  select(question, label, time_input, time_download) |>
  # add dot to end of statements (remove possibly other punctuation) 
  mutate(label = stringr::str_replace(label, "^(.*?)([.!?:;])?$", "\\1.")) |>
  mutate(
    add_to = NA,
    label_new = NA,
    reason = NA,
    dup_label = NA,
    .after = label
  )

# put inputs by wiki question into three separate dataframes (for excel sheets)
items_input <- lapply(questions, function(q) {
  subset(items_input_long, question == q, -question)
})

# add question names to list of dataframes
names(items_input) <- questions



# 2. write new inputs to check file
# (check for new inputs for each question from backup and active check file)

items_check_new <- lapply(questions, function(q) {

  message("Check for new inputs for: ", q)

  # read backup file with all implemented inputs
  message("1. Load backup file.")
  items_check_backup <- openxlsx::read.xlsx(
    sort(files_check_backup, decreasing = TRUE)[1], q, detectDates = TRUE
  )

  # keep just input, that were not processed before (add to active items list)
  time_recent <- max(items_check_backup$time_input)
  items_input_new <- filter(items_input[[q]], time_input > time_recent)


  # try to read active check file with not implemented inputs
  items_check_new <- tryCatch({

    items_check_active <- openxlsx::read.xlsx(file_check, q, detectDates = TRUE) |>
      mutate(across(everything(), as.character))
    
    # combine active check and new inputs and keep unique to write again in file
    items_check_unique <- bind_rows(items_check_active, items_input_new) |>
      distinct(label, time_input, .keep_all = TRUE) |>
      arrange(time_input)
    
    message(
      "2. Load active check file and add ", 
      nrow(items_check_unique) - nrow(items_check_active),
      " new inputs."
    )

    items_check_unique

  }, error = function(e) {
    # if now check file could be loaded: create new check file just from new inputs
    message("2. No active check file found, add ", nrow(items_input_new), " new inputs.")
    
    items_input_new
  })

  return(items_check_new)
})

# add question names to list of dataframes
names(items_check_new) <- questions

# remove empty dataframes from list (just write active check if not empty)
items_check_new <- Filter(function(df) nrow(df) > 0, items_check_new)


if (length(items_check_new) > 0) {
  writexl::write_xlsx(items_check_new, file_check)
} 

