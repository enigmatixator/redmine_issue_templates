# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class IssueTemplatesCommunityIssuesControllerTest < Redmine::ControllerTest
  include CommunityIssueTemplatesTestSupport

  tests IssuesController

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles,
           :members, :member_roles, :issues, :issue_statuses, :trackers,
           :projects_trackers, :enabled_modules, :enumerations, :workflows,
           :issue_categories, :versions, :custom_fields, :custom_values,
           :custom_fields_projects, :custom_fields_trackers

  def setup
    reset_template_plugin_settings!
    @project = enable_issue_templates!
    grant_use_issue_templates!
  end

  def teardown
    reset_template_plugin_settings!
  end

  def test_new_issue_renders_template_select_when_templates_exist
    template = create_template!(
      project: @project,
      title: 'Bug report',
      subject: 'Bug: ',
      content: 'Steps',
      tracker_ids: [1],
      default_for: true
    )
    @request.session[:user_id] = 2

    get :new, params: { project_id: @project.id }
    assert_response :success
    assert_select 'select#community_issue_template_id'
    assert_select "option[value='#{template.id}']", text: 'Bug report'
    assert_select '#community_issue_template_id[data-confirm-overwrite=?]', '1'
    assert_select '#community_issue_template_id[data-initial-default-id=?]', template.id.to_s
    assert_select '#community_issue_template_id[data-ignored-message]'
    assert_match %r{issue_templates/__ID__}, response.body
    assert_match 'issue_templates', response.body
  end

  def test_new_issue_omits_the_select_without_a_template_for_the_tracker
    create_template!(project: @project, title: 'Feature', tracker_ids: [2])
    @request.session[:user_id] = 2

    get :new, params: { project_id: @project.id }
    assert_response :success
    assert_select 'select#community_issue_template_id', count: 0
  end

  def test_new_issue_omits_the_select_without_permission
    create_template!(project: @project, title: 'Bug report', tracker_ids: [1])
    @request.session[:user_id] = 3

    get :new, params: { project_id: @project.id }
    assert_response :success
    assert_select 'select#community_issue_template_id', count: 0
  end

  def test_edit_issue_does_not_render_the_template_select
    create_template!(project: @project, title: 'Bug report', tracker_ids: [1])
    @request.session[:user_id] = 2

    get :edit, params: { id: 1 }
    assert_response :success
    assert_select 'select#community_issue_template_id', count: 0
  end

  def test_create_seeds_checklist_items_when_plugin_and_permission_are_present
    template = seed_template
    grant_manage_checklists!
    @request.session[:user_id] = 2

    assert_difference 'Issue.count', 1 do
      with_checklists_plugin(true) do
        post :create, params: new_issue_params(template)
      end
    end
    assert_response :redirect

    issue = Issue.order(:id).last
    assert_equal 'Seeded subject', issue.subject
    if issue.respond_to?(:issue_checklists)
      rows = issue.issue_checklists.order(:position, :id).to_a
      assert_equal %w[Alpha Beta], rows.map(&:subject)
      assert rows.all? { |row| !row.is_done? }
      assert_equal [1, 2], rows.map(&:position)
    else
      assert issue.persisted?
    end
  end

  def test_create_skips_checklist_seed_without_manage_permission
    template = seed_template
    revoke_manage_checklists!
    @request.session[:user_id] = 2

    assert_difference 'Issue.count', 1 do
      with_checklists_plugin(true) do
        post :create, params: new_issue_params(template)
      end
    end
    assert_response :redirect

    issue = Issue.order(:id).last
    assert_equal 0, checklist_count(issue)
  end

  def test_create_succeeds_without_seeding_when_checklists_plugin_is_absent
    template = seed_template
    grant_manage_checklists!
    @request.session[:user_id] = 2

    assert_difference 'Issue.count', 1 do
      with_checklists_plugin(false) do
        post :create, params: new_issue_params(template)
      end
    end
    assert_response :redirect
    assert_equal 0, checklist_count(Issue.order(:id).last)
  end

  private

  def seed_template
    create_template!(
      project: @project,
      title: 'Seeded bug',
      subject: 'Seeded subject',
      content: 'Seeded body',
      tracker_ids: [1],
      checklist_items: "Alpha\nBeta\n"
    )
  end

  def new_issue_params(template)
    priority = IssuePriority.active.first
    {
      project_id: @project.id,
      community_issue_template_id: template.id,
      issue: {
        tracker_id: 1,
        subject: 'Seeded subject',
        description: 'Seeded body',
        priority_id: priority&.id,
        status_id: Tracker.find(1).default_status_id
      }
    }
  end

  def grant_manage_checklists!(role = Role.find(1))
    return unless Redmine::AccessControl.permission(:manage_issue_checklists)

    role.add_permission!(:manage_issue_checklists)
  end

  def revoke_manage_checklists!(role = Role.find(1))
    return unless Redmine::AccessControl.permission(:manage_issue_checklists)

    role.remove_permission!(:manage_issue_checklists) if role.has_permission?(:manage_issue_checklists)
  end

  def checklist_count(issue)
    return 0 unless issue.respond_to?(:issue_checklists)

    issue.issue_checklists.count
  end
end
