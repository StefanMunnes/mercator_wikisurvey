
### get new items from supabase database and prepare for check in excel file 

library(dplyr)

# 0. set date time for variable and backup

date_time <- format(Sys.time(), "%Y%m%d_%H%M")

file_check <- "items/items_check.xlsx"


# 1. load and prepare respondents inputs of items from supabase database

source("results/get_db_data.R")

items_input <- data |>
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
  mutate(
    add_to = NA,
    label_new = NA,
    reason = NA,
    dup_item = NA,
    dup_label = NA,
    .after = label
  ) |> 
  mutate(time_processed = NA)


# 2. write items for check in file: new file or backup and add new items

if (!file.exists(file_check)) {
  writexl::write_xlsx(items_input, file_check)
} else {

  items_check <- openxlsx::read.xlsx(file_check, detectDates = TRUE)

  # if new items: create backup and then add new items and save
  if (nrow(items_input) > nrow(items_check)) {
  
    file.copy(
      file_check,
      paste0("items/backup/items_check_", date_time, ".xlsx")
    )

    items_check_new <- rbind(items_check, items_input) |>
      distinct(label, time_input, .keep_all = TRUE)
  
    writexl::write_xlsx(items_check_new, file_check)
  }
}
