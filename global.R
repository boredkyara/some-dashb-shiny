library(DBI)
library(RPostgreSQL)
library(shiny)
library(shinydashboard)
library(plyr)
library(dplyr)
library(RPostgreSQL)
library(stringr)
library(RColorBrewer)
library(tm)
library(ggplot2)
library(plotly)
library(wordcloud)
library(shinycssloaders)
library(DT)
library(igraph)
library(networkD3)

#############################################################
## database connection
#############################################################
## Best we can do to hide the password
pw <- {
  "sam2017."
}

## Connect to an existing postgresql database
localdb <- src_postgres(dbname = "ATOS_TechLab",
                        host = "localhost", port = 5432,
                        user = "postgres", password = pw, options="-c search_path=twitter_db")


## Connect to table within that database + collect the data
data_at_start_all <- tbl(localdb,"tweets_all") %>% collect()

##############################################################
## functions (these should be moved to a source file later)
##############################################################
toSpace = content_transformer( function(x, pattern) {gsub(pattern," ",x)} )

##color palette
cols <- c("#ce472e", "#f05336", "#ffd73e", "#eec73a", "#4ab04a")

create_word_cloud <-function (text){
  text  <- gsub('\\p{So}|\\p{Cn}|[^[:alnum:][:space:]]', "", text, perl = TRUE)
  
  myCorpus = Corpus(VectorSource(text))
  
  myCorpus = tm_map(myCorpus, content_transformer(tolower))
  myCorpus = tm_map(myCorpus, content_transformer(removePunctuation))
  myCorpus = tm_map(myCorpus, content_transformer(removeNumbers))
  myCorpus = tm_map(myCorpus, content_transformer(removeWords), 
                    stopwords("english"))
  myCorpus = tm_map( myCorpus, toSpace, "https*")
  myDTM = TermDocumentMatrix(myCorpus, control = list(minWordLength = 1))
  m <- as.matrix(myDTM)
  m
  
}
wordcloud_rep <- repeatable(wordcloud, seed=1234)

impressionsPerTweet <- function(id, clean_tweets){
  x <- clean_tweets$follower_count[!is.na(clean_tweets$rt_id)&clean_tweets$rt_id==id]
  x <- x[!is.na(x)]
  s <- sum(x)
  
  if(length(s)==0)
  {
    s <- 0
  }
  
  p <- clean_tweets$follower_count[clean_tweets$id_str==id]
  if(!length(p)==0)
  {
    q <- as.integer(s) + as.integer(p)
  }else
  {
    q <- as.integer(s) + 0
  }
  q
}

impressionsPerUser <- function(user_ids, clean_tweets){
  result <- data.frame(matrix(ncol=4,nrow=0))
  names(result) <- c("user_id","user_name", "screen_name", "impressions_total")
  for(i in 1:length(user_ids))
  {
    
    user_id <- user_ids[i]
    user_name <- unique(clean_tweets$name[user_id==clean_tweets$user_id_str])
    screen_name <- unique(clean_tweets$screen_name[user_id==clean_tweets$user_id_str])
    tweet_ids <- clean_tweets$id_str[user_id==clean_tweets$user_id_str]
    impressions_total <- 0
    if(!length(user_name)==0)
    {
      for(tweet_id in tweet_ids)
      {
        impressions_total <- impressions_total + impressionsPerTweet(tweet_id, clean_tweets) 
      }
      
      tweet_result <- data.frame(user_id = user_id, user_name = user_name, screen_name = screen_name, impressions_total = impressions_total, stringsAsFactors = FALSE)
      
      result <- rbind.data.frame(result, tweet_result)
      #print(paste0(i,"__",user_id)) 
    }
  }
  result <- unique(result)
  return(result)
}

## create a static graph from the tweeters table  
## Returns  : a graph Orignial tweeter -> retweeter 
##            and creates a file containg the graph
make_graph_normal <- function(tweeters){
  mat <- matrix(0, length(tweeters$rt_user_id), length(tweeters$user_id_str),
                dimnames = list(tweeters$rt_user_id, tweeters$user_id_str))
  
  for(i in 1:NROW(tweeters)){
    mat[toString(tweeters[i,1]),
        toString(tweeters[i,2])] <- tweeters[i,3]
  }
  
  graph <-  graph.adjacency(mat, mode="directed", weighted=TRUE)
  # assign edge's width as a function of weights.
  E(graph)$width <- E(graph)$weight + min(E(graph)$weight) + 36 # offset=6
  graph
  
}

make_interactive_graph <- function(tweeters, node_info, graph, influencers_fow, sc_members){
  
  ## computing clusters based on the connectivity degree
  walkc <- cluster_walktrap(graph)
  members <- membership(walkc)
  groups <- as.list(members)
  
  ## creating the nodes df and init its values (with 0)
  nodes <- data.frame(matrix(0, ncol=5,nrow=nrow(node_info)))
  colnames(nodes) <- c("node_id", "user_id", "user_name", "impressions", "group")
  nodes <- data.frame(0:(nrow(node_info)-1), node_info, rep(0,nrow(nodes)))
  colnames(nodes) <- c("node_id", "user_id", "user_name", "screen_name", "impressions", "group")
  
  ## computing the size of the vertices (depends on impressions)
  max_impr <- max(as.integer(node_info$impressions_total))*100
  nodes[,"impressions"] <- ((nodes[,"impressions"]/max_impr)*nodes[,"impressions"]) + 3
  
  for(i in 1: nrow(nodes)){
    user_id <- nodes[i,"user_id"]
    user_name <- nodes[i, "screen_name"]
    if(grepl('$atos|ATOS|Atos',user_name)){
      nodes$group[user_name==nodes$screen_name]<-"ATOS"
    }else if (toString(user_name) %in% influencers_fow){
      nodes$group[user_name==nodes$screen_name]<- "Influencers Of Work"
    }else if(toString(user_name) %in% sc_members){
      nodes$group[user_name==nodes$screen_name]<-"Atos Scientific Community"
    }else
    {
      nodes$group[user_name==nodes$screen_name] <- "Other"
    }
    
  }
  

  ## creating the links df
  links <- data.frame((matrix(0, ncol=3, nrow=nrow(tweeters))))
  colnames(links) <- c("Source", "Target", "Weight")
  
  links$Source        <- nodes[match(tweeters$rt_user_id,nodes$user_id),1]
  links$Target        <- nodes[match(tweeters$user_id_str,nodes$user_id),1]
  links$weight        <- (tweeters$rt_count/ max(tweeters$rt_count))*tweeters$rt_count
  
  return_output <- list(links, nodes)
  return_output
  
}

## Computes the tweeters table, nodes_infos, a static graph and an interactive graph
## Returns  : dataframe of user names and reaches
## Used     : a data frame containg the table of links between users 'links'
##            and a table containg the informations of all the vertexs
plotting_graph <- function(clean_tweets, influencers_fow, sc_members){
  
  ##creating tweeter rter relations
  df <- clean_tweets[!is.na(clean_tweets$rt_user_id),c("rt_user_id", "user_id_str")]
  df_unique <- unique(df)
  
  ##creating the nodes_info dataframe
  all_user_ids <- c()
  all_user_ids <- append(all_user_ids,df_unique$user_id_str)
  all_user_ids <- append(all_user_ids,df_unique$rt_user_id)
  all_user_ids <- unique(all_user_ids)
  
  node_info <- impressionsPerUser(all_user_ids, clean_tweets)
  all_user_ids <- node_info$user_id
  
  tweeters <- data.frame(matrix(0, ncol=3,nrow=0))
  colnames(tweeters) <- c("rt_user_id", "user_id_str", "rt_count")
  
  for(i in 1:nrow(df_unique)){
    rt_count <- length(df$rt_user_id[df$user_id_str==df_unique$user_id_str[i]
                                     & df$rt_user_id==df_unique$rt_user_id[i]])
    
    
    values <- data.frame(rt_user_id = df_unique$rt_user_id[i],
                         user_id_str = df_unique$user_id_str[i],
                         rt_count = rt_count)
    
    tweeters <- rbind.data.frame(tweeters, values)
    
  }
  
  graph <- make_graph_normal(tweeters)
  iag <- make_interactive_graph(tweeters,node_info, graph, influencers_fow, sc_members)
  iag
}


##################################################################
## functions for reactive poll
##################################################################
testFunction_all <- function(){
    query <- "SELECT MAX(created_at) FROM tweets_all"
    df <- tbl(localdb, sql(query)) %>% collect(n=Inf)
    df$max
}

readData_all <- function(){
    query <- "SELECT * FROM tweets_all"
    temp <- tbl(localdb, sql(query)) %>% collect(n=Inf)
    temp
}

read_fow <- function(){
  query <- "SELECT twitter FROM fow_ids"
  temp <- tbl(localdb, sql(query)) %>% collect(n=Inf)
  temp$twitter
}

test_fow <- function(){
  query <- "SELECT MAX(twitter) FROM fow_ids"
  df <- tbl(localdb, sql(query)) %>% collect(n=Inf)
  df$max
}

read_sc <- function(){
  query <- "SELECT twitter FROM sc_ids"
  temp <- tbl(localdb, sql(query)) %>% collect(n=Inf)
  temp$twitter
}

test_sc <- function(){
  query <- "SELECT MAX(twitter) FROM sc_ids"
  df <- tbl(localdb, sql(query)) %>% collect(n=Inf)
  df$max
}

#################################################################
## Compute summary KPIs of tweets data set
#################################################################
tweetCount <- function(allData){
  reactive({
    df <- allData()
    nr <- nrow(df)
    nr
  })
}

nrContr <- function(allData){
  reactive({
    clean_tweets <- allData()
    contributors <- clean_tweets$screen_name[clean_tweets$original==TRUE]
    nr <- nrow(table(contributors))
    nr
  })
}

#lastTweets <- function(allData){
#  reactive({
#    filtered <- allData()
#    content <- paste0("<body bgcolor=\"#ce472e\"><img src = ",filtered$image," align=\"left\"> <p align=\"right\"> <b> &emsp;", 
#                      filtered$screen_name,":</b>",filtered$text, "</p> </body>")
#    last <- tail(content, n=5)
#    last
#  })
#}

lastTweets_DT <- function(allData){
  reactive({
    clean_tweets <- tail(allData(), n=5)
    df <- data.frame(image = clean_tweets$image, screen_name = clean_tweets$screen_name, text = clean_tweets$text, sentiment = clean_tweets$sentiment)
    datatable(df, options = list())
  })
}

rawData <- function(allData){
  reactive({
    df <- allData()
    datatable(df, width = "100")
  })
}

impressions <- function(allData){
  reactive({
    df <- allData()
    all_ids <- df$id_str
    total_impressions <- 0
    for(i in 1:length(all_ids))
    {
      id <- all_ids[i]
      tweet_impressions <- impressionsPerTweet(id, df)
      total_impressions <- total_impressions + tweet_impressions
    }
    total_impressions
  })
}

pie_plot <- function(allData){
  reactive({
    clean_tweets <- allData()
    original <- length(clean_tweets$original[clean_tweets$original==TRUE])
    retweet <- length(clean_tweets$original[clean_tweets$original==FALSE])
    df <- data.frame(type = c("Original Tweets", "Retweeted Tweets"), total = c(original, retweet))
    p <- plot_ly(df, labels = ~df$type, values = ~df$total, type = 'pie' , height = "200") %>%
      layout(xaxis = list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE),
             yaxis = list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE))
    p
  })
}

topHashtags <- function(allData){
  reactive({
    df <- allData()$text
    trends <- str_extract_all(df, "#[[:alpha:]]+")
    myCorpus <- Corpus(VectorSource(trends))
    tdm <- TermDocumentMatrix(myCorpus, control = list(minWordLength = 5))
    m <- as.matrix(tdm)
    v <- sort(rowSums(m), decreasing = TRUE)
    hashtag <- matrix(nrow=6,ncol=2)
    for(i in 1:length(names(head(v,6))))
    {
      hashtag[i,1] <- paste0("#",toupper(names(head(v,6))[i]))
      hashtag[i,2] <- paste0(head(v,6)[[i]], " total tweets")
    }
    hashtag
  })
}

cloudofwords <- function(allData){
  reactive({
    df <- allData()$text
    m <- create_word_cloud(df)
    v = sort(rowSums(m), decreasing = TRUE)
    wordz = names(v)
    cloud <- wordcloud(names(v),v, scale=c(5,1), min.freq=110, random.order=FALSE,random.color=TRUE, rot.per=0, colors=brewer.pal(6,"Dark2"))
    cloud
  })
}

topContr <- function(allData){
  reactive({
    clean_tweets <- allData()
    screen_names <- names(head(sort(table(clean_tweets$screen_name[clean_tweets$original==TRUE]), decreasing = TRUE), n=5))
    images <- names(head(sort(table(clean_tweets$image[clean_tweets$original==TRUE]), decreasing = TRUE), n=5))
    followers <- names(head(sort(table(clean_tweets$follower_count[clean_tweets$original==TRUE]), decreasing = TRUE), n=5))
    names <- names(head(sort(table(clean_tweets$name[clean_tweets$original==TRUE]), decreasing = TRUE), n=5))
    df <- data.frame(image = images, screen_names = screen_names, followers = followers, names = names)
    content <- paste0("<img src = ",df$image," align=\"left\"> <p align=\"right\"> <b>@", 
                      df$screen_names,"<br /> </b>",df$names,"<br /> ",df$followers," followers.</p>")
    content
  })
}

sentiment_plot <- function(allData){
  reactive({
    clean_tweets <- allData()
    clean_tweets_sample <- tail(clean_tweets, n=50)
    sent <- ggplot(clean_tweets_sample, aes(x = created_at, y = sentiment, colour = sentiment, text = paste0("@",screen_name,": ", text)))  + geom_point(aes(x = created_at, y = sentiment, colour = sentiment), alpha = 0.8) + geom_line(aes(x = created_at, y = sentiment, colour = sentiment), alpha = 0.8) + theme_minimal() + scale_color_gradientn(colors = cols) + geom_smooth(size = 1.2, alpha = 0.2, method = "gam")
    sent
  })
}

network <- function(allData, influencers_fow, sc_members){
  reactive({
    clean_tweets <- allData()
    fow <- influencers_fow()
    sc <- sc_members()
    cleaner_tweets <- clean_tweets[which(!grepl('scarletmonahan',clean_tweets$screen_name)),]
    cleaner_tweets <- cleaner_tweets[which(!grepl('scarletmonahan',cleaner_tweets$text)),]
    cleaner_tweets <- cleaner_tweets[which(!grepl('pandoraskids',cleaner_tweets$screen_name)),]
    cleaner_tweets <- cleaner_tweets[which(!grepl('pandoraskids',cleaner_tweets$text)),]
    
    output_graph <-plotting_graph(cleaner_tweets, fow, sc)
    
    links <- na.omit(output_graph[[1]])
    nodes <- na.omit(output_graph[[2]])
    
    nodes$log_impressions <- log(nodes$impressions)
    
    g <- forceNetwork(Links = links, Nodes = nodes, Source = "Source",
                      Target = "Target", Value = "weight", NodeID = "user_name",
                      Nodesize = "impressions", Group = "group", opacity = 0.9,
                      #linkDistance =biggest_radius+100,
                      linkWidth = JS("function(d) { return Math.sqrt(d.value)+1; }"),
                      colourScale = JS("d3.scaleOrdinal()\n.domain([\"ATOS\", \"Influencers Of Work\",\"ATOS Scientific Community\",\"Other\"])\n.range([\"#8DD3C7\", \"#FFFFB3\",\"##BEBADA\",\"#FB8072\"]);"),
                      #charge= -(biggest_radius),
                      arrows=TRUE,
                      fontFamily = "Arial Black",
                      fontSize = 30,
                      zoom = TRUE,
                      #bounded = TRUE,
                      legend =TRUE, width = 1200, height = 400)
    
    g
  })
}










