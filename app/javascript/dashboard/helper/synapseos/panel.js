// CUSTOMIZAÇÃO_SYNAPSEOS: painel agentic (a "Plataforma"). Só a equipe Dexi
// acessa (permissão synapseos_platform). O login vem do Chatwoot: em nova aba
// pelo fragmento #cwsso=; embutido, por postMessage (ver PlatformPage.vue).
export const SYNAPSEOS_PANEL_URL = 'https://painel.dexidigital.com.br';
export const SYNAPSEOS_PANEL_ORIGIN = new URL(SYNAPSEOS_PANEL_URL).origin;

export const openPanelInNewTab = token => {
  const url = token
    ? `${SYNAPSEOS_PANEL_URL}/#cwsso=${encodeURIComponent(token)}`
    : SYNAPSEOS_PANEL_URL;
  window.open(url, '_blank', 'noopener,noreferrer');
};
