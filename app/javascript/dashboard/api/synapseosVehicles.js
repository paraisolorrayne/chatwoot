/* global axios */
import ApiClient from './ApiClient';

// CUSTOMIZAÇÃO_SYNAPSEOS: base de conhecimento de veículos.
class SynapseosVehiclesAPI extends ApiClient {
  constructor() {
    super('synapseos/vehicles', { accountScoped: true });
  }

  schema() {
    return axios.get(`${this.url}/schema`);
  }

  // commit=false devolve só a prévia (novos/atualizados/iguais + avisos).
  importSpreadsheet(file, commit) {
    const form = new FormData();
    form.append('file', file);
    form.append('commit', commit ? 'true' : 'false');
    return axios.post(`${this.url}/import`, form);
  }
}

export default new SynapseosVehiclesAPI();
