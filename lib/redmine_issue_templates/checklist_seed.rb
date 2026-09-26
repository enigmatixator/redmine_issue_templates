# frozen_string_literal: true

module RedmineIssueTemplates
  # After a new issue is saved, copy the selected template's checklist lines
  # onto the issue when Issue Checklists is installed.
  # Missing plugin, missing association, or missing :manage_issue_checklists
  # skips the seed. Issue creation has already succeeded and must stay successful.
  class ChecklistSeed
    def self.call(issue, params = nil)
      new(issue, params).call
    end

    # IssueChecklist::MAX_ITEMS_PER_ISSUE when that plugin is loaded, else 50.
    def self.item_limit
      checklist = Object.const_get(:IssueChecklist) if Object.const_defined?(:IssueChecklist, false)
      if checklist && checklist.const_defined?(:MAX_ITEMS_PER_ISSUE, false)
        checklist::MAX_ITEMS_PER_ISSUE
      else
        50
      end
    end

    def initialize(issue, params)
      @issue = issue
      @params = params
    end

    def call
      return unless RedmineIssueTemplates.checklists_plugin_present?
      return if @issue.blank? || !@issue.persisted?
      return unless @issue.respond_to?(:issue_checklists)

      template = selected_template
      return unless template
      return unless User.current.allowed_to?(:manage_issue_checklists, @issue.project)

      lines = seed_lines(template)
      return if lines.empty?

      lines.each_with_index do |subject, index|
        @issue.issue_checklists.create!(
          subject: subject,
          is_done: false,
          position: index + 1
        )
      end
    rescue NameError, StandardError => e
      Rails.logger.warn(
        "[redmine_issue_templates] checklist seed skipped: #{e.class}: #{e.message}"
      )
    end

    private

    def selected_template
      id = template_id
      return nil unless id

      project = @issue.project
      return nil unless project
      return nil unless User.current.allowed_to?(:use_issue_templates, project)

      CommunityIssueTemplate.visible_for(project).find_by(id: id)
    end

    def template_id
      raw = parameter_hash[:community_issue_template_id]
      return nil if raw.blank?

      number = Integer(raw)
      number.positive? ? number : nil
    rescue ArgumentError, TypeError
      nil
    end

    def parameter_hash
      raw = @params
      raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
      return {}.with_indifferent_access unless raw.is_a?(Hash)

      raw.with_indifferent_access
    rescue StandardError
      {}.with_indifferent_access
    end

    def seed_lines(template)
      limit = self.class.item_limit
      template.checklist_items.to_s.split(/\r?\n/).filter_map do |line|
        text = line.to_s.strip
        next if text.empty?

        text.length > 255 ? text[0, 255] : text
      end.first(limit)
    end
  end
end
