# frozen_string_literal: true

require 'redmine'

require_relative 'lib/redmine_issue_templates/version'
require_relative 'lib/redmine_issue_templates/settings'
require_relative 'lib/redmine_issue_templates/checklist_seed'
require_relative 'lib/redmine_issue_templates/hooks'
require_relative 'lib/redmine_issue_templates/issue_form'
require_relative 'lib/redmine_issue_templates/template_factory'
require_relative 'lib/redmine_issue_templates/safe_custom_fields'
require_relative 'lib/redmine_issue_templates/apply_payload'
require_relative 'lib/redmine_issue_templates/template_writer'
require_relative 'lib/redmine_issue_templates/template_crud'

Redmine::Plugin.register :redmine_issue_templates do
  name 'Issue Templates'
  author 'RedmineShop'
  author_url 'https://redmineshop.com'
  description 'Start a new issue from a reusable template on Redmine 7.0. Soft checklist seed when Issue Checklists is installed.'
  version RedmineIssueTemplates::VERSION
  url 'https://github.com/redmineshop/redmine_issue_templates'

  # Founder decision 2026-09-24: Redmine 7.0 and newer only.
  requires_redmine version_or_higher: '7.0'

  settings default: {
    'confirm_overwrite_on_tracker_change' => '1',
    'apply_global_templates' => '1'
  }, partial: 'settings/issue_templates'

  project_module :issue_templates do
    permission :use_issue_templates,
               { community_issue_templates: [:show] },
               read: true
    permission :manage_issue_templates,
               {
                 community_issue_templates: %i[
                   index new create edit update destroy set_default clear_default
                 ]
               }
  end

  menu :project_menu, :issue_templates,
       { controller: 'community_issue_templates', action: 'index' },
       caption: :label_community_issue_templates,
       after: :issues,
       param: :project_id,
       if: proc { |project|
         project.module_enabled?(:issue_templates) &&
           User.current.allowed_to?(:manage_issue_templates, project)
       }

  menu :admin_menu, :global_issue_templates,
       { controller: 'global_issue_templates', action: 'index' },
       caption: :label_community_issue_templates,
       if: proc { User.current.admin? }
end
