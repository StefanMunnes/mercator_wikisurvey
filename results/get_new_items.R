library(dplyr)
library(tidyr)

source("results/get_db_data.R")

data_input <- data |>
  mutate(date = as.Date(time_start)) |>
  select(question, date, starts_with("input")) |>
  pivot_longer(
    cols = starts_with("input"),
    names_to = "input", values_to = "item"
  ) |>
  filter(!is.na(item))


writexl::write_xlsx(
  data_input,
  paste0("results/data/items_new_", Sys.Date(), ".xlsx")
)
