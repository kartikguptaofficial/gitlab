# frozen_string_literal: true

module Gitlab
  module Tracking
    InvalidEventError = Class.new(RuntimeError)

    class EventDefinition
      EVENT_SCHEMA_PATH = Rails.root.join('config', 'events', 'schema.json')
      SCHEMA = ::JSONSchemer.schema(Pathname.new(EVENT_SCHEMA_PATH))

      attr_reader :path
      attr_reader :attributes

      class << self
        def paths
          @paths ||= [Rails.root.join('config', 'events', '*.yml'), Rails.root.join('ee', 'config', 'events', '*.yml')]
        end

        def definitions
          paths.flat_map { |glob_path| load_all_from_path(glob_path) }
        end

        private

        def load_from_file(path)
          definition = File.read(path)
          definition = YAML.safe_load(definition)
          definition.deep_symbolize_keys!

          self.new(path, definition).tap(&:validate!)
        rescue StandardError => e
          Gitlab::ErrorTracking.track_and_raise_for_dev_exception(Gitlab::Tracking::InvalidEventError.new(e.message))
        end

        def load_all_from_path(glob_path)
          Dir.glob(glob_path).map { |path| load_from_file(path) }
        end
      end

      def initialize(path, opts = {})
        @path = path
        @attributes = opts
      end

      def to_h
        attributes
      end
      alias_method :to_dictionary, :to_h

      def yaml_path
        path.delete_prefix(Rails.root.to_s)
      end

      def validate!
        SCHEMA.validate(attributes.stringify_keys).each do |error|
          error_message = <<~ERROR_MSG
            Error type: #{error['type']}
            Data: #{error['data']}
            Path: #{error['data_pointer']}
            Details: #{error['details']}
            Definition file: #{path}
          ERROR_MSG

          Gitlab::ErrorTracking.track_and_raise_for_dev_exception(Gitlab::Tracking::InvalidEventError.new(error_message))
        end
      end

      private

      def method_missing(method, *args)
        attributes[method] || super
      end
    end
  end
end
