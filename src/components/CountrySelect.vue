<template>
  <div>
    <p>Filter to selected countries: {{ selectedCountries.join(', ') }}</p>

    <div class="input-container">
      <cdx-lookup v-model:selected="selectedCountry" :menu-items="menuItems" :menu-config="menuConfig"
        aria-label="Lookup countries" @input="onInput" @update:selected="handleCountrySelection" />
      <div v-if="selectedCountries.length" class="button-container">
        <cdx-button @click="filterGraph">Filter Graph to Selected
          Countries</cdx-button>
        <cdx-button @click="clearSelectedCountries" action="destructive">Clear Selected Countries</cdx-button>
      </div>
    </div>
  </div>
</template>

<script>
import { defineComponent, ref } from 'vue'
import { CdxLookup, CdxButton } from '@wikimedia/codex'
import countries from './data/countries.json'

export default defineComponent({
  name: 'CountryLookup',
  components: { CdxLookup, CdxButton },
  emits: ['country-selected', 'filter-graph'],
  setup(_, { emit }) {
    const selectedCountry = ref(null)
    const selectedCountries = ref([])
    const menuItems = ref([])

    const menuConfig = {
      boldLabel: true
    }

    /**
     * Filter items on input.
     *
     * @param {string} value
     */
    function onInput(value) {
      if (value) {
        menuItems.value = countries.filter(
          (item) => item.label.toLowerCase().includes(value.toLowerCase())
            || item.description.toLowerCase().includes(value.toLowerCase())
        )

        if (menuItems.value.length > 10) {
          menuItems.value = menuItems.value.slice(0, 10)
        }
      }
    }

    function handleCountrySelection(country) {
      if (country && !selectedCountries.value.includes(country)) {
        selectedCountries.value.push(country)
        emit('country-selected', selectedCountries.value)
      }
    }

    function clearSelectedCountries() {
      selectedCountries.value = []
      emit('country-selected', [])
      filterGraph()
    }

    function filterGraph() {
      emit('filter-graph', selectedCountries.value)
    }

    return {
      selectedCountry,
      selectedCountries,
      menuItems,
      menuConfig,
      onInput,
      handleCountrySelection,
      clearSelectedCountries,
      filterGraph
    }
  }
})
</script>

<style scoped>
.input-container {
  display: flex;
  gap: 10px;
  align-items: center;
  flex-grow: 1;
}

.button-container {
  display: flex;
  flex-grow: 1;
  margin-left: 10px;
  gap: 10px;
}
</style>