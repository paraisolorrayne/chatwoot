import ApiClient from './ApiClient';

class SupportRequestsAPI extends ApiClient {
  constructor() {
    super('synapseos/support_requests', { accountScoped: true });
  }
}

export default new SupportRequestsAPI();
