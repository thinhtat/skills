---
name: jira-ticket
description: Shared reference for the Accountia skills: how to read a Jira ticket in full (issue, comments, links, Confluence pages, parent) through the Atlassian MCP.
disable-model-invocation: true
---

# Read a Jira ticket

The ticket is the **spec**: its description, comments, parent, and every Confluence page it links together define what to build. Reading changes nothing in Jira: status, assignee and comments stay as they are.

## Input

A ticket key (`ACC-1234`) or a browse URL (`https://genieitsoultions.atlassian.net/browse/ACC-1234`). Extract the key from a URL.

## Atlassian calls

- **Site:** pass `cloudId` `genieitsoultions.atlassian.net` on every call.
- **Primary tools** are called directly: `getJiraIssue`, `listJiraIssueComments`, `getConfluenceContent`, `atlassianUserInfo`.
- **Other operations** go through `executeRead`, e.g. `listJiraIssueRemoteIssueLinks`.
- **If a name is rejected,** run `discover` to find its current name.
- **Rich bodies** (mentions, panels, media) come back as HTML even when markdown is requested; read them as HTML.

## Read the ticket

- **The issue.** Call `getJiraIssue` with `view: "evidence"` and `responseContentFormat: "markdown"`. This returns status, type, assignee, reporter, parent, issue links and sub-tasks.
- **The comments.** Call `listJiraIssueComments` and page it until `isLast`. A later comment can narrow or override the description.
- **Linked pages.** Call `listJiraIssueRemoteIssueLinks` to find the linked Confluence pages and MRs.
- **Every Confluence page,** whether linked from the description or from the remote links. Read each with `getConfluenceContent` (`content_format: "markdown"`, `detail: "full"`). These pages are part of the spec.
- **The parent,** if the ticket has one. Read its summary and description, since sub-tasks inherit context from the parent.

Done when the issue, every comment, every linked page in full, and the parent have been read.
