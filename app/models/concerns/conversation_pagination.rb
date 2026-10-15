module ConversationPagination
  DEFAULT_PAGE_SIZE = 100
  MAX_PAGE_SIZE = 200

  def self.page_size
    ENV.fetch('CONVERSATION_RESULTS_PER_PAGE', DEFAULT_PAGE_SIZE).to_i.clamp(1, MAX_PAGE_SIZE)
  end
end
