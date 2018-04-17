
library(shiny)
library(shinydashboard)

options(spinner.type=8)

# Define UI for application
ui <- shinyUI(
  dashboardPage(title = "atos | twitter dashboard",
                dashboardHeader(title = span(tagList("tweet", icon("comments")))),
                dashboardSidebar(
                  sidebarSearchForm(label = "Filter Tweets...", "filter_text", "filter_button", icon = shiny::icon("search")),
                  sidebarMenu(
                    menuItem("Home", tabName = "home", icon = icon("home"))
                    ,menuItem("Network", tabName = "network", icon = icon("globe")),
                    menuItem("Clients", tabName = "clients", icon = icon("users")),
                    menuItem("Data", tabName = "data", icon = icon("database"))
                  ),
                  width = 200
                  
                ),
                
                dashboardBody(
                  tabItems(
                    tabItem(tabName ="home",
                            fluidPage(
                              fluidRow(
                              valueBoxOutput("nrTweets", 4),
                              valueBoxOutput("nrContributors", 4),
                              valueBoxOutput("nrImpressions", 4)),
                              fluidRow(
                                
                                box(title = "Latest Tweets",
                                withSpinner(dataTableOutput("tbl_DT")), width = 6, solidHeader = TRUE),
                                #box(title = "Latest Tweets",
                                #    withSpinner(htmlOutput("tbl")), width = 6, solidHeader = TRUE),
                                box(
                                  title = "Top Hashtags",
                                  withSpinner(tableOutput("hashtags")), width = 3, solidHeader = TRUE),
                                #box(title = "Percentage Original/Retweeted", withSpinner(plotlyOutput("plot")),height = "300px", width = 3, status = "primary", solidHeader = TRUE),
                                box(title = "Top Contributors",
                                    withSpinner(htmlOutput("contr")), width = 3, solidHeader = TRUE)
                                
                                
                              ),
                              box(title = "Wordcloud", withSpinner(plotOutput("wc")), width = 5, solidHeader = TRUE),
                              box(title = "Sentiment Scores", withSpinner(plotlyOutput("sent_plot")),height = "400px", width = 6, solidHeader = TRUE)
                              
                              
                              
                            )
                            
                    ),
                    tabItem(tabName="data",
                            fluidPage(
                              DT::dataTableOutput("rawdata")
                            )),
                    tabItem(tabName="network",
                            fluidPage(
                              fluidRow(box(withSpinner(forceNetworkOutput("network_plot")), height=6,width=12,solidHeader=TRUE)),
                              fluidRow(box(title="Legend", textOutput("legend"), width=4,solidHeader=TRUE))
                            ))
                  )
                  
                  
                )
                
                
                
  )
  
)


