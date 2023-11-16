# frozen_string_literal: true

module QA
  module Scenario
    class Template
      class << self
        def perform(...)
          new.tap do |scenario|
            yield scenario if block_given?
            break scenario.perform(...)
          end
        end

        def tags(*tags)
          @tags = tags
        end

        def focus
          @tags.to_a
        end
      end

      def perform(options, *args)
        define_gitlab_address(args)

        # Store passed options globally
        Support::GlobalOptions.set(options)

        # Save the scenario class name
        Runtime::Scenario.define(:klass, self.class.name)

        # Set large setup attribute
        Runtime::Scenario.define(:large_setup?, args.include?('can_use_large_setup'))

        Specs::Runner.perform do |specs|
          specs.tty = true
          specs.tags = self.class.focus
          specs.options = args if args.any?
        end
      end

      private

      delegate :define_gitlab_address_attribute!, to: QA::Support::GitlabAddress

      # Define gitlab address attribute
      #
      # Use first argument if a valid address, else use named argument or default to environment variable
      #
      # @param [Array] args
      # @return [void]
      def define_gitlab_address(args)
        address_from_opt = Runtime::Scenario.attributes[:gitlab_address]

        return define_gitlab_address_attribute!(args.shift) if args.first && Runtime::Address.valid?(args.first)
        return define_gitlab_address_attribute!(address_from_opt) if address_from_opt

        define_gitlab_address_attribute!
      end
    end
  end
end

QA::Scenario::Template.prepend_mod_with('Scenario::Template', namespace: QA)
