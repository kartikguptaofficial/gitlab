# frozen_string_literal: true

module EE
  module API
    module Entities
      module ConanPackage
        class ConanPackageManifest < Grape::Entity
          expose :package_urls, merge: true
        end
      end
    end
  end
end
