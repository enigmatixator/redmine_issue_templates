# frozen_string_literal: true

require File.expand_path('../../../test/test_helper', __dir__)

module CommunityIssueTemplatesTestSupport
  def enable_issue_templates!(project = Project.find(1))
    project.enable_module!(:issue_templates) unless project.module_enabled?(:issue_templates)
    project
  end

  def grant_use_issue_templates!(role = Role.find(1))
    role.add_permission!(:use_issue_templates)
    role
  end

  def grant_manage_issue_templates!(role = Role.find(1))
    role.add_permission!(:manage_issue_templates)
    role
  end

  def create_issue_custom_field!(attributes = {})
    attributes = attributes.symbolize_keys
    tracker_ids = Array(attributes.delete(:tracker_ids) || [1])
    field = IssueCustomField.new(attributes)
    field.is_for_all = true if attributes[:is_for_all].nil?
    field.save!
    field.trackers = Tracker.where(id: tracker_ids).to_a
    field
  end

  def create_template!(attributes = {})
    RedmineIssueTemplates::TemplateFactory.create!(attributes)
  end

  # Minitest 6 does not mix Object#stub into tests. Override the predicate
  # for the block, then restore the real plugin check.
  def with_checklists_plugin(present)
    RedmineIssueTemplates.define_singleton_method(:checklists_plugin_present?) { present }
    yield
  ensure
    RedmineIssueTemplates.define_singleton_method(:checklists_plugin_present?) do
      Redmine::Plugin.installed?(:redmine_issue_checklists)
    end
  end

  def reset_template_plugin_settings!
    Setting.plugin_redmine_issue_templates = {
      'confirm_overwrite_on_tracker_change' => '1',
      'apply_global_templates' => '1'
    }
    Setting.clear_cache if Setting.respond_to?(:clear_cache)
  end
end
