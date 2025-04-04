library(dplyr)
library(tidyr)

# load data from supabase DB
source("results/get_db_data.R")

# break if object data not available (error in get_db_data.R)
if (!exists("data")) {
  stop("No data available.")
}


data_kodaqs <- data |>
  # keep just responses with at least one wiki raited
  filter(!is.na(wiki_1)) |>
  # keep only wiki columns, start time, gender and question
  select(time_start, gender, question, starts_with("wiki")) |>
  pivot_longer(
    starts_with("wiki_pairs_"),
    names_to = "wiki_pairs_type",
    names_prefix = "wiki_pairs_",
    values_to = "wiki_pairs"
  ) |>
  # keep just fitting pairs by question
  filter(question == wiki_pairs_type) |>
  select(!wiki_pairs_type) |>
  # create single variables from string of wiki pairs and bring in long format
  separate(wiki_pairs, into = paste0("wiki_pair_", 1:10), sep = ";")


# write data to disk
write.csv(data_kodaqs, "results/kodaqs/kodaqs_data.csv", row.names = FALSE)
