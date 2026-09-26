# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class CommunityIssueTemplateDefaultTest < ActiveSupport::TestCase
  include CommunityIssueTemplatesTestSupport

  fixtures :projects, :users, :roles, :members, :member_roles, :trackers,
           :projects_trackers, :enabled_modules, :enumerations, :issue_statuses

  def setup
    reset_template_plugin_settings!
    @project = Project.find(1)
    @tracker = Tracker.find(1)
  end

  def teardown
    reset_template_plugin_settings!
  end

  def test_project_default_wins_over_global
    global = create_template!(project: nil, title: 'Global', subject: 'Global subject', tracker_ids: [1], default_for: true)
    project = create_template!(project: @project, title: 'Project', subject: 'Project subject', tracker_ids: [1], default_for: true)

    found = CommunityIssueTemplateDefault.for_tracker(@project, @tracker)
    assert_equal project.id, found.community_issue_template_id
    assert_not_equal global.id, found.community_issue_template_id
  end

  def test_global_default_is_the_fallback
    global = create_template!(project: nil, title: 'Global', subject: 'Global subject', tracker_ids: [1], default_for: true)

    found = CommunityIssueTemplateDefault.for_tracker(@project, @tracker)
    assert_equal global.id, found.community_issue_template_id
    assert_nil CommunityIssueTemplateDefault.for_tracker(@project, Tracker.find(2))
  end

  def test_disabled_project_default_falls_through_to_global
    global = create_template!(project: nil, title: 'Global', tracker_ids: [1], default_for: true)
    project = create_template!(project: @project, title: 'Project', tracker_ids: [1], enabled: false, default_for: true)
    assert_not project.enabled?

    found = CommunityIssueTemplateDefault.for_tracker(@project, @tracker)
    assert_equal global.id, found.community_issue_template_id
  end

  def test_global_fallback_is_skipped_when_global_templates_are_off
    create_template!(project: nil, title: 'Global', tracker_ids: [1], default_for: true)
    Setting.plugin_redmine_issue_templates = {
      'confirm_overwrite_on_tracker_change' => '1',
      'apply_global_templates' => '0'
    }

    assert_nil CommunityIssueTemplateDefault.for_tracker(@project, @tracker)
  end

  def test_project_default_may_point_at_a_global_template_when_global_apply_is_off
    global = create_template!(project: nil, title: 'Global', tracker_ids: [1])
    CommunityIssueTemplateDefault.create!(
      project: @project,
      tracker: @tracker,
      template: global
    )
    Setting.plugin_redmine_issue_templates = {
      'confirm_overwrite_on_tracker_change' => '1',
      'apply_global_templates' => '0'
    }

    found = CommunityIssueTemplateDefault.for_tracker(@project, @tracker)
    assert_equal global.id, found.community_issue_template_id
  end

  def test_one_default_per_project_and_tracker
    first = create_template!(project: @project, title: 'First', tracker_ids: [1], default_for: true)
    second = create_template!(project: @project, title: 'Second', tracker_ids: [1])
    duplicate = CommunityIssueTemplateDefault.new(project: @project, tracker: @tracker, template: second)

    assert_not duplicate.valid?
    assert_equal first.id, CommunityIssueTemplateDefault.for_tracker(@project, @tracker).community_issue_template_id
  end

  def test_rejects_a_template_that_is_not_linked_to_the_tracker
    template = create_template!(project: @project, title: 'Bug only', tracker_ids: [1])
    row = CommunityIssueTemplateDefault.new(project: @project, tracker_id: 2, template: template)

    assert_not row.valid?
    assert row.errors[:community_issue_template_id].present?
  end

  def test_global_default_cannot_point_at_a_project_template
    template = create_template!(project: @project, title: 'Project', tracker_ids: [1])
    row = CommunityIssueTemplateDefault.new(project_id: nil, tracker_id: 1, template: template)

    assert_not row.valid?
    assert row.errors[:community_issue_template_id].present?
  end
end
