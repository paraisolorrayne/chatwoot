<script setup>
import { defineProps, defineEmits } from 'vue';

defineProps({
  showingOriginal: Boolean,
});

defineEmits(['toggle']);
</script>

<template>
  <span>
    <!-- CUSTOMIZAÇÃO_SYNAPSEOS: herda a cor do bubble e é acessível por teclado. -->
    <button
      type="button"
      class="p-0 text-xs opacity-70 cursor-pointer hover:underline focus-visible:underline focus-visible:outline-none select-none"
      @click="$emit('toggle')"
    >
      {{
        showingOriginal
          ? $t('CONVERSATION.VIEW_TRANSLATED')
          : $t('CONVERSATION.VIEW_ORIGINAL')
      }}
    </button>
  </span>
</template>
