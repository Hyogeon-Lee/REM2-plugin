---
name: conventional-commit
description: 'Prompt and workflow for generating conventional commit messages using a structured XML format. Guides users to create standardized, descriptive commit messages in line with the Conventional Commits specification, including instructions, examples, and validation. Use when the user asks for a Conventional Commits message, wants a commit message checked against the spec, or asks how to structure the type, scope, body, or footer.'
license: MIT
metadata:
  source: "https://github.com/github/awesome-copilot/tree/caab1f623bb68a330f294a11279597d7ae7be737/skills/conventional-commit"
  source-commit: "caab1f623bb68a330f294a11279597d7ae7be737"
---

### Instructions

```xml
	<description>This file contains a prompt template for generating conventional commit messages. It provides instructions, examples, and formatting guidelines to help users write standardized, descriptive commit messages in accordance with the Conventional Commits specification.</description>
```

### Workflow

**Follow these steps:**

1. Run `git status` to review changed files.
2. Run `git diff` or `git diff --cached` to inspect changes.
3. Stage your changes with `git add <file>`.
4. Construct your commit message using the following XML structure.
5. Show the constructed commit message to the user and wait for confirmation, then run the commit in the terminal:

```bash
git commit -m "type(scope): description"
```

6. If the user has already asked you to commit directly, skip the confirmation step and run the command as soon as the message is ready.

### Commit Message Structure

```xml
<commit-message>
	<type>feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert</type>
	<scope>()</scope>
	<description>A short, imperative summary of the change</description>
	<body>(optional: more detailed explanation)</body>
	<footer>(optional: e.g. BREAKING CHANGE: details, or issue references)</footer>
</commit-message>
```

### Examples

```xml
<examples>
	<example>feat(parser): add ability to parse arrays</example>
	<example>fix(ui): correct button alignment</example>
	<example>docs: update README with usage instructions</example>
	<example>refactor: improve performance of data processing</example>
	<example>chore: update dependencies</example>
	<example>feat!: send email on registration (BREAKING CHANGE: email service required)</example>
</examples>
```

### Validation

```xml
<validation>
	<type>Must be one of the allowed types. See <reference>https://www.conventionalcommits.org/en/v1.0.0/#specification</reference></type>
	<scope>Optional, but recommended for clarity.</scope>
	<description>Required. Use the imperative mood (e.g., "add", not "added").</description>
	<body>Optional. Use for additional context.</body>
	<footer>Use for breaking changes or issue references.</footer>
</validation>
```

### Final Step

```xml
<final-step>
	<cmd>git commit -m "type(scope): description"</cmd>
	<note>Replace with your constructed message. Include body and footer if needed.</note>
</final-step>
```
