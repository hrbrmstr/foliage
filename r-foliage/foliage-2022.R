library(rprojroot)
library(sf)
library(magick)
library(tidyverse)

root <- find_rstudio_root_file()

# "borrow" the files from SmokyMountains.com, but be nice and cache them to
# avoid hitting their web server for every iteration

c("https://s3.amazonaws.com/smc0m-tech-stor/static/js/us.min.json",
  "https://smokymountains.com/wp-content/themes/smcom-2017/js/foliage2.tsv",
  "https://cdn.smokymountains.com/static/maps/rendered2022.csv") |> 
  walk(~{
    sav_tmp <- file.path(root, "data", basename(.x))
    if (!file.exists(sav_tmp)) download.file(.x, sav_tmp)
  })

# next, we read in the GeoJSON file twice. first, to get the counties
states_sf <- read_sf(file.path(root, "data", "us.min.json"), "states", stringsAsFactors = FALSE)

# we only want the continental US
states_sf <- filter(states_sf, !(id %in% c("2", "15", "72", "78")))

# it doesn't have a CRS so we give it one
st_crs(states_sf) <- 4326

# I ran into hiccups using coord_sf() to do this, so we convert it to Albers here
states_sf <- st_transform(states_sf, 5070)

# next we read in the states
counties_sf <- read_sf(file.path(root, "data", "us.min.json"), "counties", stringsAsFactors = FALSE)
st_crs(counties_sf) <- 4326
counties_sf <- st_transform(counties_sf, 5070)

# now, we read in the foliage data
read.csv(
  file.path(root, "data", "rendered2022.csv"),
  # na = "#N/A",
  # col_types = cols(.default=col_double(), id=col_character())
) -> foliage

foliage$id <- as.character(foliage$id)
colnames(foliage) <- c("id", sprintf("rate%d", 1:13))

# and, since we have a lovely sf tidy data frame, bind it together
counties_sf |> 
  left_join(foliage, "id") |> 
  filter(!is.na(rate1)) -> foliage_sf

  foliage_sf

# now, we do some munging so we have better labels and so we can
# iterate over the weeks
foliage_sf |> 
gather(
  week, 
  value, 
  -id, 
  -geometry
) |> 
  mutate(
    value = factor(value)
  ) |> 
  filter(
    week != "rate1"
  ) |> 
  mutate(
    week = factor(
      week,
      levels = unique(week),
      labels = format(
        seq(as.Date("2021-08-30"), as.Date("2021-11-15"), "1 week"),
        "%b %d"
      )
    )
  ) -> foliage_sf

# now we make a ggplot object for each week and save it out to a png
image_graph(
  width = 1500, 
  height = 900, 
  res = 300
) -> frames

# make a ggplot object for each week and print the graphic
pb <- progress_estimated(nlevels(foliage_sf$week))
walk(1:nlevels(foliage_sf$week), ~{

  pb$tick()$print()

  foliage_sf |>
  filter(
    week == levels(week)[.x]
  ) -> xdf

  ggplot() +
    geom_sf(
      data = xdf, 
      aes(fill = value), 
      size = 0.05, 
      color = "#2b2b2b"
    ) +
    geom_sf(
      data = states_sf, 
      color = "white", 
      size = 0.25, 
      fill = NA
    ) +
    viridis::scale_fill_viridis(
      name = NULL,
      option = "magma",
      direction = -1,
      discrete = TRUE,
      labels = c("No Change", "Minimal", "Patchy", "Partial", "Near Peak", "Peak", "Past Peak"),
      drop = FALSE
    ) +
    labs(
      title = sprintf("Foliage: %s ", unique(xdf$week))
    ) +
    ggthemes::theme_map() +
    theme(
      panel.grid = element_line(color = "#00000000"),
      panel.grid.major = element_line(color = "#00000000"),
      legend.position = "right"
    ) -> gg

  print(gg)

})

# animate the foliage
frames |> 
  image_animate(1) |> 
  image_write("foliage.gif")
