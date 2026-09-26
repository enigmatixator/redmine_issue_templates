# frozen_string_literal: true

get 'projects/:project_id/issue_templates',
    to: 'community_issue_templates#index',
    as: :project_community_issue_templates

post 'projects/:project_id/issue_templates',
     to: 'community_issue_templates#create'

get 'projects/:project_id/issue_templates/new',
    to: 'community_issue_templates#new',
    as: :new_project_community_issue_template

get 'projects/:project_id/issue_templates/:id/edit',
    to: 'community_issue_templates#edit',
    as: :edit_project_community_issue_template

patch 'projects/:project_id/issue_templates/:id',
      to: 'community_issue_templates#update'

put 'projects/:project_id/issue_templates/:id',
    to: 'community_issue_templates#update'

delete 'projects/:project_id/issue_templates/:id',
       to: 'community_issue_templates#destroy'

post 'projects/:project_id/issue_templates/:id/default',
     to: 'community_issue_templates#set_default',
     as: :set_default_project_community_issue_template

post 'projects/:project_id/issue_templates/:id/clear_default',
     to: 'community_issue_templates#clear_default',
     as: :clear_default_project_community_issue_template

# JSON load for the new-issue form. Declared after /new and /edit.
get 'projects/:project_id/issue_templates/:id',
    to: 'community_issue_templates#show',
    as: :project_community_issue_template

get 'admin/issue_templates',
    to: 'global_issue_templates#index',
    as: :global_issue_templates

post 'admin/issue_templates',
     to: 'global_issue_templates#create'

get 'admin/issue_templates/new',
    to: 'global_issue_templates#new',
    as: :new_global_issue_template

get 'admin/issue_templates/:id/edit',
    to: 'global_issue_templates#edit',
    as: :edit_global_issue_template

patch 'admin/issue_templates/:id',
      to: 'global_issue_templates#update',
      as: :global_issue_template

put 'admin/issue_templates/:id',
    to: 'global_issue_templates#update'

delete 'admin/issue_templates/:id',
       to: 'global_issue_templates#destroy'

post 'admin/issue_templates/:id/default',
     to: 'global_issue_templates#set_default',
     as: :set_default_global_issue_template

post 'admin/issue_templates/:id/clear_default',
     to: 'global_issue_templates#clear_default',
     as: :clear_default_global_issue_template
