# frozen_string_literal: true

module RedmineIssueTemplates
  # Builds a template in tests and from the Rails console.
  # Project and Administration screens are the normal way to create templates.
  #
  #   RedmineIssueTemplates::TemplateFactory.create!(
  #     project: Project.find(1),
  #     title: 'Bug report',
  #     subject: 'Bug: ',
  #     content: "Steps to reproduce:\n\nExpected:\n",
  #     tracker_ids: [1],
  #     default_for: true
  #   )
  module TemplateFactory
    def self.create!(attributes = {})
      attributes = attributes.to_h.symbolize_keys
      tracker_ids = Array(attributes.delete(:tracker_ids)).flatten.compact
      tracker_ids = Array(attributes.delete(:tracker_id)).compact if tracker_ids.empty?
      if tracker_ids.empty?
        raise ArgumentError, 'Pass tracker_ids so the template can appear on New Issue.'
      end

      default_for = attributes.delete(:default_for)
      template = CommunityIssueTemplate.create!(attributes)
      tracker_ids.each do |tracker_id|
        template.template_trackers.create!(tracker_id: tracker_id)
      end
      create_default!(template, tracker_ids, default_for) if default_for
      template.reload
    end

    def self.create_default!(template, tracker_ids, default_for)
      project_id = template.project_id
      tracker_id = tracker_ids.first
      if default_for.is_a?(Hash)
        project_id = default_for[:project_id] if default_for.key?(:project_id)
        tracker_id = default_for[:tracker_id] if default_for.key?(:tracker_id)
      end
      template.defaults.create!(project_id: project_id, tracker_id: tracker_id)
    end
    private_class_method :create_default!
  end
end
