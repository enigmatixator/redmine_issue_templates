# frozen_string_literal: true

module CommunityIssueTemplatesHelper
  def cit_index_path
    @project ? project_community_issue_templates_path(@project) : global_issue_templates_path
  end

  def cit_new_path
    @project ? new_project_community_issue_template_path(@project) : new_global_issue_template_path
  end

  def cit_form_url(template)
    if @project
      template.new_record? ? project_community_issue_templates_path(@project) : project_community_issue_template_path(@project, template)
    else
      template.new_record? ? global_issue_templates_path : global_issue_template_path(template)
    end
  end

  def cit_edit_path(template)
    @project ? edit_project_community_issue_template_path(@project, template) : edit_global_issue_template_path(template)
  end

  def cit_destroy_path(template)
    @project ? project_community_issue_template_path(@project, template) : global_issue_template_path(template)
  end

  def cit_set_default_path(template)
    if @project
      set_default_project_community_issue_template_path(@project, template)
    else
      set_default_global_issue_template_path(template)
    end
  end

  def cit_clear_default_path(template)
    if @project
      clear_default_project_community_issue_template_path(@project, template)
    else
      clear_default_global_issue_template_path(template)
    end
  end

  def cit_editor_trackers
    @project ? @project.trackers.sorted : Tracker.sorted
  end

  def cit_priority_options
    IssuePriority.active.map { |priority| [priority.name, priority.id] }
  end

  def cit_status_options
    IssueStatus.sorted.map { |status| [status.name, status.id] }
  end

  def cit_assignee_users
    users = @project ? @project.assignable_users : User.active.sorted
    Array(users).uniq.sort_by { |user| user.name.to_s.downcase }
  end

  def cit_category_options
    return [] unless @project

    @project.issue_categories.map { |category| [category.name, category.id] }
  end

  def cit_watcher_users
    users = @project ? @project.users.active : User.active
    users = users.sorted if users.respond_to?(:sorted)
    Array(users).uniq.sort_by { |user| user.name.to_s.downcase }
  end

  def cit_editor_custom_fields
    @cit_editor_custom_fields ||= RedmineIssueTemplates::SafeCustomFields.for_editor(@project)
  end

  def cit_custom_field_value(template, field)
    values = template.custom_field_values
    values[field.id.to_s] || values[field.id] || ''
  end

  def cit_selected_tracker_ids
    Array(@selected_tracker_ids).map(&:to_i)
  end
end
