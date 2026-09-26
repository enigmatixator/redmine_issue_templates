# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class CommunityIssueTemplatesControllerTest < Redmine::ControllerTest
  include CommunityIssueTemplatesTestSupport

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles,
           :members, :member_roles, :trackers, :projects_trackers,
           :enabled_modules, :enumerations, :issue_statuses

  def setup
    reset_template_plugin_settings!
    @project = enable_issue_templates!
    grant_use_issue_templates!
    @template = create_template!(
      project: @project,
      title: 'Bug report',
      subject: 'Bug: login',
      content: "Steps to reproduce\n\nExpected",
      tracker_ids: [1],
      author_id: 2
    )
  end

  def teardown
    reset_template_plugin_settings!
  end

  def test_show_forbidden_without_use_permission
    @request.session[:user_id] = 3
    get :show, params: { project_id: @project.id, id: @template.id }
    assert_response :forbidden
  end

  def test_show_forbidden_without_add_issues
    Role.find(1).remove_permission!(:add_issues)
    @request.session[:user_id] = 2
    get :show, params: { project_id: @project.id, id: @template.id }
    assert_response :forbidden
  end

  def test_show_forbidden_when_the_module_is_disabled
    @project.disable_module!(:issue_templates)
    @request.session[:user_id] = 2
    get :show, params: { project_id: @project.id, id: @template.id }
    assert_response :forbidden
  end

  def test_show_requires_login
    @request.session[:user_id] = nil
    get :show, params: { project_id: @project.id, id: @template.id }
    assert_response :redirect
    assert_match %r{/login}, @response.redirect_url
  end

  def test_show_returns_subject_description_and_tracker
    @request.session[:user_id] = 2
    get :show, params: { project_id: @project.id, id: @template.id, tracker_id: 1 }
    assert_response :success
    assert_match 'application/json', response.content_type

    payload = JSON.parse(response.body)
    assert_equal @template.id, payload['id']
    assert_equal 'Bug report', payload['title']
    assert_equal 'Bug: login', payload['subject']
    assert_equal "Steps to reproduce\n\nExpected", payload['description']
    assert_equal 1, payload['tracker_id']
    assert_equal [1], payload['tracker_ids']
    assert payload.key?('priority_id')
    assert payload.key?('status_id')
    assert payload.key?('assigned_to_id')
    assert payload.key?('watcher_user_ids')
    assert payload.key?('builtin_fields')
    assert payload.key?('category_id')
    assert_equal [], payload['ignored']
    assert_not payload.key?('checklist_items')
  end

  def test_show_suggests_the_bound_tracker
    feature = create_template!(project: @project, title: 'Feature', subject: 'Feature: ', content: 'Goal', tracker_ids: [2])
    @request.session[:user_id] = 2
    get :show, params: { project_id: @project.id, id: feature.id, tracker_id: 1 }
    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 2, payload['tracker_id']
    assert_equal 'Feature: ', payload['subject']
    assert_equal 'Goal', payload['description']
  end

  def test_show_hides_templates_from_another_project_and_disabled_templates
    other = create_template!(project: Project.find(2), title: 'Elsewhere', tracker_ids: [1])
    disabled = create_template!(project: @project, title: 'Off', tracker_ids: [1], enabled: false)
    @request.session[:user_id] = 2

    get :show, params: { project_id: @project.id, id: other.id }
    assert_response :not_found

    get :show, params: { project_id: @project.id, id: disabled.id }
    assert_response :not_found
  end

  def test_show_returns_a_global_template_and_hides_it_when_the_setting_is_off
    global = create_template!(project: nil, title: 'Global bug', subject: 'Global: ', content: 'Shared', tracker_ids: [1])
    @request.session[:user_id] = 2

    get :show, params: { project_id: @project.id, id: global.id }
    assert_response :success
    assert_equal 'Global: ', JSON.parse(response.body)['subject']

    Setting.plugin_redmine_issue_templates = {
      'confirm_overwrite_on_tracker_change' => '1',
      'apply_global_templates' => '0'
    }
    get :show, params: { project_id: @project.id, id: global.id }
    assert_response :not_found
  end

  def test_show_missing_template_is_not_found
    @request.session[:user_id] = 2
    get :show, params: { project_id: @project.id, id: 0 }
    assert_response :not_found
  end

  def test_show_payload_keeps_safe_fields_and_drops_unsafe_ones
    user = User.find(2)
    assignable_ids = Array(@project.assignable_users).map(&:id)
    member_ids = @project.users.active.pluck(:id)
    insider_id = (assignable_ids & member_ids).first
    outsider = User.active.where.not(id: member_ids).first
    assert insider_id, 'fixture project needs an assignable member'
    assert outsider

    blocked = IssueStatus.create!(name: "Template blocked #{SecureRandom.hex(3)}", is_closed: false)
    allowed_statuses = Array(
      Issue.new(project: @project, tracker_id: 1, author: user).new_statuses_allowed_to(user)
    ).map(&:id)
    assert_not_includes allowed_statuses, blocked.id

    priority = IssuePriority.active.first
    category = IssueCategory.create!(project: @project, name: 'Template UI')
    other_category = IssueCategory.create!(project: Project.find(2), name: 'Other project category')
    string_field = create_issue_custom_field!(name: 'Environment', field_format: 'string', tracker_ids: [1])
    user_field = create_issue_custom_field!(name: 'Owner', field_format: 'user', tracker_ids: [1])
    file_field = create_issue_custom_field!(name: 'Spec file', field_format: 'attachment', tracker_ids: [1])
    multi_field = create_issue_custom_field!(
      name: 'Tags',
      field_format: 'list',
      possible_values: %w[a b],
      multiple: true,
      tracker_ids: [1]
    )

    @template.update!(
      priority_id: priority.id,
      status_id: blocked.id,
      assigned_to_id: outsider.id,
      category_id: other_category.id,
      watcher_user_ids: [insider_id, outsider.id],
      builtin_fields: {
        string_field.id.to_s => 'production',
        user_field.id.to_s => insider_id.to_s,
        file_field.id.to_s => 'secret.pdf',
        multi_field.id.to_s => 'a',
        '999999' => 'missing'
      }
    )

    @request.session[:user_id] = 2
    get :show, params: { project_id: @project.id, id: @template.id, tracker_id: 1 }
    assert_response :success
    payload = JSON.parse(response.body)

    assert_equal priority.id, payload['priority_id']
    assert_nil payload['status_id']
    assert_nil payload['assigned_to_id']
    assert_nil payload['category_id']
    assert_equal [insider_id], payload['watcher_user_ids']
    assert_equal({ string_field.id.to_s => 'production' }, payload['builtin_fields'])
    assert_includes payload['ignored'], 'status_id'
    assert_includes payload['ignored'], 'assigned_to_id'
    assert_includes payload['ignored'], 'category_id'
    assert_includes payload['ignored'], 'watcher_user_ids'
    assert_includes payload['ignored'], 'builtin_fields'
    assert_not_includes payload['ignored'], 'priority_id'

    @template.update!(status_id: allowed_statuses.first, assigned_to_id: insider_id, category_id: category.id)
    get :show, params: { project_id: @project.id, id: @template.id, tracker_id: 1 }
    applied = JSON.parse(response.body)
    assert_equal allowed_statuses.first, applied['status_id']
    assert_equal insider_id, applied['assigned_to_id']
    assert_equal category.id, applied['category_id']
    assert_not_includes applied['ignored'], 'status_id'
  end

  def test_manage_actions_are_forbidden_without_permission
    @request.session[:user_id] = 2

    get :index, params: { project_id: @project.id }
    assert_response :forbidden

    get :new, params: { project_id: @project.id }
    assert_response :forbidden

    assert_no_difference 'CommunityIssueTemplate.count' do
      post :create, params: {
        project_id: @project.id,
        community_issue_template: { title: 'Nope', tracker_ids: ['1'] }
      }
    end
    assert_response :forbidden

    get :edit, params: { project_id: @project.id, id: @template.id }
    assert_response :forbidden

    put :update, params: {
      project_id: @project.id,
      id: @template.id,
      community_issue_template: { title: 'Nope', tracker_ids: ['1'], enabled: '1' }
    }
    assert_response :forbidden
    assert_equal 'Bug report', @template.reload.title

    assert_no_difference 'CommunityIssueTemplate.count' do
      delete :destroy, params: { project_id: @project.id, id: @template.id }
    end
    assert_response :forbidden

    post :set_default, params: { project_id: @project.id, id: @template.id, tracker_id: 1 }
    assert_response :forbidden
    assert_nil CommunityIssueTemplateDefault.find_by(project_id: @project.id, tracker_id: 1)
  end

  def test_index_is_forbidden_when_the_module_is_disabled
    grant_manage_issue_templates!
    @project.disable_module!(:issue_templates)
    @request.session[:user_id] = 2

    get :index, params: { project_id: @project.id }
    assert_response :forbidden
  end

  def test_index_lists_project_templates_and_keeps_global_templates_read_only
    grant_manage_issue_templates!
    global = create_template!(project: nil, title: 'Global bug', tracker_ids: [1])
    @request.session[:user_id] = 2

    get :index, params: { project_id: @project.id }
    assert_response :success
    assert_select 'a.icon-add', text: I18n.t(:label_community_issue_template_new)
    assert_match 'Bug report', response.body
    assert_match 'Global bug', response.body
    assert_select 'a[href=?]', edit_project_community_issue_template_path(@project, @template)
    assert_select 'a[href=?]', edit_global_issue_template_path(global), count: 0
  end

  def test_new_form_renders_safe_fields_and_hides_checklist_seed
    grant_manage_issue_templates!
    @request.session[:user_id] = 2

    with_checklists_plugin(false) do
      get :new, params: { project_id: @project.id }
    end
    assert_response :success
    assert_select 'form#community-issue-template-form'
    assert_select 'input#community_issue_template_tracker_ids_1'
    assert_select 'select#community_issue_template_priority_id'
    assert_select 'select#community_issue_template_status_id'
    assert_select 'select#community_issue_template_assigned_to_id'
    assert_match I18n.t(:text_cit_custom_field_whitelist), response.body
    assert_select 'textarea[name=?]', 'community_issue_template[checklist_items]', count: 0
  end

  def test_new_form_shows_checklist_items_when_the_checklists_plugin_is_installed
    grant_manage_issue_templates!
    @request.session[:user_id] = 2

    with_checklists_plugin(true) do
      get :new, params: { project_id: @project.id }
    end
    assert_response :success
    assert_select 'textarea#community_issue_template_checklist_items'
    assert_match I18n.t(:text_cit_checklist_items_hint), response.body
    assert_match I18n.t(:label_cit_checklist_items), response.body
  end

  def test_create_update_and_destroy
    grant_manage_issue_templates!
    string_field = create_issue_custom_field!(name: 'Environment', field_format: 'string', tracker_ids: [1])
    user_field = create_issue_custom_field!(name: 'Owner', field_format: 'user', tracker_ids: [1])
    priority = IssuePriority.active.first
    @request.session[:user_id] = 2

    assert_difference 'CommunityIssueTemplate.count', 1 do
      with_checklists_plugin(false) do
        post :create, params: {
          project_id: @project.id,
          community_issue_template: {
            title: 'Ops',
            description: 'How to report',
            subject: 'Ops: ',
            content: 'What broke?',
            enabled: '1',
            priority_id: priority.id,
            status_id: Tracker.find(1).default_status_id,
            assigned_to_id: 2,
            tracker_ids: ['1', '2'],
            watcher_user_ids: ['2', '1'],
            builtin_fields: {
              string_field.id.to_s => 'staging',
              user_field.id.to_s => '2'
            },
            project_id: Project.find(2).id,
            checklist_items: "should not save\n"
          }
        }
      end
    end
    assert_redirected_to project_community_issue_templates_path(@project)

    created = CommunityIssueTemplate.order(:id).last
    assert_equal @project.id, created.project_id
    assert_equal 'Ops', created.title
    assert_equal 'Ops: ', created.subject
    assert_equal [1, 2], created.template_trackers.order(:tracker_id).pluck(:tracker_id)
    assert_equal priority.id, created.priority_id
    assert_equal Tracker.find(1).default_status_id, created.status_id
    assert_equal 2, created.assigned_to_id
    assert_equal [2], created.watcher_ids
    assert_equal({ string_field.id.to_s => 'staging' }, created.custom_field_values)
    assert_nil created.checklist_items
    assert_equal 2, created.author_id

    put :update, params: {
      project_id: @project.id,
      id: created.id,
      community_issue_template: {
        title: 'Ops renamed',
        subject: 'Ops: renamed',
        content: 'Updated',
        enabled: '0',
        tracker_ids: ['1'],
        watcher_user_ids: [''],
        builtin_fields: { string_field.id.to_s => '' }
      }
    }
    assert_redirected_to project_community_issue_templates_path(@project)
    created.reload
    assert_equal 'Ops renamed', created.title
    assert_equal [1], created.tracker_ids
    assert_not created.enabled?
    assert_equal [], created.watcher_ids
    assert_equal({}, created.custom_field_values)

    assert_difference 'CommunityIssueTemplate.count', -1 do
      delete :destroy, params: { project_id: @project.id, id: created.id }
    end
    assert_redirected_to project_community_issue_templates_path(@project)
  end

  def test_create_saves_checklist_lines_when_the_checklists_plugin_is_installed
    grant_manage_issue_templates!
    @request.session[:user_id] = 2
    lines = (1..49).map { |number| "Item #{number}" }
    lines << ('z' * 300)
    lines << 'dropped'

    assert_difference 'CommunityIssueTemplate.count', 1 do
      with_checklists_plugin(true) do
        post :create, params: {
          project_id: @project.id,
          community_issue_template: {
            title: 'With checklist',
            subject: 'Bug: ',
            content: 'Steps',
            tracker_ids: ['1'],
            checklist_items: lines.join("\n")
          }
        }
      end
    end
    assert_redirected_to project_community_issue_templates_path(@project)

    stored = CommunityIssueTemplate.order(:id).last.checklist_items.to_s.split("\n")
    assert_equal 50, stored.size
    assert_equal 'Item 1', stored.first
    assert_equal 'z' * 255, stored.last
    assert_not_includes stored, 'dropped'
  end

  def test_create_requires_a_tracker
    grant_manage_issue_templates!
    @request.session[:user_id] = 2

    assert_no_difference 'CommunityIssueTemplate.count' do
      post :create, params: {
        project_id: @project.id,
        community_issue_template: { title: 'No tracker', tracker_ids: [''] }
      }
    end
    assert_response :unprocessable_entity
    assert_match I18n.t(:error_cit_tracker_required), response.body
  end

  def test_project_routes_do_not_edit_another_project_or_a_global_template
    grant_manage_issue_templates!
    other = create_template!(project: Project.find(2), title: 'Elsewhere', tracker_ids: [1])
    global = create_template!(project: nil, title: 'Global', tracker_ids: [1])
    @request.session[:user_id] = 2

    get :edit, params: { project_id: @project.id, id: other.id }
    assert_response :not_found

    get :edit, params: { project_id: @project.id, id: global.id }
    assert_response :not_found

    put :update, params: {
      project_id: @project.id,
      id: global.id,
      community_issue_template: { title: 'Hijack', tracker_ids: ['1'], enabled: '1' }
    }
    assert_response :not_found
    assert_equal 'Global', global.reload.title
  end

  def test_set_and_clear_default_for_a_tracker
    grant_manage_issue_templates!
    other = create_template!(project: @project, title: 'Other bug', tracker_ids: [1])
    @request.session[:user_id] = 2

    post :set_default, params: { project_id: @project.id, id: @template.id, tracker_id: 1 }
    assert_redirected_to project_community_issue_templates_path(@project)
    assert_equal @template.id,
                 CommunityIssueTemplateDefault.for_tracker(@project, Tracker.find(1)).community_issue_template_id

    post :set_default, params: { project_id: @project.id, id: other.id, tracker_id: 1 }
    assert_equal other.id,
                 CommunityIssueTemplateDefault.for_tracker(@project, Tracker.find(1)).community_issue_template_id

    post :set_default, params: { project_id: @project.id, id: @template.id, tracker_id: 2 }
    assert_redirected_to project_community_issue_templates_path(@project)
    assert_nil CommunityIssueTemplateDefault.find_by(project_id: @project.id, tracker_id: 2)

    post :clear_default, params: { project_id: @project.id, id: other.id, tracker_id: 1 }
    assert_nil CommunityIssueTemplateDefault.find_by(project_id: @project.id, tracker_id: 1)
  end

  def test_destroy_removes_the_default_row
    grant_manage_issue_templates!
    CommunityIssueTemplateDefault.create!(project: @project, tracker_id: 1, template: @template)
    @request.session[:user_id] = 2

    delete :destroy, params: { project_id: @project.id, id: @template.id }
    assert_response :redirect
    assert_nil CommunityIssueTemplateDefault.find_by(community_issue_template_id: @template.id)
  end
end
