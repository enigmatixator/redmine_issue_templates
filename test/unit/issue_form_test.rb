# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class RedmineIssueTemplatesIssueFormTest < ActiveSupport::TestCase
  include CommunityIssueTemplatesTestSupport

  fixtures :projects, :users, :roles, :members, :member_roles, :trackers,
           :projects_trackers, :issues, :issue_statuses, :enumerations,
           :enabled_modules

  def setup
    reset_template_plugin_settings!
    @project = enable_issue_templates!
    grant_use_issue_templates!
    User.current = User.find(2)
  end

  def teardown
    reset_template_plugin_settings!
    User.current = nil
  end

  def test_renders_templates_for_the_current_tracker_on_a_new_issue
    template = create_template!(
      project: @project,
      title: 'Bug report',
      subject: 'Bug: ',
      tracker_ids: [1],
      default_for: true
    )
    create_template!(project: @project, title: 'Feature', tracker_ids: [2])
    form = RedmineIssueTemplates::IssueForm.new(new_issue)

    assert form.render?
    assert_equal [template.id], form.templates.map(&:id)
    assert_equal template.id, form.default_template_id
    assert form.confirm_overwrite?
    data = form.select_data('/templates/__ID__')
    assert_equal '1', data[:confirm_overwrite]
    assert_equal template.id, data[:initial_default_id]
    assert data[:ignored_message].present?
  end

  def test_does_not_render_without_use_permission
    create_template!(project: @project, title: 'Bug report', tracker_ids: [1])
    Role.find(1).remove_permission!(:use_issue_templates)
    form = RedmineIssueTemplates::IssueForm.new(new_issue)

    assert_not form.render?
  end

  def test_does_not_render_without_add_issues
    create_template!(project: @project, title: 'Bug report', tracker_ids: [1])
    Role.find(1).remove_permission!(:add_issues)
    form = RedmineIssueTemplates::IssueForm.new(new_issue)

    assert_not form.render?
  end

  def test_does_not_render_when_the_module_is_off_or_the_issue_already_exists
    create_template!(project: @project, title: 'Bug report', tracker_ids: [1])
    @project.disable_module!(:issue_templates)
    @project.reload
    assert_not RedmineIssueTemplates::IssueForm.new(new_issue).render?

    @project.enable_module!(:issue_templates)
    assert_not RedmineIssueTemplates::IssueForm.new(Issue.find(1)).render?
  end

  def test_does_not_render_when_the_tracker_has_no_template
    create_template!(project: @project, title: 'Feature', tracker_ids: [2])
    form = RedmineIssueTemplates::IssueForm.new(new_issue)

    assert_not form.render?
  end

  private

  def new_issue
    Issue.new(project: @project, tracker: Tracker.find(1))
  end
end
