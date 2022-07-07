# frozen_string_literal: true

module Gitlab
  module Ci
    class RunnerReleases
      include Singleton

      RELEASES_VALIDITY_PERIOD = 1.day

      INITIAL_BACKOFF = 5.seconds
      MAX_BACKOFF = 1.hour
      BACKOFF_GROWTH_FACTOR = 2.0

      def initialize
        reset_backoff!
      end

      def expired?
        backoff_active? || !Rails.cache.exist?(cache_key)
      end

      # Returns a sorted list of the publicly available GitLab Runner releases
      #
      def releases
        return if backoff_active?

        Rails.cache.fetch(
          cache_key,
          skip_nil: true,
          expires_in: RELEASES_VALIDITY_PERIOD,
          race_condition_ttl: 10.seconds
        ) do
          response = Gitlab::HTTP.try_get(runner_releases_url)

          unless response.success?
            @backoff_expire_time = next_backoff.from_now
            break nil
          end

          reset_backoff!
          extract_releases(response)
        end
      end

      def reset_backoff!
        @backoff_expire_time = nil
        @backoff_count = 0
      end

      private

      def runner_releases_url
        @runner_releases_url ||= ::Gitlab::CurrentSettings.current_application_settings.public_runner_releases_url
      end

      def cache_key
        runner_releases_url
      end

      def backoff_active?
        return unless @backoff_expire_time

        Time.now.utc < @backoff_expire_time
      end

      def extract_releases(response)
        response.parsed_response.map { |release| parse_runner_release(release) }.sort!
      end

      def parse_runner_release(release)
        ::Gitlab::VersionInfo.parse(release['name'], parse_suffix: true)
      end

      def next_backoff
        return MAX_BACKOFF if @backoff_count >= 11 # optimization to prevent expensive exponentiation and possible overflows

        backoff = (INITIAL_BACKOFF * (BACKOFF_GROWTH_FACTOR**@backoff_count))
          .clamp(INITIAL_BACKOFF, MAX_BACKOFF)
          .seconds
        @backoff_count += 1

        backoff
      end
    end
  end
end
