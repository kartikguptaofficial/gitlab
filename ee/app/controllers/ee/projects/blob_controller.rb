# frozen_string_literal: true

module EE
  module Projects
    module BlobController
      extend ActiveSupport::Concern

      prepended do
        before_action do
          push_licensed_feature(:remote_development)
        end
      end
    end
  end
end
