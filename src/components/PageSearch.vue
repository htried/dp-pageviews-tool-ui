<template>
	<div>
		<ProjectSelect @project-selected="onProjectSelected" :value="selectedProject" />
		<p v-if="!isProjectSelected">Select a project.</p>
		<p>Page ID: <em>{{ selection }}</em></p>
		<cdx-lookup v-model:selected="selection" clearable :menu-items="menuItems" :menu-config="menuConfig"
			aria-label="Page lookup with fetched results" @input="onInput" :disabled="!isProjectSelected"
			:readonly="!isProjectSelected" :style="{ opacity: isProjectSelected ? 1 : 0.5 }">
			<template #no-results> No results found. </template>
		</cdx-lookup>
		<div style="display: flex; gap: 10px;">
			<StartDate @start-date="updateStartDate" :value="startDate" style="flex-grow: 1;"
				:disabled="!isProjectSelected" />
			<EndDate @end-date="updateEndDate" :value="endDate" style="flex-grow: 1;" :disabled="!isProjectSelected" />
		</div>
	</div>
	<br />
	<div class="button-container">
		<cdx-button @click="graphData" :disabled="!canSubmit" action="progressive" weight="primary">Graph
			data!</cdx-button>
		<cdx-button @click="mapData" :disabled="!canSubmit" action="progressive" weight="primary">Map data!</cdx-button>
	</div>
</template>

<script>
import { defineComponent, ref, computed, watch } from 'vue'
import { CdxLookup, CdxButton } from '@wikimedia/codex'
import ProjectSelect from './ProjectSelect.vue'
import StartDate from './StartDate.vue'
import EndDate from './EndDate.vue'

export default defineComponent({
	name: 'PageSearch',
	components: {
		CdxLookup,
		CdxButton,
		ProjectSelect,
		StartDate,
		EndDate
	},
	emits: [
		'graphData',
		'mapData'
	],
	setup(props, { emit }) {
		const selection = ref(null)
		const menuItems = ref([])
		const currentSearchTerm = ref('')
		const selectedCountry = ref('')
		const selectedProject = ref('')
		const startDate = ref('')
		const endDate = ref('')

		const isProjectSelected = computed(() => selectedProject.value !== '')
		const isFormComplete = computed(() =>
			isProjectSelected.value &&
			selection.value &&
			startDate.value &&
			endDate.value
		)
		const canSubmit = computed(() => isFormComplete.value)

		function onProjectSelected(project) {
			selectedProject.value = project;
			resetValues()
		}

		function resetValues() {
			selection.value = null
			menuItems.value = []
			currentSearchTerm.value = ''
			selectedCountry.value = ''
			startDate.value = ''
			endDate.value = ''
		}

		function updateStartDate(newStartDate) {
			startDate.value = newStartDate;
		}

		function updateEndDate(newEndDate) {
			endDate.value = newEndDate;
		}

		function fetchResults(searchTerm) {
			const params = new URLSearchParams({
				q: searchTerm,
				limit: '10'
			})
			return fetch(`https://${selectedProject.value}/w/rest.php/v1/search/title?${params.toString()}`).then(
				(response) => response.json()
			)
		}

		function onInput(value) {
			currentSearchTerm.value = value
			if (!value) {
				menuItems.value = []
				return
			}
			fetchResults(value)
				.then((data) => {
					if (currentSearchTerm.value !== value) {
						return
					}
					if (!data.pages || data.pages.length === 0) {
						menuItems.value = []
						return
					}
					const results = data.pages.map((result) => {
						return {
							label: result.title,
							value: result.id,
							description: result.description
						}
					})
					menuItems.value = results
				})
				.catch(() => {
					menuItems.value = []
				})
		}

		function graphData() {
			emit('graphData', {
				'country': selectedCountry.value,
				'project': selectedProject.value,
				'pageID': selection.value,
				'startDate': startDate.value,
				'endDate': endDate.value
			})
		}

		function mapData() {
			emit('mapData', {
				'country': selectedCountry.value,
				'project': selectedProject.value,
				'pageID': selection.value,
				'startDate': startDate.value,
				'endDate': endDate.value
			})
		}

		const menuConfig = {
			visibleItemLimit: 6
		}

		watch(selectedProject, () => {
			if (!selectedProject.value) {
				resetValues()
			}
		})

		return {
			selection,
			onProjectSelected,
			updateStartDate,
			updateEndDate,
			menuItems,
			menuConfig,
			onInput,
			graphData,
			mapData,
			isProjectSelected,
			canSubmit,
		}
	}
})
</script>

<style scoped>
.button-container {
	display: flex;
	justify-content: space-between;
}
</style>
