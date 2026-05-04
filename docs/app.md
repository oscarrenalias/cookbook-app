# App functionality and features

## Recipe management

App will allow to browse my recipes in CookLang format, which are grouped in folders. 

The current vision is that recipes are stored somewhere in the user's iPhone or iCloud Drive.

Please note that getting recipes into the folder is not the app's concern.

## Meal planning

The app will support the ggeneration of meal plans (weekly, monthly, whatever) out of recipes.

There can be multiple meals at any given time. The app will provide the ability to list, edit and manage (delete) existing meal plans. 

Meal plans should be managed as simple text-based files. 

The functional flow is as follows:

1. select a recipe
2. Tap "add to meal plan"
3. select meal plan or create a new one
4. save the meal plan. 

Viewing a meal plan should also allow to delete existing meals from it.

## Shopping lists

The app will also manage shopping lists; shopping lists can either be generated from a meal plan or by adding meals to a shopping list:

When doing it via a meal plan:

1. select meal plan
2. tap "create shopping list"
3. provide a name for the new shopping list
4. save the new shopping list

When doing it via individual recipes:

1. select recipe
2. tap "add to shopping list"
3. select existing shopping list, or create a new one
4. save the shopping list

There can be multiple named shopping lists, not just one. 

Shopping list should be displayed in reverse chronological order (from new to old). It should also be possible to:

- delete an existing shopping list
- visualize an existing shopping list
- add a new item to an existing shopping list (one-off)

# Key app components

## CookLang Parsing

Ability to parse .cook recipes is essential. There's a very old Swift reference implementation but it's not maintained, and the current canonical implementation is in Rust:

- [CookLang spec](https://cooklang.org/docs/spec/)
- [Swift CookLang parser](https://github.com/cooklang/cooklang-swift) -- note: no longer maintained but can be reused as reference for our own
- [Rust CookLang parser](https://github.com/cooklang/cooklang-rs) -- this is the reference implementation

## Meal plans

Cooklang has a convention for meal plans here: https://cooklang.org/docs/use-cases/meal-planning/

## Shopping lists

Shopping lists are expected to be plain Markdown files using Markdown conventions for checklists, e.g.:

```markdown
# Shopping list 02.05.2025

- [ ] 1 piece iceberg lettuce
- [ ] 1kg strawberries
- [X] 600g minced meat
```

The application should be able to deal with the Cook CLI's file ```aisle.conf```, which will be provided to the app. This is an example of aisle.conf (it's my own, actually): (https://raw.githubusercontent.com/oscarrenalias/cookbook/refs/heads/main/config/aisle.conf). This file will be provided to the app.

# UI 

There's a mockup of the first screen available ![ui mockup](./mockups/mockup-recipes%20view.png)