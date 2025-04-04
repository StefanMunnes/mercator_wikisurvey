library(dplyr)
library(tidyr)
library(BradleyTerry2)
library(reactable)
library(htmlwidgets)

# 1. Define input file path and load data
file_active <- "survey/items_active.xlsx"

file_kodaqs_data <- "results/kodaqs/kodaqs_data.csv"
if (!file.exists(file_kodaqs_data)) {
  stop(paste("Kodaqs data file not found:", file_kodaqs_data))
}

data_kodaqs <- read.csv(file_kodaqs_data)

# 2. Prepare data: Extract pairs and choices
items_pairs <- data_kodaqs |>
  pivot_longer(
    cols = !question,
    names_to = c(".value", "number"),
    names_pattern = "(wiki|wiki_pair)_(\\d+)"
  ) |>
  rename(chosen = wiki) |>
  filter(!is.na(chosen)) |> # remove list of pairs if no answer was given
  # split combined shown wiki pair into two items
  separate(
    wiki_pair,
    into = c("item1", "item2"),
    sep = ",",
    remove = TRUE,
    convert = TRUE
  )


questions <- c("society", "region", "work")

items_score_ls <- lapply(questions, function(q) {
  items_active <- readxl::read_xlsx(file_active, sheet = q) |>
    select(item, label)

  items <- items_active$item
  names(items) <- items_active$label

  items_pairs_wins <- items_pairs |>
    filter(question == q) |>
    transmute(
      win1 = ifelse(chosen == item1, 1, 0),
      win2 = ifelse(chosen == item2, 1, 0),
      item1 = factor(item1, levels = items, label = names(items)),
      item2 = factor(item2, levels = items, label = names(items))
    )

  model <- BTm(
    outcome = cbind(items_pairs_wins$win1, items_pairs_wins$win2),
    player1 = items_pairs_wins$item1,
    player2 = items_pairs_wins$item2
  )

  abilities <- BTabilities(model)

  beta <- abilities[, 1]

  items_scores <- data.frame(
    label = names(beta),
    score = sapply(
      names(beta),
      function(i) {
        b_i <- beta[i]
        # Exclude item i itself
        others <- beta[names(beta) != i]
        # Probability that i beats each "other" item
        p_i_beats_j <- 1 / (1 + exp(others - b_i))
        # Mean probability across all others
        value <- mean(p_i_beats_j, na.rm = TRUE) * 100

        round(value, 2)
      },
      USE.NAMES = FALSE
    )
  )

  return(items_scores)
})

names(items_score_ls) <- questions

items_scores_all <- bind_rows(items_score_ls, .id = "question") |>
  group_by(question) |>
  arrange(desc(score), .by_group = TRUE) |>
  filter(!is.na(score))

# 6. Create Reactable table
score_table <- reactable(
  items_scores_all,
  groupBy = "question",
  defaultPageSize = 15,
  columns = list(
    question = colDef(name = "Bereich"),
    label = colDef(name = "Maßnahme", minWidth = 250),
    score = colDef(
      name = "Score",
      align = "center",
      format = colFormat(digits = 1),
      style = function(value, index) {
        # Apply color style based on score within each group
        current_question <- items_scores_all$question[index]
        group_scores <- items_scores_all$score[
          items_scores_all$question == current_question
        ]
        if (length(na.omit(group_scores)) < 2) return(list(fontWeight = "bold"))
        normalized <- (value - min(group_scores, na.rm = TRUE)) /
          (max(group_scores, na.rm = TRUE) - min(group_scores, na.rm = TRUE))
        if (is.na(normalized) || !is.finite(normalized))
          return(list(fontWeight = "bold"))
        color <- colorRamp(c("red", "yellow", "green"))(normalized)
        list(
          background = sprintf("rgb(%f,%f,%f)", color[1], color[2], color[3]),
          fontWeight = "bold"
        )
      }
    )
  ),
  searchable = TRUE,
  highlight = TRUE,
  striped = TRUE,
  language = reactableLang(
    searchPlaceholder = "Items durchsuchen (ID)...", # Adjusted placeholder
    noData = "Keine Daten verfügbar",
  )
)

score_table


# Save table to HTML file

output_file <- "results/kodaqs/kodaqs_score_table.html"

saveWidget(score_table, file = output_file, selfcontained = TRUE)

message(paste("Kodaqs score table (using item IDs) saved to:", output_file))
