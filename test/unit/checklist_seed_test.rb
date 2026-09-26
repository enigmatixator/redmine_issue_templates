# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class ChecklistSeedTest < ActiveSupport::TestCase
  include CommunityIssueTemplatesTestSupport

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :trackers, :projects_trackers, :enabled_modules, :enumerations,
           :issue_statuses

  class RecordingChecklists
    attr_reader :created

    def initialize(error: nil)
      @created = []
      @error = error
    end

    def create!(attrs)
      raise @error if @error

      @created << attrs
      attrs
    end
  end

  def setup
    reset_template_plugin_settings!
    @project = enable_issue_templates!(Project.find(1))
    @user = User.find(2)
    User.current = @user
  end

  def teardown
    User.current = nil
    reset_template_plugin_settings!
  end

  def test_seeds_lines_when_the_plugin_and_permission_are_present
    template = checklist_template("  Alpha  \n\nBeta\n#{'z' * 300}")
    issue, checklists = recording_issue(@project)

    with_permissions(use: true, manage: true) do
      with_checklists_plugin(true) do
        RedmineIssueTemplates::ChecklistSeed.call(issue, template_params(template))
      end
    end

    assert_equal [
      { subject: 'Alpha', is_done: false, position: 1 },
      { subject: 'Beta', is_done: false, position: 2 },
      { subject: 'z' * 255, is_done: false, position: 3 }
    ], checklists.created
  end

  def test_seeds_at_most_the_checklists_item_limit
    limit = RedmineIssueTemplates::ChecklistSeed.item_limit
    lines = (1..(limit + 5)).map { |number| "Item #{number}" }
    template = checklist_template(lines.join("\n"))
    issue, checklists = recording_issue(@project)

    with_permissions(use: true, manage: true) do
      with_checklists_plugin(true) do
        RedmineIssueTemplates::ChecklistSeed.call(issue, template_params(template))
      end
    end

    assert_equal limit, checklists.created.size
    assert_equal 'Item 1', checklists.created.first[:subject]
    assert_equal "Item #{limit}", checklists.created.last[:subject]
    assert_equal (1..limit).to_a, checklists.created.map { |row| row[:position] }
  end

  def test_does_not_seed_when_the_checklists_plugin_is_absent
    template = checklist_template("Alpha\nBeta")
    issue, checklists = recording_issue(@project)

    with_permissions(use: true, manage: true) do
      with_checklists_plugin(false) do
        RedmineIssueTemplates::ChecklistSeed.call(issue, template_params(template))
      end
    end

    assert_empty checklists.created
  end

  def test_skips_seed_when_the_user_cannot_manage_checklists
    template = checklist_template("Alpha\nBeta")
    issue, checklists = recording_issue(@project)

    with_permissions(use: true, manage: false) do
      with_checklists_plugin(true) do
        RedmineIssueTemplates::ChecklistSeed.call(issue, template_params(template))
      end
    end

    assert_empty checklists.created
  end

  def test_skips_seed_when_the_user_cannot_use_templates
    template = checklist_template("Alpha")
    issue, checklists = recording_issue(@project)

    with_permissions(use: false, manage: true) do
      with_checklists_plugin(true) do
        RedmineIssueTemplates::ChecklistSeed.call(issue, template_params(template))
      end
    end

    assert_empty checklists.created
  end

  def test_skips_seed_when_the_issue_has_no_checklists_association
    template = checklist_template("Alpha")
    issue = Object.new
    issue.define_singleton_method(:blank?) { false }
    issue.define_singleton_method(:persisted?) { true }
    issue.define_singleton_method(:project) { @project }

    assert_nothing_raised do
      with_permissions(use: true, manage: true) do
        with_checklists_plugin(true) do
          RedmineIssueTemplates::ChecklistSeed.call(issue, template_params(template))
        end
      end
    end
  end

  def test_create_errors_do_not_raise
    template = checklist_template("Alpha")
    issue, checklists = recording_issue(@project, error: StandardError.new('boom'))

    assert_nothing_raised do
      with_permissions(use: true, manage: true) do
        with_checklists_plugin(true) do
          RedmineIssueTemplates::ChecklistSeed.call(issue, template_params(template))
        end
      end
    end
    assert_empty checklists.created
  end

  def test_does_not_seed_a_template_from_another_project
    other = enable_issue_templates!(Project.find(2))
    template = checklist_template("Alpha", project: other)
    issue, checklists = recording_issue(@project)

    with_permissions(use: true, manage: true) do
      with_checklists_plugin(true) do
        RedmineIssueTemplates::ChecklistSeed.call(issue, template_params(template))
      end
    end

    assert_empty checklists.created
  end

  def test_does_not_seed_when_no_template_was_submitted
    issue, checklists = recording_issue(@project)

    with_permissions(use: true, manage: true) do
      with_checklists_plugin(true) do
        RedmineIssueTemplates::ChecklistSeed.call(issue, {})
      end
    end

    assert_empty checklists.created
  end

  def test_seeds_a_global_template
    template = checklist_template('Global step', project: nil)
    issue, checklists = recording_issue(@project)

    with_permissions(use: true, manage: true) do
      with_checklists_plugin(true) do
        RedmineIssueTemplates::ChecklistSeed.call(issue, template_params(template))
      end
    end

    assert_equal ['Global step'], checklists.created.map { |row| row[:subject] }
  end

  private

  def checklist_template(lines, project: @project)
    create_template!(
      project: project,
      title: "Checklist #{SecureRandom.hex(4)}",
      subject: 'Bug: ',
      content: 'Steps',
      tracker_ids: [1],
      checklist_items: lines
    )
  end

  def template_params(template)
    { 'community_issue_template_id' => template.id.to_s }
  end

  def recording_issue(project, error: nil)
    checklists = RecordingChecklists.new(error: error)
    issue = Object.new
    issue.define_singleton_method(:blank?) { false }
    issue.define_singleton_method(:persisted?) { true }
    issue.define_singleton_method(:project) { project }
    issue.define_singleton_method(:issue_checklists) { checklists }
    [issue, checklists]
  end

  def with_permissions(use:, manage:)
    @user.define_singleton_method(:allowed_to?) do |permission, *_rest|
      case permission.to_sym
      when :use_issue_templates then use
      when :manage_issue_checklists then manage
      else false
      end
    end
    yield
  ensure
    @user.singleton_class.send(:remove_method, :allowed_to?)
  end
end
