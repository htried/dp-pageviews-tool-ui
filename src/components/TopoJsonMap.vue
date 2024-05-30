<template>
    <LoadingSpinner v-show="loading" />
    <div v-show="!loading" id="mapContainer">
        <div id="map"></div>
        <div id="legend"></div>
        <input type="range" v-model="selectedDateIndex" @input="updateMap" :min="0" :max="dateRange.length - 1">
        <label>{{ formattedSelectedDate }}</label>
    </div>
</template>

<script>
import * as d3 from 'd3';
import * as topojson from 'topojson-client';
import LoadingSpinner from './LoadingSpinner.vue';
import topojsonData from './data/countries-110m.json';

const cplOld = ["Afghanistan", "Azerbaijan", "Bahrain", "Bangladesh", "Belarus", "China", "Cuba", "Djibouti", "Egypt", "Eritrea", "Ethiopia", "Honduras", "Iran", "Iraq", "Kazakhstan", "Kuwait", "Laos", "Myanmar", "Nicaragua", "North Korea", "Oman", "Pakistan", "Russia", "Rwanda", "Saudi Arabia", "Sudan", "Syria", "Thailand", "Turkey", "Turkmenistan", "United Arab Emirates", "Uzbekistan", "Venezuela", "Vietnam", "Yemen"]
const mediumRisk = ['Afghanistan', 'Azerbaijan', 'Bangladesh', 'Djibouti', 'Ethiopia', 'Honduras', 'Iraq', 'Kazakhstan', 'Kuwait', 'Laos', 'Nicaragua', 'Oman', 'Pakistan', 'Palestine', 'Sudan', 'Tajikistan', 'United Arab Emirates', 'Uzbekistan', 'Venezuela', 'Yemen']
const highRisk = ['Bahrain', 'Belarus', 'Egypt', 'Eritrea', 'Russia', 'Saudi Arabia', 'Turkey', 'Turkmenistan']
const notPublished = ['China', 'Hong Kong', 'Cuba', 'Iran', 'Macau', 'Myanmar', 'North Korea', 'Syria', 'Vietnam']

export default {
    name: 'TopoJsonMap',
    components: {
        LoadingSpinner
    },
    props: {
        project: String,
        pageID: Number,
        startDate: String,
        endDate: String
    },
    data() {
        return {
            data: [],
            topojsonData: null,
            dateRange: [],
            selectedDateIndex: 0,
            loading: true,
            maxPageviews: 0,
        };
    },
    computed: {
        formattedSelectedDate() {
            return this.dateRange[this.selectedDateIndex];
        }
    },
    mounted() {
        this.topojsonData = topojsonData;
        this.fetchData();
    },
    watch: {
        startDate: 'fetchData',
        endDate: 'fetchData',
        pageID: 'fetchData',
        project: 'fetchData'
    },
    methods: {
        async fetchData() {
            try {
                const start = new Date(this.startDate);
                const end = new Date(this.endDate);
                const dateRange = [];
                let currentDate = new Date(start);

                while (currentDate <= end) {
                    dateRange.push(currentDate.toISOString().split('T')[0]);
                    currentDate.setDate(currentDate.getDate() + 1);
                }

                this.dateRange = dateRange;

                const promises = dateRange.map(async date => {
                    const response = await fetch(`https://dp-pageviews.wmcloud.org/api/v1/${this.project.slice(0, -4)}/${this.pageID}/${date}`);
                    if (!response.ok) {
                        throw new Error(`HTTP error! Status: ${response.status}`);
                    }
                    return response.json();
                });

                const responseData = await Promise.all(promises);
                let combined = [];
                responseData.forEach(d => combined = combined.concat(d.results));
                this.data = combined;

                this.maxPageviews = d3.max(combined, d => d.noisy_views);

                this.loading = false;
                this.updateMap();
            } catch (error) {
                console.error('Error fetching data:', error);
                this.loading = false;
            }
        },
        updateMap() {
            const filteredData = this.filterDataByDate(this.formattedSelectedDate);
            this.renderMap(filteredData, this.formattedSelectedDate);
        },
        filterDataByDate(date) {
            return this.data.filter(d => d.date === date);
        },
        getCTPL(country, date, pageviews) {
            let pageview_message;
            if (date >= '2024-02-15') {
                if (mediumRisk.includes(country) && pageviews === 0) {
                    pageview_message = '<550';
                } else if (highRisk.includes(country) && pageviews === 0) {
                    pageview_message = '<1,000';
                } else if (notPublished.includes(country)) {
                    pageview_message = 'Not published';
                } else if (pageviews === 0) {
                    pageview_message = '<90';
                } else {
                    pageview_message = pageviews.toLocaleString()
                }
            } else {
                if (cplOld.includes(country)) {
                    pageview_message = 'Not published';
                } else if (date >= '2023-02-06' && pageviews === 0) {
                    pageview_message = '<90';
                } else if (date >= '2017-02-09' && pageviews === 0) {
                    pageview_message = '<450';
                } else {
                    pageview_message = pageviews.toLocaleString()
                }
            }
            return pageview_message
        },
        renderMap(filteredData, date) {
            const totalPageviewsByCountry = new Map();
            filteredData.forEach(d => {
                const country = d.country;
                const pageviews = d.noisy_views;
                totalPageviewsByCountry.set(country, (totalPageviewsByCountry.get(country) || 0) + pageviews);
            });
            const width = 960, height = 600;
            d3.select('#map svg').remove();
            const svg = d3.select('#map').append('svg')
                .attr('width', width)
                .attr('height', height);

            const projection = d3.geoMercator().scale(150).translate([width / 2, height / 1.5]);
            const path = d3.geoPath().projection(projection);

            const colorScale = d3.scaleSequentialLog(d3.interpolateBlues)
                .domain([1, this.maxPageviews]);

            const tooltip = d3.select('#mapContainer').append('div')
                .attr('class', 'tooltip')
                .style('position', 'absolute')
                .style('visibility', 'hidden')
                .style('background-color', 'white')
                .style('border', 'solid 1px black')
                .style('padding', '5px')
                .style('border-radius', '3px')
                .style('pointer-events', 'none')
                .style('font-size', '12px');

            svg.append('g')
                .selectAll('path')
                .data(topojson.feature(this.topojsonData, this.topojsonData.objects.countries).features)
                .enter().append('path')
                .attr('d', path)
                .attr('fill', d => {
                    const country = d.properties.name;
                    const pageviews = totalPageviewsByCountry.get(country) || 0;
                    const pageview_message = this.getCTPL(country, date, pageviews)
                    if (pageview_message === "Not published") {
                        return "#808080"
                    }
                    return colorScale(totalPageviewsByCountry.get(country) || 1);
                })
                .attr('stroke', 'black')
                .attr('stroke-width', '0.5')
                .on('mouseover', (event, d) => {
                    const country = d.properties.name;
                    const pageviews = totalPageviewsByCountry.get(country) || 0;
                    const pageview_message = this.getCTPL(country, date, pageviews)
                    tooltip.style('visibility', 'visible')
                        .html(`<strong>${country}</strong><br>Pageviews: ${pageview_message}`);
                    d3.select(event.currentTarget)
                        .style('stroke', 'black')
                        .style('stroke-width', 2);
                })
                .on('mousemove', function (event) {
                    tooltip.style('top', `${event.pageY - 10}px`)
                        .style('left', `${event.pageX + 10}px`);
                })
                .on('mouseout', function () {
                    tooltip.style('visibility', 'hidden');
                    d3.select(this)
                        .style('stroke', null)
                        .style('stroke-width', null);
                });

            d3.select('#tooltip').remove();

            // Add legend
            const legend = d3.select('#legend').html('');
            const legendScale = d3.scaleLog()
                .domain([1, this.maxPageviews])
                .range([0, 300]);

            const legendAxis = d3.axisBottom(legendScale).ticks(5, d3.format(".0s"));

            const legendSvg = legend.append('svg')
                .attr('width', 320)
                .attr('height', 50);

            legendSvg.append('g')
                .attr('class', 'axis')
                .attr('transform', 'translate(10,30)')
                .call(legendAxis);

            const legendGradient = legendSvg.append('defs').append('linearGradient')
                .attr('id', 'legendGradient')
                .attr('x1', '0%').attr('x2', '100%')
                .attr('y1', '0%').attr('y2', '0%');

            legendGradient.selectAll('stop')
                .data(colorScale.ticks().map((t, i, n) => ({
                    offset: `${100 * i / n.length}%`,
                    color: colorScale(t)
                })))
                .enter().append('stop')
                .attr('offset', d => d.offset)
                .attr('stop-color', d => d.color);

            legendSvg.append('rect')
                .attr('x', 10)
                .attr('y', 10)
                .attr('width', 300)
                .attr('height', 20)
                .style('fill', 'url(#legendGradient)');

            legendSvg.append('text')
                .attr('x', 10)
                .attr('y', 25)
                .style('text-anchor', 'start')
                .text('Pageviews');

            legendSvg.selectAll('text')
                .style('fill', 'black');
        }
    }
};
</script>

<style scoped>
#mapContainer {
    display: flex;
    flex-direction: column;
    align-items: center;
}

#map {
    width: 960px;
    height: 600px;
}

#legend {
    margin-top: 20px;
}
</style>