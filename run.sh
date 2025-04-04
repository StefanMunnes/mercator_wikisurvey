#!/bin/bash

# Check if the .env file exists in the survey directory
if [ -f "survey/.env" ]; then
  echo "Running kodaqs_data.R script..."
  Rscript results/kodaqs/kodaqs_data.R
else
  echo "survey/.env file not found. Skipping kodaqs_data.R script."
fi

# Always run the kodaqs_table.R script
echo "Running kodaqs_table.R script..."
Rscript results/kodaqs/kodaqs_table.R

echo "Script execution finished."