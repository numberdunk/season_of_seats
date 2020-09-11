# season_of_seats
Code to pull tickets, find great deals, and automate email alerts for NBA games
![Data Diagram](https://github.com/numberdunk/season_of_seats/blob/master/Season%20of%20Seats%20Dataflow.png?raw=true)

## Overview
The code in this repository powered an automated email system where interested sports fans could sign up for alerts on daily ticket deals for their favorite team.  Oiriginally my idea came about when I had season tickets for the New York Knicks one year and found it really annoying to bring a few friends to the game.  I already knew the location of my seats, but I had to manually search for either seats nearest to me, or cheap ones in at least the same section.

After building a first prototype geared to other season ticket holders I realized the real problem was most ticket marketplaces either have limited search capabilities, or they force a proprietary scoring system on the fans.  All of them required a lot of manual research on the part of fans, and personally I found the process of buying tickets during the season almost like a second job.  It required a lot of patience and monitoring how prices changed as teams improved or declined.

So I resolved to create a system that removed as much of the hassle as possible AND give fans a choice of how "curated" they wanted their ticket deals to be.

## Infrastructure
I used three main services to fully automate this pipeline:
* GCP BigQuery to store all of the data when it was pulled daily
* Digital Ocean to spin up a droplet to automate the R scripts instead of running them locally.  I also used the same droplet to host a basic HTML site
* Mailchimp to maintain the email lists and send out daily alerts

I also set up a facebook page to spend a little on ads and give more legitimacy to the project in order to get actual users (even though the service was free)

## Pulling the Data
Most ticket marketplaces do not provide APIs which would make this a seamless process.  Stubhub had an API, but deprecated it a while ago, and Ticketmaster doesn't surface an endpoint to individual ticket listings.  Through some research I was able to use the Seatgeek API to pull individual listings and then hack together their checkout URL to make it seamless for fans to click a button in the email alert and be brought straight to the checkout page.

The majority of work here was upfront gathering all the specific venue and performer IDs in Seatgeek for each team and their corresponding arena.  Once I had that together, I used the `HTTR` and `JSONLITE` packages in R to call each endpoint and build a dataframe of all listings for all teams in the next 30 days.  I didn't want to pull data that was too far in advance as ticket inventory can change a ton when tipoff gets closer.  Plus, most fans looking to take the time and effort out of buying tickets are not the types of people who plan that far in advance.

After pulling the data I wrote the new dataframe to a table in BigQuery called ticket_api_pull_01.  I ran this job early each morning with the idea that I wanted to send alerts at the start of everyone's day, around 7:00AM local time when they were sitting to eat breakfast or commuting into work, so they had a chance to get these tickets before everyone who searched on their lunchbreaks.

## Finding the Deals
I came up with three deal calculations and tiers to reflect them.  In some cases I noticed that one team might not have any listings which met the cutoff for "best value", but I always wanted to send out three deals in each email per team.  So I created a "bronze", "silver", and "gold" tier system to indicate in the email alert to indicate how each deal ranked.

### Bronze
These are the current lowest price tickets per team.  For a fan to find these deals on their own they would have to click through each upcoming game, sort by price, and make note of the top listing.  Doing this automatically probably saves someone ten minutes of their time, and the seats are not always the best.  So I gave these the lowest rating.

### Silver
I identified these tickets by the formula `VALUE = 100 / (ROW+SECTION+PRICE)`.  Before doing the straight calculation I first cleaned up the sections as some teams use much higher magnitudes for their section numbers.  For example, the Knicks have sections 101-120 in the lower bowl, but the Rockets might have 1000-10000.  After normalizing the sections and rows I calculated the value for each listing.  The closer to 1 the better the value as price was usually above $100 for two or more tickets.  In theory it meant you had a low row and section to offset a higher price, or maybe the row and section were middle of the road but had a great price tag.

### Gold
These tickets offered the best deals, in my opinion, and the method was arguably the most robust.  I calculated the median ticket price for each section by team out of all their upcoming listings.  Then I divided each ticket in a section by that median to create an index.  Anything below 1 was considered priced below average, and I flagged one listing per team with the lowest overall index.  These still had the potential to be expensive--on one ocassion it flagged courtside seats to a NYK v DAL game, but they were 38% lower than all other courtside seats.

## Sending the Emails
I designed the sign up process to include a form which asked for the fan's hometeam.  This put them onto a list specifically for that team in Mailchimp so I could better manage the templates of the daily alerts, and understand which fans were more interested in this idea.

The first step in the process was to generate a new template for the day's email including the calculated deals from above.  I used templates because it meant I could push everything through Mailchimp's API and maintain a nice HTML design with the flexibility of piping in data directly from my deals dataframe.

After generating the templates I posted them through the API to overwrite the one's from the previous day, and then sent another post request to send the campaign.  I would subsequently spend the next hour monitoring who would open the email and then click through to the deals.

## Iterations
I did not come up with this final flow right off the bat.  A lot of things changed as I observed fan behaviors and shed my initial hypothesis about who would want this sort of functionality.  It was really interesting to see what people found helpful and adapting on the fly to incorporate their feedback.  After two weeks of sending emails to at least 100 subscribers I sent out a survey via Surveymonkey to better understand how to develop the platform further.  Most people just wanted to see all the deals and do advanced searches.  So I included a link at the bottom of each email to "See more deals!" which brought fans to Javascript table, pre-populated to their team based on a URL parameter I embeded, and let them see seven additional deals.
