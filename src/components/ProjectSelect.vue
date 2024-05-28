<template>
  <div>
    <p>Project: <em>{{ selection }}</em></p>

    <cdx-lookup v-model:selected="selection" clearable :menu-items="menuItems" :menu-config="menuConfig"
      aria-label="Lookup wikis" @input="onInput" @update:selected="$emit('project-selected', $event)" />
  </div>
</template>

<script>
import { defineComponent, ref } from 'vue'
import { CdxLookup } from '@wikimedia/codex'
import wikis from './data/wikis.json'

export default defineComponent({
  name: 'ProjectSelect',
  components: { CdxLookup },
  emits: [
    'project-selected'
  ],
  setup() {
    const selection = ref(null)
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
        menuItems.value = wikis.filter(
          (item) => item.label.toLowerCase().includes(value.toLowerCase()) || item.description.toLowerCase().includes(value.toLowerCase())
        )
      }

      if (menuItems.value.length > 10) {
        menuItems.value = menuItems.value.slice(0, 10)
      }
    }

    return {
      selection,
      menuItems,
      menuConfig,
      onInput
    }
  }
})
</script>
