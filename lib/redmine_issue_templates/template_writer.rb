# frozen_string_literal: true

module RedmineIssueTemplates
  # Assigns the template form onto a record.
  # Only scalar attributes and the safe custom-field whitelist are written.
  # project_id, author_id, and arbitrary custom fields cannot be set from the
  # request hash. Checklist lines are stored only when Issue Checklists is
  # installed; otherwise that parameter is ignored.
  class TemplateWriter
    attr_reader :tracker_ids

    def initialize(template, project:, user:)
      @template = template
      @project = project
      @user = user || User.current
      @tracker_ids = []
    end

    def assign_and_save(params)
      raw = params.require(:community_issue_template)
      @template.assign_attributes(raw.permit(:title, :description, :subject, :content, :enabled))
      @template.project = @project
      @template.author ||= @user
      @tracker_ids = allowed_tracker_ids(raw[:tracker_ids])
      @template.priority_id = allowed_priority_id(raw[:priority_id])
      @template.status_id = allowed_status_id(raw[:status_id])
      @template.assigned_to_id = allowed_assignee_id(raw[:assigned_to_id])
      @template.category_id = allowed_category_id(raw[:category_id])
      @template.watcher_user_ids = allowed_watcher_ids(raw[:watcher_user_ids])
      @template.builtin_fields = allowed_custom_fields(raw[:builtin_fields])
      assign_checklist_items(raw)

      valid = @template.valid?
      if @tracker_ids.empty?
        @template.errors.add(:base, I18n.t(:error_cit_tracker_required))
        valid = false
      end
      return false unless valid

      CommunityIssueTemplate.transaction do
        @template.save!
        @template.tracker_ids = @tracker_ids
        @template.defaults.where.not(tracker_id: @tracker_ids).destroy_all
      end
      true
    end

    private

    def assign_checklist_items(raw)
      return unless RedmineIssueTemplates.checklists_plugin_present?
      return unless raw.key?(:checklist_items) || raw.key?('checklist_items')

      @template.checklist_items = normalized_checklist_items(raw[:checklist_items])
    end

    def normalized_checklist_items(value)
      limit = ChecklistSeed.item_limit
      lines = value.to_s.split(/\r?\n/).filter_map do |line|
        text = line.to_s.strip
        next if text.empty?

        text.length > 255 ? text[0, 255] : text
      end.first(limit)
      return nil if lines.empty?

      lines.join("\n")
    end

    def allowed_tracker_ids(values)
      allowed = @project ? @project.tracker_ids : Tracker.pluck(:id)
      Array(values).filter_map { |value| integer_id(value) }.uniq & allowed
    end

    def allowed_priority_id(value)
      id = integer_id(value)
      return nil unless id
      return id if IssuePriority.active.where(id: id).exists?

      nil
    end

    def allowed_status_id(value)
      id = integer_id(value)
      return nil unless id
      return id if IssueStatus.where(id: id).exists?

      nil
    end

    def allowed_assignee_id(value)
      id = integer_id(value)
      return nil unless id

      if @project
        users = @project.assignable_users
        return id if users.respond_to?(:where) ? users.where(id: id).exists? : Array(users).any? { |user| user.id == id }
      elsif User.active.exists?(id: id)
        return id
      end

      nil
    end

    def allowed_category_id(value)
      return nil unless @project

      id = integer_id(value)
      return nil unless id
      return id if @project.issue_categories.where(id: id).exists?

      nil
    end

    def allowed_watcher_ids(values)
      ids = Array(values).filter_map { |value| integer_id(value) }.uniq
      return [] if ids.empty?

      scope = @project ? @project.users.active.where(id: ids) : User.active.where(id: ids)
      scope.select { |user| user.visible?(@user) }.map(&:id)
    end

    def allowed_custom_fields(values)
      submitted = parameter_hash(values)
      stored = {}
      SafeCustomFields.for_editor(@project).each do |field|
        key = field.id.to_s
        next unless submitted.key?(key) || submitted.key?(field.id)

        coerced = SafeCustomFields.coerce(field, submitted[key] || submitted[field.id])
        next if coerced.nil?

        stored[key] = coerced
      end
      stored
    end

    def parameter_hash(values)
      case values
      when ActionController::Parameters
        values.to_unsafe_h
      when Hash
        values
      else
        {}
      end
    end

    def integer_id(value)
      return nil if value.blank?

      number = Integer(value)
      number.positive? ? number : nil
    rescue ArgumentError, TypeError
      nil
    end
  end
end
