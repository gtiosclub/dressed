# Student starter tickets

This backlog replaces the earlier phase-sized student assignments. Each ticket asks for one basic function or small view, using plain-language instructions and a concrete example. The task-size reference is last year's [SideQuest task document](https://docs.google.com/document/d/1wiEmdK0Y3LPy2bUQQ7BZNhrf8yw1YhgU1M4lPjiMK1s/edit?tab=t.nozbwnwzo21g).

There are six tasks each for `data`, `viz`, and `social`. GitHub is the live source for status and assignments. Complex work stays in separate `lead` issues; it is not part of these student acceptance checklists. Read [officer guidance](officers/README.md) before adding more tickets.

## DATA-01 - Build the import-source buttons

[Open issue #52](https://github.com/gtiosclub/dressed/issues/52)

### Why we need this

Users need to choose how to add a picture. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Build AddSourceMenu with Camera and Photo Library buttons.

### What your code receives and returns

No inputs. Two callbacks: onCamera and onPhotoLibrary. A callback is a function passed in by the parent view so your component can report a tap without deciding what happens next.

### Example

For example, when someone taps Photo Library, call onPhotoLibrary. The parent screen will open the picker later; this ticket only builds the buttons.

### Where to work

Suggested file: `dressed/Camera/Views/AddSourceMenu.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] Both buttons have a text label and icon.
- [ ] Each tap calls its matching callback exactly once.
- [ ] A preview displays the buttons without opening a camera or photo picker.

### You do not need to build

Opening the camera/library, permissions, extraction and uploads. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Start with made-up local data. For a view, add a SwiftUI preview and show the component in a simulator. For a plain function, call it with a few small example arrays and check the returned values. You do not need a working backend or a complete screen.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `data`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.


## DATA-02 - Build one selectable clothing-review row

[Open issue #54](https://github.com/gtiosclub/dressed/issues/54)

### Why we need this

Users need to choose which detected item to keep. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Build ImportCandidateRow for one item, with a name, supplied thumbnail and selection control.

### What your code receives and returns

Input: name, SwiftUI Image and isSelected binding. Output: changed selection. A binding lets the parent view see changes to a shared value.

### Example

For example, show a blue shirt with a checked selection control. When the user unchecks it, the parent view should receive false. Nothing should be uploaded or deleted.

### Where to work

Suggested file: `dressed/Camera/Views/ImportCandidateRow.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] The row displays the supplied name and image.
- [ ] Tapping the selection control toggles the binding.
- [ ] Previews show selected and unselected examples.

### You do not need to build

Detection, crop editing, forms, saving and the full review screen. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Start with made-up local data. For a view, add a SwiftUI preview and show the component in a simulator. For a plain function, call it with a few small example arrays and check the returned values. You do not need a working backend or a complete screen.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `data`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.


## DATA-03 - Write the saveOutfit function

[Open issue #57](https://github.com/gtiosclub/dressed/issues/57)

### Why we need this

The outfit screen needs a basic way to store one completed outfit. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Add saveOutfit(_ outfit: Outfit) async throws. Convert the supplied record into Firebase fields and write it to users/{ownerId}/outfits/{id}.

### What your code receives and returns

Input: an Outfit from the shared template. Output: Void or the Firebase error. `async` lets the function wait for Firebase without blocking the screen. `throws` means it reports a failure to the calling code, which will decide how to show the error.

### Example

For example, an outfit with id outfit_001 and ownerId user_a should be saved at users/user_a/outfits/outfit_001. Saving it again should update the same document.

### Where to work

Suggested file: `dressed/Common/Firebase/OutfitFunctions.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] The function writes all supplied fields to the stated document path.
- [ ] Calling it again with the same ID updates that document instead of creating another.
- [ ] A failed write throws to the caller; no success is returned on failure.

### You do not need to build

Choosing items, creating IDs, canvas layout, ownership rules, transactions and retries. The lead supplies the approved record and development access. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Use the sample record from #49 and the development setup from #51. You can write the function while those are being prepared, but wait for the lead-provided environment before trying a real Firebase call. Show one successful call and one failed call. You do not need to design security rules or a test framework.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `data`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.


## DATA-04 - Write the saveClothingItem function

[Open issue #70](https://github.com/gtiosclub/dressed/issues/70)

### Why we need this

The closet needs a basic function for storing one approved item. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Add saveClothingItem(_ item: ClothingItem) async throws using users/{ownerId}/items/{id}.

### What your code receives and returns

Input: an already prepared ClothingItem. Output: Void or the Firebase error. `async` lets the function wait for Firebase without blocking the screen. `throws` means it reports a failure to the calling code, which will decide how to show the error.

### Example

For example, a prepared blue-shirt item with id item_001 belongs at users/user_a/items/item_001. The caller has already chosen the category and image path.

### Where to work

Suggested file: `dressed/Common/Firebase/ClothingFunctions.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] A supplied fixture is written with its field names intact.
- [ ] The record uses the supplied item ID and owner ID.
- [ ] A failed write throws to the caller.

### You do not need to build

Image processing, uploads, ID creation, review screens, security rules and multi-step cleanup. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Use the sample record from #49 and the development setup from #51. You can write the function while those are being prepared, but wait for the lead-provided environment before trying a real Firebase call. Show one successful call and one failed call. You do not need to design security rules or a test framework.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `data`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.


## DATA-05 - Write the fetchClothingItems function

[Open issue #71](https://github.com/gtiosclub/dressed/issues/71)

### Why we need this

The closet view needs a list of one user’s saved items. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Add fetchClothingItems(ownerId: String) async throws -> [ClothingItem]. Read users/{ownerId}/items and decode each record.

### What your code receives and returns

Input: the current user ID supplied by Neal’s session code. Output: an array of ClothingItem. `async` lets the function wait for Firebase without blocking the screen. `throws` means it reports a failure to the calling code, which will decide how to show the error.

### Example

For example, if user_a has a shirt and a pair of pants in their items collection, the function returns those two ClothingItem values. If there are no items, return an empty list.

### Where to work

Suggested file: `dressed/Common/Firebase/ClothingFunctions.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] An empty collection returns an empty array.
- [ ] Two valid fixture documents return two decoded items.
- [ ] A request or decoding failure throws instead of silently dropping records.

### You do not need to build

Pagination, filtering, live listeners, caching and authentication/rules design. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Use the sample record from #49 and the development setup from #51. You can write the function while those are being prepared, but wait for the lead-provided environment before trying a real Firebase call. Show one successful call and one failed call. You do not need to design security rules or a test framework.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `data`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.


## DATA-06 - Write the uploadClothingImage function

[Open issue #72](https://github.com/gtiosclub/dressed/issues/72)

### Why we need this

The import flow needs one reusable image upload function. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Add uploadClothingImage(jpegData: Data, storagePath: String) async throws -> String. Upload JPEG bytes to the supplied private Storage path and return that path.

### What your code receives and returns

Inputs: JPEG bytes and an approved Storage path. Output: the same path after success. `async` lets the function wait for Firebase without blocking the screen. `throws` means it reports a failure to the calling code, which will decide how to show the error.

### Example

For example, upload the supplied JPEG bytes to users/user_a/items/item_001/original.jpg. Return that path only when Firebase says the upload succeeded.

### Where to work

Suggested file: `dressed/Common/Firebase/ImageFunctions.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] The supplied bytes upload with image/jpeg metadata.
- [ ] The path is returned only after the upload succeeds.
- [ ] A failed upload throws to the caller.

### You do not need to build

Compression, image picking, signed URLs, path generation, rules and orphan cleanup. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Use the sample record from #49 and the development setup from #51. You can write the function while those are being prepared, but wait for the lead-provided environment before trying a real Firebase call. Show one successful call and one failed call. You do not need to design security rules or a test framework.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `data`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.


## VIZ-01 - Build one clothing-item card

[Open issue #56](https://github.com/gtiosclub/dressed/issues/56)

### Why we need this

The closet needs a reusable small card for a garment. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Build ClothingItemCard with a supplied image, name and category label.

### What your code receives and returns

Input: SwiftUI Image, name and category text. Output: onTap callback. A callback is a function passed in by the parent view so your component can report a tap without deciding what happens next.

### Example

For example, a preview can pass in a shirt icon, Blue shirt, and Tops. Tapping the card should run the action supplied by the parent view, without opening a screen by itself.

### Where to work

Suggested file: `dressed/Closet/Views/ClothingItemCard.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] The card displays all three inputs.
- [ ] Long names wrap or truncate without covering the image.
- [ ] Tapping calls onTap; a preview works using a local placeholder image.

### You do not need to build

Remote image loading, Firebase, filtering, navigation and a full closet page. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Start with made-up local data. For a view, add a SwiftUI preview and show the component in a simulator. For a plain function, call it with a few small example arrays and check the returned values. You do not need a working backend or a complete screen.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `viz`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.


## VIZ-02 - Build category-selection buttons

[Open issue #73](https://github.com/gtiosclub/dressed/issues/73)

### Why we need this

Users need to pick a closet category. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Build CategorySelector with All and the shared ClothingCategory cases.

### What your code receives and returns

Input: selected ClothingCategory? binding; nil means All. Output: updated selection. A binding lets the parent view see changes to a shared value.

### Example

For example, when the user taps Pants, the selected value becomes .pants. Tapping All changes the value to nil. The parent view will decide which clothes to show.

### Where to work

Suggested file: `dressed/Closet/Views/CategorySelector.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] All, Tops, Pants and Skirts are separate choices.
- [ ] The selected choice is visually distinct.
- [ ] Tapping a choice updates the binding; it does not filter or fetch data.

### You do not need to build

Backend calls, filtering logic and complete page layout. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Start with made-up local data. For a view, add a SwiftUI preview and show the component in a simulator. For a plain function, call it with a few small example arrays and check the returned values. You do not need a working backend or a complete screen.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `viz`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.


## VIZ-03 - Build a clothing-card grid

[Open issue #74](https://github.com/gtiosclub/dressed/issues/74)

### Why we need this

The closet needs a layout for several cards. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Build ClosetItemGrid by arranging ClothingItemCard views in a two-column grid with a short empty message.

### What your code receives and returns

Input: display items with stable IDs and local images. Output: selected item ID callback. A callback is a function passed in by the parent view so your component can report a tap without deciding what happens next.

### Example

For example, six sample cards should appear in three rows of two. With no items, show No clothes yet instead of a blank area.

### Where to work

Suggested file: `dressed/Closet/Views/ClosetItemGrid.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] A six-item preview displays every item once.
- [ ] An empty input shows No clothes yet.
- [ ] A tap forwards the correct item ID.

### You do not need to build

Fetching records, remote images, category controls and detail screens. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Start with made-up local data. For a view, add a SwiftUI preview and show the component in a simulator. For a plain function, call it with a few small example arrays and check the returned values. You do not need a working backend or a complete screen.

Reuse the clothing card from #56. Until it is available, sketch the surrounding layout; do not build a competing card.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `viz`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. Blocked by: #56.


## VIZ-04 - Write the clothing-category filter

[Open issue #75](https://github.com/gtiosclub/dressed/issues/75)

### Why we need this

Category selection needs a small reusable filtering function. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Add filterClothingItems(_ items: [ClothingItem], category: ClothingCategory?) -> [ClothingItem].

### What your code receives and returns

Input: items and optional category. Output: matching items in their original order.

### Example

For example, given a shirt, pants, and a skirt, choosing .pants returns only the pants. Choosing nil returns all three in their original order.

### Where to work

Suggested file: `dressed/Closet/ViewModels/ClothingFilter.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] nil returns every item.
- [ ] Selecting pants excludes skirts and other categories.
- [ ] An empty input returns an empty array.

### You do not need to build

SwiftUI, network calls, sorting and search. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Start with made-up local data. For a view, add a SwiftUI preview and show the component in a simulator. For a plain function, call it with a few small example arrays and check the returned values. You do not need a working backend or a complete screen.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `viz`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.


## VIZ-05 - Build a horizontal outfit-item tray

[Open issue #76](https://github.com/gtiosclub/dressed/issues/76)

### Why we need this

The outfit editor needs a small chooser for available garments. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Build OutfitItemTray as a horizontal row of existing ClothingItemCard views.

### What your code receives and returns

Input: display items. Output: selected item ID callback. A callback is a function passed in by the parent view so your component can report a tap without deciding what happens next.

### Example

For example, show a shirt, pants, and shoes in one horizontal row. Tapping the shoes sends the shoe item ID back to the parent; it does not place anything on a canvas.

### Where to work

Suggested file: `dressed/Outfits/Views/OutfitItemTray.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] Items scroll horizontally.
- [ ] Tapping a card returns that item’s ID.
- [ ] Empty input displays a short message.

### You do not need to build

Dragging, canvas placement, avatar rendering and saving outfits. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Start with made-up local data. For a view, add a SwiftUI preview and show the component in a simulator. For a plain function, call it with a few small example arrays and check the returned values. You do not need a working backend or a complete screen.

Reuse the clothing card from #56. Until it is available, sketch the surrounding layout; do not build a competing card.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `viz`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. Blocked by: #56.


## VIZ-06 - Build a selected-outfit item row

[Open issue #77](https://github.com/gtiosclub/dressed/issues/77)

### Why we need this

Users need to see an outfit item and remove it from their selection. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Build SelectedOutfitItemRow with a supplied thumbnail, item name and remove button.

### What your code receives and returns

Input: item ID, name, Image. Output: onRemove(itemId).

### Example

For example, a row for item_001 shows Blue shirt and a remove button. When tapped, the button sends item_001 to the parent, which will update the selection.

### Where to work

Suggested file: `dressed/Outfits/Views/SelectedOutfitItemRow.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] The thumbnail and name display.
- [ ] The remove button sends the correct item ID.
- [ ] The view leaves array updates to its caller.

### You do not need to build

Database deletion, outfit persistence and a complete editor. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Start with made-up local data. For a view, add a SwiftUI preview and show the component in a simulator. For a plain function, call it with a few small example arrays and check the returned values. You do not need a working backend or a complete screen.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `viz`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.


## SOCIAL-01 - Build one outfit-post card

[Open issue #60](https://github.com/gtiosclub/dressed/issues/60)

### Why we need this

Discovery needs a reusable card for a post. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Build OutfitPostCard with a supplied outfit image, username, caption and save button.

### What your code receives and returns

Inputs: Image, username, caption and isSaved. Output: onSaveTap callback. A callback is a function passed in by the parent view so your component can report a tap without deciding what happens next.

### Example

For example, show a supplied outfit image with the username example_user and caption Monday outfit. A save-button tap asks the parent to save it; the card itself makes no database call.

### Where to work

Suggested file: `dressed/Discovery/Views/OutfitPostCard.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] All supplied text and the image display.
- [ ] Saved and unsaved previews show distinct button states.
- [ ] A save tap emits one callback and performs no network request.

### You do not need to build

Feed fetching, pagination, profiles, likes and navigation. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Start with made-up local data. For a view, add a SwiftUI preview and show the component in a simulator. For a plain function, call it with a few small example arrays and check the returned values. You do not need a working backend or a complete screen.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `social`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.


## SOCIAL-02 - Write the savePost function

[Open issue #61](https://github.com/gtiosclub/dressed/issues/61)

### Why we need this

Users need a basic function for bookmarking a post. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Add savePost(_ savedPost: SavedPost) async throws. Write users/{ownerId}/savedPosts/{postId}, using the shared record.

### What your code receives and returns

Input: prepared SavedPost with id equal to postId. Output: Void or error. `async` lets the function wait for Firebase without blocking the screen. `throws` means it reports a failure to the calling code, which will decide how to show the error.

### Example

For example, saving post_001 for user_a writes users/user_a/savedPosts/post_001. Pressing Save twice should still leave only that one saved-post document.

### Where to work

Suggested file: `dressed/Common/Firebase/SavedPostFunctions.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] A valid fixture writes to the documented path.
- [ ] Saving the same post twice leaves one document.
- [ ] A write failure throws to the caller.

### You do not need to build

Unsave, lists, UI state, deletion policies and backend rules. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Use the sample record from #49 and the development setup from #51. You can write the function while those are being prepared, but wait for the lead-provided environment before trying a real Firebase call. Show one successful call and one failed call. You do not need to design security rules or a test framework.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `social`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.


## SOCIAL-03 - Build a reusable search field

[Open issue #64](https://github.com/gtiosclub/dressed/issues/64)

### Why we need this

Discovery needs a place for users to type a search. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Build SearchField with a query binding, search icon and clear button.

### What your code receives and returns

Input/output: String binding. A binding lets the parent view see changes to a shared value.

### Example

For example, typing blue shirt updates the query value to blue shirt. Pressing the clear button changes it to an empty string. There is no search request in this view.

### Where to work

Suggested file: `dressed/Discovery/Views/SearchField.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] Typing updates the binding.
- [ ] Clear sets the query to an empty string.
- [ ] A preview works without a backend.

### You do not need to build

Search algorithms, Firebase queries, recommendations and results screens. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Start with made-up local data. For a view, add a SwiftUI preview and show the component in a simulator. For a plain function, call it with a few small example arrays and check the returned values. You do not need a working backend or a complete screen.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `social`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.


## SOCIAL-04 - Build the profile header

[Open issue #78](https://github.com/gtiosclub/dressed/issues/78)

### Why we need this

A profile needs a small header above its content. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Build ProfileHeader with a supplied avatar image, username and display name.

### What your code receives and returns

Inputs: Image and two strings. No backend behavior.

### Example

For example, use a local person icon, the username example_user, and the display name Example Person. This is just the header, not the whole profile page.

### Where to work

Suggested file: `dressed/Profile/Views/ProfileHeader.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] The image and both names display.
- [ ] A long display name does not overlap the avatar.
- [ ] A preview uses made-up local data.

### You do not need to build

Follow counts, edit profile, uploads and full profile screens. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Start with made-up local data. For a view, add a SwiftUI preview and show the component in a simulator. For a plain function, call it with a few small example arrays and check the returned values. You do not need a working backend or a complete screen.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `social`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.


## SOCIAL-05 - Build a post clothing-breakdown row

[Open issue #79](https://github.com/gtiosclub/dressed/issues/79)

### Why we need this

A post needs a compact list of the garments in the outfit. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Build PostClothingBreakdown as a horizontal row using ClothingItemCard.

### What your code receives and returns

Input: display items with IDs and supplied images. Output: selected ID callback. A callback is a function passed in by the parent view so your component can report a tap without deciding what happens next.

### Example

For example, a post containing a shirt and pants should show two clothing cards. A tap sends the matching item ID to the parent; it does not read anyone’s private closet.

### Where to work

Suggested file: `dressed/Discovery/Views/PostClothingBreakdown.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] Every supplied garment appears once.
- [ ] Tapping returns the correct ID.
- [ ] An empty array shows a short no-items message.

### You do not need to build

Loading private closet records, product matching and navigation. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Start with made-up local data. For a view, add a SwiftUI preview and show the component in a simulator. For a plain function, call it with a few small example arrays and check the returned values. You do not need a working backend or a complete screen.

Reuse the clothing card from #56. Until it is available, sketch the surrounding layout; do not build a competing card.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `social`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. Blocked by: #56.


## SOCIAL-06 - Write the fetchRecentPosts function

[Open issue #80](https://github.com/gtiosclub/dressed/issues/80)

### Why we need this

The feed needs a first list of published posts. This ticket asks for one small piece that a lead will connect to the rest of the app later.

### What to build

Add fetchRecentPosts() async throws -> [Post]. Read at most 20 posts ordered by createdAt descending.

### What your code receives and returns

No arguments. Output: Post array or an error. `async` lets the function wait for Firebase without blocking the screen. `throws` means it reports a failure to the calling code, which will decide how to show the error.

### Example

For example, if there are three posts, return all three with the newest first. If there are 25 posts, return only the newest 20. Loading the next page is not part of this ticket.

### Where to work

Suggested file: `dressed/Common/Firebase/PostFunctions.swift`. Check whether it already exists before creating it. Reuse the model files in `dressed/Common/Models`; do not create a second copy of an existing model. The lead can help you find the right sample data.

### How we know it is done

- [ ] The result contains at most 20 decoded posts, newest first.
- [ ] An empty collection returns an empty array.
- [ ] Query/decoding errors are returned to the caller.

### You do not need to build

Pagination, ranking, live updates, publication and feed UI. These belong to separate lead tasks. Ask for help if completing this ticket seems to require any of them.

### Getting started and checking your work

Use the sample record from #49 and the development setup from #51. You can write the function while those are being prepared, but wait for the lead-provided environment before trying a real Firebase call. Show one successful call and one failed call. You do not need to design security rules or a test framework.

Use the [starter templates](https://github.com/gtiosclub/dressed/tree/main/templates) only when they help. A small function does not need a new service framework, and a simple view does not automatically need its own view model.

Team/project: `social`. Priority: Medium. Stage: Student starter tasks. Individual assignee: unassigned. Estimate: not set. No other student ticket is required to start.
