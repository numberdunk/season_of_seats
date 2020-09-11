library("bigrquery")
library(dplyr)
library(httr)
library(jsonlite)
options(stringsAsFactors = FALSE)
sql <- paste("SELECT * FROM",
             "`electric-loader-208815.ticket_api_pull_01.full`")
token = '{
##GCP CREDENTIALS HERE
}

'
set_service_token(token)
full_listings <- query_exec(sql, project = "electric-loader-208815", use_legacy_sql = FALSE, max_pages = Inf)
freq <- data.frame(table(full_listings$home_team))
filter <- data.frame(freq[freq$Freq > 99, 1])
colnames(filter) <- 'home_team'
full_listings <- merge(full_listings, filter, by = 'home_team')
teams <- unique(full_listings$home_team)

#FIND LOWEST PRICE TICKETS FOR EACH TEAM
lowest_price <- full_listings %>%
  group_by(home_team) %>%
  slice(which.min(current_price)) %>%
  as.data.frame(.)
lowest_price$type = 'Bronze'

#FIND BEST VALUE TICKETS FOR EACH TEAM
range01 <- function(x){(x-min(x))/(max(x)-min(x))}
temp <- full_listings %>%
  group_by(home_team, section_name) %>%
  slice(which.min(current_price)) %>%
  group_by(home_team, section_slot) %>%
  slice(which.min(row)) %>%
  as.data.frame(.)
temp <- temp[temp$row < 20, ]
temp[temp$section_slot > 100000, 'section_slot'] <- temp[temp$section_slot > 100000, 'section_slot']/1000
temp[temp$section_slot > 1000, 'section_slot'] <- temp[temp$section_slot > 1000, 'section_slot']/100
temp <- temp[temp$section_slot < 500, ]
temp$section_slot <- floor((temp$section_slot)/100)
temp <- temp[temp$section_slot < 4, ]
##VALUE = 100/(ROW+SECTION+PRICE)
temp$value <- unlist(apply(temp[ , c('row','section_slot','current_price')], 1, FUN = function(x) 100/(sum(x))))
best_value <- temp %>%
  group_by(home_team) %>%
  slice(which.max(value)) %>%
  as.data.frame(.)
best_value$type = 'Silver'
best_value$value <- NULL

#FIND TOP TRENDING TICKETS FOR EACH TEAM
avg_section_price <- aggregate(full_listings$current_price, list(Team = full_listings$teams, Section = full_listings$section_name), median)
temp <- merge(full_listings,avg_section_price, by.x = c('teams','section_name'), by.y = c('Team','Section'))
temp$trend_index <- temp$current_price/temp$x
top_trend <- temp %>%
  group_by(home_team) %>%
  slice(which.min(trend_index)) %>%
  as.data.frame(.)
top_trend$type = 'Gold'
top_trend$x <- NULL
top_trend$trend_index <- NULL

#COMBINE INTO FINAL FRAME
master <- rbind(lowest_price,best_value,top_trend)

#LOGO LINKS FOR EACH TEAM
logos <- data.frame('team' = c('atlanta-hawks', 'boston-celtics', 'brooklyn-nets', 'charlotte-hornets', 'chicago-bulls', 'cleveland-cavaliers', 'dallas-mavericks', 'denver-nuggets', 'detroit-pistons', 'golden-state-warriors', 'houston-rockets', 'indiana-pacers', 'los-angeles-clippers', 'los-angeles-lakers', 'memphis-grizzlies', 'miami-heat', 'milwaukee-bucks', 'minnesota-timberwolves', 'new-orleans-pelicans', 'new-york-knicks', 'oklahoma-city-thunder', 'orlando-magic', 'philadelphia-76ers', 'phoenix-suns', 'portland-trail-blazers', 'sacramento-kings', 'san-antonio-spurs', 'toronto-raptors', 'utah-jazz', 'washington-wizards'))
logos$logo_url <- c(
  'https://upload.wikimedia.org/wikipedia/en/thumb/2/24/Atlanta_Hawks_logo.svg/1200px-Atlanta_Hawks_logo.svg.png',
  'https://cdn.freebiesupply.com/images/large/2x/boston-celtics-logo-transparent.png',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/Brooklyn_Nets_newlogo.svg/2000px-Brooklyn_Nets_newlogo.svg.png',
  'https://upload.wikimedia.org/wikipedia/commons/4/47/Charlotte_hornets-wordmark.png',
  'https://seeklogo.com/images/C/chicago-bulls-logo-8530A1093D-seeklogo.com.png',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/0/04/Cleveland_Cavaliers_secondary_logo.svg/2000px-Cleveland_Cavaliers_secondary_logo.svg.png',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f3/Dallas_Mavericks_Primary_Logo.svg/2000px-Dallas_Mavericks_Primary_Logo.svg.png',
  'https://sportslogohistory.com/wp-content/uploads/2018/04/denver_nuggets_teensonacid.png',
  'https://upload.wikimedia.org/wikipedia/commons/6/6a/Detroit_Pistons_primary_logo_2017.png',
  'https://cdn.freebiesupply.com/images/thumbs/2x/golden-state-warriors-logo.png',
  'https://upload.wikimedia.org/wikipedia/sco/thumb/2/28/Houston_Rockets.svg/1280px-Houston_Rockets.svg.png',
  'https://upload.wikimedia.org/wikipedia/commons/9/97/Indiana_Pacers_logo.svg',
  'https://vignette.wikia.nocookie.net/nba2k/images/4/4c/Los_Angeles_Clippers_Logo.png/revision/latest?cb=20120119223412',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3c/Los_Angeles_Lakers_logo.svg/2000px-Los_Angeles_Lakers_logo.svg.png',
  'https://www.flagcenter.com/product_images/uploaded_images/grizzlies-logo.png',
  'https://vignette.wikia.nocookie.net/logopedia/images/b/b1/1200px-Miami_Heat_logo.svg.png/revision/latest?cb=20180713042802',
  'https://upload.wikimedia.org/wikipedia/en/thumb/4/4a/Milwaukee_Bucks_logo.svg/200px-Milwaukee_Bucks_logo.svg.png',
  'https://upload.wikimedia.org/wikipedia/en/thumb/c/c2/Minnesota_Timberwolves_logo.svg/1200px-Minnesota_Timberwolves_logo.svg.png',
  'https://cdn.bleacherreport.net/images/team_logos/328x328/new_orleans_pelicans.png',
  'https://images.vexels.com/media/users/3/131561/isolated/preview/b86cf87230adf7122067104d0c00d645-new-york-knicks-logo-by-vexels.png',
  'https://www.logolynx.com/images/logolynx/9a/9a5f262108a8dfd0bbb3bf2caf433fc6.png',
  'https://logosvector.net/wp-content/uploads/2012/12/orlando-magic-logo-vector.png',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/Philadelphia_76ers_Logo.svg/2000px-Philadelphia_76ers_Logo.svg.png',
  'https://vignette.wikia.nocookie.net/logopedia/images/7/72/1200px-Phoenix_Suns_logo.svg.png/revision/latest?cb=20180119030413',
  'https://upload.wikimedia.org/wikipedia/commons/b/bb/TrailBlazers.svg.png',
  'https://upload.wikimedia.org/wikipedia/en/thumb/c/c7/SacramentoKings.svg/1200px-SacramentoKings.svg.png',
  'https://upload.wikimedia.org/wikipedia/en/thumb/a/a2/San_Antonio_Spurs.svg/1200px-San_Antonio_Spurs.svg.png',
  'https://upload.wikimedia.org/wikipedia/en/thumb/3/36/Toronto_Raptors_logo.svg/1200px-Toronto_Raptors_logo.svg.png',
  'https://upload.wikimedia.org/wikipedia/en/thumb/0/04/Utah_Jazz_logo_%282016%29.svg/1200px-Utah_Jazz_logo_%282016%29.svg.png',
  'https://i0.wp.com/wnst.net/wordpress/wp-content/uploads/2015/11/Wizards.png'
)
master$away_team <- gsub(" ","-", tolower(sapply(strsplit(master$teams, " at"), "[[", 1)))
master <- merge(master,logos, by.x = 'away_team', by.y = 'team')

template <- data.frame(team = unique(master$home_team), html = 'NA')
for(i in 1:length(template$team)) {
template$html[i] <- paste('<!doctype html>
  <html xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
  
  <head>
  <title> Deals on NBA Tickets are here! </title>
<link rel="stylesheet" type="text/css" href="https://fonts.googleapis.com/css?family=Open+Sans">
<link rel="stylesheet" type="text/css" href="https://fonts.googleapis.com/css?family=Expletus+Sans">
  
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style type="text/css">
  #outlook a {
  padding: 0;
}

.ReadMsgBody {
  width: 100%;
}

.ExternalClass {
  width: 100%;
}

.ExternalClass * {
  line-height: 100%;
}

body {
  margin: 0;
  padding: 0;
  -webkit-text-size-adjust: 100%;
  -ms-text-size-adjust: 100%;
}

table,
td {
  border-collapse: collapse;
  mso-table-lspace: 0pt;
  mso-table-rspace: 0pt;
}

img {
  border: 0;
  height: auto;
  line-height: 100%;
  outline: none;
  text-decoration: none;
  -ms-interpolation-mode: bicubic;
}

p {
  display: block;
  margin: 13px 0;
}
</style>
  <!--[if !mso]><!-->
  <style type="text/css">
  @media only screen and (max-width:480px) {
    @-ms-viewport {
      width: 320px;
    }
    @viewport {
      width: 320px;
    }
  }
</style>
  <!--<![endif]-->
  <!--[if mso]>
  <xml>
  <o:OfficeDocumentSettings>
  <o:AllowPNG/>
  <o:PixelsPerInch>96</o:PixelsPerInch>
  </o:OfficeDocumentSettings>
  </xml>
  <![endif]-->
  <!--[if lte mso 11]>
  <style type="text/css">
  .outlook-group-fix { width:100% !important; }
</style>
  <![endif]-->
  <!--[if !mso]><!-->
  <link href="https://fonts.googleapis.com/css?family=Open+Sans" rel="stylesheet" type="text/css">
  <link href="https://fonts.googleapis.com/css?family=Expletus+Sans" rel="stylesheet" type="text/css">

  <!--<![endif]-->
  <style type="text/css">
  @media only screen and (min-width:736px) {
    .mj-column-per-100 {
      width: 100% !important;
      max-width: 100%;
    }
    .mj-column-per-33 {
      width: 33% !important;
      max-width: 33%;
    }
  }
</style>
  <style type="text/css">
  @media only screen and (max-width:736px) {
    table.full-width-mobile {
      width: 100% !important;
    }
    td.full-width-mobile {
      width: auto !important;
    }
  }
</style>
  </head>
  
  <body>
  <div style="display:none;font-size:1px;color:#ffffff;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;"> Looking to catch an upcoming game? Check out the latest deals on NBA tickets powered by Season of Seats... </div>
  <div style="">
  <!--[if mso | IE]>
  <table
align="center" border="0" cellpadding="0" cellspacing="0" class="" style="width:600px;" width="600"
>
  <tr>
  <td style="line-height:0px;font-size:0px;mso-line-height-rule:exactly;">
  <![endif]-->
  <div style="Margin:0px auto;max-width:600px;">
  <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="width:100%;">
  <tbody>
  <tr>
  <td style="direction:ltr;font-size:0px;padding:20px 0;text-align:center;vertical-align:top;">
  <!--[if mso | IE]>
  <table role="presentation" border="0" cellpadding="0" cellspacing="0">
  
  <tr>
  
  <td
class="" style="vertical-align:top;width:600px;"
>
  <![endif]-->
  <div class="mj-column-per-100 outlook-group-fix" style="font-size:13px;text-align:left;direction:ltr;display:inline-block;vertical-align:top;width:100%;">
  <table border="0" cellpadding="0" cellspacing="0" role="presentation" style="vertical-align:top;" width="100%">
  <tr>
  <td vertical-align="top" style="font-size:0px;padding:20px 0;word-break:break-word;">
  <!--[if mso | IE]>
  <table
align="center" border="0" cellpadding="0" cellspacing="0" class="" style="width:600px;" width="600"
>
  <tr>
  <td style="line-height:0px;font-size:0px;mso-line-height-rule:exactly;">
  <![endif]-->
  <div style="background:#f0f0f0;background-color:#f0f0f0;Margin:0px auto;max-width:600px;">
  <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="background:#f0f0f0;background-color:#f0f0f0;width:100%;">
  <tbody>
  <tr>
  <td style="direction:ltr;font-size:0px;padding:20px 0;text-align:center;vertical-align:top;">
  <!--[if mso | IE]>
  <table role="presentation" border="0" cellpadding="0" cellspacing="0">
  
  <tr>
  
  <td
class="" style="vertical-align:top;width:600px;"
>
  <![endif]-->
  <div class="mj-column-per-100 outlook-group-fix" style="font-size:13px;text-align:left;direction:ltr;display:inline-block;vertical-align:top;width:100%;">
  <table border="0" cellpadding="0" cellspacing="0" role="presentation" style="vertical-align:top;" width="100%">
  <tr>
  <td align="center" style="font-size:0px;padding:10px 25px;word-break:break-word;">
  <div style="font-family:Expletus Sans;font-size:24px;line-height:1;text-align:center;color:#000000;">
  <h1>TICKET ALERT</h1>
  </div>
  </td>
  </tr>
  <tr>
  <td align="center" style="font-size:0px;padding:10px 25px;word-break:break-word;">
  <div style="font-family:Open Sans;font-size:16px;line-height:1;text-align:center;color:#000000;"> Powered by Season of Seats </div>
  </td>
  </tr>
  </table>
  </div>
  <!--[if mso | IE]>
  </td>
  
  </tr>
  
  </table>
  <![endif]-->
  </td>
  </tr>
  </tbody>
  </table>
  </div>
  <!--[if mso | IE]>
  </td>
  </tr>
  </table>
  <![endif]-->
  </td>
  </tr>
  <tr>
  <td style="font-size:0px;padding:10px 25px;word-break:break-word;">
  <p style="border-top:solid 4px #f4c842;font-size:1;margin:0px auto;width:100%;"> </p>
  <!--[if mso | IE]>
  <table
align="center" border="0" cellpadding="0" cellspacing="0" style="border-top:solid 4px #f4c842;font-size:1;margin:0px auto;width:550px;" role="presentation" width="550px"
>
  <tr>
  <td style="height:0;line-height:0;">
  &nbsp;
</td>
  </tr>
  </table>
  <![endif]-->
  </td>
  </tr>
  <tr>
  <td align="left" style="font-size:0px;padding:10px 25px;word-break:break-word;">
  <div style="font-family:Open Sans;font-size:20px;line-height:1;text-align:left;color:#626262;"> Get excited! It\'s not too late to catch an upcoming game with these deals we found for you. Check out the selection below so you do not miss watching your favorite team live... </div>
  </td>
  </tr>
  </table>
  </div>
  <!--[if mso | IE]>
  </td>
  
  </tr>
  
  </table>
  <![endif]-->
  </td>
  </tr>
  </tbody>
  </table>
  </div>
  <!--[if mso | IE]>
  </td>
  </tr>
  </table>
  <![endif]-->
  <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="width:100%;">
  <tbody>
  <tr>
  <td>
  <!--[if mso | IE]>
  <table
align="center" border="0" cellpadding="0" cellspacing="0" class="" style="width:600px;" width="600"
>
  <tr>
  <td style="line-height:0px;font-size:0px;mso-line-height-rule:exactly;">
  <![endif]-->
  <div style="Margin:0px auto;max-width:600px;">
  <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="width:100%;">
  <tbody>
  <tr>
  <td style="direction:ltr;font-size:0px;padding:20px 0;text-align:center;vertical-align:top;">
  <!--[if mso | IE]>
  <table role="presentation" border="0" cellpadding="0" cellspacing="0">
  
  <tr>
  
  <td
class="" style="width:600px;"
>
  <![endif]-->
  <div class="mj-column-per-100 outlook-group-fix" style="font-size:0;line-height:0;text-align:left;display:inline-block;width:100%;direction:ltr;background-color:#f0f0f0;">
  <!--[if mso | IE]>
  <table  role="presentation" border="0" cellpadding="0" cellspacing="0">
  <tr>
  
  <td
style="align:center;width:600px;"
>
  <![endif]-->
  <div style="font-family:Expletus Sans;font-size:24px;line-height:1;text-align:center;color:#000000;">
  <p>VISITING TEAMS</p>
  </div>
 <div style="font-family:Expletus Sans;font-size:14px;line-height:1;text-align:center;color:#000000;">
  <p>Direct links to ticket checkout and review on SeatGeek</p>
</div>
  <!--[if mso | IE]>
  </td>
  
  <td
style="vertical-align:top;width:198px;"
>
  <![endif]-->
  <div class="mj-column-per-33 outlook-group-fix" style="font-size:13px;text-align:left;direction:ltr;display:inline-block;vertical-align:top;width:33%;">
  <table border="0" cellpadding="0" cellspacing="0" role="presentation" style="vertical-align:top;" width="100%">
  <tr>
  <td align="center" style="font-size:0px;padding:10px 30px;word-break:break-word;">
  <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:collapse;border-spacing:0px;">
  <tbody>
  <tr>
  <td style="width:138px;"> <img height="166" src="',master[master$type == 'Bronze' & master$home_team == template$team[i], 16],'" style="border:0;display:block;outline:none;text-decoration:none;height:166px;width:100%;"
width="138" /> </td>
  </tr>
  </tbody>
  </table>
  </td>
  </tr>
  <tr>
  <td align="center" style="font-size:0px;padding:10px 25px;word-break:break-word;">
  <div style="font-family:Open Sans;font-size:13px;line-height:1;text-align:center;color:#000000;">
  <h2>BRONZE</h2>
  <p>',master[master$type == 'Bronze' & master$home_team == template$team[i], 3],'</p>
  <p>',master[master$type == 'Bronze' & master$home_team == template$team[i], 9],'</p>
  <p>Row ',master[master$type == 'Bronze' & master$home_team == template$team[i], 7],'</p>
  <p>$',ceiling(master[master$type == 'Bronze' & master$home_team == template$team[i], 6]),'/Ticket</p>
  </div>
  </td>
  </tr>
  <tr>
  <td align="center" vertical-align="middle" style="font-size:0px;padding:10px 25px;word-break:break-word;">
  <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:separate;line-height:100%;">
  <tr>
  <td align="center" bgcolor="#f4c842" role="presentation" style="border:none;border-radius:3px;cursor:auto;padding:10px 25px;" valign="middle"> <a href="',master[master$type == 'Bronze' & master$home_team == template$team[i], 14],'" style="background:#f4c842;color:white;font-family:Open Sans;font-size:13px;font-weight:normal;line-height:120%;Margin:0;text-decoration:none;text-transform:none;"
target="_blank">
  Buy
</a> </td>
  </tr>
  </table>
  </td>
  </tr>
  </table>
  </div>
  <!--[if mso | IE]>
  </td>
  
  <td
style="vertical-align:top;width:198px;"
>
  <![endif]-->
  <div class="mj-column-per-33 outlook-group-fix" style="font-size:13px;text-align:left;direction:ltr;display:inline-block;vertical-align:top;width:33%;">
  <table border="0" cellpadding="0" cellspacing="0" role="presentation" style="vertical-align:top;" width="100%">
  <tr>
  <td align="center" style="font-size:0px;padding:10px 30px;word-break:break-word;">
  <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:collapse;border-spacing:0px;">
  <tbody>
  <tr>
  <td style="width:138px;"> <img height="165" src="',master[master$type == 'Silver' & master$home_team == template$team[i], 16],'" style="border:0;display:block;outline:none;text-decoration:none;height:165px;width:100%;" width="138" /> </td>
  </tr>
  </tbody>
  </table>
  </td>
  </tr>
  <tr>
  <td align="center" style="font-size:0px;padding:10px 25px;word-break:break-word;">
  <div style="font-family:Open Sans;font-size:13px;line-height:1;text-align:center;color:#000000;">
  <h2>SILVER</h2>
  <p>',master[master$type == 'Silver' & master$home_team == template$team[i], 3],'</p>
  <p>',master[master$type == 'Silver' & master$home_team == template$team[i], 9],'</p>
  <p>Row ',master[master$type == 'Silver' & master$home_team == template$team[i], 7],'</p>
<p>$',ceiling(master[master$type == 'Silver' & master$home_team == template$team[i], 6]),'/Ticket</p>
  </div>
  </td>
  </tr>
  <tr>
  <td align="center" vertical-align="middle" style="font-size:0px;padding:10px 25px;word-break:break-word;">
  <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:separate;line-height:100%;">
  <tr>
  <td align="center" bgcolor="#f4c842" role="presentation" style="border:none;border-radius:3px;cursor:auto;padding:10px 25px;" valign="middle"> <a href="',master[master$type == 'Silver' & master$home_team == template$team[i], 14],'" style="background:#f4c842;color:white;font-family:Open Sans;font-size:13px;font-weight:normal;line-height:120%;Margin:0;text-decoration:none;text-transform:none;"
target="_blank">
  Buy
</a> </td>
  </tr>
  </table>
  </td>
  </tr>
  </table>
  </div>
  <!--[if mso | IE]>
  </td>
  
  <td
style="vertical-align:top;width:198px;"
>
  <![endif]-->
  <div class="mj-column-per-33 outlook-group-fix" style="font-size:13px;text-align:left;direction:ltr;display:inline-block;vertical-align:top;width:33%;">
  <table border="0" cellpadding="0" cellspacing="0" role="presentation" style="vertical-align:top;" width="100%">
  <tr>
  <td align="center" style="font-size:0px;padding:10px 30px;word-break:break-word;">
  <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:collapse;border-spacing:0px;">
  <tbody>
  <tr>
  <td style="width:138px;"> <img height="166" src="',master[master$type == 'Gold' & master$home_team == template$team[i], 16],'" style="border:0;display:block;outline:none;text-decoration:none;height:166px;width:100%;" width="138" /> </td>
  </tr>
  </tbody>
  </table>
  </td>
  </tr>
  <tr>
  <td align="center" style="font-size:0px;padding:10px 25px;word-break:break-word;">
  <div style="font-family:Open Sans;font-size:13px;line-height:1;text-align:center;color:#000000;">
  <h2>GOLD</h2>
<p>',master[master$type == 'Gold' & master$home_team == template$team[i], 3],'</p>
  <p>',master[master$type == 'Gold' & master$home_team == template$team[i], 9],'</p>
  <p>Row ',master[master$type == 'Gold' & master$home_team == template$team[i], 7],'</p>
<p>$',ceiling(master[master$type == 'Gold' & master$home_team == template$team[i], 6]),'/Ticket</p>
  </div>
  </td>
  </tr>
  <tr>
  <td align="center" vertical-align="middle" style="font-size:0px;padding:10px 25px;word-break:break-word;">
  <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="border-collapse:separate;line-height:100%;">
  <tr>
  <td align="center" bgcolor="#f4c842" role="presentation" style="border:none;border-radius:3px;cursor:auto;padding:10px 25px;" valign="middle"> <a href="',master[master$type == 'Gold' & master$home_team == template$team[i], 14],'" style="background:#f4c842;color:white;font-family:Open Sans;font-size:13px;font-weight:normal;line-height:120%;Margin:0;text-decoration:none;text-transform:none;"
target="_blank">
  Buy
</a> </td>
  </tr>
  </table>
  </td>
  </tr>
  </table>
  </div>
  <!--[if mso | IE]>
  </td>
  
  </tr>
  </table>
  <![endif]-->
  </div>
  <!--[if mso | IE]>
  </td>
  
  </tr>
  
  </table>
  <![endif]-->
  </td>
  </tr>
  </tbody>
  </table>
  </div>
  <!--[if mso | IE]>
  </td>
  </tr>
  </table>
  <![endif]-->
  </td>
  </tr>
  </tbody>
  </table>
  <!--[if mso | IE]>
  <table
align="center" border="0" cellpadding="0" cellspacing="0" class="" style="width:600px;" width="600"
>
  <tr>
  <td style="line-height:0px;font-size:0px;mso-line-height-rule:exactly;">
  <![endif]-->
  <div style="Margin:0px auto;max-width:600px;">
  <table align="center" border="0" cellpadding="0" cellspacing="0" role="presentation" style="width:100%;">
  <tbody>
  <tr>
  <td style="direction:ltr;font-size:0px;padding:20px 0;text-align:center;vertical-align:top;">
  <!--[if mso | IE]>
  <table role="presentation" border="0" cellpadding="0" cellspacing="0">
  
  <tr>
  
  <td
class="" style="vertical-align:top;width:600px;"
>
  <![endif]-->
  <div class="mj-column-per-100 outlook-group-fix" style="font-size:13px;text-align:left;direction:ltr;display:inline-block;vertical-align:top;width:100%;">
  <table border="0" cellpadding="0" cellspacing="0" role="presentation" style="vertical-align:top;" width="100%">
  <tr>
  <td style="font-size:0px;padding:10px 25px;word-break:break-word;">
  <p style="border-top:solid 4px #f4c842;font-size:1;margin:0px auto;width:100%;"> </p>
  <!--[if mso | IE]>
  <table
align="center" border="0" cellpadding="0" cellspacing="0" style="border-top:solid 4px #f4c842;font-size:1;margin:0px auto;width:550px;" role="presentation" width="550px"
>
  <tr>
  <td style="height:0;line-height:0;">
  &nbsp;
</td>
  </tr>
  </table>
  <![endif]-->
  </td>
  </tr>
  <tr>
  <td align="left" style="font-size:0px;padding:10px 25px;word-break:break-word;">
  <div style="font-family:Open Sans;font-size:16px;line-height:1;text-align:left;color:#626262;"> Want to see even more deals? Check out our extended deals to see what we found for all upcoming home games: <a href="https://seasonofseats.com/skeleton/?team=',template$team[i],'">Click Here</a>.  Any feedback? <a href="mailto:superadmin@seasonofseats.com?Subject=Hello%20again" target="_top">Click here to contact us</a>.</div>
  </td>
  </tr>
  </table>
  </div>
  <!--[if mso | IE]>
  </td>
  
  </tr>
  
  </table>
  <![endif]-->
  </td>
  </tr>
  </tbody>
  </table>
  </div>
  <!--[if mso | IE]>
  </td>
  </tr>
  </table>
  <![endif]-->
  </div>
  </body>
  
  </html>', sep = "")}

folders <- GET(url = 'https://us3.api.mailchimp.com/3.0/template-folders', authenticate('prousseas', '###'), encode = "json")
folders <- fromJSON(rawToChar(folders$content))
temp_query <- list(folders$folders$id, 30)
names(temp_query) <- c('folder_id', 'count')
mc_templates <- GET(url = 'https://us3.api.mailchimp.com/3.0/templates', authenticate('prousseas', '###'), encode = "json", query = temp_query)
mc_templates <- fromJSON(rawToChar(mc_templates$content))$templates
mc_templates$team <- 'NA'
for(t in 1:length(mc_templates$name)) {
  mc_templates$team[t] <- strsplit(mc_templates$name, " ")[[t]][1]
}
mc_templates <- mc_templates[ , c('team', 'id')]
f_template <- merge(template,mc_templates, by = 'team')
Encoding(f_template$html) <- 'UTF-8'
for(h in 1:length(f_template$html)) {
  html_pass <- list(f_template$html[h])
  names(html_pass) <- 'html'
  patching <- PATCH(url = paste('https://us3.api.mailchimp.com/3.0/templates/',f_template$id[h], sep = ""),
      authenticate('prousseas', '###'),
      encode = "json",
      body = html_pass)
  if(patching$status_code == 200){print(paste('success', f_template$team[h]))}
  else {print(paste('failure', f_template$team[h]))}
}

list_id <- 'ca6a3c3e2e'
temp_query <- list(30)
names(temp_query) <- c('count')
segments <- GET(url = 'https://us3.api.mailchimp.com/3.0/lists/ca6a3c3e2e/segments', authenticate('prousseas', '###'), encode = "json", query = temp_query)
segments <- data.frame(id = fromJSON(rawToChar(segments$content))$segments$id,team = fromJSON(rawToChar(segments$content))$segments$name)
mc_segments <- merge(mc_templates, segments, by = 'team')
simpleCap <- function(x) {
  s <- strsplit(x, " ")[[1]]
  paste(toupper(substring(s, 1,1)), substring(s, 2),
        sep="", collapse=" ")
}
for(s in 1:length(mc_segments$team)) {
saved_segment_id <- mc_segments[s, 3]
segment_ops <- list(saved_segment_id)
names(segment_ops) <- 'saved_segment_id'
recipients <- list(list_id, segment_ops)
names(recipients) <- c('list_id', 'segment_opts')
settings <- list(paste('Your', simpleCap(gsub("-"," ",mc_segments$team[s], fixed = T)) ,'ticket deals are live: Catch them now!', sep = " "), 
                 paste(mc_segments[s,1],Sys.Date(),sep = "-"), 
                 'Season of Seats',
                 'alerts@seasonofseats.com',
                 mc_segments[s,2],
                 'Score seats at an upcoming game with these deals we found for you. Most fans will NEVER see these tickets...',
                 as.logical('True')
                 )
names(settings) <- c('subject_line','title','from_name','reply_to','template_id','preview_text', 'auto_footer')
type <- 'regular'
names(type) <- 'type'
campaign_body <- list(type,recipients,settings)
names(campaign_body) <- c('type','recipients','settings')
campaign <- POST(url = 'https://us3.api.mailchimp.com/3.0/campaigns',
                  authenticate('prousseas', '###'),
                  encode = "json",
                  body = campaign_body)
fromJSON(rawToChar(campaign$content))$id
POST(url = paste('https://us3.api.mailchimp.com/3.0/campaigns/',fromJSON(rawToChar(campaign$content))$id,'/actions/send',sep = ""), authenticate('prousseas', '6f85e07f0bd81401409930cb9e0432d8-us3'), encode = "json")
}
