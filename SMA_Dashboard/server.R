
library(shiny)
library(shinydashboard)

## Define server logic
server <- shinyServer(function(input, output, session) {
  
  
  ## Continiously updating data functions for all tweets + employee tweets
  allData <- reactivePoll(2000, session, checkFunc = testFunction_all, valueFunc = readData_all)
  influencers_fow <- reactivePoll(60000, session, checkFunc = test_fow, valueFunc = read_fow)
  sc_members <-  reactivePoll(60000, session, checkFunc = test_sc, valueFunc = read_sc)

  ## Compute KPIs
  nrTweets <- tweetCount(allData)
  lastTweet <- lastTweets(allData)
  hashtagList <- topHashtags(allData)
  rt_or_plot <- pie_plot(allData)
  wordcl <- cloudofwords(allData)
  contributors <- topContr(allData)
  nr_contr <- nrContr(allData)
  sentiment <- sentiment_plot(allData)
  raw_data <- rawData(allData)
  total_impressions <- impressions(allData)
  network_graph <- network(allData, influencers_fow, sc_members)
  lastTweet_DT <- lastTweets_DT(allData)
  
  ## Render functions for UI outputs
  
  output$nrContributors <- renderValueBox({
    valueBox(
      value = nr_contr(), width = 4,
      subtitle = "Unique Contributors",
      icon = icon("users"),
      color = "light-blue"
    )
  })
  
  output$tbl <- renderText({
    lastTweet()
    })
  
  output$tbl_DT <- renderDataTable({
    lastTweet_DT()
  })
  
  output$contr <- renderText({
    contributors()
  })
  
  output$plot <- renderPlotly({
    rt_or_plot()
  })
  
  output$topwords <- renderTable({
    trendingWords()
  }, striped = TRUE, spacing = "xs", rownames = TRUE, colnames = FALSE)
  
  output$hashtags <- renderTable({
    hashtagList()
  }, striped = TRUE, spacing = "xs", rownames = TRUE, colnames = FALSE)
  
  output$nrTweets <- renderValueBox({
    valueBox(
      value = nrTweets(), width = 4,
      subtitle = "Total Tweets",
      icon = icon("twitter"),
      color = "light-blue"
    )
  })
  
  output$wc <- renderPlot({
    wordcl()
  })
  
  output$sent_plot <- renderPlotly({
    sentiment()
    
  })
  
  output$rawdata <- DT::renderDataTable({
    raw_data()
  })
  
  output$network_plot <- renderForceNetwork({
    network_graph()
  })
  
  output$legend <- renderText({
    "Original Tweeter -> Retweeter \r\n
    Node size = Total possible impressions gathered by user \r\n
    "
  })
  
  output$nrImpressions <- renderValueBox({
    #tweets <- twitterData()
    valueBox(
      value = total_impressions(),
      "Potential Impressions", width = 4,
      icon = icon("eye"),
      color = "light-blue"
    )
  })
  
  
  
})
