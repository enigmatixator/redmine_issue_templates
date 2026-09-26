# frozen_string_literal: true

class CommunityIssueTemplatesController < ApplicationController
  menu_item :issue_templates
  helper :community_issue_templates
  include RedmineIssueTemplates::TemplateCrudActions

  before_action :require_login
  before_action :find_project
  before_action :authorize
  before_action :require_add_issues, only: :show
  before_action :find_template, only: %i[edit update destroy set_default clear_default]

  # GET /projects/:project_id/issue_templates/:id
  # Permission: :use_issue_templates on the project module, plus :add_issues.
  def show
    template = CommunityIssueTemplate.visible_for(@project).find_by(id: params[:id])
    unless template
      render_404
      return
    end

    render json: RedmineIssueTemplates::ApplyPayload.build(
      template,
      project: @project,
      user: User.current,
      current_tracker_id: params[:tracker_id]
    )
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def require_add_issues
    return if User.current.allowed_to?(:add_issues, @project)

    render_403
  end
end
