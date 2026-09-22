<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useIntervalFn } from '@vueuse/core';
import axios from 'axios';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import InputText from 'primevue/inputtext';
import Textarea from 'primevue/textarea';

const { t } = useI18n();
const { accountId, accountScopedRoute } = useAccount();
const currentUser = useMapGetter('getCurrentUser');
const inboxes = ref([]);
const requests = ref([]);
const destination = ref('');
const inboxId = ref('');
const subject = ref('');
const description = ref('');
const requestId = ref(crypto.randomUUID());
const loading = ref(false);
const sending = ref(false);
const error = ref('');
const success = ref(false);
const canSubmit = computed(
  () =>
    inboxId.value &&
    subject.value.trim() &&
    description.value.trim() &&
    !sending.value &&
    !loading.value
);
const endpoint = id => `/api/v1/accounts/${id}/synapseos/support_requests`;

async function loadRequests(silent = false) {
  const id = accountId.value;
  if (!silent) loading.value = true;
  try {
    const { data } = await axios.get(endpoint(id));
    if (id !== accountId.value) return;
    inboxes.value = data.inboxes;
    requests.value = data.requests;
    destination.value = data.destination;
    if (!inboxId.value && data.inboxes.length === 1)
      inboxId.value = data.inboxes[0].id;
  } catch {
    if (id === accountId.value && !silent)
      error.value = t('SYNAPSEOS.SUPPORT.LOAD_ERROR');
  } finally {
    if (id === accountId.value) loading.value = false;
  }
}

async function submit() {
  if (!canSubmit.value) return;
  const id = accountId.value;
  sending.value = true;
  error.value = '';
  success.value = false;
  try {
    await axios.post(endpoint(id), {
      support_request: {
        inbox_id: inboxId.value,
        subject: subject.value.trim(),
        description: description.value.trim(),
        request_id: requestId.value,
      },
    });
    if (id !== accountId.value) return;
    subject.value = '';
    description.value = '';
    requestId.value = crypto.randomUUID();
    success.value = true;
    await loadRequests(true);
  } catch (err) {
    if (id !== accountId.value) return;
    const code = err.response?.data?.error;
    error.value = t(
      `SYNAPSEOS.SUPPORT.${code === 'window_closed' ? 'WINDOW_CLOSED' : 'SEND_ERROR'}`
    );
  } finally {
    if (id === accountId.value) sending.value = false;
  }
}

watch(
  [subject, description, inboxId],
  () => {
    requestId.value = crypto.randomUUID();
    success.value = false;
  },
  { flush: 'sync' }
);
watch(
  accountId,
  () => {
    inboxes.value = [];
    requests.value = [];
    destination.value = '';
    inboxId.value = '';
    subject.value = '';
    description.value = '';
    error.value = '';
    success.value = false;
    sending.value = false;
    loadRequests();
  },
  { immediate: true }
);
useIntervalFn(() => loadRequests(true), 10000);
</script>

<template>
  <main class="flex-1 min-w-0 overflow-y-auto bg-s-bg text-s-primary">
    <div class="max-w-6xl mx-auto px-5 py-8 md:px-10 md:py-12">
      <header class="flex items-start gap-4 mb-8">
        <div
          class="flex items-center justify-center size-12 rounded-2xl bg-s-surface border border-s-border shadow-sm shrink-0"
        >
          <span class="i-lucide-life-buoy size-6 text-s-brand-text" />
        </div>
        <div>
          <h1 class="text-2xl font-semibold tracking-tight mb-2">
            {{ t('SYNAPSEOS.SUPPORT.TITLE') }}
          </h1>
          <p class="text-s-muted text-sm max-w-2xl mb-0">
            {{ t('SYNAPSEOS.SUPPORT.SUBTITLE') }}
          </p>
        </div>
      </header>
      <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_300px] items-start">
        <section
          class="bg-s-surface rounded-2xl border border-s-border shadow-sm p-6 md:p-8"
        >
          <h2 class="text-lg font-semibold mb-1">
            {{ t('SYNAPSEOS.SUPPORT.NEW_REQUEST') }}
          </h2>
          <p class="text-sm text-s-muted mb-6">
            {{ t('SYNAPSEOS.SUPPORT.FORM_HINT') }}
          </p>
          <p v-if="loading" role="status" class="text-sm text-s-muted">
            {{ t('SYNAPSEOS.SUPPORT.LOADING') }}
          </p>
          <div
            v-if="error"
            role="alert"
            class="rounded-xl bg-s-error-soft text-s-error-text p-4 text-sm mb-5"
          >
            {{ error }}
            <Button
              v-if="!inboxes.length"
              class="mt-3"
              :label="t('SYNAPSEOS.SUPPORT.REFRESH')"
              sm
              ghost
              @click="loadRequests()"
            />
          </div>
          <p
            v-if="success"
            role="status"
            class="rounded-xl bg-s-success-soft text-s-success-text p-4 text-sm mb-5"
          >
            {{ t('SYNAPSEOS.SUPPORT.SUCCESS') }}
          </p>
          <p
            v-if="!loading && !inboxes.length && !error"
            class="rounded-xl bg-s-subtle p-4 text-sm text-s-secondary"
          >
            {{ t('SYNAPSEOS.SUPPORT.NO_CHANNEL') }}
          </p>
          <form v-if="inboxes.length" @submit.prevent="submit">
            <fieldset
              :disabled="sending"
              class="flex flex-col gap-5 p-0 m-0 border-0 min-w-0"
            >
              <div>
                <label
                  for="support-inbox"
                  class="block text-sm font-medium mb-2"
                  >{{ t('SYNAPSEOS.SUPPORT.CHANNEL') }}</label
                >
                <select
                  id="support-inbox"
                  v-model="inboxId"
                  required
                  class="w-full !mb-0 !rounded-xl !bg-s-bg !border-s-border !text-s-primary"
                >
                  <option disabled value="">
                    {{ t('SYNAPSEOS.SUPPORT.SELECT_CHANNEL') }}
                  </option>
                  <option
                    v-for="inbox in inboxes"
                    :key="inbox.id"
                    :value="inbox.id"
                  >
                    {{ inbox.name }} · {{ inbox.phone_number }}
                  </option>
                </select>
              </div>
              <div>
                <label
                  for="support-subject"
                  class="block text-sm font-medium mb-2"
                  >{{ t('SYNAPSEOS.SUPPORT.SUBJECT') }}</label
                >
                <InputText
                  id="support-subject"
                  v-model="subject"
                  required
                  maxlength="120"
                  class="w-full !mb-0 !rounded-xl !bg-s-bg !border-s-border !text-s-primary"
                  :placeholder="t('SYNAPSEOS.SUPPORT.SUBJECT_PLACEHOLDER')"
                />
              </div>
              <div>
                <label
                  for="support-description"
                  class="block text-sm font-medium mb-2"
                  >{{ t('SYNAPSEOS.SUPPORT.DESCRIPTION') }}</label
                >
                <Textarea
                  id="support-description"
                  v-model="description"
                  required
                  maxlength="3000"
                  rows="7"
                  class="w-full !mb-0 !rounded-xl !min-h-40 !bg-s-bg !border-s-border !text-s-primary resize-y"
                  :placeholder="t('SYNAPSEOS.SUPPORT.DESCRIPTION_PLACEHOLDER')"
                  aria-describedby="support-description-count"
                />
                <p
                  id="support-description-count"
                  class="text-xs text-s-muted text-end mt-2 mb-0"
                >
                  {{
                    t('SYNAPSEOS.SUPPORT.CHARACTERS', {
                      count: description.length,
                    })
                  }}
                </p>
              </div>
              <div
                class="flex flex-wrap gap-4 items-center justify-between pt-2 border-t border-s-border-subtle"
              >
                <span class="text-xs text-s-muted">{{
                  t('SYNAPSEOS.SUPPORT.IDENTIFIED_AS', {
                    name: currentUser.name,
                  })
                }}</span>
                <Button
                  type="submit"
                  icon="i-lucide-send"
                  :label="
                    t(
                      sending
                        ? 'SYNAPSEOS.SUPPORT.SENDING'
                        : 'SYNAPSEOS.SUPPORT.SEND'
                    )
                  "
                  :disabled="!canSubmit"
                  :is-loading="sending"
                />
              </div>
            </fieldset>
          </form>
        </section>
        <aside class="rounded-2xl bg-s-sidebar text-s-on-dark p-6">
          <span class="i-lucide-message-circle size-7 text-s-accent-500 mb-5" />
          <h2 class="text-base font-semibold text-s-on-dark mb-3">
            {{ t('SYNAPSEOS.SUPPORT.DIRECT_SUPPORT') }}
          </h2>
          <p class="text-sm text-s-on-dark-muted leading-relaxed mb-5">
            {{ t('SYNAPSEOS.SUPPORT.DELIVERY_HINT') }}
          </p>
          <p class="text-xs text-s-on-dark-muted mb-1">
            {{ t('SYNAPSEOS.SUPPORT.DESTINATION') }}
          </p>
          <p class="text-lg font-semibold tabular-nums mb-6">
            {{ destination }}
          </p>
          <div class="border-t border-white/10 pt-5">
            <p class="text-sm font-medium mb-2">
              {{ t('SYNAPSEOS.SUPPORT.HELP_TITLE') }}
            </p>
            <p class="text-sm text-s-on-dark-muted leading-relaxed mb-0">
              {{ t('SYNAPSEOS.SUPPORT.HELP_DESCRIPTION') }}
            </p>
          </div>
        </aside>
      </div>
      <section class="mt-8" :aria-label="t('SYNAPSEOS.SUPPORT.HISTORY')">
        <div class="flex items-center justify-between gap-4 mb-4">
          <h2 class="text-lg font-semibold mb-0">
            {{ t('SYNAPSEOS.SUPPORT.HISTORY') }}
          </h2>
          <Button
            :label="t('SYNAPSEOS.SUPPORT.REFRESH')"
            icon="i-lucide-refresh-cw"
            ghost
            sm
            :disabled="loading"
            @click="loadRequests()"
          />
        </div>
        <div
          v-if="!requests.length && !loading"
          class="rounded-2xl border border-dashed border-s-border p-8 text-center text-sm text-s-muted"
        >
          {{ t('SYNAPSEOS.SUPPORT.EMPTY_HISTORY') }}
        </div>
        <ul v-else class="list-none p-0 m-0 flex flex-col gap-3">
          <li
            v-for="request in requests"
            :key="request.id"
            class="bg-s-surface border border-s-border rounded-xl p-5 flex flex-wrap items-center justify-between gap-4"
          >
            <div class="min-w-0 flex-1">
              <RouterLink
                class="font-semibold text-sm text-s-primary hover:underline break-words"
                :to="
                  accountScopedRoute('inbox_conversation', {
                    conversation_id: request.conversation_id,
                  })
                "
              >
                {{ request.subject }}
              </RouterLink>
              <p class="text-xs text-s-muted mt-2 mb-0">
                {{ request.sender_name }} · {{ request.inbox_name }} ·
                {{ new Date(request.created_at).toLocaleString() }}
              </p>
            </div>
            <span
              class="rounded-full px-3 py-1 text-xs font-medium"
              :class="
                request.status === 'failed'
                  ? 'bg-s-error-soft text-s-error-text'
                  : 'bg-s-subtle text-s-secondary'
              "
              >{{ t(`SYNAPSEOS.SUPPORT.STATUS.${request.status}`) }}</span
            >
          </li>
        </ul>
      </section>
    </div>
  </main>
</template>
