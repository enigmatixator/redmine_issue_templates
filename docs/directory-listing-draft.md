# redmine.org directory listing draft

Status: Draft

Do not submit this listing until the public repository exists and the quality bar in the plugin README is green. This file is the text to paste. It is not a submission.

## Plugin name

Issue Templates

## Identifier / website

https://github.com/redmineshop/redmine_issue_templates

## Version

0.3.0

## Compatible Redmine versions

7.0.x

Do not tick 7.1, 6.x, or older. Those versions were not run for this release.

## License

GPLv2

## Description

Start a new issue from a reusable template on Redmine 7.0.

- Global templates and per-project templates
- Each template can be linked to one or more trackers
- A default template per tracker (the project default wins; the global default is the fallback)
- On Issues → New, pick a template or receive the default. Subject, description, and tracker are filled in. Priority, workflow-allowed status, assignee, category, watchers, and a whitelist of custom fields are filled in when they are allowed
- When Issue Checklists is installed, a template can add checklist items after the issue is created. If that plugin is missing, or the user cannot manage checklists, the issue is still created

The folder name is `redmine_issue_templates` on purpose. This is the RedmineShop build for Redmine 7.0 and newer, not the classic plugin (akiko-pusu or the agileware-jp fork). Uninstall the classic plugin and restart Redmine before installing this one. Do not install them side by side.

## Screenshots to upload

- Project template list
- Template edit form, including checklist items
- New issue form with a template applied

Use the PNG files in `screenshots/`.
