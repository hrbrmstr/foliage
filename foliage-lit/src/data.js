import { json } from 'd3-fetch'
import * as topojson from 'topojson'

export const foliageData = await json('foliage-2023.json');

export const weeks = [ ... new Set(foliageData.map(d => d.week)) ]

export const us = await json('counties-10m.json');

export const counties = topojson.feature(us, us.objects.counties);
export const states = topojson.feature(us, us.objects.states);

export const counties48 = {
  type: "FeatureCollection",
  features: counties.features.filter(
    (d) => ![ "15", "02" ].includes(d.id.substring(0, 2))
  )
}

export const states48 = ({
  type: "FeatureCollection",
  features: states.features.filter((d) => ![ "15", "02" ].includes(d.id))
})