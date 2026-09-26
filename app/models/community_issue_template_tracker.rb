# frozen_string_literal: true

class CommunityIssueTemplateTracker < ApplicationRecord
  belongs_to :template,
             class_name: 'CommunityIssueTemplate',
             foreign_key: :community_issue_template_id,
             inverse_of: :template_trackers
  belongs_to :tracker

  validates :tracker_id, uniqueness: { scope: :community_issue_template_id }
end
