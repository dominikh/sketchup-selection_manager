The purpose of Selection Manager is to be able to save named
selections and recall them later, even after restarting SketchUp and
reloading a model.

# Features
- keep multiple, named selections around
- Modify saved selections by adding/removing new entities to it
- Automatically update a saved selection if parts of it get deleted
- Save and load selections with/from the model

# Usage
The plugin adds a new sub menu to the context menu, called _Selection Manager_. This menu contains the following items:

- _Add new selection_ -- Asks for a name under which to save the
  selection. If the name is already in use, the user gets asked
  whether the existing one should be replaced or extended.
- _Load selections from model_ -- Loads saved selections from the
  model. See the caveats section for more information.

Additionally, the menu has one sub menu per saved selection, which
features the following items:

- _Select_ -- Recalls the saved selection
- _Add to selection_ -- Adds the current selection to the saved
  selection
- _Remove from selection_ -- Removes the current selection from the
  saved selection
- _Remove_ -- Completely remove the saved selection. Warning: There is
  no confirmation dialog.

# Caveats
- Loading the selections from a model can take some time. My tests,
  with ~70k entities and a couple of selections, took between 0.5 and
  1 seconds.
- The selections get saved as attributes on the entities. To avoid
  copying those when copying an entity, the attributes will only be
  set temporarily during saving; they will also get removed as soon as
  _Load selections from model"_has been used. That means that the
  selections should be loaded right after opening the model and that
  they cannot be loaded again, without opening the model again.

