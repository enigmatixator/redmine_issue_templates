# frozen_string_literal: true

class CommunityIssueTemplate < ApplicationRecord
  belongs_to :project, optional: true
  belongs_to :author, class_name: 'User', optional: true

  has_many :template_trackers,
           class_name: 'CommunityIssueTemplateTracker',
           foreign_key: :community_issue_template_id,
           dependent: :destroy,
           inverse_of: :template
  has_many :trackers, through: :template_trackers
  has_many :defaults,
           class_name: 'CommunityIssueTemplateDefault',
           foreign_key: :community_issue_template_id,
           dependent: :destroy,
           inverse_of: :template

  serialize :builtin_fields, coder: JSON
  serialize :watcher_user_ids, coder: JSON

  validates :title, presence: true, length: { maximum: 255 }
  validates :subject, length: { maximum: 255 }, allow_blank: true
  validates :enabled, inclusion: { in: [true, false] }
  validates :position, numericality: { only_integer: true, greater_than: 0 }

  scope :enabled, -> { where(enabled: true) }
  scope :global, -> { where(project_id: nil) }

  before_validation :normalize_title
  before_validation :assign_position

  def self.visible_for(project)
    project_id = project.respond_to?(:id) ? project.id : project
    if RedmineIssueTemplates.apply_global_templates?
      enabled.where(project_id: [project_id, nil])
    else
      enabled.where(project_id: project_id)
    end
  end

  def self.available_for(project, tracker)
    tracker_id = tracker.respond_to?(:id) ? tracker.id : tracker
    visible_for(project)
      .joins(:template_trackers)
      .where(community_issue_template_trackers: { tracker_id: tracker_id })
      .distinct
      .order(:position, :id)
  end

  def watcher_ids
    normalized_watcher_ids
  end

  def custom_field_values
    normalized_builtin_fields.each_with_object({}) do |(key, value), hash|
      hash[key.to_s] = value
    end
  end

  # Stored fields for the new-issue form. CommunityIssueTemplatesController#show
  # wraps this in ApplyPayload, which drops values the current user cannot use.
  def apply_payload(current_tracker_id: nil)
    ids = template_trackers.order(:tracker_id, :id).pluck(:tracker_id)
    current = current_tracker_id.to_i
    suggested = if current.positive? && ids.include?(current)
                  current
                else
                  ids.first
                end
    {
      id: id,
      title: title,
      subject: subject.to_s,
      description: content.to_s,
      tracker_id: suggested,
      tracker_ids: ids,
      priority_id: priority_id,
      status_id: status_id,
      assigned_to_id: assigned_to_id,
      category_id: category_id,
      watcher_user_ids: normalized_watcher_ids,
      builtin_fields: normalized_builtin_fields
    }
  end

  private

  def normalize_title
    self.title = title.to_s.strip
  end

  def assign_position
    # 0 is invalid and must stay invalid. Only fill a missing position.
    return unless position.nil?

    scope = self.class.where(project_id: project_id)
    scope = scope.where.not(id: id) if persisted?
    self.position = scope.maximum(:position).to_i + 1
  end

  def normalized_watcher_ids
    raw = watcher_user_ids
    raw = JSON.parse(raw) if raw.is_a?(String)
    Array(raw).filter_map do |value|
      next if value.blank?

      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end
  rescue JSON::ParserError
    []
  end

  def normalized_builtin_fields
    raw = builtin_fields
    raw = JSON.parse(raw) if raw.is_a?(String)
    raw.is_a?(Hash) ? raw : {}
  rescue JSON::ParserError
    {}
  end
end
