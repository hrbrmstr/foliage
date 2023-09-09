import { LitElement, css, html, unsafeCSS } from 'lit'
import tachyons from 'tachyons/css/tachyons.min.css?inline'
import * as Plot from '@observablehq/plot';
import { weeks, counties48, states48, foliageData } from './data'

/**
* An example element.
*
* @slot - This element has a slot
* @csspart button - The button
*/
export class FoliageMap extends LitElement {
  static get properties() {
    return {
      /**
      * Current week being displayed
      */
      week: { type: String },
    }
  }

  isPlaying = false;
  intervalID = null;
  
  constructor() {
    super()
    this.week = weeks[ 0 ]
  }
  
  updateWeek(evt) {
    this.week = weeks[evt.target.value]
  }
  
  togglePlay() {
    if (this.isPlaying) {
      clearInterval(this.intervalID);
    } else {
      this.intervalID = setInterval(() => {
        const slider = this.shadowRoot.getElementById("date-slider");
        slider.value = (parseInt(slider.value) + 1) % weeks.length;
        this.week = weeks[ slider.value ]
      }, 300);
    }
    this.isPlaying = !this.isPlaying;
  }
  
  render() {

    const fWeek = new Map(
      foliageData.filter((d) => d.week == this.week).map((e) => [ e.id, e ])
    )

    const foliagePlot = Plot.plot({
      projection: "albers-usa",
      width: 1200,
      className: 'foliagePlot',
      style: {
        backgroundColor: "#00000000"
      },
      color: {
        legend: true,
        domain: [
          "No Change",
          "Minimal",
          "Patchy",
          "Partial",
          "Near Peak",
          "Peak",
          "Past Peak"
        ],
        range: [
          "#8d3d28",
          "#ae3130",
          "#dc4d33",
          "#e89150",
          "#f6ce6f",
          "#fbf6bb",
          "#8ba780"
        ],
        label: "Foliage Levels",
        reverse: true
      },
      marks: [
        Plot.geo(counties48, {
          stroke: "white",
          strokeWidth: 1 / 4,
          strokeOpacity: 1 / 2,
          title: (d) => d.id,
          fill: (d) => {
            const cty = fWeek.get(d.id);
            const val = cty === undefined ? "No Change" : cty.value;
            return val;
          }
        }),
        Plot.geo(states48, {
          stroke: "white",
          strokeWidth: 3 / 2,
          strokeOpacity: 1 / 2
        })
      ]
    })

    return html`
<div class="flex flex-column mw9 items-center justify-center center pa3 sans-serif">
  <h1 class="f1">2023 Foliage Map</h1>
  <div class="flex flex-row items-center justify-centers">
    <a class="f6 link dim br3 h2 ph3 pv2 mb2 dib white bg-mid-gray pointer" id="play-button"
       @click=${this.togglePlay}>Play</a>
    <input class="ml2 h2 white bg-mid-gray w5" type="range" min="0" max="11" value="0" id='date-slider'
           @change=${this.updateWeek}/>
  </div>
  <div class="flex items-center justify-center">
    <span class="ml2 f2" id="date-display">${this.week}</span>
  </div>
  <div id="plot" class="pa3 mt3">
  ${foliagePlot}
  </div>
</div>
    `
  }
  
  static get styles() {
    
    return css`
    ${ unsafeCSS(tachyons) }
    
    :host{
      color-scheme: dark light;
      --color-bg: white;
      --color-fg: black;
    }
    
    .foliagePlot-swatches-wrap {
      justify-content: center;
      font-size: 16pt;
    }
    `
  }
}

window.customElements.define('foliage-map', FoliageMap)
