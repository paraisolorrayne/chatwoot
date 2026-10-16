<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS: lista ranqueada com barra proporcional (Inteligência).
import { computed } from 'vue';

const props = defineProps({
  // [{ key, label, value, detail? }]
  items: { type: Array, default: () => [] },
  format: { type: Function, default: value => value },
  bar: { type: String, default: 'bg-s-chart-1' },
  emptyText: { type: String, default: '' },
  limit: { type: Number, default: 8 },
});

const visible = computed(() => props.items.slice(0, props.limit));
const max = computed(() => Math.max(1, ...visible.value.map(i => i.value)));
</script>

<template>
  <p v-if="!visible.length" class="text-sm text-s-muted">{{ emptyText }}</p>
  <ul v-else class="reset-base list-none flex flex-col gap-3">
    <li v-for="item in visible" :key="item.key" class="flex flex-col gap-1.5">
      <div class="flex items-baseline justify-between gap-3 text-sm">
        <span class="text-s-primary truncate">{{ item.label }}</span>
        <span class="flex items-baseline gap-2 flex-shrink-0">
          <span v-if="item.detail" class="text-xs text-s-muted">
            {{ item.detail }}
          </span>
          <span class="font-mono tabular-nums text-s-secondary">
            {{ format(item.value) }}
          </span>
        </span>
      </div>
      <div class="h-1.5 rounded-full bg-s-subtle overflow-hidden">
        <div
          class="h-full rounded-full motion-safe:transition-[width] duration-500"
          :class="bar"
          :style="{ width: `${(item.value / max) * 100}%` }"
        />
      </div>
    </li>
  </ul>
</template>
