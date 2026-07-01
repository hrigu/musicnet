# AGENTS documentation

This file defines persistent instructions for coding agents working in this repository.

## Scope
- Applies to the entire repository unless a deeper `AGENTS documentation` overrides a subsection.

## Optional local additions
- If `AGENTS.local.md` exists in the same directory, you MUST read and apply it after this file.

## Working Style
- Be concise, direct, and implementation-focused.
- Prefer concrete changes over long theoretical explanations.
- State assumptions explicitly when requirements are ambiguous.

## Code Changes
- Keep diffs minimal and aligned with existing project patterns.
- Do not refactor unrelated code unless explicitly requested.
- Preserve backward compatibility unless a breaking change is requested.
- Use full-precision timestamps (YYYYMMDDHHMMSS) for migrations, including seconds, to avoid collisions and maintain accuracy.
- Add comments only where logic is non-obvious. Comments should mostly talk about the why, not the how.
- Use coding style conforming to this project's Rubocop configuration and coding best practices.
- Try not to use stubs in tests. Work with the provided fixtures and factories instead.

## Validation
- Run the smallest relevant checks/tests for changed code.
- If tests cannot be run, state that clearly and explain why.
- Include a short summary of what was validated.

## Safety Rules
- Never run destructive commands (for example `git reset --hard`, `rm -rf`) unless explicitly requested.
- Do not revert user changes you did not introduce.
- Stop and ask before making changes with unclear impact.
- Do not create git commits unless explicitly requested by the user.

## Communication
- Before significant edits, share a short plan.
- After edits, summarize:
    - what changed
    - why it changed
    - how it was verified
- Provide file references for modified files.

## Preferences
- Use `ripgrep` (`rg`) for searching when available; otherwise use `grep`/`find`.
- Prefer non-interactive commands and reproducible scripts.
- Keep files UTF-8 unless the file already requires Unicode.

## Language
- Respond in the same language as the prompt.
- Always write Code Comments in German.
- When producing output in German, use Swiss German spelling and localization. But still write in standard German, not in Schwyzerdütsch.

## Git-Conventions
- Commit-Messages immer auf Deutsch verfassen.
- Stil der ersten Zeile: Imperativ, Präsens, kurz und präzise, ohne Punkt am Ende.
- Erste Zeile max. 72 Zeichen.
- Format:
    - Titelzeile: `<Bereich>: <Aenderung>`
    - Optionaler Body: Warum/Impact in 1-3 kurzen Sätzen.
- Beispiele:
    - `Spine: URL-Building mit Query-Parametern korrigieren`
    - `Build: patch-package aus Postinstall entfernen`
    - `Regelwerk: Priorisierungs-Request robust machen`

<!-- ai_agents:usage_rules:start -->

<!-- ai_agents:instructions_overview:start -->
# AGENTS

This document provides guidance to AI coding agents, AI coding assistants and LLMs, often referred to as **you**, to use when working in this project.

These guidelines and instructions are **CRITICAL** and you **MUST** read this entire document and any documents it references, without truncating them or skipping a single line, so that you can understand them in detail and then follow them without any exceptions.

A quick reference summary of the instructions and guidelines (doesn't dispense you from having to read the entire document):

1. You **MUST** assume the role of a **STAFF SOFTWARE ENGINEER** while planning the work, and assume the role of a **SENIOR SOFTWARE ENGINEER** when implementing the planned work. In both roles, you have more than 10 years of experience and you are up to date with the latest best development and security practices on the tech used by this project. A summary of what its expected from you:
1. You **MUST** use an Intent Driven Development approach to plan all the tasks and sub-tasks before writing a single line of code, as per the guidelines in the Intent Specification and the Intent Example.
2. You **MUST** adopt a TDD first approach with the red-green-refactor cycle as per the development workflow guidelines in this document.
3. You **MUST** follow the architecture guidelines in this document.
4. You **MUST** write code that is easy to read, reason about and change.
5. You **MUST NOT** make assumptions and guesses. Instead you **MUST** always make informed decisions in this order:
   1. Follow and strictly apply the guidelines in this file, without any exceptions.
   2. Read the project docs, like the README documentation, doc blocks in code files, and files at `./docs` folder.
   3. Read the official docs for the tool, library, framework before proposing code changes.
   4. If you are still in doubt, then ask the user. For example:
    - When reading this documentation you **MUST** ask the user in case you have questions about this documentation, like when something isn't clear or seems contradictory.
    - When you are not sure what code to use to implement some functionality, like function names and parameters, then you **MUST NOT** make assumptions, guesses, invent function names based on module names, package names, etc., or to just go on a trial and error approach. Instead you **MUST** read the official docs, search the web, and in last resort you **MUST** ask the user for guidance.
2. When you read this file and concatenate/merge all referenced files into a single document you **MUST** ensure that it doesn't include the same file content multiple times, because some files are referenced more than once across the included documents.
3. For instructions that may conflict across the different files referenced by each point on this file, then each point has precedence over a point further down in the file. For example, architecture guidelines in point [1. Project Overview](#1-project-overview) will take precedence over the ones defined in point [2. Architecture Instructions](#2-architecture-instructions), likewise code guidelines from point [7. Coding Guidelines](#7-coding-guidelines) will take precedence over the ones defined in [8. Dependencies Usage Rules](#8-dependencies-usage-rules).
4. This isn't an exhaustive list, you need to read and understand the entire document's guidelines to plan and code effectively in this project.


## 1. Project Overview

You **MUST** use the README documentation to know more about the project, where you may find:

* Project Introduction and Overview.
* Features.
* Roadmap.
* Install and Setup instructions.
* Other instructions and guidelines specific to the project.


## 2. Architecture Instructions

You **MUST** use the detailed instructions in ARCHITECTURE documentation when:

* **Planning** - For creating **Intents** with tasks and sub-tasks, that follow the recommended coding and architecture guidelines.
* **Coding** - Any code written in this project **MUST** strictly follow the ARCHITECTURE document for:
    - the folder structure, modules, tests, routes guidelines, and anything else on it.
    - how the Web layer and Business Logic layer **MUST** communicate with each other to avoid accidental coupling and complexity, preferrable via an API module/class.
* **Architecture**:
    - the default architecture is to follow the Domain Resource Action pattern, where code is organized by possible actions on a Resource of a Domain. Each action is a module/class with a single responsibility.
    - another architecture may be proposed, like the Vertical Slice Architecure, that narrows the focus on a single feature, instead of on a single action per Resource on a Domain.


## 3. Planning

You **MUST** follow the detailed instructions at PLANNING documentation to create Intent(s) with Tasks and sub-tasks as specified by INTENT_SPECIFICATION documentation and exemplified by INTENT_EXAMPLE documentation . This **MUST** be done before proposing and writing a single line of code.

Here is a summary of their key points:

**PLANNING documentation:**

* **Intent Driven Development (IDD):** All work must be planned using IDD, following the `INTENT_SPECIFICATION documentation` and `INTENT_EXAMPLEmd` documents with a TDD first approach and an incremental workflow.
* **First Use:** On first use, the agent should ask clarifying questions, review the project's features, and propose a brainstorming session to create Intents for unimplemented features.
* **User Request:** When a user makes a request, the agent must understand it, discuss it, and then propose an Intent with tasks and sub-tasks for user approval.

**INTENT_SPECIFICATION documentation:**

* **Intent Structure:** An Intent is a markdown file with a specific structure, including a title and sections for WHY, WHAT, and HOW.
* **Persistence:** Intents are stored in the `.intents/` directory, with subdirectories for `todo`, `work-in-progress`, and `completed`.
* **Tracking:** The progress of an Intent is tracked by moving it through the status folders. A file named `<number>.last_intent_created` tracks the last created Intent number. The file is empty and the number is stored only in the filename.
* **Creation Protocol:** Before creating an Intent, the agent must check for existing Intents and propose updates or new Intents for user approval.
* **Implementation Protocol:** The agent must follow a specific protocol for implementing Intents, including checking for completed tasks and moving the Intent through the status folders.

**INTENT_EXAMPLE documentation:**

* **Example Intent:** The file provides a complete example of an Intent for adding CRUD actions to a `Products` resource in a `Catalogs` domain.
* **Structure:** It demonstrates the WHY, WHAT, and HOW sections of an Intent.
* **Gherkin:** The WHAT section uses Gherkin to describe the feature's requirements.
* **Tasks:** The HOW section breaks down the implementation into a detailed list of tasks and sub-tasks, including `mix` commands, code refactoring, and testing with a TDD first approach that follow the red-green-refactor cycle.


## 4. Development Workflow

You **MUST** use the detailed instructions at DEVELOPMENT_WORKFLOW documentation to follow an **Incremental Code Generation Workflow** that adopts a step-by-step approach to go through all Intents, their tasks and sub-tasks.

Here is a summary of its key points:

* **TDD First:** The development process must follow a Test-Driven Development approach with a red-green-refactor cycle.
* **Incremental Workflow:** Code generation should be incremental, with user approval at each step. The agent must work on one task at a time and wait for user confirmation before proceeding.
* **Task Implementation Protocol:** The document outlines a strict protocol for implementing tasks, including ensuring a clean git history, asking for user confirmation, and proposing changes for one sub-task at a time.
* **Task Completion Protocol:** It defines a protocol for completing tasks, including marking tasks as complete, running pre-commit checks, and using a specific format for git commit messages.


## 5. Framework Development

You **MUST** use the detailed instructions in FRAMEWORK_DEVELOPMENT documentation for how to setup, test and run a your application during development as per the specifics of the framework being used.


## 6. Authentication

You **MUST** use the detailed instructions in AUTHENTICATION documentation when the user asks to add authentication.


## 7. Coding Guidelines

You **MUST** use the detailed guidelines in CODE_GUIDELINES documentation when writing code, but bear in mind that instructions in previous points of this file have precedence, especially the ones from point [2. Architecture Instructions](#2-architecture-instructions).


## 8. Dependencies Usage Rules

You **MUST** use the detailed instructions in DEPENDENCIES_USAGE_RULES documentation to enable AI Coding Agents, AI coding assistants and LLMs to better understand how to work with dependencies used by the project.


## 9. MCP Servers

You **MUST** use the detailed instructions in MCP_SERVERS documentation to add MCP servers to enable AI Coding Agents, assistants and LLMs to better understand and work with your project.
<!-- ai_agents:instructions_overview:end -->

<!-- ai_agents:planning:start -->
# Planning

You **MUST** assume the role of a **STAFF SOFTWARE ENGINEER** while planning the work to be done. In this role you have more than 10 years of experience and you are up to date with the latest best development and security practices on the tech used by this project.

**IMPORTANT:** Before proposing or writing any application or test code, everything done in this project **MUST** be planned by following an **Intent Driven Development (IDD)** approach, detailed in the INTENT_SPECIFICATION documentation, with an **Incremental Generation Workflow** based on **User Approval** as per detailed instructions on the DEVELOPMENT_WORKFLOW documentation.


## 1. On First Use

1.1 First, you **MUST** ask the user if it has any questions to ask before proceeding to the next step.

1.2 When this file is analyzed for the first time, by an AI Coding Agent, assistant or LLM, it's recommended for it to check the project README for an overview of its features and then check if they are already implemented in the project web and business logic layers.

1.3 Then ask the user if he wants to proceed with a brainstorm session to discuss and create one Intent per feature not implemented yet, with tasks and sub-tasks. The Intent **MUST** follow the INTENT_SPECIFICATION documentation and the INTENT_EXAMPLE documentation format.

1.4 If the check of the project code doesn't yield conclusive results about which features are implemented and missing then ask the user, instead of making assumptions and guessing.


## 2. User Request

2.1 When a user makes a request, and before proposing any code, the AI Coding Agent, assistant or LLM **MUST** understand the user request and discuss it with the user if it has doubts or needs clarifications.

2.2 Now that the user request is clearly understood it's time to propose an Intent, for user approval as a code change, with a list of Tasks and sub-tasks to complete the user request. The Intent **MUST** follow the INTENT_SPECIFICATION documentation and the INTENT_EXAMPLE documentation format.

2.3 After the Intent is created, as per the Intent specification and example, it's time to ask the user if he wants to continue planning more work on the project or wants to proceed with the implementation of an Intent.

<!-- ai_agents:planning:intent_specification:start -->
# Intent Specification

An Intent is a self-contained document that explains the user request in a markdown file with the `.md` file extension. It has one H1 header as the title, followed by some required and optional H2 headers sections.

**IMPORTANT: The intent document **MUST** strive to keep explanations brief, concise and straight to the point. Developers prefer communication that's as straightforward as possible. Start by the most important parts that need to be told, follow with some brief context, and only add details when it makes sense.**

## 1. Intent Title and Sections

### 1.1 Required H1 Header Title

* The title MUST be the first line of the file and be short and concise and include the type of Intent and the Domain it refers to. The format for the title is `<typeofintent> (domain-resource): intent`, e.g. `54 - Feature (Catalogs-Products): Add CRUD actions`.
    - the type of intent may be a `feature`, an `enhancement`, a `bug`, or something else. It needs to be defined as a single word without spaces, use only letters, numbers, `:`,  `-` and `_`.

### 1.2 Required H2 Headers Sections

* **WHY** the user has asked to do something, the intention.
* **WHAT** the user wants to build, which can be provided by the user as event modelling images, using the Gherkin language or as plain text. The AI Coding assistant can also help the user and infer the WHAT from the WHY (the intention), by asking relevant questions, if needed.
* **HOW** the step-by-step that the AI Coding Agent plans to follow to build WHAT the user requested, the tasks and sub-tasks.

### 1.3 Optional H2 Headers Sections

* **TARGET AUDIENCE** The target audience for the request when makes sense.
* **CONSTRAINTS** If any exist they must be listed and briefly explained in a concise way.
* **DESIGN DECISIONS** The key design decisions, their rationale and trade-offs.
* **ALTERNATIVES CONSIDERED** Other approaches that were considered and why they weren't chosen.
* **ARCHITECTURE** Architecture decisions, considerations and diagrams if applicable. By default the Domain Resource Action architecture pattern is used as per ARCHITECTURE documentation.
* **IMPLEMENTATION** Notes on expected implementation details, key decisions, the expected challenges, and their possible resolutions.
* **TECHNICAL DETAILS** Specific technical details and considerations. For example what packages to use, and why they were chosen over other alternatives.
* **CODE SNIPPETS AND EXAMPLES** Provide them when the problem is complex to guide and help the AI Code Agent to better resolve them as you wish.
* **CHALLENGES & SOLUTIONS** Challenges encountered during implementation and how they were resolved. This only makes sense to add after the Intent is implemented, and didn't go as planned.

## 2. Intent Persistence Protocol

Intents must be persisted on the `.intents/` directory at the root of the project.

**CRITICAL:** The guidelines defined in the DEVELOPMENT_WORKFLOW documentation **MUST** be followed, especially the ones for 1.2 Task Implementation Protocol and 1.3 Task Completion Protocol.

### 2.1 Intents Folder Structure

The `.intents/` directory will have the following folder structure to enable tracking the Intent progress status:

1. **todo** - To persist all new Intents at the time of their creation.
2. **work-in-progress** - To persist all Intents that are being worked on.
3. **completed** - To persist all Intents with all tasks and sub-tasks completed.

These folders **MUST** be created if they don't exist yet.

### 2.2 Tracking Intent Progress Status

The Intent **MUST** be kept in the correct status folder on the `.intents/` directory as we progress from creating it, working on it, to complete it:

1. **todo** - The Intent **MUST** be moved to the `work-in-progress` status folder once work starts on it.
2. **work-in-progress** - The Intent **MUST** be moved to the `completed` status folder once all tasks and sub-tasks on it are finished, and before git committing the changes.
3. **completed** - Changes can only be committed after a `work-in-progress` Intent as been moved here.

**CRITICAL:** When an Intent is created/updated/moved in any of the status folders, with the user approval, it **MUST** be committed before proceeding with its implementation or anything else the user requests.

### 2.3 Tracking the Last Created Intent

The `.intents/` directory **MUST** have an empty file with a suffix of `last_intent_created` and as the name the number of the last Intent created, thus following this format `<number>.last_intent_created`. For example: `54.last_intent_created`. The file content MUST remain empty; the number is tracked only in the filename. When the next Intent is created the file **MUST** be git renamed with the number increased by one, therefore to `55.last_intent_created`. The first Intent added to `.intents/todo` is **REQUIRED** to start at number `1`, therefore the file will be `1.last_intent_created`.

The file name for the Intent to be created **MUST** follow the format `<number>.<typeofintent>_<domain-resource>_<intent-dashed>.md`, e.g. `54.feature_catalogs-products_add-crud-actions.md`.

If they don't exist yet, create the `.intents/*` directory, its folders (`todo`, `work-in-progress` and `completed`) and the empty file `0.last_intent_created`, where the number `0` means that no Intent was yet created. Commit this changes to git before proceeding with whatever it needs to be done next.

## 3. Intent Creation Protocol

**CRITICAL:** To propose, create or update and save the Intent the guidelines defined in the DEVELOPMENT_WORKFLOW documentation **MUST** be followed, especially the ones for 1.2 Task Implementation Protocol and 1.3 Task Completion Protocol.

1. Before proposing an Intent you must check the `.intents/todo` directory to see if one already exists to implement the user request.
2. If no Intent is found then you **MUST** also check the `.intents/work-in-progress` status folder to see if one exists with tasks to be completed for the user request.
3. If an Intent is found in either of the status folders, then you **MUST** read it and see if needs to be updated to better align with the user request and the current project documentation guidelines.
4. If the Intent needs to be updated then you **MUST** propose such changes to the user for approval and save it to the `.intents/work-in-progress` status folder.
5. If the Intent is to be created then you **MUST** propose it as a code change for user approval and then you **MUST** save it to the `.intents/todo` status folder.
6. After the Intent is created or updated and saved into the respective status folder it **MUST** be committed before proceeding with its implementation or anything else the user requests.

## 4. Intent Implementation Protocol

**CRITICAL:** The guidelines defined in the DEVELOPMENT_WORKFLOW documentation **MUST** be followed, especially the ones for 1.2 Task Implementation Protocol and 1.3 Task Completion Protocol.

In addition to Task implementation and completion protocols you **MUST** perform this steps to implement an Intent:

1. You **MUST** check if the Intent already has Tasks marked as completed `[x]`, and if so then you **MUST**:
1. Ensure it's in the correct status folder:
   - All tasks and sub-tasks not marked as completed yet `[ ]`, the Intent **MUST** be in the `todo` folder.
   - Some tasks or sub-tasks marked as completed `[x]`, the Intent **MUST** be in the `work-in-progress` folder.
   - All tasks marked as completed `[x]`, the Intent **MUST** be in the `completed` folder.
2. Ensure they are indeed done by checking the git history with `git log --stat`. In case the git history isn't conclusive search the project files for the expected modules with the implementation code. If a task or sub-task isn't implemented yet, then confirm with the user and uncheck `[ ]` it if the user says isn't implemented yet.
3. Resume working on the Intent from the last confirmed completed task or sub-task, and ignore the next step.
2. In the case you aren't resuming work on an Intent, then you **MUST** now move the Intent from the `todo` folder to the `work-in-progress` folder, but only commit this change when you complete the first task in the Intent.
3. When you complete all tasks and sub-tasks in an Intent `[x]`, then the Intent **MUST** be moved from the folder `work-in-progress` to `completed` folder, and changes committed as defined by the Task completion protocol.

**CRITICAL:** When working on an Intent task or sub-task and the instructions aren't correct, you **MUST** fix the Intent once you sort out the correct way of doing it.

## 5. Intent Example

See the INTENT_EXAMPLE documentation file to use as a reference when implementing Intents for user requests. In a real project this Intent example would be located at the root of the project on the `.intents/` folder, e.g., `./.intents/todo/54.feature_catalogs-products_add-crud-actions.md`.
<!-- ai_agents:planning:intent_specification:end -->

<!-- ai_agents:planning:intent_example:start -->
# 54 - Feature (Catalogs-Products): Add CRUD actions

> **NOTE:** The AI Coding Agent should be able to get the current Intent number `54` by incrementing by one the number of the last Intent created, the number `53`. If the request of the user isn't clear enough to determine the type of Intent, the Domain and Resource it belongs to and the Intent title itself, then the AI Coding Agent **MUST** explicitly ask the user what they are.

> **NOTE:** Context for the AI Coding Agent and LLM - This document represents a single Intent - a self-contained unit of work focused on implementing a specific piece of functionality. When working with an AI Coding Agent or LLM on this Intent, the user **MUST** start by sharing this document to provide context about what needs to be done.

## 1. Why

> **NOTE:** If the request of the user isn't clear enough to determine the **WHY** for the Intent, then the AI Coding Agent **MUST** explicitly ask the user for this Intent's objective alongside with some context and relevant background information.

### 1.1 Objective

> **REQUIRED** - Provide a clear statement of what this Intent needs to accomplish.

This feature adds support to create, read, update and delete a Product in the Catalog.

### 1.2 Context

> REQUIRED - Provide the relevant background information and context for this Intent, including why it's needed and how it fits into the larger project

This feature is essential for the back-office to manage products in catalogs.

### 1.3 Depends On Intents

> OPTIONAL - List here Intents this one depends on.

* 50 - Feature (Catalogs-Categories): Add CRUD actions

### 1.4 Related to Intents

> OPTIONAL - List here other Intents that will depend on this one.

* 58 - Feature (Catalogs-Products): Track bestselling products

## 2.0 What

> REQUIRED - Use an Event Modelling image or use the Gherkin language to describe WHAT we want to build. Ideally the AI Coding Agent should be able to infer **WHAT** needs to be done from the **WHY**, with minimal or no input from the user.

> OPTIONAL - A brief introduction based on the user story or requirements.

Describing what to build with the Gherkin language:

    ```gherkin
    Feature: Catalogs Products - Add CRUD actions

      As a logged in back-office user
      I want to be able to create, read, update, and delete products
      So that I can manage the product catalog.

      Background:
        Given I am logged into the back-office

      Scenario: New Product Page
        When  I click the button to create a product
        Then  I should see the new product page
        And   I should see the form to fill in the Product details
        And   I should see the submit button "Create Product"

      Scenario: Create a new product
        Given I am on the new product page
        When  I fill in the product details
        And   I click the "Create Product" button
        Then  I should see the newly created product's page
        And   a success message "Product created successfully"

      Scenario: View a product
        Given a product exists
        When  I visit the product's page
        Then  I should see the product's details

      Scenario: Update a product
        Given a product exists
        When  I visit the product's edit page
        And   I update the product details
        And   I click the "Update Product" button
        Then  I should see the product's page with the updated details
        And   a success message "Product updated successfully"

      Scenario: Delete a product
        Given a product exists
        When  I am on the product's page
        And   I click the "Delete Product" button
        And   I confirm the deletion
        Then  I should be redirected to the product list page
        And   a success message "Product deleted successfully"
    ```

## 3.0 How

> REQUIRED - Ideally the AI Coding Agent should be able to figure out the context and the list of all the tasks and sub-tasks needed to complete this Intent.

### 3.1 Implementation Context

> REQUIRED - Provide some implementation context about the tasks listed below.

The Catalog Product CRUD actions will use Domain Resource Action architecture for both the web layer and business logic layer as per the instructions, guidelines and module examples in the ARCHITECTURE documentation.

The task to implement the Catalog Product CRUD actions will use a TDD-first approach that will adhere to the guidelines specified in the DEVELOPMENT_WORKFLOW.

### 3.2 Tasks

> REQUIRED - List here the Tasks and sub-tasks to complete this Intent.

> REQUIRED - The tasks to define the tests **MUST** be created in the same order of the Gherkin Scenarios, reflect or use their title, and follow the red-green-refactor cycle. If no Gherkin scenarios exist then you **MUST** stop and add them with user feedback. You are allowed to create more tests for scenarios and edge cases not listed in the Gherkin scenarios. No need to create sub-tasks with the steps defined in the development workflow guidelines, like the ones for TDD or Task Completion protocol, because they **MUST** always be followed without the need to have sub-tasks defining them.

* [ ] 1.0 - Generating the Catalogs Products CRUD Actions with LiveView:
    - [ ] 1.1 - Run `mix phx.gen.live Catalogs.Products Product products name:string desc:string --web Catalogs.Products`
    - [ ] 1.2 - Add live routes:
        - [ ] 1.2.1 - Add a new `scope "/catalogs/products", MyAppWeb.Catalogs.Products` in `lib/my_app_web/router.ex` that pipes through `:browser` and wraps routes in `live_session :catalogs_products_require_authenticated_user` with `on_mount: [{MyAppWeb.Accounts.Users.UserAuth, :require_authenticated}]`.
        - [ ] 1.2.2 - Inside the live_session, add all product routes removing the duplicated `products` from paths (e.g., `/` for index, `/new` for new, `/:id` for show, `/:id/edit` for edit)
    - [ ] 1.3 - Verify and fix routes:
        - [ ] 1.3.1 - Run `mix compile` to find all modules with route warnings.
        - [ ] 1.3.2 - Create a list of files with route warnings from the compile output.
        - [ ] 1.3.3 - Use find-and-replace tool to fix all route references in one pass across all files in the list.
        - [ ] 1.3.4 - Run `mix compile` again to verify no route warnings remain.
        - [ ] 1.3.5 - Run `mix test` to find all tests with routes to be fixed.
        - [ ] 1.3.6 - Create a list of files with routes to fix from the tests output
        - [ ] 1.3.7 - Use find-and-replace tool to fix all route references in one pass across all test files in the list.
        - [ ] 1.3.8 - Run `mix test` to ensure all tests using routes are now fixed.
    - [ ] 1.4 - Run `mix ecto.migrate` to apply the new database migrations.
* [ ] 2.0 - Refactor the Phoenix Context `MyApp.Catalogs.Products` into `MyApp.Catalogs.CatalogsProductsAPI` to follow the Domain Resource Action architecture:
    - [ ] 2.1 - mv `lib/my_app/catalogs/products.ex` to `lib/my_app/catalogs/catalogs_products_api.ex` and update the module definition to `MyApp.Catalogs.CatalogsProductsAPI`.
    - [ ] 2.2 - Extract each function body into its own module with only one public function named after the action, without the resource name, at `lib/my_app/catalogs/products/<action>/<action>_catalog_product.ex`. For example: `lib/my_app/catalogs/products/create/create_catalog_product.ex` with a function named `create`. The `CatalogsProductsAPI` function header is kept, but its body its now only calling the new action module function, but without using `defdelegate`, otherwise we lose the API contract. Private functions from the context also need to be extracted to an action, like `broadcast`.
    - [ ] 2.3 - Update all previous calls from the web layer to the old Phoenix Context `MyApp.Catalogs.Products` into `MyApp.Catalogs.CatalogsProductsAPI`.
    - [ ] 2.4 - Update the tests for the now refactored `MyApp.Catalogs.Products` Phoenix context to test instead `MyApp.Catalogs.CatalogsProductsAPI`. Rename the test file, Module name, and then replace each call to the context with a call to new API module.
    - [ ] 2.5 - Run `mix test` to ensure no test is broken after the refactor. If any test is broken, fix it before proceeding.
* [ ] 3.0 - Verify authentication and user scoping in the LiveView tests for Catalogs Products, with the TDD red-green-refactor cycle:
    - [ ] 3.1 - Review and update generated LiveView tests to ensure they test user scoping on resources.
    - [ ] 3.2 - Add test for index page displaying only current user's articles and not other users' articles
    - [ ] 3.3 - Add test for preventing view of another user's article
    - [ ] 3.4 - Add test for preventing edit of another user's article
    - [ ] 3.5 - Add test for preventing deletion of another user's article
* [ ] 4.0 - Add navigation links to the new Catalogs Products resource into the top menu bar with a red-green-refactor TDD approach:
    - [ ] 4.1 - Add the tests to the home page test file `test/my_app_web/controllers/page_controller_test.exs` to ensure the top menu has a link to each Catalogs Products action as a drop-down menu.
    - [ ] 4.2 - Find the top menu bar on the app root layout at `lib/my_app_web/components/layouts/root.html.heex` and add the links for each action as a drop-down.
<!-- ai_agents:planning:intent_example:end -->
<!-- ai_agents:planning:end -->

<!-- ai_agents:development_workflow:start -->
# Development Workflow

This document provides guidance to AI coding agents, AI coding assistants and LLMs, often referred to as **you**, for the development workflow to use when working in this project.

You **MUST** assume the role of a **STAFF SOFTWARE ENGINEER** while planning and creating the Intent with the tasks and sub-tasks, and assume the role of a **SENIOR SOFTWARE ENGINEER** when implementing the planned tasks and sub-tasks in the Intent. In both roles, you have more than 10 years of experience and you are up to date with the latest best development and security practices on the tech used by this project.

**CRITICAL: Don't get stuck in commands that require user interaction. Immediately abort and try to find if the command as a non-interactive flag that can be used. If not use the bash trick `yes | command` or similar.**

## 1. Intent Implementation

You **MUST** follow the INTENT_SPECIFICATION document for the protocol to implement an Intent, which can be found at `## 4. Intent Implementation Protocol`.


## 2. TDD First

**IMPORTANT: When creating tests there is no need to use mocks for accessing the database or other modules the current module depends on. Only create mocks for tests that will reach the external world, like third-party APIs, webhooks, mail services, etc.**

### 2.1 TDD First - Rules

1. You **MUST** write comprehensive tests to cover all code paths, starting **ALWAYS** by the primary use cases, followed by covering all the remaining use cases, and then by edge cases. You **MUST NEVER** start by writing tests for dummy or sanity check tests cases. All written tests **MUST** follow a red-green-refactor cycle, without any exceptions:
1. **RED** - The test **MUST** fail without compiler warnings or errors, but you **MUST NOT** implement the full working code under test to solve the warning or the error, otherwise you get a GREEN test without a having first a correct RED failing test. You **MUST** implement only the minimal required code to satisfy the warning or error for the code under test, like creating the Module/Class/File with an **empty** function by preference, or in alternative one function that returns `TODO`.
2. **GREEN** - Implement the minimal code required to make the test pass. This code needs to be well crafted, secure, easy to read, reason about, and to modify later.
3. **REFACTOR** - After the test is GREEN inspect the code for opportunities of improvement to follow best practices, avoid common pitfalls, performance issues, security issues (OWASP TOP TEN and more), and to ensure it follows this project guidelines.
4. **TEST RUNNER** - During the red-green-refactor cycle you **MUST** run it only for the file being tested, and/or only for the function being tested when applicable.
5. **COMPILER AND LSP SERVER** - When tests are failing you **MUST** check first for the reason in the warnings and/or errors provided by the Compiler and/or LSP server. If they aren't the reason for the tests failure you **MUST** still fix them before you move on to the next task or sub-task.
2. When you are coding a module/class/file that depends on other ones you **MUST** start by the leaf dependency and work you way up to the file that starts the dependency chain. You **MUST** use the TDD red-green-refactor cycle for this.
3. Don't change the code under test to suit the way you wrote the test. Instead re-write it.
4. Only if a test is really hard to write, then you need to analyze and compare the test and the code under test to determine:
1. If the test is over-engineered, not following best practices, or just not testing what it should. If affirmative for any of them, then rewrite the test.
2. If it is the code under test that is not easily testable, then refactor it for testability.
5. Restrain from adding comments to code or tests, unless you really need to explain WHY it's being done that way. You **MUST** never explain in a comment WHAT it's being done, because that should be obvious from well-written code, that's easy to understand and reason about.


### 2.2 TDD First - Workflow Steps

These TDD steps **MUST** be used always to adhere to the TDD first approach and practice a red-green-refactor cycle:

1. First, create the Module for the application code with the public function, but no logic on it, only returning `:todo`.
2. Next, create the test Module with only one test for the main success scenario.
3. Then run `bundle exec rspec spec/path/to/file_spec.rb` and the test **MUST** fail (red), because the application code is returning `:todo`, as the application code logic to make it pass wasn't written yet. If the test fails because of any other reason (e.g. syntax errors, missing imports, compilation warnings or errors, etc.) then you **MUST** fix them before proceeding to the next step.
4. Now, implement the minimal amount of application code to make the test pass (green).
   The code needs to be easy to understand, reason about, and change, just as a senior engineer with more than a decade of experience would write.
5. If there is any opportunity to make the code being tested more easy to reason about, maintain, secure, testable, performant, etc., then ask the user if you can refactor it, and give the user a summary of what you plan to and why. Only proceed to propose code changes if the user accepts to refactor the code.
6. Repeat these steps by going back to step 1. again. This **MUST** be repeated until the test suite covers:
- all success scenarios.
- all failure scenarios.
- all edge cases.
- all code paths.

**IMPORTANT:** To translate this TDD first approach to tasks and sub-tasks, see the INTENT_EXAMPLE documentation file to implement the CRUD actions for a Domain Resource in the business logic and web logic layers.

## 3. Incremental Code Generation Workflow

**IMPORTANT: Before proposing any code for a user request, the AI Coding Agent **MUST** always use the detailed instructions from PLANNING documentation to create Intent(s) and Tasks and sub-tasks to have a detailed and concise step-by-step plan to accomplish the user request.**

**CRITICAL: You **MUST** never start working on an Intent, task or sub-task if you don't have a clean git working tree. Always check for uncommitted changes with `git status`, and if any exist, ask user guidance on how to proceed. Uncommitted changes from your working shouldn't exist, unless you failed to follow the Task Completion Protocol enumerated in this document.**

**CRITICAL: After completing each step below, you MUST STOP and WAIT for explicit user approval before proceeding to the next task. When you ask "Ready for task X?", you are NOT allowed to continue until the user responds. NEVER create code for the next task until the user says "yes", "proceed", "continue", "ok" or similar.**

Work on an Intent at a time, executing step-by-step each task and sub-task from it, with user feedback in between, following the Domain Resource Action pattern as per the detailed instructions at ARCHITECTURE documentation.

You **MUST** not try to propose code changes for multiple tasks or sub-tasks in one go. Always keep code changes focused on the sub-task being executed.


## 4. Task Implementation Protocol

Repeat each step in the below process for each Task and sub-task on an Intent:

1. **Clean Git Working Tree:** Run `git status` to ensure that there are no uncommitted changes. Before continuing to step 2, ask for user guidance if they exist.
2. **Always ask for user confirmation** before starting to work on a parent task listed in the Intent - this is MANDATORY. Sub-tasks don't require user confirmation to start or for proceeding to the next one.
3. **If user says "continue", "proceed", "yes", "y" or "ok"**, start or continue to work on the Intent Task.
4. **One sub-task at a time:** You **MUST** only propose code changes for one single sub-task. Do **NOT** try to add code changes to accomplish more than one sub-task. This is MANDATORY.
5. **If user provides feedback**, adjust and re-present your solution.
6. **If user says "skip X"**, skip that task, sub-task or Intent.
7. **If user says "edit/refine/refactor X" or similar**, stop and iterate with the user to refine the Intent, task or sub-task.
8. **Keep focused** - don't jump ahead, don't create multiple Intents, tasks or sub-tasks at once. Use baby-steps.
9. **Brief and concise explanations** - what you did, not verbose details. Start by the most important things to be told, followed by some context when it makes sense, and if only if strictly necessary a few more specific details.
10. **Task Completion** - once you think you completed a sub-task, you **MUST** follow the [Task Completion Protocol](#task-completion-protocol).

This approach enables early validation, catches issues before coding, and allows mid-course adjustments.

## 5. Task Completion Protocol

The following steps apply:

1. When you finish a **sub‑task**, you **MUST** immediately mark it as completed by changing `[ ]` to `[x]`. This is **MANDATORY** to be done before proceeding to the next sub-task or task. You **MUST** run `bundle exec rspec <spec_file>` to confirm that all tests are passing, otherwise you need to fix them.
2. If **all** sub-tasks underneath a parent task are now `[x]`, follow this sequence:
1. **First**: Run `bundle exec rspec spec` to run the full test suite and `bundle exec rubocop` for style checks. Skip this step when creating an Intent.
2. **Only if all tests and checks pass**: Proceed, otherwise go back and fix the failing tests or Rubocop offences.
3. **Clean up**: Remove any temporary files and temporary code.
4. **Tasks Tracking**: Mark the **parent task** as completed. Skip this step when creating an Intent.

3. **Do NOT commit automatically.** Never run `git add` or `git commit` unless the user explicitly instructs you to do so. When the user asks to commit, use a descriptive commit message:
- Intent creation: `git commit -m "Intent 1 Planning - Bug (app-zugang): Team-Plan sichtbar trotz fehlendem Recht." -m "Intent planned tasks:" -m "- List one task per -m flag"`
- Development work: `git commit -m "bug (app-zugang): team-plan abilities in ZugangEntity. Intent: 1, Task: 1" -m "- key change 1" -m "- key change 2"`
- Never add a commit trailer. Omit any "Co-authored-by".

4. Stop after each task, ask for user confirmation that they are satisfied with the implementation before proceeding to the next task.
<!-- ai_agents:development_workflow:end -->

<!-- usage-rules-end -->