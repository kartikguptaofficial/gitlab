# frozen_string_literal: true
module Groups
  class ObservabilityController < Groups::ApplicationController
    feature_category :tracing

    content_security_policy do |p|
      next if p.directives.blank?

      default_frame_src = p.directives['frame-src'] || p.directives['default-src']

      # When ObservabilityUI is not authenticated, it needs to be able to redirect to the GL sign-in page, hence 'self'
      frame_src_values = Array.wrap(default_frame_src) | [observability_url, "'self'"]

      p.frame_src(*frame_src_values)
    end

    before_action :check_observability_allowed, only: :index

    def index
      # Format: https://observe.gitlab.com/-/GROUP_ID
      @observability_iframe_src = "#{observability_url}/-/#{@group.id}"

      render layout: 'group', locals: { base_layout: 'layouts/fullscreen' }
    end

    private

    def self.observability_url
      Gitlab::Observability.observability_url
    end

    def observability_url
      self.class.observability_url
    end

    def check_observability_allowed
      return render_404 unless observability_url.present?

      render_404 unless can?(current_user, :read_observability, @group)
    end
  end
end
