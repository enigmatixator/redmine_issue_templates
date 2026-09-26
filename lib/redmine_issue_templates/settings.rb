# frozen_string_literal: true

module RedmineIssueTemplates
  # Founder decision: confirm before a tracker change applies a new default.
  CONFIRM_OVERWRITE_ON_TRACKER_CHANGE_DEFAULT = true
  APPLY_GLOBAL_TEMPLATES_DEFAULT = true

  # This build registers :redmine_issue_templates, the same id as classic
  # akiko-pusu / agileware-jp. Plugin.installed? on that id is this plugin.
  CLASSIC_TABLE = 'issue_templates'

  def self.plugin_settings
    Setting.plugin_redmine_issue_templates || {}
  end

  def self.confirm_overwrite_on_tracker_change?
    setting_on?('confirm_overwrite_on_tracker_change', CONFIRM_OVERWRITE_ON_TRACKER_CHANGE_DEFAULT)
  end

  def self.apply_global_templates?
    setting_on?('apply_global_templates', APPLY_GLOBAL_TEMPLATES_DEFAULT)
  end

  # True when classic code, a leftover classic table, or another folder that
  # registers this id is present. Never true merely because this plugin loaded.
  def self.classic_plugin_installed?
    classic_model_loaded? || classic_table_present? || classic_plugin_directory_present?
  end

  # Soft dependency. Never requires_redmine_plugin.
  def self.checklists_plugin_present?
    Redmine::Plugin.installed?(:redmine_issue_checklists)
  end

  def self.classic_model_loaded?
    return false unless Object.const_defined?(:IssueTemplate)

    model = Object.const_get(:IssueTemplate)
    model.is_a?(Class) && model < ActiveRecord::Base && model.table_name == CLASSIC_TABLE
  rescue StandardError
    false
  end
  private_class_method :classic_model_loaded?

  def self.classic_table_present?
    ActiveRecord::Base.connection.data_source_exists?(CLASSIC_TABLE)
  rescue StandardError
    false
  end
  private_class_method :classic_table_present?

  def self.classic_plugin_directory_present?
    plugins_dir = Rails.root.join('plugins')
    return false unless plugins_dir.directory?

    Dir.children(plugins_dir).any? do |entry|
      next false if entry == 'redmine_issue_templates'

      init = plugins_dir.join(entry, 'init.rb')
      next false unless init.file?

      source = init.read
      source.include?('Redmine::Plugin.register :redmine_issue_templates') &&
        !source.include?('RedmineIssueTemplates::VERSION')
    end
  rescue StandardError
    false
  end
  private_class_method :classic_plugin_directory_present?

  def self.setting_on?(key, default)
    value = plugin_settings[key]
    return default if value.nil? || value.to_s.strip.empty?

    %w[1 true yes on].include?(value.to_s.strip.downcase)
  end
  private_class_method :setting_on?
end
