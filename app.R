
library(shiny)
library(shinydashboard)

server <- shinyServer(function(input, output, session) {
  
  twitterData <- reactivePoll(100, session, checkFunc = testFunction, valueFunc = readAllTwitterData)
  compData <- reactivePoll(100, session, checkFunc = compTestFunction, valueFunc = readAllCompData)
  nrTweets <- tweetCount(twitterData)
  lastTweet <- lastTweets(twitterData)
  bubbles <- bubblePlot(twitterData)
  trendingWords <- trendingList(twitterData)
  contributors <- topContributors(twitterData)
  HashtagList <- atosHashtagList(twitterData)
  
  output$tbl <- renderTable({
    lastTweet()
  }, striped = TRUE, spacing = "xs", colnames = FALSE
  
  )
  
  output$topcontributors <- renderTable({
    contributors()
  }, striped = TRUE, spacing = "xs", rownames = TRUE, colnames = FALSE)
  
  output$topwords <- renderTable({
    trendingWords()
  }, striped = TRUE, spacing = "xs", rownames = TRUE, colnames = FALSE)
  
  output$hashtags <- renderTable({
    HashtagList()
  }, striped = TRUE, spacing = "xs", rownames = TRUE, colnames = FALSE)
  
  output$leaflet_map <- renderLeaflet({
    tweets <- twitterData()
    leaflet(tweets) %>% addCircleMarkers(lng = ~lon, lat = ~lat,
                                         popup =  ~paste0(text),radius=2) %>% addProviderTiles(providers$OpenWeatherMap)
  })
  
  output$nrTweets <- renderValueBox({
    valueBox(
      value = nrTweets(), width = 4,
      subtitle = "Total Tweets",
      icon = icon("twitter")
    )
  })
  
  output$nrLinkedIn <- renderValueBox({
    #tweets <- twitterData()
    valueBox(
      value = paste0(0,"%"),
      "Positive", color = "red", width = 4,
      icon = icon("thumbs-up")
    )
  })
  
  output$nrFacebook <- renderValueBox({
    #tweets <- twitterData()
    valueBox(
      value = 0,
      "Total Impressions", color = "yellow", width = 4,
      icon = icon("eye")
    )
  })
  
  
  output$bubblePlot <- renderBubbles({
    if (nrow(twitterData())==0)
      return()
    
    bubbles()
    
  })
  
  
  
})

# Define UI for application
ui <- shinyUI(dashboardPage( title = "atos | social media dashboard",
                       dashboardHeader(
                         title = span(tagList("atos SoMe dashboard", icon("comments")))),
                       dashboardSidebar(
                         sidebarMenu(
                           menuItem("Home", tabName = "home", icon = icon("home")),
                           menuItem("Competitors", tabName = "competitors", icon = icon("globe")),
                           menuItem("Clients", tabName = "clients", icon = icon("users"))
                         )
                       ),
                       
                       dashboardBody(
                         tabItems(
                           tabItem(tabName ="home",
                                   
                                   fluidRow(
                                     valueBoxOutput("nrTweets"),valueBoxOutput("nrLinkedIn"),valueBoxOutput("nrFacebook")),
                                   fluidRow(
                                     box(
                                       title = "Top Contributors",
                                       tableOutput("topcontributors"), width = 4, status = "info"
                                       
                                     ),
                                     #box(title = "Words associated with Atos",
                                     #    bubblesOutput("bubblePlot")),
                                     box(title = "Top Words",
                                         tableOutput("topwords"), width = 4, status = "danger"),
                                     box(title = "Latest Tweets",
                                         tableOutput("tbl"), width = 4, status = "warning")
                                   ),
                                   fluidRow(
                                     box(
                                       title = "Top Hashtags",
                                       tableOutput("hashtags"), width = 4, status = "info")
                                   )
                           )
                           ,
                           
                           
                           tabItem(tabName="competitors",
                                   fluidRow(
                                     box(
                                       leafletOutput("leaflet_map"), solidHeader = TRUE, width = 12
                                     ))
                           ),
                           
                           tabItem(tabName="clients",
                                   h2("PageTest"))
                         )
                         
                         
                         
                       )
)
)


# Run the application 
#shinyApp(ui = ui, server = server)

