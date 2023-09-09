library(sf)
library(magick)
library(rprojroot)
library(tidyverse)

root <- find_rstudio_root_file()

# "borrow" the files from SmokyMountains.com, but be nice and cache them to
# avoid hitting their web server for every iteration

c("https://s3.amazonaws.com/smc0m-tech-stor/static/js/us.min.json",
  "https://cdn.smokymountains.com/static/maps/rendered2023.csv") |>
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
  file.path(root, "data", "rendered2023.csv"),
  # na = "#N/A",
  # col_types = cols(.default=col_double(), id=col_character())
) -> foliage

foliage$id <- as.character(foliage$id)
colnames(foliage) <- c("id", sprintf("rate%d", 1:13))

# and, since we have a lovely sf tidy data frame, bind it together
counties_sf |>
  left_join(foliage, "id") |>
  filter(!is.na(rate1)) -> foliage_sf

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
        seq(
          from = as.Date("2023-09-04"),
          to = as.Date("2023-11-20"),
          by = "1 week"
        ),
        "%b %d"
      )
    )
  ) -> foliage_sf

foliage_sf |>
  select(id, week , value) |>
  as.data.frame() |>
  select(-geometry) |>
  mutate(
    id = sprintf("%05d", as.integer(id))
  ) -> save_df

save_df |>
  filter(id == "46007") |>
  mutate(id = "46102") |>
  bind_rows(save_df) |>
  mutate(
    value = value |>
      factor(
        levels = c("0.01", "0.1", "0.2", "0.3", "0.4", "0.5", "0.6"),
        labels = c("No Change", "Minimal", "Patchy", "Partial", "Near Peak", "Peak", "Past Peak")
      )
  ) |>
  jsonlite::toJSON() |>
  writeLines(
    file.path(root, "foliage-2023.json")
  )

# now we make a ggplot object for each week and save it out to a png
image_graph(
  width = 1500,
  height = 900,
  res = 300
) -> frames

# make a ggplot object for each week and print the graphic
foliage_sf |>
  pull(week) |>
  levels() |>
  unique() |>
  walk(
    \(.x) {

      foliage_sf |>
        dplyr::filter(
          as.character(week) == .x
        ) -> xdf

      ggplot() +
        geom_sf(
          data = xdf,
          aes(fill = value),
          linewidth = 0.125,
          color = "#2b2b2b"
        ) +
        geom_sf(
          data = states_sf,
          color = "white",
          linewidth = 0.125,
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

    },
    .progress = TRUE
  )

# animate the foliage
suppressWarnings(
  invisible(
    file.remove(
      file.path(root, "foliage.gif")
    )
  )
)

frames |>
  image_animate(1) |>
  image_write(
    file.path(root, "foliage.gif")
  )
