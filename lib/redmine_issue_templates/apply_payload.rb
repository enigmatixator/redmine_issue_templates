# frozen_string_literal: true

module RedmineIssueTemplates
  # JSON body for the new-issue form.
  # Stored ids are returned only when the current user may use them on this
  # project. Dropped values are listed in +ignored+ and are not applied.
  class ApplyPayload
    def self.build(template, project:, user:, current_tracker_id: nil)
      new(template, project, user, current_tracker_id).to_h
    end

    def initialize(template, project, user, current_tracker_id)
      @template = template
      @project = project
      @user = user || User.current
      @current_tracker_id = current_tracker_id
    end

    def to_h
      payload = @template.apply_payload(current_tracker_id: @current_tracker_id)
      @tracker_id = payload[:tracker_id]
      ignored = []

      payload[:priority_id] = filter_id(payload[:priority_id], 'priority_id', ignored) { |id| active_priority?(id) }
      payload[:status_id] = filter_id(payload[:status_id], 'status_id', ignored) { |id| allowed_status_ids.include?(id) }
      payload[:assigned_to_id] = filter_id(payload[:assigned_to_id], 'assigned_to_id', ignored) { |id| assignee_allowed?(id) }
      payload[:category_id] = filter_id(payload[:category_id], 'category_id', ignored) { |id| category_allowed?(id) }
      payload[:watcher_user_ids] = filter_watchers(payload[:watcher_user_ids], ignored)
      payload[:builtin_fields] = filter_custom_fields(ignored)
      payload[:ignored] = ignored
      payload
    end

    private

    def filter_id(value, key, ignored)
      return nil if value.blank?

      id = value.to_i
      if id.positive? && yield(id)
        id
      else
        ignored << key
        nil
      end
    end

    def active_priority?(id)
      IssuePriority.active.where(id: id).exists?
    end

    def allowed_status_ids
      @allowed_status_ids ||= begin
        issue = Issue.new(project: @project, tracker_id: @tracker_id, author: @user)
        Array(issue.new_statuses_allowed_to(@user)).map(&:id)
      rescue StandardError
        []
      end
    end

    def assignee_allowed?(id)
      users = @project.assignable_users
      if users.respond_to?(:where)
        users.where(id: id).exists?
      else
        Array(users).any? { |user| user.id == id }
      end
    end

    def category_allowed?(id)
      @project.issue_categories.where(id: id).exists?
    end

    def filter_watchers(ids, ignored)
      wanted = Array(ids).map(&:to_i).select(&:positive?).uniq
      return [] if wanted.empty?

      allowed = @project.users.active.where(id: wanted).select { |user| user.visible?(@user) }.map(&:id)
      ignored << 'watcher_user_ids' if allowed.sort != wanted.sort
      allowed
    end

    def filter_custom_fields(ignored)
      raw = @template.custom_field_values
      return {} if raw.blank?

      fields = IssueCustomField.where(id: raw.keys.map(&:to_i)).index_by { |field| field.id.to_s }
      kept = {}
      dropped = false
      raw.each do |key, value|
        field = fields[key.to_s]
        coerced = field && available_field?(field) ? SafeCustomFields.coerce(field, value) : nil
        if coerced.nil?
          dropped = true
          Rails.logger.debug { "[redmine_issue_templates] skipped custom field #{key}" }
          next
        end
        kept[field.id.to_s] = coerced
      end
      ignored << 'builtin_fields' if dropped
      kept
    end

    def available_field?(field)
      return false unless SafeCustomFields.safe_format?(field)
      return false if @tracker_id.blank? || !field.tracker_ids.include?(@tracker_id.to_i)
      return false unless field.is_for_all? || field.project_ids.include?(@project.id)

      field.visible_by?(@project, @user)
    end
  end
end
