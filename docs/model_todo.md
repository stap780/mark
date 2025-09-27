# Model To‑Do (Mark app)

Purpose: shared checklist for adding a new model/feature so the team stays consistent with Basecamp‑style multitenancy, Tailwind, and Hotwire.

## “Copy model” policy

When we say “copy model,” we do NOT copy random files directly. We:

1) Study the reference implementation
   - Read the reference app’s models, controllers, routes, views, jobs/services.
   - Extract the essential data model and behavior (attributes, associations, callbacks, streams).

2) Scaffold it in this app using base Rails commands
   - Generate models/controllers/migrations with Rails generators so we get proper 14‑digit timestamps and idiomatic structure.
   - Adjust the generated code to fit our app conventions (account scoping, Tailwind, Hotwire, responders).

3) Migrate and wire up UI & streams
   - Run migrations, add account‑scoped routes, Tailwind views/partials, and Turbo stream updates.

## Base flow (checklist)

- Data model
  - Decide attributes, enums, indexes, and associations.
  - Prefer references with foreign keys.
- Generate
  - Model and/or scaffold via Rails generators (examples below).
  - Add account:references when the record is tenant‑owned.
- Migrate
  - bin/rails db:migrate (ensure 14‑digit filenames from generators).
- Routes
  - Add under path scope: /accounts/:account_id.
- Controller
  - Load via current_account.association (no global Current usage in queries).
- Views
  - Tailwind UI, small partials, shared/errors, consistent button/link styles.
  - Use Turbo Frames/Streams where it improves UX.
- Broadcasts
  - Scope broadcasts to [account, "<stream>"] with static DOM targets.
- Links inside broadcasted partials
  - Build nested URLs from the record association (e.g., edit_account_…_path(record.account, record)), not Current.
- Tests (optional but preferred)
  - Model validations, a couple of controller/system happy‑path checks.

## Rails generator templates

Replace placeholders with actual names/fields.

- Model:
  - rails g model ModelName field1:type field2:type account:references
- Scaffold (model + controller + views + routes entry):
  - rails g scaffold ResourceName field1:type field2:type account:references
- Controller only:
  - rails g controller ResourceNames index show new edit

Then run:
- bin/rails db:migrate

## Account‑scoped routes pattern

In config/routes.rb:

scope "/accounts/:account_id", as: :account do
  resources :your_resources
end

## Hotwire patterns

- Subscribe in the index view to account‑scoped stream name:
  - turbo_stream_from [current_account, "your_stream"]
- Keep DOM target ids stable (e.g., your_resources) and let broadcasts target those ids.
- For frame navigation (modals/offcanvas), make the frame id constant (e.g., offcanvas) and don’t overload it with account in the id.

## Example: Swatch Group (from myappda → Mark)

- Data model (simplified):
  - SwatchGroup: name, option_name, status, styles, position, account:references
  - SwatchGroupProduct: swatch_group:references, product:references, swatch_label, swatch_value, custom_image_url, position

- Generate (example commands):
  - rails g scaffold SwatchGroup name:string option_name:string status:integer product_page_style:string collection_page_style:string swatch_image_source:string visible_on_store:boolean position:integer account:references
  - rails g model SwatchGroupProduct swatch_group:references product:references swatch_label:string swatch_value:string custom_image_url:string position:integer

- After generation:
  - Add associations to Account (has_many :swatch_groups, :products if needed).
  - Add account‑scoped routes and CRUD controller that uses current_account.swatch_groups.
  - Tailwind views (index/new/edit/show) and partials.
  - Add Turbo Streams/broadcasts scoped to [account, "swatch_groups"].

## Gotchas

- Don’t build nested paths from Current inside broadcasted partials. Use record.account.
- Keep frame ids stable; scope with stream names, not frame ids.
- Use generators to avoid bad migration filenames. 14‑digit timestamps are required for proper ordering.
