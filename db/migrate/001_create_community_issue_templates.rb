# frozen_string_literal: true

# Rails 8 compatibility class. Redmine 7.0.0 loads Migration[8.0];
# Redmine 7.0.1 (Rails 8.1) still runs it. Sibling plugins that declare
# Redmine 5 stay on Migration[6.1]; this plugin does not.
class CreateCommunityIssueTemplates < ActiveRecord::Migration[8.0]
  def up
    # Names are deliberately not issue_templates / global_issue_templates /
    # note_templates, so a leftover classic schema does not collide.
    # Side-by-side use with classic redmine_issue_templates is still unsupported.
    create_table :community_issue_templates do |t|
      t.integer :project_id
      t.string :title, null: false, limit: 255
      t.text :description
      t.string :subject, limit: 255
      t.text :content
      t.integer :priority_id
      t.integer :status_id
      t.integer :assigned_to_id
      t.integer :category_id
      t.boolean :enabled, null: false, default: true
      t.integer :position, null: false, default: 1
      t.integer :author_id
      # Newline-separated checklist subjects. M1 stores the column only.
      # M3 may seed IssueChecklist rows after save. Do not seed in M1.
      # If the user lacks :manage_issue_checklists, that future seed must skip.
      t.text :checklist_items
      t.text :builtin_fields
      t.text :watcher_user_ids
      t.timestamps
    end
    add_index :community_issue_templates, :project_id, name: 'index_cit_templates_on_project_id'
    add_index :community_issue_templates, :author_id, name: 'index_cit_templates_on_author_id'
    add_index :community_issue_templates, %i[project_id enabled position], name: 'index_cit_templates_on_project_enabled_position'

    create_table :community_issue_template_trackers do |t|
      t.integer :community_issue_template_id, null: false
      t.integer :tracker_id, null: false
    end
    add_index :community_issue_template_trackers,
              %i[community_issue_template_id tracker_id],
              unique: true,
              name: 'index_cit_trackers_on_template_and_tracker'
    add_index :community_issue_template_trackers, :tracker_id, name: 'index_cit_trackers_on_tracker_id'

    create_table :community_issue_template_defaults do |t|
      t.integer :project_id
      t.integer :tracker_id, null: false
      t.integer :community_issue_template_id, null: false
      t.timestamps
    end
    # MySQL and PostgreSQL unique indexes still allow multiple NULL project_id
    # rows. Global uniqueness is enforced on the model (project_id IS NULL).
    add_index :community_issue_template_defaults,
              %i[project_id tracker_id],
              unique: true,
              name: 'index_cit_defaults_on_project_and_tracker'
    add_index :community_issue_template_defaults,
              :community_issue_template_id,
              name: 'index_cit_defaults_on_template_id'
    add_index :community_issue_template_defaults, :tracker_id, name: 'index_cit_defaults_on_tracker_id'
  end

  def down
    drop_table :community_issue_template_defaults, if_exists: true
    drop_table :community_issue_template_trackers, if_exists: true
    drop_table :community_issue_templates, if_exists: true
  end
end
