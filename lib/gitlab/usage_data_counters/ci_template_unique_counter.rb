# frozen_string_literal: true

module Gitlab::UsageDataCounters
  class CiTemplateUniqueCounter
    PREFIX = 'ci_templates'

    class << self
      def track_unique_project_event(project:, template:, config_source:, user:)
        expanded_template_name = expand_template_name(template)
        return unless expanded_template_name

        event_name = ci_template_event_name(expanded_template_name, config_source)
        Gitlab::UsageDataCounters::HLLRedisCounter.track_event(event_name, values: project.id)

        namespace = project.namespace
        Gitlab::InternalEvents.track_event('ci_template_included', namespace: namespace, project: project, user: user)
      end

      def ci_templates(relative_base = 'lib/gitlab/ci/templates')
        Dir.glob('**/*.gitlab-ci.yml', base: Rails.root.join(relative_base))
      end

      def ci_template_event_name(template_name, config_source)
        prefix = 'implicit_' if config_source.to_s == 'auto_devops_source'

        "p_#{PREFIX}_#{prefix}#{template_to_event_name(template_name)}"
      end

      def expand_template_name(template_name)
        Gitlab::Template::GitlabCiYmlTemplate.find(template_name.chomp('.gitlab-ci.yml'))&.full_name
      end

      def all_included_templates(template_name)
        expanded_template_name = expand_template_name(template_name)
        results = [expanded_template_name].tap do |result|
          template = Gitlab::Template::GitlabCiYmlTemplate.find(template_name.chomp('.gitlab-ci.yml'))
          data = Gitlab::Ci::Config::Yaml::Loader.new(template.content).load.content
          [data[:include]].compact.flatten.each do |ci_include|
            if ci_include_template = ci_include[:template]
              result.concat(all_included_templates(ci_include_template))
            end
          end
        end

        results.uniq.sort_by { _1['name'] }
      end

      private

      def template_to_event_name(template)
        ActiveSupport::Inflector.parameterize(template.chomp('.gitlab-ci.yml'), separator: '_').underscore
      end
    end
  end
end
