# frozen_string_literal: true

module RedmineIssueTemplates
  # Decides whether the new-issue form shows a template select.
  class IssueForm
    def initialize(issue, user = User.current)
      @issue = issue
      @user = user || User.current
    end

    def render?
      return false unless @issue&.new_record?
      return false unless project && tracker
      return false unless project.module_enabled?(:issue_templates)
      return false unless @user.allowed_to?(:use_issue_templates, project)
      return false unless @user.allowed_to?(:add_issues, project)

      templates.any?
    end

    def templates
      @templates ||= CommunityIssueTemplate.available_for(project, tracker).to_a
    end

    def default_template_id
      return nil unless tracker

      row = CommunityIssueTemplateDefault.for_tracker(project, tracker)
      template_id = row&.community_issue_template_id
      return nil unless template_id && templates.any? { |template| template.id == template_id }

      template_id
    end

    def confirm_overwrite?
      RedmineIssueTemplates.confirm_overwrite_on_tracker_change?
    end

    def option_pairs
      pairs = [[I18n.t(:label_community_issue_template_blank), '']]
      templates.each { |template| pairs << [template.title, template.id] }
      pairs
    end

    def select_data(load_url_template)
      data = {
        load_url_template: load_url_template,
        confirm_overwrite: confirm_overwrite? ? '1' : '0',
        confirm_message: I18n.t(:text_community_issue_template_confirm_overwrite),
        applied_message: I18n.t(:text_community_issue_template_default_applied),
        ignored_message: I18n.t(:text_community_issue_template_fields_skipped),
        error_message: I18n.t(:text_community_issue_template_load_failed)
      }
      data[:initial_default_id] = default_template_id if default_template_id
      data
    end

    private

    def project
      @issue&.project
    end

    def tracker
      @issue&.tracker
    end
  end
end
