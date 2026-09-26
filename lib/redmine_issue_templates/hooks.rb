# frozen_string_literal: true

module RedmineIssueTemplates
  class Hooks < Redmine::Hook::ViewListener
    # Renders immediately above the tracker field inside the new-issue form.
    # The script moves the control to sit directly under the tracker select.
    render_on :view_issues_form_details_top,
              partial: 'community_issue_templates/form_select'

    render_on :view_layouts_base_html_head,
              partial: 'community_issue_templates/html_head'
  end

  # Runs only after IssuesController has saved a new issue.
  class ChecklistSeedListener < Redmine::Hook::Listener
    def controller_issues_new_after_save(context = {})
      context ||= {}
      ChecklistSeed.call(context[:issue], context[:params])
    end
  end
end
