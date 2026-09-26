# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class RedmineIssueTemplatesApplyPayloadTest < ActiveSupport::TestCase
  include CommunityIssueTemplatesTestSupport

  fixtures :projects, :users, :email_addresses, :user_preferences, :roles,
           :members, :member_roles, :trackers, :projects_trackers,
           :enabled_modules, :enumerations, :issue_statuses

  def setup
    reset_template_plugin_settings!
    @project = Project.find(1)
    @user = User.find(2)
    User.current = @user
  end

  def teardown
    reset_template_plugin_settings!
    User.current = nil
  end

  def test_whitelist_drops_unsafe_custom_field_formats
    string_field = create_issue_custom_field!(name: 'Environment', field_format: 'string')
    text_field = create_issue_custom_field!(name: 'Notes', field_format: 'text')
    bool_field = create_issue_custom_field!(name: 'Reproduced', field_format: 'bool')
    list_field = create_issue_custom_field!(name: 'Channel', field_format: 'list', possible_values: %w[web mail])
    int_field = create_issue_custom_field!(name: 'Count', field_format: 'int')
    float_field = create_issue_custom_field!(name: 'Hours note', field_format: 'float')
    date_field = create_issue_custom_field!(name: 'Seen on', field_format: 'date')
    user_field = create_issue_custom_field!(name: 'Owner', field_format: 'user')
    version_field = create_issue_custom_field!(name: 'Found in', field_format: 'version')
    file_field = create_issue_custom_field!(name: 'Attachment', field_format: 'attachment')
    link_field = create_issue_custom_field!(name: 'Ticket', field_format: 'link')
    multi_field = create_issue_custom_field!(
      name: 'Tags',
      field_format: 'list',
      possible_values: %w[a b],
      multiple: true
    )

    assert_not_includes RedmineIssueTemplates::SafeCustomFields::FORMATS, 'user'
    assert_not_includes RedmineIssueTemplates::SafeCustomFields.for_editor(@project).map(&:id), user_field.id
    assert_includes RedmineIssueTemplates::SafeCustomFields.for_editor(@project).map(&:id), string_field.id
    assert_nil RedmineIssueTemplates::SafeCustomFields.coerce(int_field, 'nope')
    assert_nil RedmineIssueTemplates::SafeCustomFields.coerce(date_field, '2026/01/02')
    assert_equal '2026-01-02', RedmineIssueTemplates::SafeCustomFields.coerce(date_field, '2026-01-02')
    assert_equal '1', RedmineIssueTemplates::SafeCustomFields.coerce(bool_field, 'yes')
    assert_nil RedmineIssueTemplates::SafeCustomFields.coerce(list_field, 'phone')
    assert_nil RedmineIssueTemplates::SafeCustomFields.coerce(multi_field, 'a')

    template = create_template!(
      project: @project,
      title: 'Bug report',
      subject: 'Bug: ',
      content: 'Steps',
      tracker_ids: [1],
      builtin_fields: {
        string_field.id.to_s => 'production',
        text_field.id.to_s => 'Long note',
        bool_field.id.to_s => '1',
        list_field.id.to_s => 'web',
        int_field.id.to_s => '3',
        float_field.id.to_s => '1.5',
        date_field.id.to_s => '2026-01-02',
        user_field.id.to_s => '2',
        version_field.id.to_s => '1',
        file_field.id.to_s => 'spec.pdf',
        link_field.id.to_s => 'https://example.test',
        multi_field.id.to_s => 'a',
        '999999' => 'missing'
      }
    )

    payload = RedmineIssueTemplates::ApplyPayload.build(
      template,
      project: @project,
      user: @user,
      current_tracker_id: 1
    )

    assert_equal(
      {
        string_field.id.to_s => 'production',
        text_field.id.to_s => 'Long note',
        bool_field.id.to_s => '1',
        list_field.id.to_s => 'web',
        int_field.id.to_s => '3',
        float_field.id.to_s => '1.5',
        date_field.id.to_s => '2026-01-02'
      },
      payload[:builtin_fields]
    )
    assert_includes payload[:ignored], 'builtin_fields'
    assert_equal 'Bug: ', payload[:subject]
    assert_equal 'Steps', payload[:description]
    assert_equal 1, payload[:tracker_id]
  end

  def test_menus_are_registered
    project_names = Redmine::MenuManager.items(:project_menu).children.map(&:name)
    admin_names = Redmine::MenuManager.items(:admin_menu).children.map(&:name)
    assert_includes project_names, :issue_templates
    assert_includes admin_names, :global_issue_templates
  end
end
