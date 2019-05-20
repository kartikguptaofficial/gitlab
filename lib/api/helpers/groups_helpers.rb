# frozen_string_literal: true

module API
  module Helpers
    module GroupsHelpers
      extend ActiveSupport::Concern
    end
  end
end

API::Helpers::GroupsHelpers.prepend(EE::API::Helpers::GroupsHelpers)
