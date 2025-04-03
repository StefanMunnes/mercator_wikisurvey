# Wiki Survey: Social Cohesion

This repository contains an implementation of a **Wiki Survey** on **social cohesion**, built using the R package [surveydown][surveydown]. The survey collects opinions on measures to strengthen social cohesion in various contexts: **nationwide (Germany)**, **regional**, and **workplace**.

**Link to the Wiki Survey: [https://shiny2.wzb.eu/afs-team/wikisurvey/](https://shiny2.wzb.eu/afs-team/wikisurvey/)**

This Wiki Survey is part of the broader research project [Zukunftsvisionen junger Menschen zu Gesellschaft und Zusammenhalt][wzb-project] at the [Berlin Social Science Center](https://www.wzb.eu), and is funded by the [Stiftung Mercator](https://www.stiftung-mercator.de/de/).


## What is a Wiki Survey?

A Wiki Survey is an innovative method that combines elements of traditional surveys with the collaborative nature of platforms like wikis. Participants are shown pairs of items and asked to select the one they prefer. They may also contribute new items, which are subsequently added to the survey for future participants to evaluate. This iterative and collaborative format allows the survey to evolve dynamically, capturing a broader and more detailed understanding of collective preferences.

The core concept of Wiki Surveys and methods for evaluating their results are described in the following publication:

- Salganik, M. J., & Levy, K. E. C. (2015). Wiki surveys: Open and quantifiable social data collection. *PLOS ONE*, 10(5). [https://doi.org/10.1371/journal.pone.0123483][wiki-article]


## Implementation in R with surveydown

![example of pairwise comparisons in surveydown](misc/img_survey.jpg "Screenshot from wiki-like pairwise comparison implemented with surveydown")

This Wiki Survey is implemented using the R package [surveydown][surveydown], a code-based solution that employs the [R programming language](https://www.r-project.org/), the [Shiny](https://github.com/rstudio/shiny) framework for building reactive web applications, [Quarto](https://github.com/quarto-dev/quarto) for markdown formatting with code interpretation, and [Supabase](https://github.com/supabase/supabase) as a PostgreSQL database backend.

1. **Pairwise Comparisons**: Participants are shown up to 10 randomly selected item pairs and asked to choose their preferred one. The survey starts with a curated list of items and evolves through user contributions. Each item can be compared with others multiple times.

2. **Controlled Item Addition**: Participants may suggest new items, which are manually reviewed by the research team before inclusion. This step ensures the exclusion of inappropriate or redundant items, thereby maintaining the clarity and distinctiveness of the results.

3. **Data Collection and Item Scores**: Participants answers are stored in a PostgreSQL database, managed by surveydown package. The ratings given can be accessed via a simple API query to calculate the score and further analyses either directly via the Shiny server or locally at a later time. Find out more about the evaluation methods in the [section about calculating the item scores](#main-result-item-scores).


## Special Features 

The three main differences between this implementation and the one realized by the original authors of the concept with [allourideas.org](https://github.com/allourideas/allourideas.org) are:


1. **Limited Comparisons**: Due to the classic structure of this implementation, a fixed number of comparisons is defined, which limits the number of possible matchups and new entries.

2. **Additional Questions**: This setup allows for traditional survey elements, enabling the addition of extra questions such as socio-demographic information.

3. **Flexibility and Control**: Leveraging an open-source and programmable framework gives researchers full flexibility. They can easily customize the design, number of questions, item selection probabilities, filtering logic, scoring methods, result presentation, and more.


## Folder and File Structure

The repository is organized into three main folders:

1. [**survey**](/survey/): Contains all files necessary to host the Wiki Survey on a Shiny server
    1. [survey.qmd](survey/survey.qmd) – Defines the survey structure, text elements, and static questions.
    2. [app.R](survey/app.R) – Contains Shiny functionalities, server options, and reactive logic.
    3. [items_active.xlsx](survey/items_active.xlsx) – Repository of all currently active items with associated statistics.
    4. .env (hidden) – Stores Supabase DB server and login credentials.
    5. _survey-folder – Processes data via surveydown to generate the web application.
2. [**items**](items/): Includes scripts for item management and post-processing
    1. [get_new_items_for_check.R](items/get_new_items_for_check.R) – Fetches new items from the database, creates backups, and generates an Excel file for manual review.
    2. [add_checked_items_to_active.R](items/add_checked_items_to_active.R) – Adds approved items to [items_active.xlsx](survey/items_active.xlsx).
    3. [get_items_statistics.R](items/get_items_statistics.R) – Counts item comparisons and computes scores to enrich items_active.xlsx.
3. [**results**](results/): Focuses on data management and analysis.
    1. [get_db_data.R](results/get_db_data.R) - query the most recent data from the supabase DB and create a backup


## Main Result: Item Scores

The primary result of this Wiki Survey is the generation of a score for each item, reflecting its relative preference among participants. These scores are calculated using the Bradley-Terry model, which estimates the likelihood that one item is preferred over another in pairwise comparisons.

The script [get_items_statistics.R](items/get_items_statistics.R) performs the following actions:

1. **Data Preparation**: Extracts and aggregates all relevant comparison data.
2. **Model Estimation**: Applies the Bradley-Terry model to estimate preferences.
3. **Score Calculation**: Computes a numerical score for each item, indicating its relative strength of preference.

These scores offer a clear ranking and help identify which ideas or suggestions resonate most (or least) with participants.

![example of table with item scores](misc/img_items_scores.jpg)


## Usage and Replication

This repository uses the [`renv`](https://rstudio.github.io/renv/) package to ensure reproducibility by tracking R versions and package dependencies. To replicate the environment, clone the repository and run the following command:

```R
renv::restore()
```

To deploy the web application, save your database credentials in an `.env` file within the [survey](survey) directory, then run [app.R](survey/app.R) to let surveydown generate the necessary files. For further guidance, check the [surveydown documentation](https://surveydown.org/documentation).

If you wish to adapt this repository for a different topic, be sure to provide a new set of seed items in the [items_active.xlsx](survey/items_active.xlsx) file.

[surveydown]: https://github.com/surveydown-dev/surveydown
[wzb-project]: https://wzb.eu/de/forschung/dynamiken-sozialer-ungleichheiten/arbeit-familie-und-soziale-ungleichheit/projekte/zukunftsvisionen-junger-menschen-zu-gesellschaft-und-zusammenhalt
[wiki-article]: https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0123483