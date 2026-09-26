# frozen_string_literal: true

module RedmineIssueTemplates
  # Custom fields a template may store and apply.
  #
  # Allowed (single value only):
  #   string, text, bool, list, int, float, date, enumeration
  #
  # Ignored (not stored from the form, dropped from the new-issue payload):
  #   user, version, attachment, link, any other format, and any field with
  #   multiple values. Enumeration is the Redmine key/value list, single id only.
  module SafeCustomFields
    FORMATS = %w[string text bool list int float date enumeration].freeze

    module_function

    def safe_format?(field)
      return false unless field
      return false unless FORMATS.include?(field.field_format.to_s)
      return false if field.respond_to?(:multiple?) && field.multiple?

      true
    end

    # Fields the template form is allowed to edit.
    # Project forms only include fields enabled on that project.
    # Global forms include every safe issue custom field that has a tracker.
    def for_editor(project)
      tracker_ids = if project
                      project.tracker_ids
                    else
                      Tracker.pluck(:id)
                    end
      IssueCustomField.sorted.select do |field|
        next false unless safe_format?(field)
        next false if (field.tracker_ids & tracker_ids).empty?
        next true if project.nil?

        field.is_for_all? || field.project_ids.include?(project.id)
      end
    end

    # Returns a string to store/apply, or nil when the value must be dropped.
    # Blank text-like values return nil so an empty input does not wipe the
    # issue form. Bool is always "0" or "1" when a value was submitted.
    def coerce(field, raw)
      return nil unless safe_format?(field)
      return nil if raw.is_a?(Array)

      value = raw.to_s
      case field.field_format.to_s
      when 'bool'
        %w[1 true yes on].include?(value.strip.downcase) ? '1' : '0'
      when 'int'
        return nil if value.blank?
        return nil unless value.match?(/\A-?\d+\z/)

        value
      when 'float'
        return nil if value.blank?
        return nil unless value.match?(/\A-?\d+(?:\.\d+)?\z/)

        value
      when 'date'
        return nil if value.blank?

        Date.iso8601(value).strftime('%Y-%m-%d')
      when 'list'
        return nil if value.blank?
        return nil unless Array(field.possible_values).map(&:to_s).include?(value)

        value
      when 'enumeration'
        return nil if value.blank?
        return nil unless enumeration_id?(field, value)

        value.to_i.to_s
      else
        return nil if value.blank?
        max = field.respond_to?(:max_length) ? field.max_length.to_i : 0
        return nil if max.positive? && value.length > max

        value
      end
    rescue ArgumentError, TypeError
      nil
    end

    def enumeration_id?(field, value)
      return false unless value.to_s.match?(/\A\d+\z/)
      return false unless field.respond_to?(:enumerations)

      field.enumerations.any? { |enumeration| enumeration.id == value.to_i }
    end
  end
end
