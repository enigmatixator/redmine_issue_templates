# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class GlobalIssueTemplatesControllerTest < Redmine::ControllerTest
  include CommunityIssueTemplatesTestSupport

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles,
           :members, :member_roles, :trackers, :projects_trackers,
           :enabled_modules, :enumerations, :issue_statuses

  def setup
    reset_template_plugin_settings!
    @request.session[:user_id] = 1
  end

  def teardown
    reset_template_plugin_settings!
  end

  def test_non_admin_is_forbidden
    @request.session[:user_id] = 2
    get :index
    assert_response :forbidden

    assert_no_difference 'CommunityIssueTemplate.count' do
      post :create, params: {
        community_issue_template: { title: 'Nope', tracker_ids: ['1'] }
      }
    end
    assert_response :forbidden
  end

  def test_admin_creates_a_global_template_and_sets_the_default
    assert User.find(1).admin?

    assert_difference 'CommunityIssueTemplate.count', 1 do
      post :create, params: {
        community_issue_template: {
          title: 'Global bug',
          subject: 'Bug: ',
          content: 'Shared steps',
          enabled: '1',
          tracker_ids: ['1'],
          project_id: 1,
          category_id: 1
        }
      }
    end
    assert_redirected_to global_issue_templates_path

    template = CommunityIssueTemplate.order(:id).last
    assert_nil template.project_id
    assert_nil template.category_id
    assert_equal [1], template.tracker_ids
    assert_equal 1, template.author_id

    post :set_default, params: { id: template.id, tracker_id: 1 }
    assert_redirected_to global_issue_templates_path
    found = CommunityIssueTemplateDefault.for_tracker(Project.find(1), Tracker.find(1))
    assert_equal template.id, found.community_issue_template_id
    assert_nil found.project_id

    post :clear_default, params: { id: template.id, tracker_id: 1 }
    assert_nil CommunityIssueTemplateDefault.find_by(project_id: nil, tracker_id: 1)

    delete :destroy, params: { id: template.id }
    assert_redirected_to global_issue_templates_path
    assert_nil CommunityIssueTemplate.find_by(id: template.id)
  end

  def test_admin_index_renders_the_list
    create_template!(project: nil, title: 'Global bug', subject: 'Bug: ', tracker_ids: [1])
    get :index
    assert_response :success
    assert_match 'Global bug', response.body
    assert_select 'a.icon-add', text: I18n.t(:label_community_issue_template_new)
  end
end
