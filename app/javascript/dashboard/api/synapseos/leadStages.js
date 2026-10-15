/* global axios */
// CUSTOMIZAÇÃO_SYNAPSEOS — estágio do lead por conversa (display_id), em lote.
import ApiClient from '../ApiClient';

class LeadStagesAPI extends ApiClient {
  constructor() {
    super('synapseos/leads/stages', { accountScoped: true });
  }

  get(displayIds) {
    return axios.get(this.url, { params: { display_ids: displayIds } });
  }
}

export default new LeadStagesAPI();
