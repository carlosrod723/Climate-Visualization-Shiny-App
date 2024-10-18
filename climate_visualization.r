# Load necessary libraries
library(shiny)
library(ggplot2)
library(dplyr)
library(plotly)
library(lubridate)

# Load the dataset (adjust file path if necessary)
climate_data <- read.csv("/Users/lidiaacosta/Downloads/Univ_Min_Global_Summary.csv")

# Convert DATE to proper Date format
climate_data$DATE <- as.Date(paste0(climate_data$DATE, "-01"), format="%Y-%m-%d")

# UI
ui <- fluidPage(
  titlePanel("Climate Data Visualization"),
  sidebarLayout(
    sidebarPanel(
      selectInput("plot_type", "Plot Type:",
                  choices = c("Time Series", "Bivariate")),
      selectInput("variable", "Variable:",
                  choices = c("TAVG", "TMAX", "TMIN", "PRCP")),
      conditionalPanel(
        condition = "input.plot_type == 'Bivariate'",
        selectInput("variable2", "Second Variable:",
                    choices = c("TAVG", "TMAX", "TMIN", "PRCP"))
      ),
      dateRangeInput("dates", "Date range:",
                     start = min(climate_data$DATE),
                     end = max(climate_data$DATE)),
      checkboxGroupInput("regions", "Select Regions:",
                         choices = unique(climate_data$NAME),
                         selected = unique(climate_data$NAME)[1])
    ),
    mainPanel(
      plotlyOutput("climatePlot")
    )
  )
)

# Server
server <- function(input, output) {
  output$climatePlot <- renderPlotly({
    print("Filtering data...")
    filtered_data <- climate_data %>%
      filter(DATE >= input$dates[1] &
             DATE <= input$dates[2] &
             NAME %in% input$regions)
    
    print("Filtered data dimensions:")
    print(dim(filtered_data))
    
    if(input$plot_type == "Time Series") {
      print("Creating Time Series plot...")
      
      # Create a data frame for each region
      plot_data <- filtered_data %>%
        group_by(NAME) %>%
        do({
          data <- .
          model <- lm(as.formula(paste(input$variable, "~ as.numeric(DATE)")), data = data, na.action = na.exclude)
          data$predicted <- predict(model, newdata = data)
          data$residuals <- residuals(model)
          data
        }) %>%
        ungroup()
      
      # Detect anomalies (points beyond 2 standard deviations)
      sd_threshold <- 2
      plot_data <- plot_data %>%
        group_by(NAME) %>%
        mutate(is_anomaly = abs(residuals) > sd_threshold * sd(residuals, na.rm = TRUE)) %>%
        ungroup()
      
      p <- ggplot(plot_data, aes(x = DATE, y = .data[[input$variable]])) +
        geom_line(color = "blue") +
        geom_line(aes(y = predicted), color = "red") +
        geom_point(data = plot_data %>% filter(is_anomaly), color = "green", size = 3) +
        labs(title = paste(input$variable, "Over Time with Trend and Anomalies"),
             x = "Date",
             y = input$variable) +
        theme_minimal() +
        facet_wrap(~NAME, scales = "free_y")
    } else {
      print("Creating Bivariate plot...")
      p <- ggplot(filtered_data, aes(x = .data[[input$variable]], y = .data[[input$variable2]], color = NAME)) +
        geom_point(alpha = 0.6) +
        geom_smooth(method = "lm", se = FALSE) +
        labs(title = paste(input$variable, "vs", input$variable2, "with Trend"),
             x = input$variable,
             y = input$variable2) +
        theme_minimal() +
        facet_wrap(~NAME)
    }
    
    print("Converting to plotly...")
    tryCatch({
      ggplotly(p)
    }, error = function(e) {
      print(paste("Error in ggplotly:", e$message))
      ggplotly(ggplot() + ggtitle("Error in creating interactive plot"))
    })
  })
}

# Set option to automatically open the browser
options(shiny.launch.browser = TRUE)

# Run the Shiny app
shinyApp(ui = ui, server = server)