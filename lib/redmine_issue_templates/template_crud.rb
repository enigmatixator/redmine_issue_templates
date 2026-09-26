# frozen_string_literal: true

module RedmineIssueTemplates
  # Shared list / form / default actions for project templates and global templates.
  module TemplateCrudActions
    def index
      @templates = template_scope.includes(:trackers).order(:position, :id)
      @defaults = defaults_by_tracker(@project&.id)
      if @project
        @global_templates = if RedmineIssueTemplates.apply_global_templates?
                              CommunityIssueTemplate.global.includes(:trackers).order(:position, :id)
                            else
                              []
                            end
        @global_defaults = defaults_by_tracker(nil)
      end
      render 'community_issue_templates/index'
    end

    def new
      @template = CommunityIssueTemplate.new(project: @project, enabled: true, author: User.current)
      @selected_tracker_ids = []
      render 'community_issue_templates/new'
    end

    def create
      @template = CommunityIssueTemplate.new(enabled: true)
      persist_template(creating: true)
    end

    def edit
      @selected_tracker_ids = @template.tracker_ids
      render 'community_issue_templates/edit'
    end

    def update
      persist_template(creating: false)
    end

    def destroy
      @template.destroy!
      flash[:notice] = l(:notice_successful_delete)
      redirect_to template_index_path
    end

    def set_default
      tracker_id = params[:tracker_id].to_i
      unless tracker_id.positive? && @template.template_trackers.exists?(tracker_id: tracker_id)
        flash[:error] = l(:error_cit_default_tracker)
        redirect_to template_index_path
        return
      end

      row = CommunityIssueTemplateDefault.find_or_initialize_by(project_id: @project&.id, tracker_id: tracker_id)
      row.template = @template
      if row.save
        flash[:notice] = l(:notice_cit_default_set)
      else
        flash[:error] = row.errors.full_messages.to_sentence
      end
      redirect_to template_index_path
    end

    def clear_default
      tracker_id = params[:tracker_id].to_i
      CommunityIssueTemplateDefault.where(
        project_id: @project&.id,
        tracker_id: tracker_id,
        community_issue_template_id: @template.id
      ).destroy_all
      flash[:notice] = l(:notice_cit_default_cleared)
      redirect_to template_index_path
    end

    private

    def persist_template(creating:)
      writer = TemplateWriter.new(@template, project: @project, user: User.current)
      if writer.assign_and_save(params)
        flash[:notice] = l(creating ? :notice_successful_create : :notice_successful_update)
        redirect_to template_index_path
      else
        @selected_tracker_ids = writer.tracker_ids
        action = creating ? 'new' : 'edit'
        render "community_issue_templates/#{action}", status: :unprocessable_entity
      end
    end

    def find_template
      @template = template_scope.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def template_scope
      if @project
        CommunityIssueTemplate.where(project_id: @project.id)
      else
        CommunityIssueTemplate.global
      end
    end

    def defaults_by_tracker(project_id)
      CommunityIssueTemplateDefault.where(project_id: project_id).index_by(&:tracker_id)
    end

    def template_index_path
      if @project
        project_community_issue_templates_path(@project)
      else
        global_issue_templates_path
      end
    end
  end
end
