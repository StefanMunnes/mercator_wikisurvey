library(surveydown)
library(shinyvalidate)


if (Sys.info()["sysname"] == "Windows") {
  db <- sd_db_connect(ignore = TRUE)
} else {
  db <- sd_db_connect(gssencmode = NULL)
}


questions_short <- c(
  "in Deutschland" = "society",
  "in Ihrer Region" = "region",
  "am Arbeitsplatz" = "work"
)

items <- lapply(unname(questions_short), function(q) {
  readxl::read_xlsx("items.xlsx", sheet = q)
})

names(items) <- unname(questions_short)


server <- function(input, output, session) {

  # load and prepare wiki items as pairs from loaded excel file
  pairs <- lapply(items, function(q) {

    items_raw <- setNames(as.character(q$item), q$label)

    pairs <- replicate(
      10, 
      sample(items_raw, 2, replace = FALSE, prob = q$prob),
      simplify = FALSE
    )

    return(pairs)
  })

  # store all randomly assigned pairs in variable for each subgroup of question
  for (pairs_name in names(pairs)) {
    pairs_combined <- paste0(
      sapply(pairs[[pairs_name]], paste0, collapse = ","), # , inside each pair
      collapse = ";" # , between multiple pairs
    )
  
    sd_store_value(pairs_combined, paste0("wiki_pairs_", pairs_name))
  }

  
  shiny::observe({

    # prepare question depending lable for wiki headlines 
    question_chosen <- names(questions_short[questions_short == input$question])

    sd_store_value(question_chosen, "question_lab_1")
    sd_store_value(question_chosen, "question_lab_2")


    # create all wiki questions with randomly paired statements for chosen question
    if (!is.null(input$question)) {

      for (pair in seq_along(pairs[[input$question]])) {

        sd_question(
          id = paste0("wiki_", pair),
          type = "mc_buttons",
          label = NULL,
          direction = "vertical",
          option = pairs[[input$question]][[pair]]
        )
      }
    }
  })


  sd_show_if(

    sd_is_answered("wiki_1") ~ "wiki_2",
    sd_is_answered("wiki_2") ~ "wiki_3",
    sd_is_answered("wiki_3") ~ "wiki_4",
    sd_is_answered("wiki_4") ~ "wiki_5",
    sd_is_answered("wiki_5") ~ "wiki_6",
    sd_is_answered("wiki_6") ~ "wiki_7",
    sd_is_answered("wiki_7") ~ "wiki_8",
    sd_is_answered("wiki_8") ~ "wiki_9",
    sd_is_answered("wiki_9") ~ "wiki_10",

    stringr::str_length(input$input1) > 5 ~ "input2",
    stringr::str_length(input$input2) > 5 ~ "input3",
    stringr::str_length(input$input3) > 5 ~ "input4",
    stringr::str_length(input$input4) > 5 ~ "input5",
    stringr::str_length(input$input5) > 5 ~ "input6",
    stringr::str_length(input$input6) > 5 ~ "input7",
    stringr::str_length(input$input7) > 5 ~ "input8",
    stringr::str_length(input$input8) > 5 ~ "input9",
    stringr::str_length(input$input9) > 5 ~ "input10",

    input$question == "region" ~ "region",
    input$job == "sonstiges" ~ "job_sonstiges",
    input$region == "sonstiges" ~ "region_sonstiges"
  )

  iv <- InputValidator$new()
  iv$add_rule("byear", sv_regex("^(19[2-9][0-9])|(20[01][0-9])$", "Kein gültiges Geburtsjahr"))
  iv$add_rule("plz", sv_regex("[0-9]{4,5}$", "Keine gültige PLZ"))
  iv$enable()

  sd_server(
    db = db,
    language = "de",
    required_questions = c("question", "wiki_1"),
    auto_scroll = TRUE,
    use_cookies = FALSE
  )
}

shiny::shinyApp(ui = sd_ui(), server = server)