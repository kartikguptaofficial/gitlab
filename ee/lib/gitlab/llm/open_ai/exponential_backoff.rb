# frozen_string_literal: true

module Gitlab
  module Llm
    module OpenAi
      module ExponentialBackoff
        INITIAL_DELAY = 1.second
        EXPONENTIAL_BASE = 2
        MAX_RETRIES = 3
        RateLimitError = Class.new(StandardError)

        def self.included(base)
          base.extend(ExponentialBackoff)
        end

        def retry_methods_with_exponential_backoff(*method_names)
          method_names.each do |method_name|
            original_method = instance_method(method_name)

            define_method(method_name) do |*args, **kwargs|
              retry_with_exponential_backoff do
                original_method.bind_call(self, *args, **kwargs)
              end
            end
          end
        end

        private

        def retry_with_exponential_backoff
          retries = 0
          delay = INITIAL_DELAY

          loop do
            response = yield

            return if response.nil?
            return response unless response.too_many_requests?

            retries += 1
            raise RateLimitError, "Maximum number of retries (#{MAX_RETRIES}) exceeded." if retries >= MAX_RETRIES

            delay *= EXPONENTIAL_BASE * (1 + Random.rand)
            sleep delay
            next
          end
        end
      end
    end
  end
end
