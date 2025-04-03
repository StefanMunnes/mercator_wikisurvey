library(dplyr)
library(tidyr)
library(BradleyTerry2)

# 0. set questions and file path
questions <- c("society", "region", "work")

file_active <- "survey/items_active.xlsx"


# 1.1 get local excel list of active items for each question
items_active_ls <- lapply(questions, function(q) {
  readxl::read_xlsx(file_active, sheet = q) |>
    select(item, label, time_added)
})

names(items_active_ls) <- questions

items_active <- bind_rows(items_active_ls, .id = "question")


# 1.2 get answer table from DB (supabase)
source("results/get_db_data.R")


# 2. create dataframe with all shown and answered pairs of items and chosen ones
items_pairs <- data |>
  filter(!is.na(wiki_1)) |> # keep only if first wiki pair was answered
  select(question, starts_with("wiki")) |> # keep only wiki columns and question
  # split three helper variables of wiki pairs by question into long format
  pivot_longer(
    starts_with("wiki_pairs_"),
    names_to = "wiki_pairs_type",
    names_prefix = "wiki_pairs_",
    values_to = "wiki_pairs"
  ) |>
  filter(question == wiki_pairs_type) |> # keep just fitting pairs by question
  # create single variables from string of wiki pairs and bring in long format
  separate(wiki_pairs, into = paste0("wiki_pair_", 1:10), sep = ";") |>
  select(!wiki_pairs_type) |>
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


# 3. calculate statistics (times shown, times chosen, winrate) for each item
items_winrate <- items_pairs |>
  pivot_longer(
    cols = c(item1, item2),
    names_to = "option_index",
    values_to = "item"
  ) |>
  summarize(
    times_shown = n(),
    times_chosen = sum(item == chosen),
    winning_rate = round(times_chosen / times_shown, 4),
    .by = c("question", "item")
  ) |>
  full_join(
    items_active,
    by = c("question", "item")
  )


items_active_stat_ls <- lapply(questions, function(q) {
  message(paste0("Add statistics and calculate Score for question: ", q))

  items_winrate <- items_winrate |>
    filter(question == q) |>
    # new probability to be shown: normalize between 0.5 and 1 depending on times_shown
    mutate(
      across(c(times_shown, times_chosen), ~ ifelse(is.na(.x), 0, .x)),
      prob = 1 -
        (times_shown - min(times_shown)) /
          (max(times_shown) - min(times_shown)) *
          0.5
    ) |>
    select(
      item,
      label,
      prob,
      winning_rate,
      times_chosen,
      times_shown,
      time_added
    ) |>
    arrange(item)

  items <- items_winrate$item
  names(items) <- items_winrate$label

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

  full_join(items_winrate, items_scores, by = "label") |>
    mutate(score = ifelse(times_shown < 3, NA, score)) |>
    select(
      item,
      label,
      winning_rate,
      score,
      times_chosen,
      times_shown,
      prob,
      time_added
    )
})

names(items_active_stat_ls) <- questions

writexl::write_xlsx(items_active_stat_ls, file_active)
