<template>
	<div>
		<p>End date: <em>{{ inputValue }}</em></p>
		<div class="input-wrapper">
			<cdx-text-input v-model="inputValue" aria-label="end date input" input-type="date" clearable
				:disabled="disabled" :min="minDate" :max="maxDate" @update:modelValue="handleDateChange"
				:status="isInvalidDate ? 'error' : ''" :status-message="errorMessage" />
		</div>
	</div>
</template>

<script>
import { defineComponent, ref, watch, computed } from 'vue';
import { CdxTextInput } from '@wikimedia/codex';

export default defineComponent({
	name: 'EndDate',
	components: { CdxTextInput },
	props: {
		disabled: Boolean
	},
	emits: ['end-date'],
	setup(props, { emit }) {
		const inputValue = ref('');
		const errorMessage = ref('');
		const constantDate = new Date('2024-01-01');
		const today = new Date('2024-05-29');
		const maxDate = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
		const minDate = `${constantDate.getFullYear()}-${String(constantDate.getMonth() + 1).padStart(2, '0')}-${String(constantDate.getDate()).padStart(2, '0')}`;

		watch(inputValue, (newValue) => {
			const selectedDate = new Date(newValue);

			if (selectedDate < constantDate) {
				errorMessage.value = `End date cannot be before ${constantDate.toDateString()}`;
			} else if (selectedDate > today) {
				errorMessage.value = 'End date cannot be in the future';
			} else {
				errorMessage.value = '';
				emit('end-date', inputValue.value);
			}
		});

		const handleDateChange = (newValue) => {
			inputValue.value = newValue;
		};

		const isInvalidDate = computed(() => errorMessage.value !== '');

		return {
			inputValue,
			minDate,
			maxDate,
			errorMessage,
			handleDateChange,
			isInvalidDate,
		};
	},
});
</script>

<style scoped>
.input-wrapper {
	display: flex;
	flex-direction: column;
}
</style>