<template>
  <LoadingSpinner v-show="loading" />
  <div v-show="!loading" id="lineGraph"></div>
  <div style="display: flex; gap: 10px;">
    <CountrySelect @country-selected="updateCountry" @filter-graph="filterLineGraph" />
  </div>
</template>

<script>
import * as d3 from 'd3';
import CountrySelect from './CountrySelect.vue'
import LoadingSpinner from './LoadingSpinner.vue'

export default {
  name: 'LineGraph',
  components: {
    CountrySelect,
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
      loading: true,
    };
  },
  mounted() {
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
        // Calculate the number of days between start and end dates
        const start = new Date(this.startDate);
        const end = new Date(this.endDate);
        const dateRange = [];
        let currentDate = new Date(start);

        while (currentDate <= end) {
          dateRange.push(new Date(currentDate));
          currentDate.setDate(currentDate.getDate() + 1);
        }

        // Make multiple API requests, one for each day
        const promises = dateRange.map(async date => {
          const response = await fetch(`https://dp-pageviews.wmcloud.org/api/v1/${this.project.slice(0, -4)}/${this.pageID}/${date.toISOString().split('T')[0]}`);
          if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`);
          }
          return response.json(); // Parse response as JSON
        });

        // Wait for all requests to complete
        const responseData = await Promise.all(promises);

        // Concatenate all data from responses
        let combined = []
        responseData.forEach(d => combined = combined.concat(d.results));
        this.data = combined;

        this.loading = false;
        // Render line graph
        this.renderLineGraph();
      } catch (error) {
        console.error('Error fetching data:', error);
        this.loading = false;
      }
    },
    filterLineGraph(selectedCountries) {
      // Filter the data based on the selectedCountries
      let filteredData;
      if (selectedCountries.length > 0) {
        filteredData = this.data.filter(d => selectedCountries.includes(d.country_code));
        this.renderLineGraph(filteredData)
      } else {
        this.renderLineGraph()
      }
    },
    renderLineGraph(filteredData = this.data) {
      const totalPageviewsByCountry = new Map();
      filteredData.forEach(d => {
        const country = d.country;
        const pageviews = d.noisy_views;
        totalPageviewsByCountry.set(country, (totalPageviewsByCountry.get(country) || 0) + pageviews);
      });

      // Sort countries by total pageviews in descending order
      const sortedCountries = Array.from(totalPageviewsByCountry.keys()).sort((a, b) => {
        return totalPageviewsByCountry.get(b) - totalPageviewsByCountry.get(a);
      });

      // Create legend items sorted by total pageviews
      var legendItems = sortedCountries.map(country => {
        return { country, totalPageviews: totalPageviewsByCountry.get(country) };
      });

      filteredData = filteredData.sort((a, b) => b.date - a.date);

      const tooltip = d3.select('#lineGraph').append('div')
        .attr('class', 'tooltip')
        .style('position', 'absolute')
        .style('visibility', 'hidden')
        .style('background-color', 'white')
        .style('border', 'solid 1px black')
        .style('padding', '5px')
        .style('border-radius', '3px')
        .style('pointer-events', 'none')
        .style('font-size', '12px');

      const margin = { top: 20, right: 20, bottom: 70, left: 80 };
      const width = 800 - margin.left - margin.right;
      const height = 600 - margin.top - margin.bottom;

      // Remove any existing SVG elements
      d3.select('#lineGraph svg').remove();

      // Create SVG element
      const svg = d3.select('#lineGraph')
        .append('svg')
        .attr('width', width + margin.left + margin.right)
        .attr('height', height + margin.top + margin.bottom)
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      // Group data by country
      const dataByCountry = d3.group(filteredData, d => d.country);

      // Create scales
      const xScale = d3.scaleTime()
        .domain(d3.extent(filteredData, d => new Date(d.date)))
        .range([0, width]);

      const yScale = d3.scaleLinear()
        .domain([0, d3.max(filteredData, d => d.noisy_views)])
        .nice() // Make y-axis nice
        .range([height, 0]);

      const xAxis = d3.axisBottom(xScale)
        .tickSize(-height)
        .tickFormat(d3.timeFormat("%Y-%m-%d"));

      const yAxis = d3.axisLeft(yScale)
        .tickSize(-width);

      svg.append('g')
        .attr('transform', `translate(0,${height})`)
        .call(xAxis)
        .selectAll('text')
        .style('fill', 'black')
        .attr('transform', 'rotate(-45)')
        .style('text-anchor', 'end');

      svg.append('g')
        .call(yAxis)
        .selectAll('text')
        .style('fill', 'black');

      svg.selectAll('.tick line')
        .attr('stroke', '#ddd');

      const line = d3.line()
        .x(d => xScale(new Date(d.date)))
        .y(d => yScale(d.noisy_views));

      const colorScale = d3.scaleOrdinal()
        .domain([...dataByCountry.keys()])
        .range(d3.schemeCategory10);

      dataByCountry.forEach((countryData, country) => {
        svg.append('path')
          .datum(countryData)
          .attr('class', 'line')
          .attr('d', line)
          .attr('fill', 'none')
          .attr('stroke', colorScale(country))
          .attr('stroke-width', 1.5);

        svg.selectAll(`circle.${country}`)
          .data(countryData)
          .enter()
          .append('circle')
          .attr('class', country)
          .attr('cx', d => xScale(new Date(d.date)))
          .attr('cy', d => yScale(d.noisy_views))
          .attr('r', 3)
          .attr('fill', colorScale(country));
      });

      // Attach tooltip to each data point
      svg.selectAll('circle')
        .on('mouseover', (event, d) => {
          // Show tooltip and update content
          tooltip.style('visibility', 'visible')
            .html(`<strong>${d.country}</strong><br><strong>Date:</strong> ${d.date}<br><strong>Page views:</strong> ${d.noisy_views.toLocaleString()}`);
        })
        .on('mousemove', (event) => {
          // Move tooltip with mouse
          tooltip.style('top', `${event.pageY}px`)
            .style('left', `${event.pageX + 10}px`);
        })
        .on('mouseout', () => {
          // Hide tooltip when mouse leaves data point
          tooltip.style('visibility', 'hidden');
        });

      // using SVG elements for the legend
      const legend = svg.append('g')
        .attr('transform', `translate(${width + 20}, 20)`); // Adjusted position to be within the SVG

      legend.selectAll('legendItem')
        .data(legendItems)
        .enter()
        .append('g')
        .attr('class', 'legendItem')
        .attr('transform', (d, i) => `translate(0, ${i * 20})`) // Adjust spacing between legend items
        .each(function (d) {
          const legendItem = d3.select(this);

          legendItem.append('circle')
            .attr('cx', 0)
            .attr('cy', 0)
            .attr('r', 5)
            .attr('fill', colorScale(d.country));

          legendItem.append('text')
            .attr('x', 10)
            .attr('y', 5)
            .style('font-size', '12px')
            .style('fill', 'black')
            .text(`${d.country} (Total pageviews: ${d.totalPageviews.toLocaleString()})`);
        });

      // Adjusting X-axis title position
      svg.append('text')
        .attr('transform', `translate(${width / 2}, ${height + margin.bottom - 5})`)
        .style('text-anchor', 'middle')
        .style('font-size', '14px')
        .style('fill', 'black')
        .text('Date');

      svg.append('text')
        .attr('transform', `rotate(-90) translate(-${height / 2}, ${-margin.left + 20})`)
        .style('text-anchor', 'middle')
        .style('font-size', '14px')
        .style('fill', 'black')
        .text('Page views');
    },
  }
}
</script>

<style scoped>
#graphArea {
  width: 100%;
  height: 400px;
  /* Adjust height as needed */
}
</style>