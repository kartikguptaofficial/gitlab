# frozen_string_literal: true

#
# IMPORTANT: With the new development of the 'gitlab-http' gem (https://gitlab.com/gitlab-org/gitlab/-/issues/415686),
# no additional change should be implemented in this class. This class will be removed after migrating all
# the usages to the new gem.
#

require_relative 'http_connection_adapter'

module Gitlab
  class LegacyHTTP # rubocop:disable Gitlab/NamespacedClass
    include HTTParty # rubocop:disable Gitlab/HTTParty

    class << self
      alias_method :httparty_perform_request, :perform_request
    end

    connection_adapter ::Gitlab::HTTPConnectionAdapter

    def self.perform_request(http_method, path, options, &block)
      raise_if_blocked_by_silent_mode(http_method)

      log_info = options.delete(:extra_log_info)
      options_with_timeouts =
        if !options.has_key?(:timeout)
          options.with_defaults(Gitlab::HTTP::DEFAULT_TIMEOUT_OPTIONS)
        else
          options
        end

      return httparty_perform_request(http_method, path, options_with_timeouts, &block) if options[:stream_body]

      start_time = nil
      read_total_timeout = options.fetch(:timeout, Gitlab::HTTP::DEFAULT_READ_TOTAL_TIMEOUT)

      httparty_perform_request(http_method, path, options_with_timeouts) do |fragment|
        start_time ||= ::Gitlab::Metrics::System.monotonic_time
        elapsed = ::Gitlab::Metrics::System.monotonic_time - start_time

        if elapsed > read_total_timeout
          raise Gitlab::HTTP::ReadTotalTimeout, "Request timed out after #{elapsed} seconds"
        end

        yield fragment if block
      end
    rescue HTTParty::RedirectionTooDeep
      raise Gitlab::HTTP::RedirectionTooDeep
    rescue *Gitlab::HTTP::HTTP_ERRORS => e
      extra_info = log_info || {}
      extra_info = log_info.call(e, path, options) if log_info.respond_to?(:call)
      Gitlab::ErrorTracking.log_exception(e, extra_info)
      raise e
    end

    def self.try_get(path, options = {}, &block)
      self.get(path, options, &block) # rubocop:disable Style/RedundantSelf
    rescue *Gitlab::HTTP::HTTP_ERRORS
      nil
    end

    def self.raise_if_blocked_by_silent_mode(http_method)
      return unless blocked_by_silent_mode?(http_method)

      ::Gitlab::SilentMode.log_info(
        message: 'Outbound HTTP request blocked',
        outbound_http_request_method: http_method.to_s
      )

      raise Gitlab::HTTP::SilentModeBlockedError,
        'only get, head, options, and trace methods are allowed in silent mode'
    end

    def self.blocked_by_silent_mode?(http_method)
      ::Gitlab::SilentMode.enabled? && Gitlab::HTTP::SILENT_MODE_ALLOWED_METHODS.exclude?(http_method)
    end
  end
end
