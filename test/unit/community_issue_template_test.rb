# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class CommunityIssueTemplateTest < ActiveSupport::TestCase
  include CommunityIssueTemplatesTestSupport

  fixtures :projects, :users, :roles, :members, :member_roles, :trackers,
           :projects_trackers, :enabled_modules, :enumerations, :issue_statuses

  def setup
    reset_template_plugin_settings!
    @project = Project.find(1)
  end

  def teardown
    reset_template_plugin_settings!
    User.current = nil
  end

  def test_classic_detection_does_not_treat_this_plugin_as_classic
    plugin = Redmine::Plugin.find(:redmine_issue_templates)
    assert_equal 'Issue Templates', plugin.name
    assert_not RedmineIssueTemplates.classic_plugin_installed?
  end

  def test_table_name_does_not_use_the_classic_plugin_tables
    assert_equal 'community_issue_templates', CommunityIssueTemplate.table_name
    assert_equal 'community_issue_template_trackers', CommunityIssueTemplateTracker.table_name
    assert_equal 'community_issue_template_defaults', CommunityIssueTemplateDefault.table_name
  end

  def test_migration_declares_reversible_drops
    path = File.expand_path('../../db/migrate/001_create_community_issue_templates.rb', __dir__)
    source = File.read(path)
    assert_includes source, 'ActiveRecord::Migration[8.0]'
    assert_includes source, 'def down'
    assert_includes source, 'drop_table :community_issue_template_defaults'
    assert_includes source, 'drop_table :community_issue_template_trackers'
    assert_includes source, 'drop_table :community_issue_templates'
    assert_not_includes source, 'create_table :issue_templates '
  end

  def test_requires_title
    template = CommunityIssueTemplate.new(title: '   ', project: @project, enabled: true)
    assert_not template.valid?
    assert template.errors[:title].present?
  end

  def test_strips_title_and_accepts_disabled
    template = create_template!(
      project: @project,
      title: '  Bug report  ',
      subject: 'Bug: ',
      content: 'Steps',
      enabled: false,
      tracker_ids: [1]
    )
    assert_equal 'Bug report', template.title
    assert_not template.enabled?
  end

  def test_rejects_non_positive_position
    template = CommunityIssueTemplate.new(title: 'Bug', project: @project, enabled: false, position: 0)
    assert_not template.valid?
    assert template.errors[:position].present?
    assert_empty template.errors[:enabled]
  end

  def test_blank_position_becomes_positive
    template = CommunityIssueTemplate.new(title: 'Bug', project: @project, enabled: true, position: nil)
    assert template.valid?
    assert template.position.to_i.positive?
  end

  def test_destroys_tracker_links_and_defaults_with_the_template
    assert_equal :destroy, CommunityIssueTemplate.reflect_on_association(:template_trackers).options[:dependent]
    assert_equal :destroy, CommunityIssueTemplate.reflect_on_association(:defaults).options[:dependent]
    assert_equal 'template_trackers',
                 CommunityIssueTemplate.reflect_on_association(:trackers).options[:through].to_s
  end

  def test_tracker_link_is_unique
    template = create_template!(project: @project, title: 'Bug', tracker_ids: [1])
    duplicate = template.template_trackers.build(tracker_id: 1)
    assert_not duplicate.valid?
  end

  def test_available_for_includes_project_and_global_templates_for_the_tracker
    project_template = create_template!(project: @project, title: 'Project bug', tracker_ids: [1], position: 1)
    global_template = create_template!(project: nil, title: 'Global bug', tracker_ids: [1], position: 2)
    create_template!(project: @project, title: 'Feature only', tracker_ids: [2])
    create_template!(project: @project, title: 'Disabled', tracker_ids: [1], enabled: false)
    create_template!(project: Project.find(2), title: 'Other project', tracker_ids: [1])

    ids = CommunityIssueTemplate.available_for(@project, Tracker.find(1)).pluck(:id)
    assert_equal [project_template.id, global_template.id], ids
  end

  def test_available_for_hides_global_templates_when_the_setting_is_off
    create_template!(project: nil, title: 'Global bug', tracker_ids: [1])
    project_template = create_template!(project: @project, title: 'Project bug', tracker_ids: [1])
    Setting.plugin_redmine_issue_templates = {
      'confirm_overwrite_on_tracker_change' => '1',
      'apply_global_templates' => '0'
    }

    ids = CommunityIssueTemplate.available_for(@project, Tracker.find(1)).pluck(:id)
    assert_equal [project_template.id], ids
  end

  def test_apply_payload_returns_subject_description_and_tracker
    template = create_template!(
      project: @project,
      title: 'Bug report',
      subject: 'Bug: login',
      content: "Steps to reproduce\n\nExpected",
      tracker_ids: [1, 2],
      priority_id: 4,
      builtin_fields: { '1' => 'server' },
      watcher_user_ids: [2]
    )
    template.reload

    payload = template.apply_payload(current_tracker_id: 1)
    assert_equal template.id, payload[:id]
    assert_equal 'Bug: login', payload[:subject]
    assert_equal "Steps to reproduce\n\nExpected", payload[:description]
    assert_equal 1, payload[:tracker_id]
    assert_equal [1, 2], payload[:tracker_ids]
    assert_equal 4, payload[:priority_id]
    assert_nil payload[:status_id]
    assert_equal [2], payload[:watcher_user_ids]
    assert_equal({ '1' => 'server' }, payload[:builtin_fields])
  end

  def test_apply_payload_suggests_a_bound_tracker_when_the_current_one_does_not_match
    template = create_template!(project: @project, title: 'Feature', tracker_ids: [2])
    payload = template.apply_payload(current_tracker_id: 1)
    assert_equal 2, payload[:tracker_id]
  end

  def test_confirm_overwrite_setting_defaults_on_and_can_be_disabled
    assert RedmineIssueTemplates::CONFIRM_OVERWRITE_ON_TRACKER_CHANGE_DEFAULT
    assert RedmineIssueTemplates.confirm_overwrite_on_tracker_change?

    Setting.plugin_redmine_issue_templates = {
      'confirm_overwrite_on_tracker_change' => '0',
      'apply_global_templates' => '1'
    }
    assert_not RedmineIssueTemplates.confirm_overwrite_on_tracker_change?
  end

  def test_factory_links_trackers_and_optional_default
    template = create_template!(
      project: @project,
      title: 'Support',
      subject: 'Support: ',
      content: 'What happened?',
      tracker_ids: [1, 3],
      default_for: true
    )
    assert_equal [1, 3], template.template_trackers.order(:tracker_id).pluck(:tracker_id)
    assert_equal template.id, CommunityIssueTemplateDefault.for_tracker(@project, Tracker.find(1)).community_issue_template_id
  end
end
