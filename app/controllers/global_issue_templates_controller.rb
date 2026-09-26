# frozen_string_literal: true

class GlobalIssueTemplatesController < ApplicationController
  layout 'admin'
  menu_item :global_issue_templates
  helper :community_issue_templates
  include RedmineIssueTemplates::TemplateCrudActions

  before_action :require_login
  before_action :require_admin
  before_action :clear_project
  before_action :find_template, only: %i[edit update destroy set_default clear_default]

  private

  def clear_project
    @project = nil
  end
end
