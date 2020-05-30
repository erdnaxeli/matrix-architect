module Matrix::Architect
  module Errors
    struct RateLimited
      getter retry_after_ms : Int32

      def initialize(payload)
        @retry_after_ms = payload["retry_after_ms"].as_i
      end
    end
  end
end
