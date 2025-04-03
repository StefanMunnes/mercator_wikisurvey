
# load database connection details from .env file
dotenv::load_dot_env("survey/.env")

# connect to database
pool <- pool::dbPool(
  RPostgres::Postgres(),
  host = Sys.getenv("SD_HOST"),
  dbname = Sys.getenv("SD_DBNAME"),
  port = Sys.getenv("SD_PORT"),
  user = Sys.getenv("SD_USER"),
  password = Sys.getenv("SD_PASSWORD"),
  gssencmode = Sys.getenv("SD_GSSENCMODE", "prefer")
)

# load data from database table
data <- DBI::dbReadTable(pool, Sys.getenv("SD_TABLE")) 


# close connection
pool::poolClose(pool)


# write data to disk as backup
write.csv(
  data, 
  paste0(
    "results/data/backup/db", "_",
    Sys.getenv("SD_TABLE"), "_",
    format(Sys.time(), "%Y%m%d_%H%M"), ".csv"
  )
)