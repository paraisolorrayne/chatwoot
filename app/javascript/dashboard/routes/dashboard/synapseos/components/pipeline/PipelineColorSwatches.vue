<script setup>
// CUSTOMIZAÇÃO_SYNAPSEOS — seletor de cor do estágio com a paleta de gráficos do
// Fykos (o valor salvo continua sendo hex). Rádios nativos: setas trocam a cor.
import { useI18n } from 'vue-i18n';
import { STAGE_COLOR_SWATCHES } from './pipelineHelpers';

const model = defineModel({ type: String, required: true });

const { t } = useI18n();
</script>

<template>
  <fieldset class="flex flex-col gap-1.5">
    <legend class="mb-1.5 text-sm text-s-primary">
      {{ t('SYNAPSEOS.PIPELINE.STAGE_COLOR') }}
    </legend>
    <div class="flex flex-wrap gap-2">
      <label
        v-for="swatch in STAGE_COLOR_SWATCHES"
        :key="swatch.hex"
        class="flex items-center justify-center size-8 rounded-full cursor-pointer ring-offset-2 ring-offset-s-surface has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-focus"
        :class="[
          swatch.className,
          model === swatch.hex
            ? 'outline outline-2 outline-offset-2 outline-s-primary'
            : '',
        ]"
        :title="t(`SYNAPSEOS.PIPELINE.COLORS.${swatch.key}`)"
      >
        <input
          v-model="model"
          type="radio"
          name="pipeline-stage-color"
          :value="swatch.hex"
          class="sr-only"
        />
        <span
          v-if="model === swatch.hex"
          class="i-lucide-check size-4 text-white"
          aria-hidden="true"
        />
        <span class="sr-only">
          {{ t(`SYNAPSEOS.PIPELINE.COLORS.${swatch.key}`) }}
        </span>
      </label>
    </div>
  </fieldset>
</template>
