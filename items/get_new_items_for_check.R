# Goal: get new items from supabase database and add for check to excel file
# active check file should just have statements that were not processed before
# after manual check of statements: run add_checked_items_to_active.R to add to survey
# this will also move the checked items to a backup file with time processed to survey
# before creating new check file: check for active check file (not processed yet)
# if this is the case, add most recent inputs to check file
# if no active check file: create new check file with most recent inputs (not in backup)

library(dplyr)
library(tidyllm)

# 0. set date time for variable and backup and define file paths

date_time <- format(Sys.time(), "%Y%m%d_%H%M")

questions <- c("society", "region", "work")


file_embeddings <- "items/items_active_embeddings.RDS"
file_check <- "items/items_check.xlsx"
files_check_backup <- list.files(
  "items/backup",
  "^items_check_",
  full.names = TRUE
)

items_active_embeddings <- readRDS(file_embeddings)
options(tidyllm_embed_default = openai(.model = "text-embedding-3-small"))

cos_sim <- function(a, b) {
  sum(a * b) / (sqrt(sum(a^2)) * sqrt(sum(b^2)))
}

# 1. load and prepare respondents inputs of items from supabase database

# get data from database
source("results/get_db_data.R")

# prepare data (add times; long format of inputs; add helper variables)
items_input_long <- data |>
  mutate(
    time_start = ifelse(is.na(time_start), time_end, time_start),
    time_input = format(as.POSIXct(time_start), "%Y%m%d_%H%M"),
    time_download = date_time
  ) |>
  select(question, time_input, time_download, starts_with("input")) |>
  tidyr::pivot_longer(
    cols = starts_with("input"),
    names_to = "input",
    values_to = "label"
  ) |>
  filter(!is.na(label)) |>
  select(question, label, time_input, time_download) |>
  # add dot to end of statements (remove possibly other punctuation) and first letter uppercase
  mutate(
    label = stringr::str_replace(label, "^(.+?)([.!?:; ])*$", "\\1."),
    label = gsub("^([a-zäöü])", "\\U\\1", label, perl = TRUE)
  ) |>
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
    sort(files_check_backup, decreasing = TRUE)[1],
    q,
    detectDates = TRUE
  )

  # keep just input, that were not processed before (add to active items list)
  time_recent <- max(items_check_backup$time_input, na.rm = TRUE)
  items_input_new <- filter(items_input[[q]], time_input > time_recent)

  # try to read active check file with not implemented inputs
  items_check_new <- tryCatch(
    {
      items_check_active <- openxlsx::read.xlsx(
        file_check,
        q,
        detectDates = TRUE
      ) |>
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
    },
    error = function(e) {
      # if now check file could be loaded: create new check file just from new inputs
      message(
        "2. No active check file found, add ",
        nrow(items_input_new),
        " new inputs."
      )

      items_input_new
    }
  )

  # 3.
  message("3. Get top 3 similar active items.")

  items_active_embeddings_question <- items_active_embeddings[
    items_active_embeddings$question == q,
  ]

  items_check_new_embeddings <- embed(items_check_new$label)

  # Calculate similarity: loop over each new item
  items_check_new_similarity <- lapply(
    1:nrow(items_check_new_embeddings),
    function(item_new_nr) {
      # calculate cosine similarity between new item and each active items
      similarities <- sapply(
        items_active_embeddings_question$embeddings,
        function(item_embbing_active) {
          cos_sim(
            items_check_new_embeddings$embeddings[[item_new_nr]],
            item_embbing_active
          )
        }
      )

      temp_results <- data.frame(
        label = items_check_new_embeddings$input[item_new_nr],
        item_active = items_active_embeddings_question$input,
        similarity = round(similarities, 2)
      ) |>
        arrange(desc(similarity)) |>
        slice_head(n = 3) |>
        mutate(index = row_number()) |>
        tidyr::pivot_wider(
          names_from = index,
          values_from = c(item_active, similarity)
        ) |>
        select(
          label,
          item_active_1,
          similarity_1,
          item_active_2,
          similarity_2,
          item_active_3,
          similarity_3
        )

      return(temp_results)
    }
  ) |>
    bind_rows()

  # add existing columns back to dataframe
  items_check_new_all <- cbind(
    items_check_new_similarity,
    items_check_new[,
      !(names(items_check_new) %in% c("label"))
    ]
  )

  message("4. Order new items by similarity.")

  # order new items by similarity
  order <- do.call(rbind, items_check_new_embeddings$embeddings) |>
    dist(method = "euclidean") |> # calculate the distance matrix
    hclust(method = "ward.D2") |> # perform h.-clustering using Ward's method
    getElement("order") #  get the optimal ordering of the sentences

  items_check_new_ordered <- items_check_new_all[order, ]

  return(items_check_new_ordered)
})

# add question names to list of dataframes
names(items_check_new) <- questions

# remove empty dataframes from list (just write active check if not empty)
items_check_new <- Filter(function(df) nrow(df) > 0, items_check_new)

# write new inputs to check file
if (length(items_check_new) > 0) {
  writexl::write_xlsx(items_check_new, file_check)
}
