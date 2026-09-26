# frozen_string_literal: true

class CommunityIssueTemplateDefault < ApplicationRecord
  belongs_to :template,
             class_name: 'CommunityIssueTemplate',
             foreign_key: :community_issue_template_id,
             inverse_of: :defaults
  belongs_to :tracker
  belongs_to :project, optional: true

  validates :tracker_id, presence: true
  validates :tracker_id, uniqueness: { scope: :project_id }
  validate :template_matches_tracker_and_project

  # Project default wins. Global default is the fallback when the plugin
  # setting allows global templates.
  def self.for_tracker(project, tracker)
    project_id = record_id(project)
    tracker_id = record_id(tracker)
    return nil if project_id.nil? || tracker_id.nil?

    rows = includes(:template).where(tracker_id: tracker_id)
    project_row = rows.find_by(project_id: project_id)
    return project_row if usable?(project_row, project_id)

    return nil unless RedmineIssueTemplates.apply_global_templates?

    global_row = rows.find_by(project_id: nil)
    return global_row if usable?(global_row, project_id)

    nil
  end

  def self.usable?(row, project_id)
    template = row&.template
    return false unless template&.enabled?
    return false if template.project_id.present? && template.project_id != project_id

    true
  end
  private_class_method :usable?

  def self.record_id(record_or_id)
    return nil if record_or_id.nil?

    value = record_or_id.respond_to?(:id) ? record_or_id.id : record_or_id
    number = Integer(value)
    number.positive? ? number : nil
  rescue ArgumentError, TypeError
    nil
  end
  private_class_method :record_id

  private

  def template_matches_tracker_and_project
    return if template.nil? || tracker_id.blank?

    unless template.template_trackers.exists?(tracker_id: tracker_id)
      errors.add(:community_issue_template_id, :tracker_mismatch)
    end

    if project_id.nil?
      errors.add(:community_issue_template_id, :must_be_global) if template.project_id.present?
    elsif template.project_id.present? && template.project_id != project_id
      errors.add(:community_issue_template_id, :project_mismatch)
    end
  end
end
