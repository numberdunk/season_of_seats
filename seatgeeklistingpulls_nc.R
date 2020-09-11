library("bigrquery")
library(dplyr)
library(httr)
library(jsonlite)
options(stringsAsFactors = FALSE)

venueid = c(213174, 1621, 205377, 42680, 1681, 3361, 1643, 1683, 448550, 102, 7803, 1843, 601, 601, 13023, 1641, 102041427, 1823, 5263, 1282, 3873, 180760, 1281, 364, 3866, 444091, 4781, 5883, 1864, 527) ##YANKEE STADIUM, FENWAY, SAFECO
performerid = c(6769, 2744, 6770, 26089, 2863, 2987, 2747, 2864, 2862, 136, 3026, 3002, 966, 964, 6772, 2745, 6767, 2986, 3084, 2742, 335486, 6771, 2746, 541, 2562, 137, 3042, 7549, 3082, 2770) ##NYY,BOS,SEA
home_team = c('atlanta-hawks', 'boston-celtics', 'brooklyn-nets', 'charlotte-hornets', 'chicago-bulls', 'cleveland-cavaliers', 'dallas-mavericks', 'denver-nuggets', 'detroit-pistons', 'golden-state-warriors', 'houston-rockets', 'indiana-pacers', 'los-angeles-clippers', 'los-angeles-lakers', 'memphis-grizzlies', 'miami-heat', 'milwaukee-bucks', 'minnesota-timberwolves', 'new-orleans-pelicans', 'new-york-knicks', 'oklahoma-city-thunder', 'orlando-magic', 'philadelphia-76ers', 'phoenix-suns', 'portland-trail-blazers', 'sacramento-kings', 'san-antonio-spurs', 'toronto-raptors', 'utah-jazz', 'washington-wizards')

seatgeek_events <- data.frame(home_team = character(), datetime = character(), performerid = numeric(), listing_id = integer(), current_price = numeric(), row = numeric(), quantity = integer(), section_name = character(), seat_number = character(), teams = character(), date = character(), section_slot = numeric(), url = character())

for(x in 1:length(home_team)) {
  data <- list("NTA5Mzc2M3wxNTI5Nzk1MTIxLjEz", home_team[x],13665, 50,Sys.Date()+30)
  names(data) <- c("client_id","performers[home_team].slug","aid","per_page","datetime_utc.lte")
  inventory <- GET(url = "https://api.seatgeek.com",
                   path = "/2/events",
                   query = data,
                   encode = "json")
  inventory.s <- fromJSON(rawToChar(inventory$content))
  event_ids <- inventory.s$events$id
  teams <- inventory.s$events$title
  date <- inventory.s$events$datetime_local
  for(u in 1:length(event_ids)) {
      data <- fromJSON(paste("https://seatgeek.com/listings?id=",event_ids[u],"&aid=11955&client_id=MTY2MnwxMzgzMzIwMTU4",sep = ""))
      if(length(data$listings) < 1) {next}
    sg_listings <- data$listings
    myLetters <- c('AA', 'A2', 'A3', 'A4', 'BB', 'CC', 'DD','EE',toupper(letters[1:26]))
    sg_listings[is.na(as.numeric(sg_listings[, 'rr'])), 'rr'] <- match(sg_listings[is.na(as.numeric(sg_listings[, 'rr'])), 'rr'], myLetters)
    seatgeek_events_stage <- data.frame(listing_id = as.integer(event_ids[u]), 
                                      current_price = sg_listings$sgp+sg_listings$sgf,
                                      row = as.numeric(sg_listings$rr),
                                      quantity = sg_listings$q,
                                      section_name = sg_listings$sf,
                                      section_slot = as.numeric(sg_listings$sr)
                                      )
    seatgeek_events_stage$teams <- teams[u]
    seatgeek_events_stage$date <- date[u]
    seatgeek_events_stage$home_team <- home_team[x]
    seatgeek_events_stage$datetime <- as.Date(date[u])
    seatgeek_events_stage$performerid <- performerid[x]
    for(s in 1:length(seatgeek_events_stage$quantity)) {
    seatgeek_events_stage$seat_number[s] <- paste(seq(from = 1, to = seatgeek_events_stage$quantity[s]), collapse = ' ')
  }
    seatgeek_events_stage$url <- paste('https://seatgeek.com/event/click?tid='
                                       ,sg_listings$id
                                       ,'&eid='
                                       ,event_ids[u]
                                       ,'&section='
                                       ,sg_listings$sr
                                       ,'&row='
                                       ,sg_listings$rr
                                       ,'&is_quantity_specified=true&quantity='
                                       ,substring(gsub("[^0-9\\.]", "", sg_listings$sp),1,1)
                                       ,'&price='
                                       ,sg_listings$pf
                                       ,'&baseprice='
                                       ,sg_listings$p
                                       ,'&sgp='
                                       ,sg_listings$sgp
                                       ,'&dq='
                                       ,sg_listings$dq
                                       ,'&w='
                                       ,sg_listings$w
                                       ,'&market='
                                       ,sg_listings$m
                                       ,'&et='
                                       ,sg_listings$et
                                       ,'&mk=s%3A'
                                       ,sg_listings$sr
                                       ,'%20r%3A'
                                       ,sg_listings$rr
                                       ,'&gidx=-1&region=-1&sg=0&fbp=true&aid=13665',sep = '')
    seatgeek_events_stage <- seatgeek_events_stage[ , c(9,10,11,1:5,12,7,8,6,13)]
    seatgeek_events_stage <- seatgeek_events_stage[complete.cases(seatgeek_events_stage) , ]
    seatgeek_events <- rbind(seatgeek_events,seatgeek_events_stage)
    gc()
  }

}

object_upload <- seatgeek_events[seatgeek_events$datetime < Sys.Date()+30, ]

token = '{
##GCP CREDENTIALS
}

'
set_service_token(token)
insert_upload_job("electric-loader-208815", "ticket_api_pull_01", "full", object_upload, write_disposition = "WRITE_TRUNCATE")
