# Changelog — Issue Templates

## [0.3.0] — 2026-09-25

### Added

- Plugin id and directory name are `redmine_issue_templates`. Display name is Issue Templates. Uninstall the classic plugin before installing this one. Do not run them side by side.
- Template form shows **Checklist items** (one per line) when Issue Checklists is installed
- After a new issue is created from a template, those lines are added as checklist items (`is_done: false`, positions in order), up to 50
- If Issue Checklists is not installed, the association is missing, or the user cannot manage checklists, the seed is skipped and the issue is still created
- English and Vietnamese strings for the checklist field

### Not in this version

- Import from classic `redmine_issue_templates`
- Applying a template while editing an existing issue

## [0.2.0] — 2026-09-24

### Added

- Project menu **Issue templates**: list, create, edit, and delete templates for a project (`manage_issue_templates` and the Issue Templates module)
- Administration → **Issue templates**: the same screens for global templates (administrators)
- Set or clear the default template for a tracker. The project default is preferred; the global default is the fallback
- New-issue apply now fills priority, workflow-allowed status, assignable assignee, project category, visible project-member watchers, and whitelisted custom fields
- Custom-field whitelist: single-value string, text, boolean, list, key/value list, integer, float, and date. User, version, file, link, and multiple-value fields are ignored
- English and Vietnamese strings for the new screens
- Plugin settings still warn against installing beside classic `redmine_issue_templates`, and link to the global template list

### Not in this version

- Checklist item seeding
- Applying a template while editing an existing issue
- Import from classic `redmine_issue_templates`

## [0.1.0] — 2026-09-24

### Added

- Tables `community_issue_templates`, `community_issue_template_trackers`, and `community_issue_template_defaults`
- Permissions `use_issue_templates` and `manage_issue_templates` on the Issue Templates project module
- JSON load of one template for a project (`use_issue_templates` and `add_issues`)
- Template select on the new-issue form, filling subject, description, and tracker
- Confirm-before-overwrite when a tracker change applies a default (on by default)
- Settings: that confirm flag, global templates on every project, and a warning not to install beside classic `redmine_issue_templates`
- `RedmineIssueTemplates::TemplateFactory` for tests and the Rails console
