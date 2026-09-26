// Fills the new-issue form from a template JSON payload.
// Applies subject, description, tracker, and the safe optional fields
// (priority, status, assignee, category, watchers, whitelisted custom fields).
// Status and priority changes must not reapply a template.
// Checklist rows are created on the server after the issue is saved,
// from the submitted template id. This script does not create them.
(function () {
  var booted = false;
  var pendingApply = null;

  function field(id) {
    return document.getElementById(id);
  }

  function isDirty() {
    var subject = field('issue_subject');
    var description = field('issue_description');
    var subjectText = subject ? subject.value.trim() : '';
    var descriptionText = description ? description.value.trim() : '';
    return subjectText.length > 0 || descriptionText.length > 0;
  }

  function setField(element, value) {
    if (!element) return;
    element.value = value;
    element.dispatchEvent(new Event('input', { bubbles: true }));
    element.dispatchEvent(new Event('change', { bubbles: true }));
    if (window.jQuery) {
      window.jQuery(element).trigger('input').trigger('change');
    }
  }

  function showNotice(select, text) {
    var notice = field('community-issue-template-notice');
    if (!notice) return;
    notice.textContent = text || '';
    notice.hidden = !text;
  }

  function shouldConfirm(select, mode) {
    if (!isDirty()) return false;
    if (mode === 'default' && select.getAttribute('data-confirm-overwrite') !== '1') {
      return false;
    }
    return true;
  }

  function placeSelect() {
    var row = field('community-issue-template-row');
    var tracker = field('issue_tracker_id');
    if (!row || !tracker || !tracker.parentNode) return;
    var anchor = tracker.closest ? (tracker.closest('p') || tracker) : tracker;
    if (!anchor.parentNode || anchor.nextSibling === row) return;
    anchor.parentNode.insertBefore(row, anchor.nextSibling);
  }

  function trackerWillChange(payload) {
    var tracker = field('issue_tracker_id');
    if (!tracker || payload.tracker_id == null || payload.tracker_id === '') return false;
    return String(tracker.value) !== String(payload.tracker_id);
  }

  function switchTracker(payload) {
    var tracker = field('issue_tracker_id');
    // The form refresh would otherwise apply that tracker's default on top
    // of the template the user just chose.
    tracker.setAttribute('data-cit-skip-default', '1');
    tracker.value = String(payload.tracker_id);
    if (typeof tracker.onchange === 'function') {
      tracker.onchange();
    }
  }

  function setChoice(id, value) {
    if (value == null || value === '') return;
    var element = field(id);
    if (!element) return;
    var stringValue = String(value);
    if (element.options) {
      var match = false;
      var index;
      for (index = 0; index < element.options.length; index += 1) {
        if (element.options[index].value === stringValue) {
          match = true;
          break;
        }
      }
      if (!match) return;
    }
    setField(element, stringValue);
  }

  function applyWatchers(ids) {
    var form = document.getElementById('issue-form');
    if (!form) return;
    var wanted = {};
    (ids || []).forEach(function (id) {
      wanted[String(id)] = true;
    });
    var boxes = form.querySelectorAll('input[name="issue[watcher_user_ids][]"]');
    Array.prototype.forEach.call(boxes, function (box) {
      if (box.type === 'checkbox') {
        var checked = !!wanted[box.value];
        if (box.checked !== checked) {
          box.checked = checked;
          box.dispatchEvent(new Event('change', { bubbles: true }));
        }
      }
    });
    var holderId = 'community-issue-template-watcher-ids';
    var holder = document.getElementById(holderId);
    if (!holder) {
      holder = document.createElement('div');
      holder.id = holderId;
      holder.hidden = true;
      form.appendChild(holder);
    }
    holder.textContent = '';
    (ids || []).forEach(function (id) {
      var selector = 'input[type="checkbox"][name="issue[watcher_user_ids][]"][value="' + String(id) + '"]';
      if (form.querySelector(selector)) return;
      var input = document.createElement('input');
      input.type = 'hidden';
      input.name = 'issue[watcher_user_ids][]';
      input.value = String(id);
      holder.appendChild(input);
    });
  }

  function applyCustomFields(fields) {
    if (!fields) return;
    Object.keys(fields).forEach(function (id) {
      var element = field('issue_custom_field_values_' + id);
      if (!element) return;
      var value = fields[id];
      if (element.type === 'checkbox') {
        element.checked = String(value) === '1';
        element.dispatchEvent(new Event('change', { bubbles: true }));
        return;
      }
      setChoice(element.id, value);
    });
  }

  function applyFields(payload) {
    setField(field('issue_subject'), payload.subject || '');
    setField(field('issue_description'), payload.description || '');
    setChoice('issue_priority_id', payload.priority_id);
    setChoice('issue_status_id', payload.status_id);
    setChoice('issue_assigned_to_id', payload.assigned_to_id);
    setChoice('issue_category_id', payload.category_id);
    applyWatchers(payload.watcher_user_ids);
    applyCustomFields(payload.builtin_fields);
  }

  function noticeText(select, mode, payload) {
    var parts = [];
    if (mode === 'default') {
      var applied = select.getAttribute('data-applied-message');
      if (applied) parts.push(applied);
    }
    if (payload.ignored && payload.ignored.length) {
      var skipped = select.getAttribute('data-ignored-message');
      if (skipped) parts.push(skipped);
    }
    return parts.join(' ');
  }

  function finishApply(payload, mode) {
    applyFields(payload);
    var select = field('community_issue_template_id');
    if (!select) return;
    if (payload.id != null && payload.id !== '') {
      var optionExists = !select.options || Array.prototype.some.call(select.options, function (option) {
        return option.value === String(payload.id);
      });
      if (optionExists) select.value = String(payload.id);
    }
    showNotice(select, noticeText(select, mode, payload));
  }

  function applyPayload(select, payload, mode) {
    if (shouldConfirm(select, mode)) {
      var message = select.getAttribute('data-confirm-message') ||
        'Replace the subject and description with this template?';
      if (!window.confirm(message)) {
        if (mode === 'manual') {
          select.value = select.getAttribute('data-previous-value') || '';
        } else {
          select.value = '';
        }
        return;
      }
    }

    if (trackerWillChange(payload)) {
      pendingApply = { payload: payload, mode: mode };
      switchTracker(payload);
      return;
    }
    finishApply(payload, mode);
  }

  function loadTemplate(select, id, mode) {
    var template = select.getAttribute('data-load-url-template');
    if (!template || !id) return;
    var url = template.split('__ID__').join(encodeURIComponent(id));
    var tracker = field('issue_tracker_id');
    if (tracker && tracker.value) {
      url += (url.indexOf('?') === -1 ? '?' : '&') + 'tracker_id=' + encodeURIComponent(tracker.value);
    }
    var requestId = String(id);
    select.setAttribute('data-loading-id', requestId);
    window.fetch(url, {
      method: 'GET',
      credentials: 'same-origin',
      headers: { Accept: 'application/json' }
    }).then(function (response) {
      if (!response.ok) throw new Error('load failed');
      return response.json();
    }).then(function (payload) {
      if (!select.isConnected) return;
      if (select.getAttribute('data-loading-id') !== requestId) return;
      applyPayload(select, payload, mode);
    }).catch(function () {
      if (!select.isConnected) return;
      showNotice(select, select.getAttribute('data-error-message'));
      if (mode === 'manual') {
        select.value = select.getAttribute('data-previous-value') || '';
      }
    });
  }

  function applyDefault(mode) {
    var select = field('community_issue_template_id');
    if (!select) return;
    var id = select.getAttribute('data-initial-default-id');
    if (!id) return;
    select.value = id;
    loadTemplate(select, id, mode);
  }

  function wrapUpdateIssueFrom() {
    if (typeof window.updateIssueFrom !== 'function' || window.updateIssueFrom.__issueTemplatesWrapped) {
      return;
    }
    var original = window.updateIssueFrom;
    var wrapped = function (url, el) {
      var triggerId = el && el.id;
      var request = original.apply(this, arguments);
      if (triggerId === 'issue_tracker_id' && request && typeof request.done === 'function') {
        request.done(function () {
          placeSelect();
          var skipDefault = el && el.getAttribute('data-cit-skip-default') === '1';
          if (el) el.removeAttribute('data-cit-skip-default');
          if (pendingApply) {
            var job = pendingApply;
            pendingApply = null;
            finishApply(job.payload, job.mode);
            return;
          }
          if (!skipDefault) applyDefault('default');
        });
      }
      return request;
    };
    wrapped.__issueTemplatesWrapped = true;
    window.updateIssueFrom = wrapped;
  }

  function boot() {
    if (booted) return;
    booted = true;
    wrapUpdateIssueFrom();
    placeSelect();
    applyDefault('default');
    document.addEventListener('focusin', function (event) {
      var target = event.target;
      if (target && target.id === 'community_issue_template_id') {
        target.setAttribute('data-previous-value', target.value);
      }
    });
    document.addEventListener('change', function (event) {
      var target = event.target;
      if (!target || target.id !== 'community_issue_template_id') return;
      if (!target.value) return;
      loadTemplate(target, target.value, 'manual');
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
