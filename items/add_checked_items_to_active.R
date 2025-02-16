
### add ckecked user input statements to active items excel list

library(dplyr)

# 0. set date time and valid questions
date_time <- format(Sys.time(), "%Y%m%d_%H%M")

questions <- c("society", "region", "work")

file_check <- "items/items_check.xlsx"
file_active <- "survey/items_active.xlsx"


# 1. prepare checked items (keep just new and valid)

items_check <- openxlsx::read.xlsx(file_check, detectDates = TRUE)

# error message if no add_to and no reason provided against add
if (nrow(filter(items_check, !is.na(add_to), !is.na(reason))) > 0) {
  stop("Provide a reason, if new items should not be added to any question.")
}

items_check_valid <- items_check |>
  # keep just statements that were not processed before
  filter(is.na(time_processed)) |>
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
  distinct(add_to, label, .keep_all = TRUE)


# error message if include not match question names
if (!all(unique(items_check_valid$include) %in% questions)) {
  stop(
    "Invalid entry in include column (needs to be one of: ",
    paste0(questions, collapse = ", ")
  )
}


# 2. load and add new checked items to active items exel files

items_active_new <- lapply(questions, function(q) {
  items_active <- readxl::read_xlsx(file_active, sheet = q)

  items_active_new <- bind_rows(
    items_active,
    items_check_valid[items_check_valid$add_to == q, ]
  ) |>
    distinct(label, .keep_all = TRUE) |> 
    mutate(item = ifelse(is.na(item), row_number(), item)) |> 
    select(!add_to)

  return(items_active_new)
})

# create backup before adding new items to active
file.copy(
  file_active,
  paste0("items/backup/items_active_", date_time, ".xlsx")
)

# write new items to active
writexl::write_xlsx(items_active_new, file_active)


# 3. update items_check excel file with processed time for newly added items

items_check |> 
  mutate(
    time_processed = ifelse(is.na(time_processed), date_time, time_processed)
  ) |>
  writexl::write_xlsx(file_check)
